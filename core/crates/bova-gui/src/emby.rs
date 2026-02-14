use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::mpsc::{Sender, Receiver, channel};
use std::thread;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EmbyServer {
    pub name: String,
    pub url: String,
    pub username: String, // Store username for display/re-auth if needed
    pub user_id: Option<String>,
    pub access_token: Option<String>,
}

#[derive(Debug, Clone, Deserialize, PartialEq)]
#[serde(rename_all = "PascalCase")] // Emby uses PascalCase for JSON fields
pub struct EmbyItem {
    pub id: String,
    pub name: String,
    pub original_title: Option<String>,
    #[serde(rename = "Type")]
    pub field_type: Option<String>, // "Movie", "Episode", "Series", "Folder", "CollectionFolder"
    pub media_type: Option<String>, // "Video", "Audio"
    pub parent_id: Option<String>,
    pub index_number: Option<i32>,      // Episode number
    pub parent_index_number: Option<i32>, // Season number
    pub run_time_ticks: Option<i64>,
    pub image_tags: Option<HashMap<String, String>>, // Primary image tag
    pub backdrop_image_tags: Option<Vec<String>>,
    pub overview: Option<String>,
    pub production_year: Option<i32>,
    pub community_rating: Option<f32>,
    pub official_rating: Option<String>,
    pub child_count: Option<i32>,  // 子项数量（剧集总数）
    pub recursive_item_count: Option<i32>,  // 递归子项数量
}

#[derive(Debug, Clone)]
pub struct EmbyDashboard {
    pub views: Vec<EmbyItem>,
    pub resume_items: Vec<EmbyItem>,
}

#[derive(Debug, Clone)]
pub enum EmbyEvent {
    AuthSuccess(EmbyServer),
    AuthError(String),
    ItemsLoaded(Vec<EmbyItem>),
    DashboardLoaded(EmbyDashboard),
    ItemsError(String),
    ImageLoaded(String, Vec<u8>), // (image_key, image_data)
    ViewItemsLoaded(String, Vec<EmbyItem>), // (view_id, items) - 用于 Dashboard 预览
    SeasonEpisodesLoaded(String, Vec<EmbyItem>), // (season_id, episodes) - 用于 Series 详情页
    SeriesEpisodeCountLoaded(String, i32), // (series_id, total_episode_count) - 用于显示剧集数量徽章
}

/// Helper to run blocking Emby requests in a background thread
pub struct EmbyClient {
    tx: Sender<EmbyEvent>,
}

impl EmbyClient {
    pub fn new(tx: Sender<EmbyEvent>) -> Self {
        Self { tx }
    }

    pub fn authenticate(&self, mut server: EmbyServer, password: String) {
        let tx = self.tx.clone();
        thread::spawn(move || {
            let client = reqwest::blocking::Client::new();
            let auth_url = format!("{}/Users/AuthenticateByName", server.url.trim_end_matches('/'));
            
            let body = serde_json::json!({
                "Username": server.username,
                "Pw": password
            });

            match client.post(&auth_url)
                // Add required headers for Emby
                .header("X-Emby-Client", "BovaPlayer")
                .header("X-Emby-Device-Name", "BovaPlayer Desktop")
                .header("X-Emby-Device-Id", "bova-player-id")
                .header("X-Emby-Client-Version", "0.0.1")
                .json(&body)
                .send() 
            {
                Ok(resp) => {
                    if resp.status().is_success() {
                        if let Ok(json) = resp.json::<serde_json::Value>() {
                            if let (Some(token), Some(user)) = (
                                json.get("AccessToken").and_then(|v| v.as_str()),
                                json.get("User").and_then(|u| u.get("Id").and_then(|v| v.as_str()))
                            ) {
                                server.access_token = Some(token.to_string());
                                server.user_id = Some(user.to_string());
                                let _ = tx.send(EmbyEvent::AuthSuccess(server));
                            } else {
                                let _ = tx.send(EmbyEvent::AuthError("Invalid response format".to_string()));
                            }
                        } else {
                            let _ = tx.send(EmbyEvent::AuthError("Failed to parse JSON".to_string()));
                        }
                    } else {
                        let _ = tx.send(EmbyEvent::AuthError(format!("Auth failed: {}", resp.status())));
                    }
                }
                Err(e) => {
                    let _ = tx.send(EmbyEvent::AuthError(format!("Network error: {}", e)));
                }
            }
        });
    }

    pub fn get_dashboard(&self, server: &EmbyServer) {
        if let (Some(token), Some(user_id)) = (&server.access_token, &server.user_id) {
            let tx = self.tx.clone();
            let base_url = server.url.clone();
            let token = token.clone();
            let user_id = user_id.clone();

            thread::spawn(move || {
                let client = reqwest::blocking::Client::new();
                let fields = "Fields=PrimaryImageAspectRatio,Overview,ProductionYear,CommunityRating,OfficialRating";
                
                // 1. Fetch Views (My Media)
                let views_url = format!("{}/Users/{}/Views?{}", base_url.trim_end_matches('/'), user_id, fields);
                let views = match client.get(&views_url).header("X-Emby-Token", &token).send() {
                     Ok(r) => if r.status().is_success() {
                         r.json::<serde_json::Value>().ok()
                          .and_then(|v| serde_json::from_value::<Vec<EmbyItem>>(v["Items"].clone()).ok())
                          .unwrap_or_default()
                     } else { Vec::new() },
                     Err(_) => Vec::new(),
                };

                // 2. Fetch Resume Items (Continue Watching)
                let resume_url = format!("{}/Users/{}/Items/Resume?Limit=12&Recursive=true&{}", base_url.trim_end_matches('/'), user_id, fields);
                let resume = match client.get(&resume_url).header("X-Emby-Token", &token).send() {
                     Ok(r) => if r.status().is_success() {
                         r.json::<serde_json::Value>().ok()
                          .and_then(|v| serde_json::from_value::<Vec<EmbyItem>>(v["Items"].clone()).ok())
                          .unwrap_or_default()
                     } else { Vec::new() },
                     Err(_) => Vec::new(),
                };

                let _ = tx.send(EmbyEvent::DashboardLoaded(EmbyDashboard {
                    views,
                    resume_items: resume,
                }));
            });
        }
    }

