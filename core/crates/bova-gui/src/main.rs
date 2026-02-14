use std::sync::{mpsc, Arc, Mutex};
use std::sync::atomic::{AtomicU32, Ordering};
use std::sync::mpsc::{Receiver, Sender, channel};
use std::path::PathBuf;
use std::time::Duration;
use std::time::Instant;

use bova_core::{create_player, MediaOptions, Player};
#[cfg(feature = "mpv")]
use bova_playback::start_mpv_playback_handles;
use bova_playback::{AudioFrame, PlaybackHandles, PlaybackConfig, PlaybackCommand, PlaybackEngine, PlaybackEvent, MpvCommand, SubtitleTrackInfo, VideoFrame, SubtitleFrame};
use eframe::{egui, App};
use rodio::{OutputStream, Sink, OutputStreamHandle, buffer::SamplesBuffer};
use rfd::FileDialog;

mod emby;
use emby::{EmbyClient, EmbyServer, EmbyItem, EmbyEvent, EmbyDashboard};

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  Theme / Colors
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

mod theme {
    use eframe::egui;
    
    // Main palette
    pub const BG_DARK: egui::Color32 = egui::Color32::from_rgb(18, 18, 24);        // deep dark background
    pub const BG_PANEL: egui::Color32 = egui::Color32::from_rgb(26, 27, 38);       // panel bg
    pub const BG_SURFACE: egui::Color32 = egui::Color32::from_rgb(34, 36, 50);     // elevated surface
    pub const BG_HOVER: egui::Color32 = egui::Color32::from_rgb(42, 44, 62);       // hover state
    pub const BG_ACTIVE: egui::Color32 = egui::Color32::from_rgb(50, 52, 72);      // active/pressed

    pub const ACCENT: egui::Color32 = egui::Color32::from_rgb(99, 135, 255);       // electric blue accent
    pub const ACCENT_HOVER: egui::Color32 = egui::Color32::from_rgb(120, 155, 255);
    pub const ACCENT_MUTED: egui::Color32 = egui::Color32::from_rgb(60, 80, 160);  // muted accent for borders

    pub const SUCCESS: egui::Color32 = egui::Color32::from_rgb(80, 200, 120);      // green
    pub const WARNING: egui::Color32 = egui::Color32::from_rgb(255, 180, 60);      // amber
    pub const ERROR: egui::Color32 = egui::Color32::from_rgb(255, 90, 90);         // red

    pub const TEXT_PRIMARY: egui::Color32 = egui::Color32::from_rgb(220, 225, 240);
    pub const TEXT_SECONDARY: egui::Color32 = egui::Color32::from_rgb(140, 145, 170);
    pub const TEXT_DIM: egui::Color32 = egui::Color32::from_rgb(90, 95, 115);

    pub const BORDER: egui::Color32 = egui::Color32::from_rgb(45, 48, 65);
    pub const BORDER_BRIGHT: egui::Color32 = egui::Color32::from_rgb(60, 65, 85);