    pub fn get_items(&self, server: &EmbyServer, parent_id: Option<String>, recursive: bool) {
        if let (Some(token), Some(user_id)) = (&server.access_token, &server.user_id) {
            let tx = self.tx.clone();
            let base_url = server.url.clone();
            let token = token.clone();
            let user_id = user_id.clone();
            let parent_id = parent_id.clone();

            thread::spawn(move || {
                let client = reqwest::blocking::Client::new();
                
                let fields = "Fields=Overview,PrimaryImageAspectRatio,ProductionYear,CommunityRating,OfficialRating,BackdropImageTags,ChildCount,RecursiveItemCount";
                let url = if let Some(pid) = parent_id {
                    if recursive {
                        // 递归查询，用于浏览器模式（跳过空文件夹，直接找到影片）
                        format!("{}/Users/{}/Items?ParentId={}&Recursive=true&IncludeItemTypes=Movie,Series&SortBy=DateCreated,SortName&SortOrder=Descending&{}", 
                            base_url.trim_end_matches('/'), user_id, pid, fields)
                    } else {
                        // 非递归查询，用于 Series -> Season 或 Season -> Episode
                        format!("{}/Users/{}/Items?ParentId={}&SortBy=SortName&{}", 
                            base_url.trim_end_matches('/'), user_id, pid, fields)
                    }
                } else {
                    // 根目录获取 Views
                    format!("{}/Users/{}/Views?{}", 
                        base_url.trim_end_matches('/'), user_id, fields)
                };

                match client.get(&url)
                    .header("X-Emby-Token", token)
                    .send() 
                {
                    Ok(resp) => {
                        if resp.status().is_success() {
                            #[derive(Deserialize)]
                            struct ItemsResp {
                                Items: Vec<EmbyItem>,
                            }
                            match resp.json::<ItemsResp>() {
                                Ok(data) => {
                                    let _ = tx.send(EmbyEvent::ItemsLoaded(data.Items));
                                }
                                Err(e) => {
                                    let _ = tx.send(EmbyEvent::ItemsError(format!("Parse error: {}", e)));
                                }
                            }
                        } else {
                            let _ = tx.send(EmbyEvent::ItemsError(format!("API error: {}", resp.status())));
                        }
                    }
                    Err(e) => {
                        let _ = tx.send(EmbyEvent::ItemsError(format!("Network error: {}", e)));
                    }
                }
            });
        }
    }

    pub fn get_stream_url(server: &EmbyServer, item_id: &str) -> String {
        if let Some(token) = &server.access_token {
            format!("{}/Videos/{}/stream?static=true&api_key={}", 
                server.url.trim_end_matches('/'), item_id, token)
        } else {
            String::new()
        }
    }
    
    pub fn get_image_url(server: &EmbyServer, item_id: &str, tag: &str, is_backdrop: bool) -> String {
        let endpoint = if is_backdrop { "Backdrop" } else { "Primary" };
        format!("{}/Items/{}/Images/{}?tag={}&quality=90", 
            server.url.trim_end_matches('/'), item_id, endpoint, tag)
    }
    
    /// 获取 Series 的总集数（递归查询所有 Episode）
    pub fn get_series_episode_count(&self, server: &EmbyServer, series_id: String) {
        if let (Some(token), Some(user_id)) = (&server.access_token, &server.user_id) {
            let tx = self.tx.clone();
            let base_url = server.url.clone();
            let token = token.clone();
            let user_id = user_id.clone();

            thread::spawn(move || {
                let client = reqwest::blocking::Client::new();
                
                // 递归查询该 Series 下的所有 Episode
                let url = format!("{}/Users/{}/Items?ParentId={}&Recursive=true&IncludeItemTypes=Episode", 
                    base_url.trim_end_matches('/'), user_id, series_id);

                match client.get(&url)
                    .header("X-Emby-Token", token)
                    .send() 
                {
                    Ok(resp) => {
                        if resp.status().is_success() {
                            #[derive(Deserialize)]
                            struct ItemsResp {
                                Items: Vec<EmbyItem>,
                            }
                            match resp.json::<ItemsResp>() {
                                Ok(data) => {
                                    let count = data.Items.len() as i32;
                                    let _ = tx.send(EmbyEvent::SeriesEpisodeCountLoaded(series_id, count));
                                }
                                Err(_) => {
                                    // 解析失败，不发送事件
                                }
                            }
                        }
                    }
                    Err(_) => {
                        // 网络错误，不发送事件
                    }
                }
            });
        }
    }
}