    pub fn apply(ctx: &egui::Context) {
        let mut style = (*ctx.style()).clone();
        
        // Visuals
        let mut v = egui::Visuals::dark();
        v.panel_fill = BG_PANEL;
        v.window_fill = BG_PANEL;
        v.extreme_bg_color = BG_DARK;
        v.faint_bg_color = BG_SURFACE;
        v.code_bg_color = BG_SURFACE;
        
        // Widgets
        v.widgets.noninteractive.bg_fill = BG_SURFACE;
        v.widgets.noninteractive.bg_stroke = egui::Stroke::new(1.0, BORDER);
        v.widgets.noninteractive.fg_stroke = egui::Stroke::new(1.0, TEXT_SECONDARY);
        
        v.widgets.inactive.bg_fill = BG_SURFACE;
        v.widgets.inactive.bg_stroke = egui::Stroke::new(1.0, BORDER);
        v.widgets.inactive.fg_stroke = egui::Stroke::new(1.0, TEXT_PRIMARY);
        v.widgets.inactive.rounding = egui::Rounding::same(6.0);
        
        v.widgets.hovered.bg_fill = BG_HOVER;
        v.widgets.hovered.bg_stroke = egui::Stroke::new(1.0, ACCENT_MUTED);
        v.widgets.hovered.fg_stroke = egui::Stroke::new(1.0, TEXT_PRIMARY);
        v.widgets.hovered.rounding = egui::Rounding::same(6.0);
        
        v.widgets.active.bg_fill = ACCENT;
        v.widgets.active.bg_stroke = egui::Stroke::new(1.0, ACCENT_HOVER);
        v.widgets.active.fg_stroke = egui::Stroke::new(1.0, egui::Color32::WHITE);
        v.widgets.active.rounding = egui::Rounding::same(6.0);
        
        v.widgets.open.bg_fill = BG_ACTIVE;
        v.widgets.open.bg_stroke = egui::Stroke::new(1.0, ACCENT_MUTED);
        v.widgets.open.fg_stroke = egui::Stroke::new(1.0, TEXT_PRIMARY);
        
        v.selection.bg_fill = ACCENT.linear_multiply(0.3);
        v.selection.stroke = egui::Stroke::new(1.0, ACCENT);
        
        v.window_rounding = egui::Rounding::same(8.0);
        v.window_shadow = egui::epaint::Shadow {
            offset: egui::Vec2::new(0.0, 4.0),
            blur: 12.0,
            spread: 0.0,
            color: egui::Color32::from_black_alpha(60),
        };
        
        v.window_stroke = egui::Stroke::new(1.0, BORDER);
        
        style.visuals = v;
        
        // Spacing
        style.spacing.item_spacing = egui::vec2(8.0, 6.0);
        style.spacing.button_padding = egui::vec2(12.0, 5.0);
        style.spacing.window_margin = egui::Margin::same(12.0);
        
        ctx.set_style(style);
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  Custom widgets
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

fn icon_button(ui: &mut egui::Ui, icon: &str, tooltip: &str) -> egui::Response {
    let btn = egui::Button::new(
        egui::RichText::new(icon).size(18.0)
    )
    .min_size(egui::vec2(36.0, 36.0))
    .rounding(egui::Rounding::same(8.0));
    ui.add(btn).on_hover_text(tooltip)
}

// 大号图标按钮（用于播放器浮动控制）
fn large_icon_button(ui: &mut egui::Ui, icon: &str, tooltip: &str) -> egui::Response {
    let btn = egui::Button::new(
        egui::RichText::new(icon).size(32.0).color(egui::Color32::WHITE)
    )
    .fill(egui::Color32::from_black_alpha(180))
    .min_size(egui::vec2(60.0, 60.0))
    .rounding(egui::Rounding::same(30.0));
    ui.add(btn).on_hover_text(tooltip)
}

// 渲染保持宽高比的图片
fn render_image_fit(
    painter: &egui::Painter,
    texture_id: egui::TextureId,
    container_rect: egui::Rect,
    texture_size: [usize; 2],
) {
    let container_aspect = container_rect.width() / container_rect.height();
    let image_aspect = texture_size[0] as f32 / texture_size[1] as f32;
    
    let image_rect = if image_aspect > container_aspect {
        // 图片更宽，以宽度为准
        let height = container_rect.width() / image_aspect;
        let y_offset = (container_rect.height() - height) / 2.0;
        egui::Rect::from_min_size(
            egui::pos2(container_rect.min.x, container_rect.min.y + y_offset),
            egui::vec2(container_rect.width(), height)
        )
    } else {
        // 图片更高，以高度为准
        let width = container_rect.height() * image_aspect;
        let x_offset = (container_rect.width() - width) / 2.0;
        egui::Rect::from_min_size(
            egui::pos2(container_rect.min.x + x_offset, container_rect.min.y),
            egui::vec2(width, container_rect.height())
        )
    };
    
    painter.image(
        texture_id,
        image_rect,
        egui::Rect::from_min_max(egui::pos2(0.0, 0.0), egui::pos2(1.0, 1.0)),
        egui::Color32::WHITE,
    );
}

fn accent_button(ui: &mut egui::Ui, label: &str) -> egui::Response {
    let btn = egui::Button::new(
        egui::RichText::new(label)
            .color(egui::Color32::WHITE)
            .strong()
    )
    .fill(theme::ACCENT)
    .rounding(egui::Rounding::same(8.0))
    .min_size(egui::vec2(0.0, 32.0));
    ui.add(btn)
}

fn subtle_button(ui: &mut egui::Ui, label: &str) -> egui::Response {
    let btn = egui::Button::new(
        egui::RichText::new(label)
            .color(theme::TEXT_SECONDARY)
    )
    .fill(theme::BG_SURFACE)
    .stroke(egui::Stroke::new(1.0, theme::BORDER))
    .rounding(egui::Rounding::same(8.0))
    .min_size(egui::vec2(0.0, 32.0));
    ui.add(btn)
}

fn section_header(ui: &mut egui::Ui, title: &str) {
    ui.add_space(4.0);
    ui.label(
        egui::RichText::new(title)
            .color(theme::TEXT_DIM)
            .size(11.0)
            .strong()
    );
    ui.add_space(2.0);
}

#[allow(dead_code)]
fn status_badge(ui: &mut egui::Ui, text: &str, color: egui::Color32) {
    let label = egui::RichText::new(format!("● {}", text))
        .color(color)
        .size(12.0);
    ui.label(label);
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  App state
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct BovaGuiApp {
    // 输入
    url: String,
    seek_input: String,

    // 状态栏
    opened: bool,
    last_instant: Option<Instant>,

    // 事件日志
    logs: Vec<String>,
    rx: mpsc::Receiver<String>,

    // 探测结果
    last_probe_json: Option<String>,

    // 选择文件夹
    current_dir: Option<PathBuf>,

    // 播放器
    player: bova_core::BovaPlayer,

    // 软解码与渲染
    video_tex: Option<egui::TextureHandle>,
    video_w: u32,
    video_h: u32,

    // 音频输出
    audio_stream: Option<OutputStream>,
    audio_handle: Option<rodio::OutputStreamHandle>,
    audio_sink: Option<Sink>,

    // A/V 同步
    audio_anchor_pts: Option<i64>,
    audio_anchor_time: Option<Instant>,
    video_anchor_pts: Option<i64>,
    video_anchor_time: Option<Instant>,
    pending_video: Option<bova_playback::VideoFrame>,
    last_video_show_instant: Option<Instant>,
    // Playback state
    playback: Option<PlaybackHandles>,
    playing: bool,
    position_ms: i64,
    duration_ms: i64,
    volume: f32,
    loop_play: bool,
    
    // Engine state
    playback_engine: PlaybackEngine,
    hwaccel_enabled: bool,
    subtitle_enabled: bool,
    current_subtitle_index: Option<u32>,
    mpv_command_tx: Option<Sender<bova_playback::PlaybackCommand>>, // legacy
    mpv_event_rx: Option<Receiver<bova_playback::PlaybackEvent>>, // legacy
    
    // Subtitle state
    subtitle_tracks: Vec<SubtitleTrackInfo>,
    selected_subtitle_id: Option<i64>,
    active_subtitles: Vec<SubtitleFrame>,

    // Emby State
    emby_servers: Vec<EmbyServer>,
    current_emby_server: Option<EmbyServer>,
    emby_client: Option<EmbyClient>,
    emby_event_rx: Receiver<EmbyEvent>,
    emby_event_tx: Sender<EmbyEvent>,
    emby_items: Vec<EmbyItem>,
    emby_dashboard: Option<EmbyDashboard>,
    emby_navigation_stack: Vec<(String, String)>, // (id, name)
    emby_view_mode: EmbyViewMode,
    selected_emby_item: Option<EmbyItem>,
    
    // 每个 View 的预览项目缓存
    emby_view_items: std::collections::HashMap<String, Vec<EmbyItem>>,
    
    // Series 详情页的 Season/Episode 数据
    series_seasons: Vec<EmbyItem>,  // 当前 Series 的所有 Season
    season_episodes: std::collections::HashMap<String, Vec<EmbyItem>>, // season_id -> episodes
    selected_season_index: usize,  // 当前选中的 Season 索引
    
    // Image cache for Emby posters/backdrops
    emby_image_cache: std::collections::HashMap<String, egui::TextureHandle>,
    emby_image_loading: std::collections::HashSet<String>,
    pending_images: Vec<(String, egui::ColorImage)>,
    
    // Episode count cache for Series items
    series_episode_count: std::collections::HashMap<String, i32>, // series_id -> total episode count
    series_count_loading: std::collections::HashSet<String>, // series_id being loaded
    
    // Pagination
    emby_items_per_page: usize,
    emby_current_page: usize,
    
    // Emby UI State
    show_add_server_window: bool,
    new_server_url: String,
    new_server_user: String,
    new_server_pass: String,
    emby_status_msg: Option<String>,
    
    app_mode: AppMode,
    // MRU & 播放列表
    mru: Vec<String>,
    playlist: Vec<String>,
    playlist_index: usize,

    // UI state
    show_logs: bool,
    show_probe: bool,
    
    // Track the video display area for dynamic render sizing
    video_display_w: f32,
    video_display_h: f32,
}

#[derive(PartialEq, Clone, Copy)]
enum EmbyViewMode {
    ServerList,
    Dashboard,
    Browser,
    ItemDetail,
}

#[derive(PartialEq, Clone, Copy)]
enum AppMode {
    Welcome,  // 新增：欢迎页/启动页
    Player,
    Emby,
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  Playback control methods
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

impl BovaGuiApp {
    fn start_playback(&mut self) {
        self.stop_playback();
        
        match self.playback_engine {
            PlaybackEngine::MPV => {
                let cfg = PlaybackConfig {
                    hwaccel: self.hwaccel_enabled,
                    subtitle_enabled: self.subtitle_enabled,
                    subtitle_index: self.current_subtitle_index,
                    engine: Some(PlaybackEngine::MPV),
                };
                #[cfg(feature = "mpv")]
                match start_mpv_playback_handles(&self.url, &cfg) {
                    Ok(h) => {
                        self.playback = Some(h);
                        self.playing = true;
                        self.subtitle_tracks.clear();
                        self.selected_subtitle_id = None;
                        
                        // Set initial volume
                        if let Some(pb) = &self.playback {
                            if let Some(cmd_tx) = &pb.cmd_tx {
                                let _ = cmd_tx.try_send(MpvCommand::SetVolume((self.volume * 100.0) as f64));
                            }
                        }

                        let accel = if self.hwaccel_enabled { "硬件解码" } else { "软解码" };
                        self.logs.push(format!("▶ MPV引擎已启动 ({})", accel));
                    }
                    Err(e) => {
                        self.logs.push(format!("✕ MPV引擎启动失败: {e}"));
                    }
                }
                #[cfg(not(feature = "mpv"))]
                {
                    self.logs.push("✕ MPV feature 未启用".to_string());
                }
            }
            PlaybackEngine::FFmpeg => {
                let cfg = PlaybackConfig { 
                    hwaccel: self.hwaccel_enabled,
                    subtitle_enabled: self.subtitle_enabled,
                    subtitle_index: self.current_subtitle_index,
                    engine: Some(PlaybackEngine::FFmpeg),
                };
                match bova_playback::start_playback_with(&self.url, cfg) {
                    Ok(h) => {
                        self.playback = Some(h);
                        self.playing = true;
                        let accel = if self.hwaccel_enabled { "硬件解码" } else { "软解码" };
                        self.logs.push(format!("▶ FFmpeg引擎已启动 ({})", accel));
                    }
                    Err(e) => {
                        self.logs.push(format!("✕ FFmpeg引擎启动失败: {e}"));
                    }
                }
            }
        }

        // 初始化音频输出
        if self.audio_sink.is_none() {
            if let Ok((stream, handle)) = OutputStream::try_default() {
                if let Ok(sink) = Sink::try_new(&handle) {
                    self.audio_sink = Some(sink);
                    self.audio_handle = Some(handle);
                    self.audio_stream = Some(stream);
                }
            }
        }
        self.audio_anchor_pts = None;
        self.audio_anchor_time = None;
        self.video_anchor_pts = None;
        self.video_anchor_time = None;
        self.last_video_show_instant = None;
    }

    fn stop_playback(&mut self) {
        if let Some(pb) = self.playback.take() {
            let _ = pb.stop_tx.send(());
        }
        if let Some(cmd_tx) = &self.mpv_command_tx {
            let _ = cmd_tx.send(PlaybackCommand::Stop);
        }
        self.mpv_command_tx = None;
        self.mpv_event_rx = None;
        if let Some(sink) = self.audio_sink.take() { sink.stop(); }
        self.audio_handle = None;
        self.audio_stream = None;
        self.video_tex = None;
        self.audio_anchor_pts = None;
        self.audio_anchor_time = None;
        self.active_subtitles.clear();
        self.playing = false;
    }

    fn current_audio_time_ms(&self) -> Option<i64> {
        if !self.playing { return None; }
        if let (Some(pts), Some(t0)) = (self.audio_anchor_pts, self.audio_anchor_time) {
            return Some(pts + t0.elapsed().as_millis() as i64);
        }
        None
    }

    fn remember_file(&mut self, path: String) {
        if let Some(pos) = self.mru.iter().position(|p| p == &path) { self.mru.remove(pos); }
        self.mru.insert(0, path.clone());
        if self.mru.len() > 10 { self.mru.pop(); }
        if !self.playlist.iter().any(|p| p == &path) {
            self.playlist.push(path);
            self.playlist_index = self.playlist.len()-1;
        }
    }

    fn open_and_play(&mut self, path: String) {
        self.url = path.clone();
        let opts = MediaOptions::default();
        match self.player.open(&self.url, opts) {
            Ok(_) => {
                let _ = self.player.play();
                self.start_playback();
                self.remember_file(self.url.clone());
            }
            Err(e) => self.logs.push(format!("✕ 打开失败: {e}")),
        }
    }

    fn add_to_playlist(&mut self) {
        let path = self.url.clone();
        if path.is_empty() { return; }
        self.remember_file(path);
    }

    fn playlist_prev(&mut self) {
        if self.playlist.is_empty() { return; }
        if self.playlist_index == 0 { self.playlist_index = self.playlist.len()-1; } else { self.playlist_index -= 1; }
        let path = self.playlist[self.playlist_index].clone();
        self.open_and_play(path);
    }

    fn playlist_next(&mut self) {
        if self.playlist.is_empty() { return; }
        self.playlist_index = (self.playlist_index + 1) % self.playlist.len();
        let path = self.playlist[self.playlist_index].clone();
        self.open_and_play(path);
    }
    
    fn file_basename(&self) -> String {
        if self.url.is_empty() { return "未选择文件".to_string(); }
        std::path::Path::new(&self.url)
            .file_name()
            .map(|n| n.to_string_lossy().to_string())
            .unwrap_or_else(|| self.url.clone())
    }
    
    fn format_time(ms: i64) -> String {
        let s = (ms / 1000) % 60;
        let m = (ms / 60000) % 60;
        let h = ms / 3600000;
        if h > 0 {
            format!("{h}:{m:02}:{s:02}")
        } else {
            format!("{m}:{s:02}")
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  Constructor
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

impl BovaGuiApp {
    fn new(cc: &eframe::CreationContext<'_>) -> Self {
        // Apply theme
        theme::apply(&cc.egui_ctx);

        // Load CJK font
        if let Some(bytes) = load_cjk_font() {
            let mut fonts = egui::FontDefinitions::default();
            fonts.font_data.insert("cjk".to_string(), egui::FontData::from_owned(bytes));
            fonts.families
                .entry(egui::FontFamily::Proportional)
                .or_default()
                .insert(0, "cjk".to_string());
            fonts.families
                .entry(egui::FontFamily::Monospace)
                .or_default()
                .insert(0, "cjk".to_string());
            cc.egui_ctx.set_fonts(fonts);
        }
        
        let (tx, rx) = mpsc::channel::<String>();
        let mut player = create_player();
        let tx_arc: Arc<Mutex<mpsc::Sender<String>>> = Arc::new(Mutex::new(tx));
        let tx_clone = tx_arc.clone();
        player.on_event(Arc::new(move |json| {
            let _ = tx_clone.lock().unwrap().send(json.to_string());
        }));

        let (emby_tx, emby_rx) = channel();

        Self {
            url: String::new(),
            opened: false,
            video_tex: None,
            video_w: 0,
            video_h: 0,
            
            // ... (other fields initialized implicitly by Default if not listed, but we list them)
            playback: None,
            playing: false,
            position_ms: 0,
            duration_ms: 0,
            volume: 1.0,
            loop_play: false,
            
            playback_engine: PlaybackEngine::MPV,
            hwaccel_enabled: true,
            subtitle_enabled: true,
            current_subtitle_index: None,
            mpv_command_tx: None,
            mpv_event_rx: None,
            
            audio_sink: None,
            audio_handle: None,
            audio_stream: None,
            
            logs: Vec::new(),
            show_logs: false,
            show_probe: false,
            last_probe_json: None,
            
            playlist: Vec::new(),
            playlist_index: 0,
            mru: Vec::new(),
            current_dir: None,
            
            audio_anchor_pts: None,
            audio_anchor_time: None,
            video_anchor_pts: None,
            video_anchor_time: None,
            last_video_show_instant: None,
            pending_video: None,
            last_instant: None,
            seek_input: String::new(),
            
            video_display_w: 640.0,
            video_display_h: 360.0,
            
            subtitle_tracks: Vec::new(),
            selected_subtitle_id: None,
            
            // Emby init
            emby_servers: Self::load_servers(),
            current_emby_server: None,
            emby_client: Some(EmbyClient::new(emby_tx.clone())),
            emby_event_rx: emby_rx,
            emby_event_tx: emby_tx,
            emby_items: Vec::new(),
            emby_dashboard: None,
            emby_navigation_stack: Vec::new(),
            emby_view_mode: EmbyViewMode::ServerList,
            selected_emby_item: None,
            emby_view_items: std::collections::HashMap::new(),
            series_seasons: Vec::new(),
            season_episodes: std::collections::HashMap::new(),
            selected_season_index: 0,
            show_add_server_window: false,
            new_server_url: String::new(),
            new_server_user: String::new(),
            new_server_pass: String::new(),
            emby_status_msg: None,
            emby_image_cache: std::collections::HashMap::new(),
            emby_image_loading: std::collections::HashSet::new(),
            pending_images: Vec::new(),
            series_episode_count: std::collections::HashMap::new(),
            series_count_loading: std::collections::HashSet::new(),
            emby_items_per_page: 20,
            emby_current_page: 0,
            player,
            rx,
            active_subtitles: Vec::new(),
            app_mode: AppMode::Welcome,  // 默认显示欢迎页
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  Main update loop
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

impl App for BovaGuiApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        // ── Process events ──
        while let Ok(msg) = self.rx.try_recv() {
            self.logs.push(msg.clone());
            if let Ok(evt) = serde_json::from_str::<serde_json::Value>(&msg) {
                if let Some(kind) = evt.get("kind").and_then(|k| k.as_str()) {
                    match kind {
                        "opened" => { self.opened = true; self.playing = false; self.position_ms = 0; }
                        "play" => { 
                            self.playing = true;
                            if let Some(sink) = &self.audio_sink { sink.play(); }
                            self.audio_anchor_pts = None;
                            self.audio_anchor_time = None;
                        }
                        "pause" => { 
                            self.playing = false;
                            if let Some(sink) = &self.audio_sink { sink.pause(); }
                        }
                        "stop" => { 
                            self.playing = false; self.opened = false; self.position_ms = 0;
                            if let Some(sink) = &self.audio_sink { sink.stop(); }
                            self.video_tex = None;
                        }
                        "seek" => {
                            if let Some(p) = evt.get("payload").and_then(|p| p.get("position_ms")).and_then(|v| v.as_i64()) {
                                self.position_ms = p;
                            }
                        }
                        _ => {}
                    }
                }
            }
        }

        // Update position from video frame PTS (remove fake simulation)
        let now = Instant::now();
        self.last_instant = Some(now);

        // Process MPV events
        if let Some(event_rx) = &self.mpv_event_rx {
            while let Ok(event) = event_rx.try_recv() {
                match event {
                    PlaybackEvent::FileLoaded => { self.opened = true; }
                    PlaybackEvent::Started => { self.playing = true; }
                    PlaybackEvent::Paused => { self.playing = false; }
                    PlaybackEvent::Resumed => { self.playing = true; }
                    PlaybackEvent::Stopped => { self.playing = false; self.opened = false; }
                    PlaybackEvent::Finished => {
                        self.playing = false;
                        if self.loop_play {
                            if let Some(cmd_tx) = &self.mpv_command_tx {
                                let _ = cmd_tx.send(PlaybackCommand::Play);
                            }
                        }
                    }
                    PlaybackEvent::PositionChanged(pos) => {
                        self.position_ms = (pos * 1000.0) as i64;
                    }
                    PlaybackEvent::Error(err) => {
                        self.logs.push(format!("✕ 错误: {}", err));
                    }
                }
            }
        }

        // ── Process video/audio/subtitle frames ──
        if let Some(pb) = &self.playback {
            let video_rx = pb.video_rx.clone();
            let audio_rx = pb.audio_rx.clone();
            let subtitle_rx = pb.subtitle_rx.clone();
            let eos_rx = pb.eos_rx.clone();
            let track_info_rx = pb.track_info_rx.clone();
            let target_w = pb.target_render_w.clone();
            let target_h = pb.target_render_h.clone();

            // Update target render size based on video display area
            {
                let ppp = ctx.pixels_per_point();
                let tw = (self.video_display_w * ppp).max(160.0) as u32;
                let th = (self.video_display_h * ppp).max(90.0) as u32;
                target_w.store(tw, Ordering::Relaxed);
                target_h.store(th, Ordering::Relaxed);
            }

            // Receive subtitle track info from MPV
            if let Some(track_rx) = &track_info_rx {
                if let Ok(tracks) = track_rx.try_recv() {
                    self.logs.push(format!("🎦 发现 {} 条字幕轨道", tracks.len()));
                    for t in &tracks {
                        self.logs.push(format!("  {t}"));
                    }
                    self.subtitle_tracks = tracks;
                }
            }

            // Drain video channel to latest frame (skip intermediate frames)
            // MPV handles A/V sync internally, so we just display the newest frame
            let mut latest_frame: Option<bova_playback::VideoFrame> = self.pending_video.take();
            while let Ok(frame) = video_rx.try_recv() {
                // Update position and duration from every frame we see
                if let Some(pts) = frame.pts_ms {
                    self.position_ms = pts;
                }
                if let Some(dur) = frame.duration_ms {
                    self.duration_ms = dur;
                }
                latest_frame = Some(frame);
            }
            if let Some(frame) = latest_frame {
                self.show_video_frame(ctx, frame);
            }

            if let Some(sink) = &self.audio_sink {
                let mut n = 0;
                while self.playing && n < 5 {
                    match audio_rx.try_recv() {
                        Ok(af) => {
                            let buf = SamplesBuffer::new(af.channels as u16, af.sample_rate, af.samples);
                            sink.append(buf);
                            if let Some(pts) = af.pts_ms {
                                if self.audio_anchor_pts.is_none() {
                                    self.audio_anchor_pts = Some(pts);
                                    self.audio_anchor_time = Some(Instant::now());
                                }
                            }
                            n += 1;
                        }
                        Err(_) => break,
                    }
                }
            }
            
            if self.subtitle_enabled {
                let mut n = 0;
                while n < 5 {
                    match subtitle_rx.try_recv() {
                        Ok(sf) => { self.active_subtitles.push(sf); n += 1; }
                        Err(_) => break,
                    }
                }
                let current_time_ms = self.current_audio_time_ms().unwrap_or(self.position_ms);
                self.active_subtitles.retain(|sf| sf.end_ms >= current_time_ms);
            }

            if eos_rx.try_recv().is_ok() {
                self.logs.push("◼ 播放结束".to_string());
                if self.loop_play {
                    self.start_playback();
                } else {
                    self.playing = false;
                }
            }
        }

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        //  UI Layout
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        //  UI Layout - 只在播放器模式下显示顶部栏和底部栏
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        // 只在播放器模式下显示顶部栏和底部栏
        if self.app_mode == AppMode::Player {
            // ── Top bar ──
            egui::TopBottomPanel::top("title_bar")
                .frame(egui::Frame::none()
                    .fill(theme::BG_DARK)
                    .inner_margin(egui::Margin::symmetric(16.0, 8.0))
                )
                .show(ctx, |ui| {
                    ui.horizontal(|ui| {
                        // 返回首页按钮
                        if ui.button("⬅ 返回首页").clicked() {
                            self.app_mode = AppMode::Welcome;
                        }
                        
                        ui.separator();
                        
                        // Logo / brand
                        ui.label(
                            egui::RichText::new("▶ BovaPlayer")
                                .color(theme::ACCENT)
                                .size(16.0)
                                .strong()
                        );
                        ui.add_space(12.0);

                        // File picker button - 只在非 Emby 播放时显示
                        if self.current_emby_server.is_none() {
                            if accent_button(ui, "📂 选择文件").clicked() {
                                self.pick_and_play_file();
                            }
                            ui.add_space(8.0);

                            // File name
                            let fname = self.file_basename();
                            ui.label(
                                egui::RichText::new(&fname)
                                    .color(theme::TEXT_SECONDARY)
                                    .size(13.0)
                            );
                        }

                        ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                            // Status indicator
                            let (status_text, status_color) = if self.playing {
                                ("播放中", theme::SUCCESS)
                            } else if self.opened {
                                ("已暂停", theme::WARNING)
                            } else {
                                ("就绪", theme::TEXT_DIM)
                            };
                            ui.label(
                                egui::RichText::new(format!("● {}", status_text))
                                    .color(status_color)
                                    .size(12.0)
                            );
                            
                            // Engine badge
                            let engine_name = match self.playback_engine {
                                PlaybackEngine::MPV => "MPV",
                                PlaybackEngine::FFmpeg => "FFmpeg",
                            };
                            ui.label(
                                egui::RichText::new(engine_name)
                                    .color(theme::ACCENT_MUTED)
                                    .size(11.0)
                                    .strong()
                            );
                        });
                    });
                });

            // ── Bottom control bar ──
            egui::TopBottomPanel::bottom("control_bar")
            .frame(egui::Frame::none()
                .fill(theme::BG_DARK)
                .inner_margin(egui::Margin::symmetric(16.0, 10.0))
                .stroke(egui::Stroke::new(1.0, theme::BORDER))
            )
            .show(ctx, |ui| {
                // Progress bar row
                ui.horizontal(|ui| {
                    // Current time
                    ui.label(
                        egui::RichText::new(Self::format_time(self.position_ms))
                            .color(theme::TEXT_SECONDARY)
                            .size(11.0)
                            .monospace()
                    );
                    
                    // Interactive progress bar
                    let avail_w = ui.available_width() - 60.0; // Leave room for duration text
                    let (response, painter) = ui.allocate_painter(
                        egui::vec2(avail_w, 16.0),
                        egui::Sense::click_and_drag()
                    );
                    let rect = response.rect;
                    
                    // Handle seek (click or drag)
                    if response.clicked() || response.dragged() {
                        if let Some(pos) = response.interact_pointer_pos() {
                            let pct = ((pos.x - rect.min.x) / rect.width()).clamp(0.0, 1.0);
                            let target_ms = (self.duration_ms as f32 * pct) as i64;
                            
                            // Optimistic update
                            self.position_ms = target_ms;
                            
                            if let Some(pb) = &self.playback {
                                if let Some(cmd_tx) = &pb.cmd_tx {
                                    let _ = cmd_tx.try_send(MpvCommand::SeekAbsolute(target_ms as f64 / 1000.0));
                                }
                            }
                        }
                    }

                    let track_rect = egui::Rect::from_min_size(
                        egui::pos2(rect.min.x, rect.center().y - 3.0),
                        egui::vec2(rect.width(), 6.0),
                    );
                    
                    // Track background
                    painter.rect_filled(track_rect, 3.0, theme::BG_SURFACE);
                    
                    // Fill based on real position/duration
                    let progress = if self.duration_ms > 0 {
                        (self.position_ms as f32 / self.duration_ms as f32).clamp(0.0, 1.0)
                    } else {
                        0.0
                    };
                    if progress > 0.0 {
                        let fill_rect = egui::Rect::from_min_size(
                            track_rect.min,
                            egui::vec2(track_rect.width() * progress, 6.0),
                        );
                        painter.rect_filled(fill_rect, 3.0, theme::ACCENT);
                        
                        // Playhead dot
                        let dot_x = fill_rect.max.x;
                        painter.circle_filled(
                            egui::pos2(dot_x, track_rect.center().y),
                            5.0,
                            theme::ACCENT_HOVER,
                        );
                    }

                    // Hover highlight
                    if response.hovered() {
                        let hover_rect = egui::Rect::from_min_size(
                            egui::pos2(rect.min.x, rect.center().y - 4.0),
                            egui::vec2(rect.width(), 8.0),
                        );
                        painter.rect_filled(hover_rect, 4.0, theme::BG_HOVER);
                        if progress > 0.0 {
                            let fill_rect = egui::Rect::from_min_size(
                                hover_rect.min,
                                egui::vec2(hover_rect.width() * progress, 8.0),
                            );
                            painter.rect_filled(fill_rect, 4.0, theme::ACCENT);
                        }
                    }

                    // Duration text
                    ui.label(
                        egui::RichText::new(Self::format_time(self.duration_ms))
                            .color(theme::TEXT_DIM)
                            .size(11.0)
                            .monospace()
                    );
                });
                
                ui.add_space(4.0);

                // Transport controls
                ui.horizontal(|ui| {
                    // Left: playlist controls
                    if icon_button(ui, "⏮", "上一首").clicked() { self.playlist_prev(); }
                    
                    // Play/pause
                    if self.playing {
                        if accent_button(ui, "⏸  暂停").clicked() {
                            self.playing = false; // Optimistic update
                            if let Some(pb) = &self.playback {
                                if let Some(cmd_tx) = &pb.cmd_tx {
                                    let _ = cmd_tx.try_send(MpvCommand::Pause);
                                }
                            }
                        }
                    } else {
                        if accent_button(ui, "▶  播放").clicked() {
                            // If we have an active playback handle (paused), resume it
                            if let Some(pb) = &self.playback {
                                self.playing = true; // Optimistic update
                                if let Some(cmd_tx) = &pb.cmd_tx {
                                    let _ = cmd_tx.try_send(MpvCommand::Resume);
                                }
                            } else {
                                // Otherwise start new playback
                                if self.url.is_empty() {
                                    self.pick_and_play_file();
                                } else {
                                    self.start_playback();
                                }
                            }
                        }
                    }
                    
                    if icon_button(ui, "⏹", "停止").clicked() { self.stop_playback(); }
                    if icon_button(ui, "⏭", "下一首").clicked() { self.playlist_next(); }

                    ui.add_space(12.0);
                    ui.separator();
                    ui.add_space(8.0);

                    // Volume
                    ui.label(egui::RichText::new("🔊").size(14.0));
                    let vol_slider = egui::Slider::new(&mut self.volume, 0.0..=1.0)
                        .show_value(false)
                        .custom_formatter(|v, _| format!("{:.0}%", v * 100.0));
                    if ui.add_sized(egui::vec2(80.0, 20.0), vol_slider).changed() {
                         if let Some(pb) = &self.playback {
                            if let Some(cmd_tx) = &pb.cmd_tx {
                                let _ = cmd_tx.try_send(MpvCommand::SetVolume((self.volume * 100.0) as f64));
                            }
                        }
                    }

                    ui.add_space(8.0);
                    ui.separator();
                    ui.add_space(8.0);

                    // Toggles
                    let loop_text = if self.loop_play {
                        egui::RichText::new("🔁").color(theme::ACCENT)
                    } else {
                        egui::RichText::new("🔁").color(theme::TEXT_DIM)
                    };
                    if ui.add(egui::Button::new(loop_text).frame(false)).on_hover_text("循环播放").clicked() {
                        self.loop_play = !self.loop_play;
                    }

                    ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                        // Right: settings toggles
                        if subtle_button(ui, if self.show_logs { "📋 日志 ▾" } else { "📋 日志" }).clicked() {
                            self.show_logs = !self.show_logs;
                        }
                        if subtle_button(ui, if self.show_probe { "🔍 信息 ▾" } else { "🔍 信息" }).clicked() {
                            self.show_probe = !self.show_probe;
                        }
                    });
                });
            });
        } // 结束播放器模式的 UI

        // ── Optional: Side panel for Probe info ──
        if self.show_probe && self.app_mode == AppMode::Player {
            egui::SidePanel::left("probe_panel")
                .resizable(true)
                .default_width(280.0)
                .frame(egui::Frame::none()
                    .fill(theme::BG_PANEL)
                    .inner_margin(egui::Margin::same(12.0))
                    .stroke(egui::Stroke::new(1.0, theme::BORDER))
                )
                .show(ctx, |ui| {
                    // Panel header with close button
                    ui.horizontal(|ui| {
                        section_header(ui, "信息面板");
                        ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                            if ui.add(egui::Button::new(
                                egui::RichText::new("✕").color(theme::TEXT_DIM).size(14.0)
                            ).frame(false)).on_hover_text("关闭面板").clicked() {
                                self.show_probe = false;
                            }
                        });
                    });
                    ui.separator();
                    ui.add_space(4.0);
                    
                    section_header(ui, "媒体信息");
                    
                    ui.horizontal(|ui| {
                        ui.label(egui::RichText::new("文件:").color(theme::TEXT_DIM).size(12.0));
                        ui.add_sized(
                            egui::vec2(ui.available_width(), 24.0),
                            egui::TextEdit::singleline(&mut self.url)
                                .font(egui::TextStyle::Small)
                        );
                    });
                    
                    ui.add_space(4.0);
                    ui.horizontal(|ui| {
                        if subtle_button(ui, "📂 选择文件").clicked() {
                            self.pick_and_play_file();
                        }
                        if subtle_button(ui, "🔍 Probe").clicked() {
                            let info = bova_probe::probe(&self.url);
                            self.last_probe_json = Some(serde_json::to_string_pretty(&info).unwrap());
                        }
                    });
                    
                    ui.add_space(4.0);
                    ui.separator();
                    
                    // Settings
                    section_header(ui, "设置");
                    ui.horizontal(|ui| {
                        ui.checkbox(&mut self.hwaccel_enabled, 
                            egui::RichText::new("硬件解码").color(theme::TEXT_PRIMARY).size(13.0));
                    });
                    ui.horizontal(|ui| {
                        ui.label(egui::RichText::new("引擎:").color(theme::TEXT_DIM).size(12.0));
                        ui.radio_value(&mut self.playback_engine, PlaybackEngine::MPV, 
                            egui::RichText::new("MPV").size(12.0));
                        ui.radio_value(&mut self.playback_engine, PlaybackEngine::FFmpeg, 
                            egui::RichText::new("FFmpeg").size(12.0));
                    });

                    // ── Subtitle Section ──
                    ui.add_space(4.0);
                    ui.separator();
                    section_header(ui, "字幕");

                    // Subtitle visibility toggle
                    let mut sub_vis = self.subtitle_enabled;
                    if ui.checkbox(&mut sub_vis,
                        egui::RichText::new("显示字幕").color(theme::TEXT_PRIMARY).size(13.0)
                    ).changed() {
                        self.subtitle_enabled = sub_vis;
                        if let Some(pb) = &self.playback {
                            if let Some(cmd_tx) = &pb.cmd_tx {
                                let _ = cmd_tx.try_send(MpvCommand::SetSubVisibility(sub_vis));
                            }
                        }
                    }

                    // Subtitle track selector
                    if !self.subtitle_tracks.is_empty() {
                        ui.add_space(4.0);
                        ui.label(egui::RichText::new("字幕轨道:").color(theme::TEXT_DIM).size(12.0));

                        // "None" option
                        let is_none = self.selected_subtitle_id.is_none();
                        if ui.selectable_label(is_none,
                            egui::RichText::new("无字幕").color(if is_none { theme::ACCENT } else { theme::TEXT_SECONDARY }).size(12.0)
                        ).clicked() {
                            self.selected_subtitle_id = None;
                            if let Some(pb) = &self.playback {
                                if let Some(cmd_tx) = &pb.cmd_tx {
                                    let _ = cmd_tx.try_send(MpvCommand::DisableSubtitle);
                                }
                            }
                        }

                        // Track options
                        let tracks_snapshot = self.subtitle_tracks.clone();
                        for track in &tracks_snapshot {
                            let is_selected = self.selected_subtitle_id == Some(track.id);
                            let label = format!("{}", track);
                            if ui.selectable_label(is_selected,
                                egui::RichText::new(&label)
                                    .color(if is_selected { theme::ACCENT } else { theme::TEXT_SECONDARY })
                                    .size(12.0)
                            ).clicked() {
                                self.selected_subtitle_id = Some(track.id);
                                if let Some(pb) = &self.playback {
                                    if let Some(cmd_tx) = &pb.cmd_tx {
                                        let _ = cmd_tx.try_send(MpvCommand::SelectSubtitle(track.id));
                                    }
                                }
                            }
                        }
                    } else if self.playing {
                        ui.label(egui::RichText::new("无字幕轨道").color(theme::TEXT_DIM).size(11.0));
                    }

                    // Load external subtitle
                    ui.add_space(4.0);
                    if subtle_button(ui, "📄 加载外部字幕").clicked() {
                        if let Some(path) = FileDialog::new()
                            .add_filter("字幕文件", &["srt", "ass", "ssa", "sub", "vtt", "sup", "idx"])
                            .pick_file()
                        {
                            let path_str = path.to_string_lossy().to_string();
                            self.logs.push(format!("📄 加载字幕: {}", path.file_name().unwrap_or_default().to_string_lossy()));
                            if let Some(pb) = &self.playback {
                                if let Some(cmd_tx) = &pb.cmd_tx {
                                    let _ = cmd_tx.try_send(MpvCommand::LoadExternalSub(path_str));
                                }
                            }
                        }
                    }
                    
                    // Probe result
                    if let Some(json) = &self.last_probe_json {
                        ui.add_space(4.0);
                        ui.separator();
                        section_header(ui, "PROBE 结果");
                        egui::ScrollArea::vertical().show(ui, |ui| {
                            ui.monospace(
                                egui::RichText::new(json)
                                    .color(theme::TEXT_SECONDARY)
                                    .size(11.0)
                            );
                        });
                    }
                    
                    // Playlist
                    if !self.playlist.is_empty() {
                        ui.add_space(4.0);
                        ui.separator();
                        section_header(ui, "播放列表");
                        
                        egui::ScrollArea::vertical().max_height(200.0).show(ui, |ui| {
                            let playlist_snapshot = self.playlist.clone();
                            for (i, it) in playlist_snapshot.iter().enumerate() {
                                let basename = std::path::Path::new(it)
                                    .file_name()
                                    .map(|n| n.to_string_lossy().to_string())
                                    .unwrap_or_else(|| it.clone());
                                let is_current = i == self.playlist_index;
                                let text = if is_current {
                                    egui::RichText::new(format!("▶ {}", basename))
                                        .color(theme::ACCENT)
                                        .size(12.0)
                                } else {
                                    egui::RichText::new(format!("  {}", basename))
                                        .color(theme::TEXT_SECONDARY)
                                        .size(12.0)
                                };
                                if ui.add(egui::Label::new(text).sense(egui::Sense::click())).clicked() {
                                    let path = it.clone();
                                    self.open_and_play(path);
                                }
                            }
                        });
                    }
                    
                    // MRU
                    if !self.mru.is_empty() {
                        ui.add_space(4.0);
                        ui.separator();
                        section_header(ui, "最近打开");
                        
                        let mru_snapshot = self.mru.clone();
                        for it in mru_snapshot.iter().take(5) {
                            let basename = std::path::Path::new(it)
                                .file_name()
                                .map(|n| n.to_string_lossy().to_string())
                                .unwrap_or_else(|| it.clone());
                            let text = egui::RichText::new(&basename)
                                .color(theme::TEXT_SECONDARY)
                                .size(12.0);
                            if ui.add(egui::Label::new(text).sense(egui::Sense::click()))
                                .on_hover_text(it)
                                .clicked()
                            {
                                let path = it.clone();
                                self.open_and_play(path);
                            }
                        }
                    }
                });
        }

        // ── Optional: Bottom panel for logs ──
        if self.show_logs && self.app_mode == AppMode::Player {
            egui::TopBottomPanel::bottom("logs_panel")
                .resizable(true)
                .default_height(150.0)
                .frame(egui::Frame::none()
                    .fill(theme::BG_DARK)
                    .inner_margin(egui::Margin::same(10.0))
                    .stroke(egui::Stroke::new(1.0, theme::BORDER))
                )
                .show(ctx, |ui| {
                    ui.horizontal(|ui| {
                        section_header(ui, "日志");
                        ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                            if ui.add(egui::Button::new(
                                egui::RichText::new("清除").color(theme::TEXT_DIM).size(11.0)
                            ).frame(false)).clicked() {
                                self.logs.clear();
                            }
                        });
                    });
                    egui::ScrollArea::vertical()
                        .stick_to_bottom(true)
                        .show(ui, |ui| {
                            for line in &self.logs {
                                let color = if line.starts_with('✕') {
                                    theme::ERROR
                                } else if line.starts_with('▶') {
                                    theme::SUCCESS
                                } else if line.starts_with('◼') {
                                    theme::WARNING
                                } else {
                                    theme::TEXT_DIM
                                };
                                ui.label(
                                    egui::RichText::new(line)
                                        .color(color)
                                        .size(11.0)
                                        .monospace()
                                );
                            }
                        });
                });
        }

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        //  Central: Video area - 只在播放器模式下显示
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        if self.app_mode == AppMode::Player {
            egui::CentralPanel::default()
            .frame(egui::Frame::none()
                .fill(theme::BG_DARK)
                .inner_margin(egui::Margin::same(0.0))
            )
            .show(ctx, |ui| {
                if let Some(tex) = &self.video_tex {
                    let avail = ui.available_size();
                    // Track the display area for dynamic render sizing
                    self.video_display_w = avail.x;
                    self.video_display_h = avail.y;
                    let (vw, vh) = (self.video_w as f32, self.video_h as f32);
                    if vw > 0.0 && vh > 0.0 {
                        let scale = (avail.x / vw).min(avail.y / vh).max(0.1);
                        let size = egui::vec2(vw * scale, vh * scale);
                        
                        // Center the video
                        let offset_x = (avail.x - size.x) / 2.0;
                        let offset_y = (avail.y - size.y) / 2.0;
                        
                        let (response, painter) = ui.allocate_painter(avail, egui::Sense::click());
                        let rect = egui::Rect::from_min_size(
                            egui::pos2(response.rect.min.x + offset_x, response.rect.min.y + offset_y),
                            size,
                        );
                        
                        // Draw video
                        painter.image(
                            tex.id(), rect,
                            egui::Rect::from_min_max(egui::pos2(0.0, 0.0), egui::pos2(1.0, 1.0)),
                            egui::Color32::WHITE,
                        );
                        
                        // Draw subtitles
                        if self.subtitle_enabled && !self.active_subtitles.is_empty() {
                            let current_time_ms = self.current_audio_time_ms().unwrap_or(self.position_ms);
                            let current_subtitles: Vec<&bova_playback::SubtitleFrame> = self.active_subtitles.iter()
                                .filter(|sf| sf.start_ms <= current_time_ms && sf.end_ms >= current_time_ms)
                                .collect();
                            
                            if !current_subtitles.is_empty() {
                                let mut y_offset = rect.height() - 50.0;
                                for subtitle in current_subtitles {
                                    let font = egui::FontId::proportional(subtitle.style.font_size * scale);
                                    let text_color = egui::Color32::from_rgba_unmultiplied(
                                        subtitle.style.font_color[0], subtitle.style.font_color[1],
                                        subtitle.style.font_color[2], subtitle.style.font_color[3],
                                    );
                                    let bg_color = egui::Color32::from_black_alpha(180);
                                    
                                    let galley = ui.painter().layout_no_wrap(
                                        subtitle.text.clone(), font.clone(), text_color,
                                    );
                                    let text_rect = egui::Rect::from_min_size(
                                        egui::pos2(rect.center().x - galley.size().x / 2.0, rect.min.y + y_offset),
                                        galley.size(),
                                    );
                                    painter.rect_filled(text_rect.expand(6.0), 4.0, bg_color);
                                    painter.galley(text_rect.min, galley.clone(), text_color);
                                    y_offset -= galley.size().y + 12.0;
                                }
                            }
                        }
                        
                        // 浮动控制按钮 - 鼠标悬停在视频中央时显示
                        let mouse_pos = response.hover_pos();
                        let show_floating_controls = if let Some(pos) = mouse_pos {
                            rect.contains(pos)
                        } else {
                            false
                        };
                        
                        if show_floating_controls && self.playing {
                            // 在视频中央显示浮动控制按钮
                            let center = rect.center();
                            let button_spacing = 80.0;
                            
                            // 半透明背景
                            let controls_rect = egui::Rect::from_center_size(
                                center,
                                egui::vec2(button_spacing * 3.0 + 40.0, 80.0)
                            );
                            painter.rect_filled(controls_rect, 12.0, egui::Color32::from_black_alpha(120));
                            
                            // 在控制区域内分配 UI
                            ui.allocate_ui_at_rect(controls_rect, |ui| {
                                ui.horizontal(|ui| {
                                    ui.add_space(10.0);
                                    
                                    // 快退 10 秒
                                    if large_icon_button(ui, "⏪", "快退 10 秒").clicked() {
                                        let target_ms = (self.position_ms - 10000).max(0);
                                        self.position_ms = target_ms;
                                        if let Some(pb) = &self.playback {
                                            if let Some(cmd_tx) = &pb.cmd_tx {
                                                let _ = cmd_tx.try_send(MpvCommand::SeekAbsolute(target_ms as f64 / 1000.0));
                                            }
                                        }
                                    }
                                    
                                    ui.add_space(10.0);
                                    
                                    // 暂停/播放
                                    if self.playing {
                                        if large_icon_button(ui, "⏸", "暂停").clicked() {
                                            self.playing = false;
                                            if let Some(pb) = &self.playback {
                                                if let Some(cmd_tx) = &pb.cmd_tx {
                                                    let _ = cmd_tx.try_send(MpvCommand::Pause);
                                                }
                                            }
                                        }
                                    } else {
                                        if large_icon_button(ui, "▶", "播放").clicked() {
                                            self.playing = true;
                                            if let Some(pb) = &self.playback {
                                                if let Some(cmd_tx) = &pb.cmd_tx {
                                                    let _ = cmd_tx.try_send(MpvCommand::Resume);
                                                }
                                            }
                                        }
                                    }
                                    
                                    ui.add_space(10.0);
                                    
                                    // 快进 10 秒
                                    if large_icon_button(ui, "⏩", "快进 10 秒").clicked() {
                                        let target_ms = (self.position_ms + 10000).min(self.duration_ms);
                                        self.position_ms = target_ms;
                                        if let Some(pb) = &self.playback {
                                            if let Some(cmd_tx) = &pb.cmd_tx {
                                                let _ = cmd_tx.try_send(MpvCommand::SeekAbsolute(target_ms as f64 / 1000.0));
                                            }
                                        }
                                    }
                                });
                            });
                        }
                        
                        // Click to toggle play/pause (保留原有的点击功能)
                        if response.clicked() && !show_floating_controls {
                            if self.playing {
                                self.playing = false;
                                if let Some(pb) = &self.playback {
                                    if let Some(cmd_tx) = &pb.cmd_tx {
                                        let _ = cmd_tx.try_send(MpvCommand::Pause);
                                    }
                                }
                            } else if !self.url.is_empty() {
                                self.playing = true;
                                if let Some(pb) = &self.playback {
                                    if let Some(cmd_tx) = &pb.cmd_tx {
                                        let _ = cmd_tx.try_send(MpvCommand::Resume);
                                    }
                                } else {
                                    self.start_playback();
                                }
                            }
                        }
                    }
                } else {
                    // Empty state: show drag-drop hint
                    let avail = ui.available_size();
                    let (_, painter) = ui.allocate_painter(avail, egui::Sense::click_and_drag());
                    let center = painter.clip_rect().center();
                    
                    // Draw circle icon
                    painter.circle_stroke(center - egui::vec2(0.0, 28.0), 28.0, egui::Stroke::new(2.0, theme::BORDER_BRIGHT));
                    painter.text(
                        center - egui::vec2(0.0, 28.0),
                        egui::Align2::CENTER_CENTER,
                        "▶",
                        egui::FontId::proportional(24.0),
                        theme::ACCENT_MUTED,
                    );
                    
                    // Hint text
                    painter.text(
                        center + egui::vec2(0.0, 20.0),
                        egui::Align2::CENTER_CENTER,
                        "拖拽文件到这里，或点击选择文件",
                        egui::FontId::proportional(14.0),
                        theme::TEXT_DIM,
                    );
                    painter.text(
                        center + egui::vec2(0.0, 44.0),
                        egui::Align2::CENTER_CENTER,
                        "支持 MP4 / MKV / MOV / AVI / MP3 / FLAC",
                        egui::FontId::proportional(11.0),
                        theme::TEXT_DIM,
                    );
                }
            });

            // ── Handle drag-and-drop ──
            for file in ctx.input(|i| i.raw.dropped_files.clone()) {
                if let Some(path) = file.path {
                    if let Some(s) = path.to_str() {
                        self.url = s.to_string();
                        self.logs.push(format!("📂 拖入文件: {}", self.file_basename()));
                        self.open_and_play(self.url.clone());
                    }
                }
            }
        } // 结束播放器模式的视频区域

        // ── Process Emby Events ──
        self.process_emby_events();
        
        // ── Process pending images ──
        if !self.pending_images.is_empty() {
            let pending = std::mem::take(&mut self.pending_images);
            for (key, color_image) in pending {
                let texture = ctx.load_texture(&key, color_image, egui::TextureOptions::LINEAR);
                self.emby_image_cache.insert(key, texture);
            }
        }

        // ── Render UI ──
        egui::CentralPanel::default()
            .frame(egui::Frame::none().fill(theme::BG_DARK))
            .show(ctx, |ui| {
                match self.app_mode {
                    AppMode::Welcome => self.show_welcome_ui(ctx, ui),
                    AppMode::Player => {
                        // 播放器模式不需要额外的导航栏，已经有顶部栏了
                        self.show_player_ui(ctx, ui);
                    }
                    AppMode::Emby => {
                        // Emby 模式下根据视图显示不同的导航
                        if self.emby_view_mode == EmbyViewMode::ServerList {
                            // 服务器列表页显示返回按钮
                            egui::TopBottomPanel::top("top_nav").frame(egui::Frame::none().fill(theme::BG_PANEL).inner_margin(8.0)).show_inside(ui, |ui| {
                                ui.horizontal(|ui| {
                                    if ui.button("⬅ 返回首页").clicked() {
                                        self.app_mode = AppMode::Welcome;
                                    }
                                });
                            });
                        }
                        self.show_emby_ui(ctx, ui);
                    }
                }
            });

        // Request repaint frequently during playback  
        if self.playing {
            ctx.request_repaint(); // immediate, every-frame repaint
        } else {
            ctx.request_repaint_after(std::time::Duration::from_millis(100));
        }
    }
}

impl BovaGuiApp {
    // 显示欢迎页/启动页
    fn show_welcome_ui(&mut self, _ctx: &egui::Context, ui: &mut egui::Ui) {
        let available = ui.available_size();
        
        // 居中显示
        ui.vertical_centered(|ui| {
            ui.add_space(available.y * 0.25);
            
            // Logo / 标题
            ui.label(
                egui::RichText::new("▶ BovaPlayer")
                    .color(theme::ACCENT)
                    .size(48.0)
                    .strong()
            );
            
            ui.add_space(20.0);
            ui.label(
                egui::RichText::new("选择播放模式")
                    .color(theme::TEXT_SECONDARY)
                    .size(18.0)
            );
            
            ui.add_space(60.0);
            
            // 两个大按钮
            ui.horizontal(|ui| {
                ui.add_space((available.x - 600.0) / 2.0);
                
                // 本地播放按钮
                let local_btn = egui::Button::new(
                    egui::RichText::new("📺\n\n本地播放")
                        .size(24.0)
                        .color(egui::Color32::WHITE)
                )
                .fill(theme::BG_SURFACE)
                .stroke(egui::Stroke::new(2.0, theme::BORDER_BRIGHT))
                .rounding(egui::Rounding::same(12.0))
                .min_size(egui::vec2(280.0, 200.0));
                
                if ui.add(local_btn).clicked() {
                    self.app_mode = AppMode::Player;
                }
                
                ui.add_space(40.0);
                
                // 媒体服务器按钮
                let server_btn = egui::Button::new(
                    egui::RichText::new("🌐\n\n媒体服务器")
                        .size(24.0)
                        .color(egui::Color32::WHITE)
                )
                .fill(theme::BG_SURFACE)
                .stroke(egui::Stroke::new(2.0, theme::BORDER_BRIGHT))
                .rounding(egui::Rounding::same(12.0))
                .min_size(egui::vec2(280.0, 200.0));
                
                if ui.add(server_btn).clicked() {
                    self.app_mode = AppMode::Emby;
                    // 总是先进入服务器列表页
                    self.emby_view_mode = EmbyViewMode::ServerList;
                }
            });
            
            ui.add_space(40.0);
            
            // 提示文字
            ui.label(
                egui::RichText::new("本地播放：播放本地视频文件")
                    .color(theme::TEXT_DIM)
                    .size(13.0)
            );
            ui.label(
                egui::RichText::new("媒体服务器：连接 Emby/Jellyfin 服务器")
                    .color(theme::TEXT_DIM)
                    .size(13.0)
            );
        });
    }
    
    fn load_servers() -> Vec<EmbyServer> {
        if let Ok(path) = std::env::current_dir() {
             let path = path.join("bova_emby_config.json");
             if path.exists() {
                 if let Ok(file) = std::fs::File::open(path) {
                     if let Ok(servers) = serde_json::from_reader(file) {
                         return servers;
                     }
                 }
             }
        }
        Vec::new()
    }

    fn save_servers(&self) {
        if let Ok(path) = std::env::current_dir() {
             let path = path.join("bova_emby_config.json");
             if let Ok(file) = std::fs::File::create(path) {
                 let _ = serde_json::to_writer_pretty(file, &self.emby_servers);
             }
        }
    }
    
    // Extract existing player UI into helper
    fn show_player_ui(&mut self, ctx: &egui::Context, ui: &mut egui::Ui) {
        let _avail_rect = ui.available_rect_before_wrap();
        
        // If we want side panel behavior inside here, we can use a Splitter or just columns
        if self.show_probe {
           egui::SidePanel::left("probe_inner").show_inside(ui, |ui| {
               self.render_probe_panel(ui);
           });
        }
        
        // Player Central Area
        self.render_player_center(ui, ctx);
    }
    
    fn render_player_center(&mut self, ui: &mut egui::Ui, ctx: &egui::Context) {
        // Calculate dynamic video size based on available space
        let video_area = ui.available_rect_before_wrap();
        self.video_display_w = video_area.width();
        self.video_display_h = video_area.height();

        // Center the video
        let centered_rect = if self.video_w > 0 && self.video_h > 0 {
             let aspect = self.video_w as f32 / self.video_h as f32;
             let container_aspect = video_area.width() / video_area.height();
             
             let (w, h) = if aspect > container_aspect {
                 (video_area.width(), video_area.width() / aspect)
             } else {
                 (video_area.height() * aspect, video_area.height())
             };
             
             egui::Rect::from_center_size(video_area.center(), egui::vec2(w, h))
        } else {
             video_area
        };

        // Draw Video Texture
        if let Some(texture) = &self.video_tex {
             ui.painter().image(
                 texture.id(),
                 centered_rect,
                 egui::Rect::from_min_max(egui::pos2(0.0, 0.0), egui::pos2(1.0, 1.0)),
                 egui::Color32::WHITE
             );
        } else {
             // Placeholder / Drop zone
             ui.painter().rect_filled(video_area, 0.0, egui::Color32::BLACK);
        }
        
        // ── Controls Overlay ──
        // Only show controls if mouse matches or idle
        let mouse_pos = ctx.input(|i| i.pointer.interact_pos());
        let show_controls = if let Some(pos) = mouse_pos {
             video_area.contains(pos) || !self.playing
        } else {
             !self.playing
        };

        if show_controls || !self.opened {
             // Gradient Overlay at bottom
             let _bottom_rect = egui::Rect::from_min_size(
                 egui::pos2(video_area.min.x, video_area.max.y - 120.0),
                 egui::vec2(video_area.width(), 120.0)
             );
             // ui.painter().rect_filled(bottom_rect, 0.0, egui::Color32::from_black_alpha(150)); 
             // (Simple fill for now, gradient needs mesh)
        }

        if !self.opened {
            // Hint text
            ui.painter().text(
                video_area.center(),
                egui::Align2::CENTER_CENTER,
                "拖拽文件到这里，或点击选择文件",
                egui::FontId::proportional(20.0),
                theme::TEXT_DIM,
            );
        }
        // 注释掉视频上的悬浮控制栏，使用底部固定控制栏
        /*
        } else {
            // Render controls at bottom
             let controls_rect = egui::Rect::from_min_max(
                 egui::pos2(video_area.min.x, video_area.max.y - 80.0),
                 video_area.max
             );
             
             // Check interaction to avoid hiding
             let interact = ui.interact(controls_rect, ui.id().with("controls"), egui::Sense::hover());
             if interact.hovered() || show_controls {
                  ui.allocate_ui_at_rect(controls_rect, |ui| {
                      egui::Frame::none().fill(egui::Color32::from_black_alpha(180)).inner_margin(12.0).show(ui, |ui| {
                           ui.vertical(|ui| {
                               // Progress Bar
                                self.render_progress_bar(ui);
                                ui.add_space(8.0);
                                // Buttons
                                ui.horizontal(|ui| {
                                     if icon_button(ui, "⏮", "上一首").clicked() { self.playlist_prev(); }
                                     if self.playing {
                                         if accent_button(ui, "⏸  暂停").clicked() {
                                             self.playing = false;
                                             if let Some(pb) = &self.playback {
                                                 if let Some(cmd_tx) = &pb.cmd_tx {
                                                     let _ = cmd_tx.try_send(MpvCommand::Pause);
                                                 }
                                             }
                                         }
                                     } else {
                                         if accent_button(ui, "▶  播放").clicked() {
                                              if let Some(pb) = &self.playback {
                                                  self.playing = true;
                                                  if let Some(cmd_tx) = &pb.cmd_tx {
                                                      let _ = cmd_tx.try_send(MpvCommand::Resume);
                                                  }
                                              } else {
                                                  if self.url.is_empty() { self.pick_and_play_file(); }
                                                  else { self.start_playback(); }
                                              }
                                         }
                                     }
                                     if icon_button(ui, "⏹", "停止").clicked() { self.stop_playback(); }
                                     if icon_button(ui, "⏭", "下一首").clicked() { self.playlist_next(); }
                                     
                                     ui.add_space(20.0);
                                     ui.label("🔊");
                                     let vol_slider = egui::Slider::new(&mut self.volume, 0.0..=1.0).show_value(false);
                                     if ui.add_sized(egui::vec2(80.0, 20.0), vol_slider).changed() {
                                          if let Some(pb) = &self.playback {
                                              if let Some(cmd_tx) = &pb.cmd_tx {
                                                  let _ = cmd_tx.try_send(MpvCommand::SetVolume((self.volume * 100.0) as f64));
                                              }
                                          }
                                     }
                                     
                                     ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                                          if ui.button("📂 打开").clicked() { self.pick_and_play_file(); }
                                          if ui.button("ℹ 信息").clicked() { self.show_probe = !self.show_probe; }
                                     });
                                });
                           });
                      });
                  });
             }
        }
        */
        
        // ── Handle drag-and-drop ──
        for file in ctx.input(|i| i.raw.dropped_files.clone()) {
            if let Some(path) = file.path {
                if let Some(s) = path.to_str() {
                    self.url = s.to_string();
                    self.logs.push(format!("📂 拖入文件: {}", self.file_basename()));
                    self.open_and_play(self.url.clone());
                }
            }
        }
    }
    
    // Extracted helper for progress bar to reuse code
    fn render_progress_bar(&mut self, ui: &mut egui::Ui) {
         let (response, painter) = ui.allocate_painter(egui::vec2(ui.available_width(), 16.0), egui::Sense::click_and_drag());
         let rect = response.rect;
         
         // Seek logic
         if response.clicked() || response.dragged() {
              if let Some(pos) = response.interact_pointer_pos() {
                   let pct = ((pos.x - rect.min.x) / rect.width()).clamp(0.0, 1.0);
                   let target_ms = (self.duration_ms as f32 * pct) as i64;
                   self.position_ms = target_ms; // Optimistic
                   if let Some(pb) = &self.playback {
                       if let Some(cmd_tx) = &pb.cmd_tx {
                           let _ = cmd_tx.try_send(MpvCommand::SeekAbsolute(target_ms as f64 / 1000.0));
                       }
                   }
              }
         }
         
         // Draw background
         let track_rect = egui::Rect::from_min_size(egui::pos2(rect.min.x, rect.center().y - 2.0), egui::vec2(rect.width(), 4.0));
         painter.rect_filled(track_rect, 2.0, theme::BG_SURFACE);
         
         // Fill
         let progress = if self.duration_ms > 0 { (self.position_ms as f32 / self.duration_ms as f32).clamp(0.0, 1.0) } else { 0.0 };
         if progress > 0.0 {
              let fill_rect = egui::Rect::from_min_size(track_rect.min, egui::vec2(track_rect.width() * progress, 4.0));
              painter.rect_filled(fill_rect, 2.0, theme::ACCENT);
              painter.circle_filled(egui::pos2(fill_rect.max.x, track_rect.center().y), 6.0, theme::ACCENT_HOVER);
         }
         
         // Time text
         let time_text = format!("{} / {}", Self::format_time(self.position_ms), Self::format_time(self.duration_ms));
         ui.painter().text(rect.max + egui::vec2(0.0, 10.0), egui::Align2::RIGHT_TOP, time_text, egui::FontId::proportional(12.0), theme::TEXT_DIM);
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  Emby Logic
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
impl BovaGuiApp {
    fn process_emby_events(&mut self) {
        while let Ok(event) = self.emby_event_rx.try_recv() {
            match event {
                EmbyEvent::AuthSuccess(server) => {
                    self.emby_status_msg = Some(format!("已连接到 {}", server.name));
                    self.emby_servers.push(server.clone());
                    self.save_servers();
                    self.current_emby_server = Some(server);
                    self.show_add_server_window = false;
                    // Auto enter dashboard
                    self.emby_view_mode = EmbyViewMode::Dashboard;
                    if let (Some(client), Some(srv)) = (&self.emby_client, &self.current_emby_server) {
                        client.get_dashboard(srv);
                    }
                }
                EmbyEvent::AuthError(err) => {
                    self.emby_status_msg = Some(format!("连接失败: {}", err));
                }
                EmbyEvent::ItemsLoaded(items) => {
                    // 如果当前在详情页且选中的是 Series，则这些是 Seasons
                    if self.emby_view_mode == EmbyViewMode::ItemDetail {
                        if let Some(selected) = &self.selected_emby_item {
                            if selected.field_type.as_deref() == Some("Series") {
                                self.series_seasons = items.clone();
                                self.season_episodes.clear();
                                self.emby_status_msg = None;
                                
                                // 为每个 Season 加载 Episodes
                                if let (Some(client), Some(srv)) = (&self.emby_client, &self.current_emby_server) {
                                    for season in &items {
                                        let season_id = season.id.clone();
                                        let tx = self.emby_event_tx.clone();
                                        let srv_clone = srv.clone();
                                        
                                        std::thread::spawn(move || {
                                            if let (Some(token), Some(user_id)) = (&srv_clone.access_token, &srv_clone.user_id) {
                                                let client = reqwest::blocking::Client::new();
                                                let fields = "Fields=PrimaryImageAspectRatio,Overview";
                                                let url = format!(
                                                    "{}/Users/{}/Items?ParentId={}&{}", 
                                                    srv_clone.url.trim_end_matches('/'), 
                                                    user_id, 
                                                    season_id, 
                                                    fields
                                                );
                                                
                                                if let Ok(resp) = client.get(&url).header("X-Emby-Token", token).send() {
                                                    if resp.status().is_success() {
                                                        #[derive(serde::Deserialize)]
                                                        struct ItemsResp {
                                                            Items: Vec<EmbyItem>,
                                                        }
                                                        if let Ok(data) = resp.json::<ItemsResp>() {
                                                            let _ = tx.send(EmbyEvent::SeasonEpisodesLoaded(season_id, data.Items));
                                                        }
                                                    }
                                                }
                                            }
                                        });
                                    }
                                }
                                return;
                            }
                        }
                    }
                    
                    // 否则是正常的浏览器模式
                    self.emby_items = items;
                    self.emby_current_page = 0; // 重置到第一页
                    self.emby_view_mode = EmbyViewMode::Browser; // Switch to browser when items loaded
                    self.emby_status_msg = None;
                }
                EmbyEvent::DashboardLoaded(dash) => {
                    // 保存 dashboard
                    self.emby_dashboard = Some(dash.clone());
                    self.emby_status_msg = None;
                    
                    // 自动加载每个 View 的内容（递归查找影片）
                    if let (Some(client), Some(srv)) = (&self.emby_client, &self.current_emby_server) {
                        for view in &dash.views {
                            let view_id = view.id.clone();
                            let tx = self.emby_event_tx.clone();
                            let srv_clone = srv.clone();
                            
                            // 在后台线程递归加载影片
                            std::thread::spawn(move || {
                                if let (Some(token), Some(user_id)) = (&srv_clone.access_token, &srv_clone.user_id) {
                                    let client = reqwest::blocking::Client::new();
                                    
                                    // 使用 Recursive=true 参数递归获取，但区分电影和剧集
                                    // Movie: 直接显示电影
                                    // Series: 显示剧集（不显示单集 Episode）
                                    let fields = "Fields=PrimaryImageAspectRatio,Overview,ProductionYear,CommunityRating,OfficialRating";
                                    let url = format!(
                                        "{}/Users/{}/Items?ParentId={}&Recursive=true&IncludeItemTypes=Movie,Series&Limit=12&SortBy=DateCreated,SortName&SortOrder=Descending&{}", 
                                        srv_clone.url.trim_end_matches('/'), 
                                        user_id, 
                                        view_id, 
                                        fields
                                    );
                                    
                                    if let Ok(resp) = client.get(&url).header("X-Emby-Token", token).send() {
                                        if resp.status().is_success() {
                                            #[derive(serde::Deserialize)]
                                            struct ItemsResp {
                                                Items: Vec<EmbyItem>,
                                            }
                                            if let Ok(data) = resp.json::<ItemsResp>() {
                                                let _ = tx.send(EmbyEvent::ViewItemsLoaded(view_id, data.Items));
                                            }
                                        }
                                    }
                                }
                            });
                        }
                    }
                }
                EmbyEvent::ItemsError(err) => {
                    self.emby_status_msg = Some(format!("获取媒体失败: {}", err));
                }
                EmbyEvent::ImageLoaded(key, data) => {
                    // 解码图片并创建纹理
                    if let Ok(img) = image::load_from_memory(&data) {
                        let rgba = img.to_rgba8();
                        let size = [img.width() as usize, img.height() as usize];
                        let color_image = egui::ColorImage::from_rgba_unmultiplied(size, &rgba);
                        // 注意：这里需要 egui Context，我们在 update 中处理
                        // 暂时存储原始数据
                        self.pending_images.push((key.clone(), color_image));
                        self.emby_image_loading.remove(&key);
                    }
                }
                EmbyEvent::ViewItemsLoaded(view_id, items) => {
                    // 缓存该 View 的预览项目
                    self.emby_view_items.insert(view_id, items);
                }
                EmbyEvent::SeasonEpisodesLoaded(season_id, episodes) => {
                    // 缓存该 Season 的 Episodes
                    self.season_episodes.insert(season_id, episodes);
                }
                EmbyEvent::SeriesEpisodeCountLoaded(series_id, count) => {
                    // 缓存该 Series 的总集数
                    self.series_episode_count.insert(series_id.clone(), count);
                    self.series_count_loading.remove(&series_id);
                }
            }
        }
    }

    fn render_probe_panel(&mut self, ui: &mut egui::Ui) {
         // Panel header with close button
        ui.horizontal(|ui| {
            // section_header(ui, "信息面板"); // Assuming helper exists or just use heading
            ui.heading("信息面板");
            ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                if ui.button("✕").on_hover_text("关闭面板").clicked() {
                    self.show_probe = false;
                }
            });
        });
        ui.separator();
        ui.add_space(4.0);
        
        ui.label(egui::RichText::new("文件:").strong());
        ui.label(self.file_basename());
        ui.add_space(4.0);
        
        ui.label(egui::RichText::new("分辨率:").strong());
        ui.label(format!("{} x {}", self.video_w, self.video_h));
        ui.add_space(4.0);
        
        ui.label(egui::RichText::new("时长:").strong());
        ui.label(Self::format_time(self.duration_ms));
        ui.add_space(4.0);
        
        ui.label(egui::RichText::new("字幕轨道:").strong());
        for track in &self.subtitle_tracks {
            ui.label(track.to_string());
        }
    }

    fn show_emby_ui(&mut self, ctx: &egui::Context, ui: &mut egui::Ui) {
        if self.emby_view_mode == EmbyViewMode::ServerList {
            self.show_emby_server_list(ui);
        } else if self.emby_view_mode == EmbyViewMode::Dashboard {
            self.show_emby_dashboard(ui);
        } else if self.emby_view_mode == EmbyViewMode::Browser {
            self.show_emby_browser(ui);
        } else if self.emby_view_mode == EmbyViewMode::ItemDetail {
            self.show_emby_item_detail(ui);
        }

        // Add Server Window/Overlay
        if self.show_add_server_window {
            egui::Window::new("添加 Media Server")
                .anchor(egui::Align2::CENTER_CENTER, egui::vec2(0.0, 0.0))
                .collapsible(false)
                .resizable(false)
                .show(ctx, |ui| {
                    ui.set_min_width(500.0);
                    ui.add_space(20.0);
                    
                    egui::Grid::new("add_server_grid")
                        .spacing(egui::vec2(15.0, 15.0))
                        .show(ui, |ui| {
                            ui.label(egui::RichText::new("地址:").size(16.0));
                            ui.add_sized(
                                egui::vec2(380.0, 24.0), 
                                egui::TextEdit::singleline(&mut self.new_server_url)
                            ).on_hover_text("例如: http://192.168.1.10:8096");
                            ui.end_row();
                            
                            ui.label(egui::RichText::new("用户名:").size(16.0));
                            ui.add_sized(
                                egui::vec2(380.0, 24.0),
                                egui::TextEdit::singleline(&mut self.new_server_user)
                            );
                            ui.end_row();
                            
                            ui.label(egui::RichText::new("密码:").size(16.0));
                            ui.add_sized(
                                egui::vec2(380.0, 24.0),
                                egui::TextEdit::singleline(&mut self.new_server_pass).password(true)
                            );
                            ui.end_row();
                        });
                        
                    ui.add_space(20.0);
                    
                    ui.horizontal(|ui| {
                        ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                            if ui.add_sized(egui::vec2(80.0, 30.0), egui::Button::new("取消")).clicked() {
                                self.show_add_server_window = false;
                            }
                            ui.add_space(10.0);
                            if ui.add_sized(egui::vec2(80.0, 30.0), egui::Button::new("连接").fill(theme::ACCENT)).clicked() {
                                self.emby_status_msg = Some("正在连接...".to_string());
                                if let Some(client) = &self.emby_client {
                                    let server = EmbyServer {
                                        name: self.new_server_url.clone(), // Temp name
                                        url: self.new_server_url.clone(),
                                        username: self.new_server_user.clone(),
                                        user_id: None,
                                        access_token: None,
                                    };
                                    client.authenticate(server, self.new_server_pass.clone());
                                }
                            }
                        });
                    });
                    
                    if let Some(msg) = &self.emby_status_msg {
                        ui.add_space(10.0);
                        ui.label(egui::RichText::new(msg).color(theme::ACCENT));
                    }
                    ui.add_space(10.0);
                });
        }
    }

    fn show_emby_server_list(&mut self, ui: &mut egui::Ui) {
        ui.heading("媒体服务器列表");
        ui.add_space(10.0);
        
        if ui.button("➕ 添加服务器").clicked() {
            self.show_add_server_window = true;
            self.emby_status_msg = None;
        }
        
        ui.add_space(10.0);
        ui.separator();
        
        let mut delete_idx = None;
        egui::ScrollArea::vertical().show(ui, |ui| {
            for (i, server) in self.emby_servers.iter().enumerate() {
                ui.group(|ui| {
                    ui.horizontal(|ui| {
                        ui.label(egui::RichText::new("🌐").size(20.0));
                        ui.vertical(|ui| {
                            ui.heading(&server.name);
                            ui.label(&server.url);
                        });
                        ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                            if ui.button("🗑").on_hover_text("删除").clicked() {
                                delete_idx = Some(i);
                            }
                            if ui.button("进入").clicked() {
                                self.current_emby_server = Some(server.clone());
                                self.emby_view_mode = EmbyViewMode::Dashboard;
                                if let Some(client) = &self.emby_client {
                                    client.get_dashboard(server);
                                }
                            }
                        });
                    });
                });
            }
        });
        
        if let Some(i) = delete_idx {
            self.emby_servers.remove(i);
            self.save_servers();
        }
    }

    fn show_emby_dashboard(&mut self, ui: &mut egui::Ui) {
         // 顶部导航栏 - 返回服务器列表
         ui.horizontal(|ui| {
             if ui.add(egui::Button::new("⬅ 服务器列表").min_size(egui::vec2(100.0, 28.0))).clicked() {
                 self.emby_view_mode = EmbyViewMode::ServerList;
                 self.current_emby_server = None;
                 self.emby_dashboard = None;
                 self.emby_items.clear();
                 self.emby_navigation_stack.clear();
             }
             ui.separator();
             if let Some(server) = &self.current_emby_server {
                 ui.label(egui::RichText::new(&server.name).color(theme::TEXT_PRIMARY).size(14.0));
             }
         });
         ui.separator();
         
         // 克隆 dashboard 数据以避免借用冲突
         let dash = self.emby_dashboard.clone();
         
         if let Some(dash) = dash {
             egui::ScrollArea::vertical().show(ui, |ui| {
                 ui.add_space(10.0);
                 
                 // 只显示媒体库，去掉"继续观看"
                 if !dash.views.is_empty() {
                     // 克隆 views 以避免借用问题
                     let views = dash.views.clone();
                     
                     for view in &views {
                         ui.add_space(20.0);
                         
                         // 目录标题行
                         let view_id = view.id.clone();
                         let view_name = view.name.clone();
                         
                         // 检测"更多"按钮点击
                         let mut clicked_more = false;
                         
                         ui.horizontal(|ui| {
                             ui.heading(egui::RichText::new(&view_name).size(20.0).strong());
                             ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                                 if ui.add(egui::Button::new("更多 →")
                                     .fill(theme::BG_SURFACE)
                                     .stroke(egui::Stroke::new(1.0, theme::BORDER))
                                     .rounding(egui::Rounding::same(6.0))
                                     .min_size(egui::vec2(80.0, 28.0))
                                 ).clicked() {
                                     clicked_more = true;
                                 }
                             });
                         });
                         
                         // 在 horizontal 闭包外处理点击
                         if clicked_more {
                             self.emby_navigation_stack.clear();
                             self.emby_navigation_stack.push((view_id.clone(), view_name.clone()));
                             self.emby_current_page = 0;
                             if let Some(client) = &self.emby_client {
                                 if let Some(srv) = &self.current_emby_server {
                                     client.get_items(srv, Some(view_id.clone()), true);  // 浏览器模式，使用递归
                                 }
                             }
                         }
                         
                         ui.add_space(10.0);
                         
                         // 横向滚动展示该目录下的项目（预览前几个）
                         self.render_horizontal_item_row(ui, &view_id, 6);
                         
                         ui.add_space(5.0);
                         ui.separator();
                     }
                 }
             });
         }
    }
    
    // 渲染横向滚动的项目行（用于 Dashboard 预览）
    fn render_horizontal_item_row(&mut self, ui: &mut egui::Ui, parent_id: &str, _limit: usize) {
        // 从缓存中获取该 View 的项目
        let items = self.emby_view_items.get(parent_id).cloned();
        
        egui::ScrollArea::horizontal()
            .id_source(format!("row_{}", parent_id))
            .show(ui, |ui| {
                ui.horizontal(|ui| {
                    if let Some(items) = items {
                        // 显示实际的项目
                        for item in items.iter().take(12) {
                            let clicked = self.render_compact_item_card(ui, item);
                            if clicked {
                                // 点击项目，进入详情或子目录
                                self.handle_emby_item_click(item);
                            }
                        }
                    } else {
                        // 加载中，显示占位符
                        for i in 0..6 {
                            ui.group(|ui| {
                                ui.set_min_size(egui::vec2(120.0, 190.0));
                                ui.vertical_centered(|ui| {
                                    ui.add_space(5.0);
                                    
                                    // 图片占位区域
                                    let (rect, _) = ui.allocate_exact_size(
                                        egui::vec2(100.0, 150.0),
                                        egui::Sense::hover()
                                    );
                                    ui.painter().rect_filled(rect, 4.0, theme::BG_DARK);
                                    ui.painter().text(
                                        rect.center(),
                                        egui::Align2::CENTER_CENTER,
                                        "⏳",
                                        egui::FontId::proportional(30.0),
                                        theme::TEXT_DIM,
                                    );
                                    
                                    ui.add_space(5.0);
                                    ui.label(egui::RichText::new("加载中...").size(11.0).color(theme::TEXT_DIM));
                                });
                            });
                        }
                    }
                });
            });
    }
    
    // 渲染紧凑的项目卡片（用于横向滚动）- 简洁版
    fn render_compact_item_card(&mut self, ui: &mut egui::Ui, item: &EmbyItem) -> bool {
        let width = 140.0;
        let height = 240.0;
        
        let (rect, response) = ui.allocate_exact_size(
            egui::vec2(width, height),
            egui::Sense::click()
        );
        
        if ui.is_rect_visible(rect) {
            // 图片区域
            let image_height = 190.0;
            let image_rect = egui::Rect::from_min_size(
                rect.min,
                egui::vec2(width, image_height)
            );
            
            // 尝试显示图片 - 直角
            let image_key = format!("{}_{}", item.id, "Primary");
            if let Some(texture) = self.emby_image_cache.get(&image_key) {
                ui.painter().rect_filled(image_rect, 0.0, theme::BG_DARK);
                ui.painter().image(
                    texture.id(),
                    image_rect,
                    egui::Rect::from_min_max(egui::pos2(0.0, 0.0), egui::pos2(1.0, 1.0)),
                    egui::Color32::WHITE,
                );
            } else {
                // 占位符
                ui.painter().rect_filled(image_rect, 0.0, theme::BG_DARK);
                
                let icon = match item.field_type.as_deref() {
                    Some("Folder") | Some("CollectionFolder") | Some("UserView") => "📁",
                    Some("Movie") | Some("Video") => "🎬",
                    Some("Episode") => "📺",
                    Some("Series") | Some("BoxSet") => "📺",
                    Some("Season") => "📂",
                    _ => "📄",
                };
                ui.painter().text(
                    image_rect.center(),
                    egui::Align2::CENTER_CENTER,
                    icon,
                    egui::FontId::proportional(30.0),
                    theme::TEXT_DIM,
                );
                
                // 触发加载
                if !self.emby_image_loading.contains(&image_key) {
                    self.load_emby_image(item, false);
                }
            }
            
            // 剧集数量徽章（右上角）- 只对 Series 显示
            if item.field_type.as_deref() == Some("Series") {
                // 尝试从缓存获取剧集数量
                let count = self.series_episode_count.get(&item.id).copied();
                
                // 如果没有缓存且未在加载中，触发加载
                if count.is_none() && !self.series_count_loading.contains(&item.id) {
                    if let Some(client) = &self.emby_client {
                        if let Some(server) = &self.current_emby_server {
                            self.series_count_loading.insert(item.id.clone());
                            client.get_series_episode_count(server, item.id.clone());
                        }
                    }
                }
                
                // 如果有数据，显示徽章
                if let Some(count) = count {
                    let badge_size = 32.0;
                    let badge_pos = egui::pos2(image_rect.max.x - badge_size - 8.0, image_rect.min.y + 8.0);
                    let badge_rect = egui::Rect::from_min_size(badge_pos, egui::vec2(badge_size, badge_size));
                    
                    ui.painter().circle_filled(badge_rect.center(), badge_size / 2.0, egui::Color32::from_rgb(80, 200, 120));
                    
                    ui.painter().text(
                        badge_rect.center(),
                        egui::Align2::CENTER_CENTER,
                        format!("{}", count),
                        egui::FontId::proportional(13.0),
                        egui::Color32::WHITE,
                    );
                }
            }
            
            // 标题
            let title_y = image_rect.max.y + 8.0;
            
            let max_chars = 14;
            let title = if item.name.chars().count() > max_chars {
                let truncated: String = item.name.chars().take(max_chars).collect();
                format!("{}...", truncated)
            } else {
                item.name.clone()
            };
            
            let galley = ui.painter().layout_no_wrap(
                title,
                egui::FontId::proportional(13.0),
                theme::TEXT_PRIMARY,
            );
            
            let text_pos = egui::pos2(
                rect.min.x + (width - galley.size().x) / 2.0,
                title_y
            );
            ui.painter().galley(text_pos, galley, theme::TEXT_PRIMARY);
            
            // 年份
            if let Some(year) = item.production_year {
                let year_text = format!("{}", year);
                let year_galley = ui.painter().layout_no_wrap(
                    year_text,
                    egui::FontId::proportional(11.0),
                    theme::TEXT_DIM,
                );
                
                let year_pos = egui::pos2(
                    rect.min.x + (width - year_galley.size().x) / 2.0,
                    title_y + 18.0
                );
                ui.painter().galley(year_pos, year_galley, theme::TEXT_DIM);
            }
            
            // Hover 效果
            if response.hovered() {
                ui.painter().rect_stroke(image_rect, 0.0, egui::Stroke::new(3.0, theme::ACCENT));
            }
        }
        
        response.clicked()
    }
    
    // 渲染宽卡片（用于"继续观看"）
    fn render_wide_item_card(&mut self, ui: &mut egui::Ui, item: &EmbyItem) -> bool {
        let width = 280.0;
        let height = 180.0;
        
        let (rect, response) = ui.allocate_exact_size(
            egui::vec2(width, height),
            egui::Sense::click()
        );
        
        if ui.is_rect_visible(rect) {
            // 背景
            let bg_color = if response.hovered() {
                theme::BG_HOVER
            } else {
                theme::BG_SURFACE
            };
            ui.painter().rect_filled(rect, 8.0, bg_color);
            
            // 尝试显示背景图（Backdrop）
            let backdrop_key = format!("{}_{}", item.id, "Backdrop");
            if let Some(texture) = self.emby_image_cache.get(&backdrop_key) {
                ui.painter().image(
                    texture.id(),
                    rect,
                    egui::Rect::from_min_max(egui::pos2(0.0, 0.0), egui::pos2(1.0, 1.0)),
                    egui::Color32::WHITE,
                );
                
                // 添加底部渐变遮罩
                let gradient_rect = egui::Rect::from_min_size(
                    egui::pos2(rect.min.x, rect.max.y - 60.0),
                    egui::vec2(width, 60.0)
                );
                ui.painter().rect_filled(gradient_rect, 0.0, egui::Color32::from_black_alpha(180));
            } else {
                // 占位符
                ui.painter().rect_filled(rect, 8.0, theme::BG_DARK);
                
                let icon = match item.field_type.as_deref() {
                    Some("Episode") => "📺",
                    Some("Movie") => "🎬",
                    Some("Series") => "📺",
                    Some("Season") => "📂",
                    _ => "▶️",
                };
                ui.painter().text(
                    rect.center(),
                    egui::Align2::CENTER_CENTER,
                    icon,
                    egui::FontId::proportional(50.0),
                    theme::TEXT_DIM,
                );
                
                // 触发加载
                if !self.emby_image_loading.contains(&backdrop_key) {
                    self.load_emby_image(item, true);
                }
            }
            
            // 标题和信息（底部）
            let text_rect = egui::Rect::from_min_size(
                egui::pos2(rect.min.x + 12.0, rect.max.y - 50.0),
                egui::vec2(width - 24.0, 40.0)
            );
            
            ui.painter().text(
                text_rect.left_top(),
                egui::Align2::LEFT_TOP,
                &item.name,
                egui::FontId::proportional(14.0),
                egui::Color32::WHITE,
            );
            
            // 额外信息
            let mut info_parts = Vec::new();
            if let Some(series) = &item.original_title {
                info_parts.push(series.clone());
            }
            if let (Some(season), Some(episode)) = (item.parent_index_number, item.index_number) {
                info_parts.push(format!("S{}:E{}", season, episode));
            }
            
            if !info_parts.is_empty() {
                ui.painter().text(
                    text_rect.left_top() + egui::vec2(0.0, 20.0),
                    egui::Align2::LEFT_TOP,
                    info_parts.join(" • "),
                    egui::FontId::proportional(11.0),
                    egui::Color32::from_gray(200),
                );
            }
            
            // Hover 效果
            if response.hovered() {
                ui.painter().rect_stroke(rect, 8.0, egui::Stroke::new(3.0, theme::ACCENT));
            }
        }
        
        response.clicked()
    }
    
    // 渲染单个项目卡片（带图片）
    fn render_item_card(&mut self, ui: &mut egui::Ui, item: &EmbyItem, width: f32, height: f32) -> egui::Response {
        let group = ui.group(|ui| {
            ui.set_min_size(egui::vec2(width, height));
            ui.vertical(|ui| {
                // 图片区域
                let image_height = height - 60.0;
                let (rect, response) = ui.allocate_exact_size(
                    egui::vec2(width - 20.0, image_height),
                    egui::Sense::click()
                );
                
                // 尝试加载并显示图片
                let image_key = format!("{}_{}", item.id, "Primary");
                if let Some(texture) = self.emby_image_cache.get(&image_key) {
                    // 显示已缓存的图片
                    ui.painter().image(
                        texture.id(),
                        rect,
                        egui::Rect::from_min_max(egui::pos2(0.0, 0.0), egui::pos2(1.0, 1.0)),
                        egui::Color32::WHITE,
                    );
                } else {
                    // 显示占位符并触发加载
                    ui.painter().rect_filled(rect, 4.0, theme::BG_SURFACE);
                    
                    let icon = match item.field_type.as_deref() {
                        Some("Episode") => "📺",
                        Some("Movie") => "🎬",
                        Some("Series") => "📺",
                        Some("Season") => "📂",
                        Some("Folder") => "📁",
                        _ => "▶️",
                    };
                    ui.painter().text(
                        rect.center(),
                        egui::Align2::CENTER_CENTER,
                        icon,
                        egui::FontId::proportional(40.0),
                        theme::TEXT_DIM,
                    );
                    
                    // 触发图片加载
                    if !self.emby_image_loading.contains(&image_key) {
                        self.load_emby_image(item, false);
                    }
                }
                
                ui.add_space(8.0);
                
                // 标题
                ui.label(egui::RichText::new(&item.name).strong().size(13.0));
                
                // 额外信息
                if let Some(year) = item.production_year {
                    ui.label(egui::RichText::new(format!("{}", year)).color(theme::TEXT_DIM).size(11.0));
                }
                
                response
            });
        });
        
        if group.response.interact(egui::Sense::click()).clicked() {
            self.selected_emby_item = Some(item.clone());
            self.emby_view_mode = EmbyViewMode::ItemDetail;
        }
        
        group.response
    }
    
    // 加载 Emby 图片
    fn load_emby_image(&mut self, item: &EmbyItem, is_backdrop: bool) {
        if let Some(srv) = &self.current_emby_server {
            let image_key = format!("{}_{}", item.id, if is_backdrop { "Backdrop" } else { "Primary" });
            
            // 检查是否有图片标签
            let tag = if is_backdrop {
                item.backdrop_image_tags.as_ref().and_then(|tags| tags.first()).cloned()
            } else {
                item.image_tags.as_ref().and_then(|tags| tags.get("Primary")).cloned()
            };
            
            if let Some(tag) = tag {
                self.emby_image_loading.insert(image_key.clone());
                
                let url = EmbyClient::get_image_url(srv, &item.id, &tag, is_backdrop);
                let tx = self.emby_event_tx.clone();
                
                // 在后台线程加载图片
                std::thread::spawn(move || {
                    if let Ok(response) = reqwest::blocking::get(&url) {
                        if let Ok(bytes) = response.bytes() {
                            // 发送图片数据回主线程
                            let _ = tx.send(EmbyEvent::ImageLoaded(image_key, bytes.to_vec()));
                        }
                    }
                });
            }
        }
    }

    fn show_emby_browser(&mut self, ui: &mut egui::Ui) {
        // 面包屑导航 - 紧凑单行
        ui.horizontal(|ui| {
            if ui.add(egui::Button::new("⬅ 服务器").min_size(egui::vec2(80.0, 28.0))).clicked() {
                self.emby_view_mode = EmbyViewMode::ServerList;
                self.current_emby_server = None;
                self.emby_dashboard = None;
                self.emby_items.clear();
                self.emby_navigation_stack.clear();
                return;
            }
            
            ui.separator();
            
            if ui.add(egui::Button::new("🏠 首页").min_size(egui::vec2(70.0, 28.0))).clicked() {
                self.emby_view_mode = EmbyViewMode::Dashboard;
                self.emby_current_page = 0;
                if let (Some(client), Some(srv)) = (&self.emby_client, &self.current_emby_server) {
                    client.get_dashboard(srv);
                }
                return;
            }
            
            let mut target_idx = None;
            for (i, (_id, name)) in self.emby_navigation_stack.iter().enumerate() {
                ui.label(egui::RichText::new("/").color(theme::TEXT_DIM));
                if ui.add(egui::Button::new(name).frame(false)).clicked() {
                    target_idx = Some(i);
                }
            }
            
            if let Some(idx) = target_idx {
                // truncate stack to idx+1 (keep the clicked one)
                self.emby_navigation_stack.truncate(idx + 1);
                self.emby_current_page = 0;
                let (pid, _) = &self.emby_navigation_stack.last().unwrap();
                if let Some(client) = &self.emby_client {
                    if let Some(srv) = &self.current_emby_server {
                       client.get_items(srv, Some(pid.clone()), true);  // 浏览器模式，使用递归
                    }
                }
            }
        });
        ui.separator();
        
        if let Some(msg) = &self.emby_status_msg {
            ui.label(msg);
        }

        // 计算分页
        let total_items = self.emby_items.len();
        let total_pages = (total_items + self.emby_items_per_page - 1) / self.emby_items_per_page;
        let start_idx = self.emby_current_page * self.emby_items_per_page;
        let end_idx = (start_idx + self.emby_items_per_page).min(total_items);
        
        // 单行分页控制栏
        ui.horizontal(|ui| {
            ui.label(egui::RichText::new(format!("共 {} 项", total_items)).color(theme::TEXT_SECONDARY).size(13.0));
            
            if total_pages > 1 {
                ui.add_space(20.0);
                
                // 紧凑的分页按钮
                if ui.add_enabled(self.emby_current_page > 0, 
                    egui::Button::new("⏮").min_size(egui::vec2(32.0, 24.0))
                ).on_hover_text("首页").clicked() {
                    self.emby_current_page = 0;
                }
                
                if ui.add_enabled(self.emby_current_page > 0,
                    egui::Button::new("◀").min_size(egui::vec2(32.0, 24.0))
                ).on_hover_text("上一页").clicked() {
                    self.emby_current_page -= 1;
                }
                
                ui.label(egui::RichText::new(format!("{} / {}", self.emby_current_page + 1, total_pages))
                    .color(theme::TEXT_PRIMARY).size(13.0));
                
                if ui.add_enabled(self.emby_current_page < total_pages - 1,
                    egui::Button::new("▶").min_size(egui::vec2(32.0, 24.0))
                ).on_hover_text("下一页").clicked() {
                    self.emby_current_page += 1;
                }
                
                if ui.add_enabled(self.emby_current_page < total_pages - 1,
                    egui::Button::new("⏭").min_size(egui::vec2(32.0, 24.0))
                ).on_hover_text("末页").clicked() {
                    self.emby_current_page = total_pages - 1;
                }
            }
        });
        
        ui.add_space(10.0);
        ui.separator();
        ui.add_space(10.0);

        // Grid view - 只显示当前页的项目
        let mut clicked_item = None;
        egui::ScrollArea::vertical().show(ui, |ui| {
            let width = ui.available_width();
            let item_width = 160.0;
            let item_height = 240.0;
            let spacing = 12.0;
            let cols = ((width - 20.0) / (item_width + spacing)).floor() as usize;
            let cols = if cols == 0 { 1 } else { cols };

            // 克隆当前页的项目以避免借用冲突
            let page_items: Vec<EmbyItem> = if start_idx < total_items {
                self.emby_items[start_idx..end_idx].to_vec()
            } else {
                Vec::new()
            };

            egui::Grid::new("emby_grid")
                .spacing(egui::vec2(spacing, spacing))
                .show(ui, |ui| {
                    for (i, item) in page_items.iter().enumerate() {
                        if i > 0 && i % cols == 0 {
                            ui.end_row();
                        }
                        
                        // 使用新的卡片渲染函数
                        let response = self.render_item_card_inline(ui, item, item_width, item_height);
                        
                        if response.clicked() {
                            clicked_item = Some(item.clone());
                        }
                    }
                    ui.end_row();
                });
        });
        
        if let Some(item) = clicked_item {
            self.handle_emby_item_click(&item);
        }
    }
    
    // 内联渲染项目卡片（用于网格布局）- 简洁版
    fn render_item_card_inline(&mut self, ui: &mut egui::Ui, item: &EmbyItem, width: f32, height: f32) -> egui::Response {
        let (rect, response) = ui.allocate_exact_size(
            egui::vec2(width, height),
            egui::Sense::click()
        );
        
        if ui.is_rect_visible(rect) {
            // 图片区域 - 占据大部分空间
            let image_height = height - 70.0;  // 留出空间给标题和年份
            let image_rect = egui::Rect::from_min_size(
                rect.min,
                egui::vec2(width, image_height)
            );
            
            // 尝试显示图片 - 直角处理
            let image_key = format!("{}_{}", item.id, "Primary");
            if let Some(texture) = self.emby_image_cache.get(&image_key) {
                // 先画背景
                ui.painter().rect_filled(image_rect, 0.0, theme::BG_DARK);
                // 再画图片
                ui.painter().image(
                    texture.id(),
                    image_rect,
                    egui::Rect::from_min_max(egui::pos2(0.0, 0.0), egui::pos2(1.0, 1.0)),
                    egui::Color32::WHITE,
                );
            } else {
                // 占位符 - 直角
                ui.painter().rect_filled(image_rect, 0.0, theme::BG_DARK);
                
                let icon = match item.field_type.as_deref() {
                    Some("Folder") | Some("CollectionFolder") | Some("UserView") => "📁",
                    Some("Movie") | Some("Episode") | Some("Video") => "🎬",
                    Some("Series") | Some("BoxSet") => "📺",
                    Some("Season") => "📂",
                    _ => "📄",
                };
                ui.painter().text(
                    image_rect.center(),
                    egui::Align2::CENTER_CENTER,
                    icon,
                    egui::FontId::proportional(40.0),
                    theme::TEXT_DIM,
                );
                
                // 触发加载
                if !self.emby_image_loading.contains(&image_key) {
                    self.load_emby_image(item, false);
                }
            }
            
            // 剧集数量徽章（右上角）- 只对 Series 显示
            if item.field_type.as_deref() == Some("Series") {
                // 尝试从缓存获取剧集数量
                let count = self.series_episode_count.get(&item.id).copied();
                
                // 如果没有缓存且未在加载中，触发加载
                if count.is_none() && !self.series_count_loading.contains(&item.id) {
                    if let Some(client) = &self.emby_client {
                        if let Some(server) = &self.current_emby_server {
                            self.series_count_loading.insert(item.id.clone());
                            client.get_series_episode_count(server, item.id.clone());
                        }
                    }
                }
                
                // 如果有数据，显示徽章
                if let Some(count) = count {
                    let badge_size = 35.0;
                    let badge_pos = egui::pos2(image_rect.max.x - badge_size - 8.0, image_rect.min.y + 8.0);
                    let badge_rect = egui::Rect::from_min_size(badge_pos, egui::vec2(badge_size, badge_size));
                    
                    // 绿色圆形背景
                    ui.painter().circle_filled(badge_rect.center(), badge_size / 2.0, egui::Color32::from_rgb(80, 200, 120));
                    
                    // 显示集数
                    ui.painter().text(
                        badge_rect.center(),
                        egui::Align2::CENTER_CENTER,
                        format!("{}", count),
                        egui::FontId::proportional(14.0),
                        egui::Color32::WHITE,
                    );
                }
            }
            
            // 标题 - 在图片下方
            let title_y = image_rect.max.y + 8.0;
            
            // 截断标题文字
            let max_chars = 20;
            let title = if item.name.chars().count() > max_chars {
                let truncated: String = item.name.chars().take(max_chars).collect();
                format!("{}...", truncated)
            } else {
                item.name.clone()
            };
            
            // 标题文字
            let galley = ui.painter().layout_no_wrap(
                title,
                egui::FontId::proportional(14.0),
                theme::TEXT_PRIMARY,
            );
            
            let text_pos = egui::pos2(
                rect.min.x + (width - galley.size().x) / 2.0,
                title_y
            );
            ui.painter().galley(text_pos, galley, theme::TEXT_PRIMARY);
            
            // 年份 - 在标题下方，灰色小字
            if let Some(year) = item.production_year {
                let year_text = format!("{}", year);
                let year_galley = ui.painter().layout_no_wrap(
                    year_text,
                    egui::FontId::proportional(12.0),
                    theme::TEXT_DIM,
                );
                
                let year_pos = egui::pos2(
                    rect.min.x + (width - year_galley.size().x) / 2.0,
                    title_y + 20.0
                );
                ui.painter().galley(year_pos, year_galley, theme::TEXT_DIM);
            }
            
            // Hover 效果 - 只在图片上显示边框
            if response.hovered() {
                ui.painter().rect_stroke(image_rect, 0.0, egui::Stroke::new(3.0, theme::ACCENT));
            }
        }
        
        response
    }

    fn show_emby_item_detail(&mut self, ui: &mut egui::Ui) {
         if let Some(item) = self.selected_emby_item.clone() {
             // 顶部导航栏 - 紧凑单行
             ui.horizontal(|ui| {
                 if ui.add(egui::Button::new("⬅ 服务器").min_size(egui::vec2(80.0, 28.0))).clicked() {
                     self.emby_view_mode = EmbyViewMode::ServerList;
                     self.current_emby_server = None;
                     self.emby_dashboard = None;
                     self.emby_items.clear();
                     self.emby_navigation_stack.clear();
                     self.selected_emby_item = None;
                     return;
                 }
                 
                 ui.separator();
                 
                 if ui.add(egui::Button::new("⬅ 返回").min_size(egui::vec2(70.0, 28.0))).clicked() {
                     if self.emby_navigation_stack.is_empty() {
                         self.emby_view_mode = EmbyViewMode::Dashboard;
                     } else {
                         self.emby_view_mode = EmbyViewMode::Browser;
                     }
                     self.selected_emby_item = None;
                 }
                 ui.label(egui::RichText::new("/").color(theme::TEXT_DIM));
                 ui.label(egui::RichText::new(&item.name).color(theme::TEXT_PRIMARY).size(14.0));
             });
             ui.separator();
             
             egui::ScrollArea::vertical().show(ui, |ui| {
                 // Hero Section with Backdrop
                 let width = ui.available_width();
                 let height = 400.0;
                 let (_, rect) = ui.allocate_space(egui::vec2(width, height));
                 
                 let painter = ui.painter();
                 
                 // 尝试显示背景图
                 let backdrop_key = format!("{}_{}", item.id, "Backdrop");
                 if let Some(texture) = self.emby_image_cache.get(&backdrop_key) {
                     painter.image(
                         texture.id(),
                         rect,
                         egui::Rect::from_min_max(egui::pos2(0.0, 0.0), egui::pos2(1.0, 1.0)),
                         egui::Color32::WHITE,
                     );
                     
                     // 添加渐变遮罩效果（用半透明黑色矩形模拟）
                     let gradient_rect = egui::Rect::from_min_size(
                         egui::pos2(rect.min.x, rect.max.y - 200.0),
                         egui::vec2(width, 200.0)
                     );
                     painter.rect_filled(gradient_rect, 0.0, egui::Color32::from_black_alpha(180));
                 } else {
                     // 深色背景占位
                     painter.rect_filled(rect, 0.0, egui::Color32::from_rgb(20, 25, 35));
                     
                     // 触发背景图加载
                     if !self.emby_image_loading.contains(&backdrop_key) {
                         self.load_emby_image(&item, true);
                     }
                 }
                 
                 // 在背景上叠加信息
                 ui.allocate_ui_at_rect(rect, |ui| {
                     ui.with_layout(egui::Layout::bottom_up(egui::Align::LEFT), |ui| {
                         ui.add_space(20.0);
                         ui.horizontal(|ui| {
                             ui.add_space(20.0);
                             
                             // 左侧：海报图
                             let poster_width = 180.0;
                             let poster_height = 270.0;
                             let (poster_rect, _) = ui.allocate_exact_size(
                                 egui::vec2(poster_width, poster_height),
                                 egui::Sense::hover()
                             );
                             
                             let poster_key = format!("{}_{}", item.id, "Primary");
                             if let Some(texture) = self.emby_image_cache.get(&poster_key) {
                                 ui.painter().image(
                                     texture.id(),
                                     poster_rect,
                                     egui::Rect::from_min_max(egui::pos2(0.0, 0.0), egui::pos2(1.0, 1.0)),
                                     egui::Color32::WHITE,
                                 );
                             } else {
                                 ui.painter().rect_filled(poster_rect, 4.0, theme::BG_SURFACE);
                                 ui.painter().text(
                                     poster_rect.center(),
                                     egui::Align2::CENTER_CENTER,
                                     "🎬",
                                     egui::FontId::proportional(60.0),
                                     theme::TEXT_DIM,
                                 );
                                 
                                 if !self.emby_image_loading.contains(&poster_key) {
                                     self.load_emby_image(&item, false);
                                 }
                             }
                             
                             ui.add_space(20.0);
                             
                             // 右侧：详细信息
                             ui.vertical(|ui| {
                                 // 标题
                                 ui.heading(egui::RichText::new(&item.name).size(36.0).color(egui::Color32::WHITE).strong());
                                 
                                 ui.add_space(8.0);
                                 
                                 // 元数据行
                                 ui.horizontal(|ui| {
                                     // 如果是剧集，优先显示季和集信息
                                     if let (Some(season), Some(episode)) = (item.parent_index_number, item.index_number) {
                                         ui.label(egui::RichText::new(format!("Season {} Episode {}", season, episode))
                                             .color(theme::ACCENT)
                                             .size(16.0)
                                             .strong());
                                         ui.label(egui::RichText::new("•").color(theme::TEXT_DIM));
                                     }
                                     
                                     if let Some(year) = item.production_year {
                                         ui.label(egui::RichText::new(format!("{}", year)).color(theme::TEXT_PRIMARY).size(15.0));
                                         ui.label(egui::RichText::new("•").color(theme::TEXT_DIM));
                                     }
                                     
                                     if let Some(rating) = &item.official_rating {
                                         ui.label(egui::RichText::new(format!("{}", rating)).color(theme::TEXT_PRIMARY).size(15.0));
                                         ui.label(egui::RichText::new("•").color(theme::TEXT_DIM));
                                     }
                                     
                                     if let Some(runtime) = item.run_time_ticks {
                                         let minutes = runtime / 10_000_000 / 60;
                                         let hours = minutes / 60;
                                         let mins = minutes % 60;
                                         let time_str = if hours > 0 {
                                             format!("{}小时{}分钟", hours, mins)
                                         } else {
                                             format!("{}分钟", mins)
                                         };
                                         ui.label(egui::RichText::new(time_str).color(theme::TEXT_PRIMARY).size(15.0));
                                     }
                                 });
                                 
                                 ui.add_space(8.0);
                                 
                                 // 评分
                                 if let Some(score) = item.community_rating {
                                     ui.horizontal(|ui| {
                                         ui.label(egui::RichText::new("★").color(egui::Color32::GOLD).size(20.0));
                                         ui.label(egui::RichText::new(format!("{:.1}/10", score)).color(egui::Color32::WHITE).size(18.0).strong());
                                     });
                                     ui.add_space(8.0);
                                 }
                                 
                                 // 类型标签
                                 if let Some(media_type) = &item.media_type {
                                     ui.horizontal(|ui| {
                                         ui.label(egui::RichText::new(format!("类型: {}", media_type)).color(theme::TEXT_PRIMARY).size(14.0));
                                     });
                                     ui.add_space(8.0);
                                 }
                                 
                                 // 播放按钮
                                 if ui.add_sized(
                                     egui::vec2(160.0, 50.0),
                                     egui::Button::new(egui::RichText::new("▶ 立即播放").size(18.0).color(egui::Color32::WHITE))
                                         .fill(theme::ACCENT)
                                         .rounding(egui::Rounding::same(8.0))
                                 ).clicked() {
                                     if let Some(srv) = &self.current_emby_server {
                                         let url = EmbyClient::get_stream_url(srv, &item.id);
                                         if !url.is_empty() {
                                             self.app_mode = AppMode::Player;
                                             self.url = url.clone();
                                             self.logs.push(format!("🌐 Emby播放: {}", item.name));
                                             self.open_and_play(url);
                                         }
                                     }
                                 }
                                 
                                 ui.add_space(20.0);
                             });
                         });
                     });
                 });
                 
                 // Content Below Backdrop
                 ui.add_space(30.0);
                 
                 // 详细信息区域
                 ui.horizontal(|ui| {
                     ui.add_space(20.0);
                     ui.vertical(|ui| {
                         // 简介
                         ui.heading(egui::RichText::new("简介").size(22.0).strong());
                         ui.add_space(10.0);
                         
                         if let Some(overview) = &item.overview {
                             ui.label(egui::RichText::new(overview).size(15.0).color(theme::TEXT_SECONDARY));
                         } else {
                             ui.label(egui::RichText::new("暂无简介").color(theme::TEXT_DIM));
                         }
                         
                         ui.add_space(30.0);
                         
                         // 如果是 Series，显示 Season 选择器和 Episodes
                         if item.field_type.as_deref() == Some("Series") && !self.series_seasons.is_empty() {
                             let seasons = self.series_seasons.clone();
                             
                             // Season 选择下拉框
                             ui.horizontal(|ui| {
                                 ui.heading(egui::RichText::new("季").size(22.0).strong());
                                 ui.add_space(10.0);
                                 
                                 // 下拉框
                                 egui::ComboBox::from_id_source("season_selector")
                                     .selected_text(if self.selected_season_index < seasons.len() {
                                         seasons[self.selected_season_index].name.clone()
                                     } else {
                                         "选择季".to_string()
                                     })
                                     .width(200.0)
                                     .show_ui(ui, |ui| {
                                         for (idx, season) in seasons.iter().enumerate() {
                                             ui.selectable_value(&mut self.selected_season_index, idx, &season.name);
                                         }
                                     });
                             });
                             
                             ui.add_space(15.0);
                             
                             // 显示选中 Season 的 Episodes
                             if self.selected_season_index < seasons.len() {
                                 let selected_season = &seasons[self.selected_season_index];
                                 
                                 if let Some(episodes) = self.season_episodes.get(&selected_season.id).cloned() {
                                     // 横向滚动显示 Episodes
                                     egui::ScrollArea::horizontal()
                                         .id_source(format!("season_{}", selected_season.id))
                                         .show(ui, |ui| {
                                             ui.horizontal(|ui| {
                                                 for (idx, episode) in episodes.iter().enumerate() {
                                                     // 渲染 Episode 卡片
                                                     let width = 230.0;
                                                     let height = 150.0;
                                                     
                                                     let (rect, response) = ui.allocate_exact_size(
                                                         egui::vec2(width, height),
                                                         egui::Sense::click()
                                                     );
                                                     
                                                     if ui.is_rect_visible(rect) {
                                                         // 背景
                                                         ui.painter().rect_filled(rect, 6.0, theme::BG_SURFACE);
                                                         
                                                         // 图片区域
                                                         let image_key = format!("{}_{}", episode.id, "Primary");
                                                         if let Some(texture) = self.emby_image_cache.get(&image_key) {
                                                             ui.painter().image(
                                                                 texture.id(),
                                                                 rect,
                                                                 egui::Rect::from_min_max(egui::pos2(0.0, 0.0), egui::pos2(1.0, 1.0)),
                                                                 egui::Color32::WHITE,
                                                             );
                                                         } else {
                                                             ui.painter().rect_filled(rect, 6.0, theme::BG_DARK);
                                                             ui.painter().text(
                                                                 rect.center(),
                                                                 egui::Align2::CENTER_CENTER,
                                                                 "📺",
                                                                 egui::FontId::proportional(40.0),
                                                                 theme::TEXT_DIM,
                                                             );
                                                             
                                                             if !self.emby_image_loading.contains(&image_key) {
                                                                 self.load_emby_image(episode, false);
                                                             }
                                                         }
                                                         
                                                         // 底部文字
                                                         let text_rect = egui::Rect::from_min_size(
                                                             egui::pos2(rect.min.x + 10.0, rect.max.y - 35.0),
                                                             egui::vec2(width - 20.0, 30.0)
                                                         );
                                                         
                                                         // 半透明背景
                                                         ui.painter().rect_filled(
                                                             egui::Rect::from_min_size(
                                                                 egui::pos2(rect.min.x, rect.max.y - 40.0),
                                                                 egui::vec2(width, 40.0)
                                                             ),
                                                             0.0,
                                                             egui::Color32::from_black_alpha(180)
                                                         );
                                                         
                                                         let episode_label = if let Some(ep_num) = episode.index_number {
                                                             format!("{}. Episode {}", idx + 1, ep_num)
                                                         } else {
                                                             format!("{}. {}", idx + 1, episode.name)
                                                         };
                                                         
                                                         ui.painter().text(
                                                             text_rect.left_center(),
                                                             egui::Align2::LEFT_CENTER,
                                                             episode_label,
                                                             egui::FontId::proportional(13.0),
                                                             egui::Color32::WHITE,
                                                         );
                                                         
                                                         // Hover 效果
                                                         if response.hovered() {
                                                             ui.painter().rect_stroke(rect, 6.0, egui::Stroke::new(2.0, theme::ACCENT));
                                                         }
                                                         
                                                         // 点击播放
                                                         if response.clicked() {
                                                             if let Some(srv) = &self.current_emby_server {
                                                                 let url = EmbyClient::get_stream_url(srv, &episode.id);
                                                                 if !url.is_empty() {
                                                                     self.app_mode = AppMode::Player;
                                                                     self.url = url.clone();
                                                                     self.logs.push(format!("🌐 Emby播放: {}", episode.name));
                                                                     self.open_and_play(url);
                                                                 }
                                                             }
                                                         }
                                                     }
                                                     
                                                     ui.add_space(10.0);
                                                 }
                                             });
                                         });
                                 } else {
                                     // 加载中
                                     ui.label(egui::RichText::new("加载中...").color(theme::TEXT_DIM));
                                 }
                             }
                             
                             ui.add_space(30.0);
                         }
                         
                         // 其他信息
                         ui.heading(egui::RichText::new("详细信息").size(22.0).strong());
                         ui.add_space(10.0);
                         
                         egui::Grid::new("detail_grid")
                             .spacing(egui::vec2(20.0, 10.0))
                             .show(ui, |ui| {
                                 if let Some(original_title) = &item.original_title {
                                     ui.label(egui::RichText::new("原始标题:").color(theme::TEXT_DIM).size(14.0));
                                     ui.label(egui::RichText::new(original_title).color(theme::TEXT_PRIMARY).size(14.0));
                                     ui.end_row();
                                 }
                                 
                                 if let Some(field_type) = &item.field_type {
                                     ui.label(egui::RichText::new("类型:").color(theme::TEXT_DIM).size(14.0));
                                     ui.label(egui::RichText::new(field_type).color(theme::TEXT_PRIMARY).size(14.0));
                                     ui.end_row();
                                 }
                                 
                                 if let Some(index) = item.index_number {
                                     ui.label(egui::RichText::new("集数:").color(theme::TEXT_DIM).size(14.0));
                                     ui.label(egui::RichText::new(format!("第 {} 集", index)).color(theme::TEXT_PRIMARY).size(14.0));
                                     ui.end_row();
                                 }
                                 
                                 if let Some(season) = item.parent_index_number {
                                     ui.label(egui::RichText::new("季数:").color(theme::TEXT_DIM).size(14.0));
                                     ui.label(egui::RichText::new(format!("第 {} 季", season)).color(theme::TEXT_PRIMARY).size(14.0));
                                     ui.end_row();
                                 }
                             });
                     });
                 });
                 
                 ui.add_space(40.0);
             });
         }
    }

    fn handle_emby_item_click(&mut self, item: &EmbyItem) {
        let item_type = item.field_type.as_deref();
        
        match item_type {
            // Series 直接进入详情页，并加载 Seasons
            Some("Series") => {
                self.selected_emby_item = Some(item.clone());
                self.emby_view_mode = EmbyViewMode::ItemDetail;
                self.series_seasons.clear();
                self.season_episodes.clear();
                self.selected_season_index = 0;  // 重置为第一季
                
                // 加载该 Series 的所有 Seasons（不递归）
                if let Some(client) = &self.emby_client {
                    if let Some(srv) = &self.current_emby_server {
                        client.get_items(srv, Some(item.id.clone()), false);  // Series -> Season，不递归
                    }
                }
            }
            // Folder, Season 等进入浏览器模式
            Some("Folder") | Some("CollectionFolder") | Some("UserView") | Some("BoxSet") => {
                self.emby_navigation_stack.push((item.id.clone(), item.name.clone()));
                self.emby_current_page = 0;
                self.emby_view_mode = EmbyViewMode::Browser;
                if let Some(client) = &self.emby_client {
                    if let Some(srv) = &self.current_emby_server {
                        client.get_items(srv, Some(item.id.clone()), true);  // 浏览器模式，递归查找影片
                    }
                }
            }
            // Season 进入浏览器模式，显示 Episodes
            Some("Season") => {
                self.emby_navigation_stack.push((item.id.clone(), item.name.clone()));
                self.emby_current_page = 0;
                self.emby_view_mode = EmbyViewMode::Browser;
                if let Some(client) = &self.emby_client {
                    if let Some(srv) = &self.current_emby_server {
                        client.get_items(srv, Some(item.id.clone()), false);  // Season -> Episode，不递归
                    }
                }
            }
            // 可播放的项目（Movie 或 Episode），显示详情
            _ => {
                self.selected_emby_item = Some(item.clone());
                self.emby_view_mode = EmbyViewMode::ItemDetail;
            }
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  Original Update Loop (Renamed/Moved)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


impl BovaGuiApp {
    /// Display a video frame immediately (no A/V sync — MPV handles that internally)
    fn show_video_frame(&mut self, ctx: &egui::Context, frame: bova_playback::VideoFrame) {
        let w = frame.width as usize;
        let h = frame.height as usize;
        if w == 0 || h == 0 { return; }

        let ci = egui::ColorImage::from_rgba_unmultiplied([w, h], &frame.rgba);
        self.video_tex = Some(ctx.load_texture(
            "video",
            ci,
            egui::TextureOptions::LINEAR,
        ));
        self.video_w = frame.width;
        self.video_h = frame.height;
        self.last_video_show_instant = Some(Instant::now());
    }
    
    fn pick_and_play_file(&mut self) {
        let mut dlg = FileDialog::new();
        if let Some(dir) = &self.current_dir { dlg = dlg.set_directory(dir); }
        if let Some(file) = dlg
            .add_filter("视频文件", &["mp4","mkv","mov","avi","wmv","webm","flv","ts","m2ts","mpg","mpeg","rmvb","rm","3gp","vob"])
            .add_filter("音频文件", &["mp3","flac","m4a","aac","wav","ogg","wma","opus","ape","alac"])
            .add_filter("所有文件", &["*"])
            .pick_file()
        {
            if let Some(path) = file.to_str() {
                self.url = path.to_string();
                self.logs.push(format!("📂 选择文件: {}", self.file_basename()));
                self.open_and_play(self.url.clone());
            }
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  Entry point
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

fn main() -> eframe::Result<()> {
    let native_options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_inner_size([1100.0, 720.0])
            .with_min_inner_size([640.0, 400.0])
            .with_title("BovaPlayer"),
        ..Default::default()
    };
    eframe::run_native(
        "BovaPlayer",
        native_options,
        Box::new(|cc| Box::new(BovaGuiApp::new(cc))),
    )
}

// CJK font loader
fn load_cjk_font() -> Option<Vec<u8>> {
    use std::fs;
    let candidates: &[&str] = &[
        "/System/Library/Fonts/PingFang.ttc",
        "/System/Library/Fonts/STHeiti Light.ttc",
        "/System/Library/Fonts/STHeiti Medium.ttc",
        "C:/Windows/Fonts/msyh.ttc",
        "C:/Windows/Fonts/simhei.ttf",
        "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
        "/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc",
        "/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc",
    ];
    for p in candidates {
        if let Ok(bytes) = fs::read(p) {
            return Some(bytes);
        }
    }
    None
}
