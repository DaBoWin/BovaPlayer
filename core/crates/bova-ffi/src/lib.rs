//! C ABI for BovaPlayer minimal core

use libc::{c_char, c_int, c_longlong, c_void};
use std::ffi::{CStr, CString};
use std::sync::{Arc, Mutex};
use std::collections::HashMap;

use bova_core::{create_player, MediaOptions, Player};

#[repr(C)]
pub struct BovaPlayerHandle(*mut c_void);

// 标记为unsafe Send，因为原始指针需要手动保证线程安全
unsafe impl Send for BovaPlayerHandle {}
unsafe impl Sync for BovaPlayerHandle {}

struct Holder {
    player: bova_core::BovaPlayer,
}

#[no_mangle]
pub extern "C" fn bova_create() -> BovaPlayerHandle {
    let holder = Box::new(Holder { player: create_player() });
    BovaPlayerHandle(Box::into_raw(holder) as *mut c_void)
}

#[no_mangle]
pub extern "C" fn bova_destroy(h: BovaPlayerHandle) {
    if h.0.is_null() { return; }
    unsafe { drop(Box::from_raw(h.0 as *mut Holder)); }
}

fn opt_from_json(ptr: *const c_char) -> MediaOptions {
    if ptr.is_null() { return MediaOptions::default(); }
    unsafe {
        match CStr::from_ptr(ptr).to_str().ok().and_then(|s| serde_json::from_str::<MediaOptions>(s).ok()) {
            Some(o) => o,
            None => MediaOptions::default(),
        }
    }
}

#[no_mangle]
pub extern "C" fn bova_open(h: BovaPlayerHandle, url: *const c_char, options_json: *const c_char) -> c_int {
    if h.0.is_null() || url.is_null() { return -1; }
    let opts = opt_from_json(options_json);
    let holder = unsafe { &mut *(h.0 as *mut Holder) };
    let url_rs = unsafe { CStr::from_ptr(url).to_string_lossy().to_string() };
    match holder.player.open(&url_rs, opts) { Ok(_) => 0, Err(_) => -2 }
}

#[no_mangle]
pub extern "C" fn bova_play(h: BovaPlayerHandle) -> c_int {
    if h.0.is_null() { return -1; }
    let holder = unsafe { &mut *(h.0 as *mut Holder) };
    match holder.player.play() { Ok(_) => 0, Err(_) => -2 }
}

#[no_mangle]
pub extern "C" fn bova_pause(h: BovaPlayerHandle) -> c_int {
    if h.0.is_null() { return -1; }
    let holder = unsafe { &mut *(h.0 as *mut Holder) };
    match holder.player.pause() { Ok(_) => 0, Err(_) => -2 }
}

#[no_mangle]
pub extern "C" fn bova_seek(h: BovaPlayerHandle, pos_ms: c_longlong, accurate: c_int) -> c_int {
    if h.0.is_null() { return -1; }
    let holder = unsafe { &mut *(h.0 as *mut Holder) };
    let acc = accurate != 0;
    match holder.player.seek(pos_ms as i64, acc) { Ok(_) => 0, Err(_) => -2 }
}

#[no_mangle]
pub extern "C" fn bova_stop(h: BovaPlayerHandle) -> c_int {
    if h.0.is_null() { return -1; }
    let holder = unsafe { &mut *(h.0 as *mut Holder) };
    match holder.player.stop() { Ok(_) => 0, Err(_) => -2 }
}

// Helper to get version string (for quick sanity in host bindings)
#[no_mangle]
pub extern "C" fn bova_version_string() -> *mut c_char {
    let s = CString::new("BovaFFI 0.0.1").unwrap();
    s.into_raw()
}

#[no_mangle]
pub extern "C" fn bova_string_free(p: *mut c_char) {
    if p.is_null() { return; }
    unsafe { drop(CString::from_raw(p)); }
}

// ============================================================================
// Flutter MPV Player FFI API
// ============================================================================

use std::sync::atomic::{AtomicBool, AtomicU32, Ordering};

#[cfg(feature = "mpv")]
use bova_playback::{start_mpv_playback_handles, PlaybackConfig, MpvCommand};

// 全局播放器管理器
lazy_static::lazy_static! {
    static ref PLAYERS: Arc<Mutex<HashMap<i64, PlayerInstance>>> = Arc::new(Mutex::new(HashMap::new()));
    static ref NEXT_PLAYER_ID: Arc<Mutex<i64>> = Arc::new(Mutex::new(1));
}

struct PlayerInstance {
    #[cfg(feature = "mpv")]
    handles: Option<bova_playback::PlaybackHandles>,
    is_playing: Arc<AtomicBool>,
    current_position: Arc<Mutex<f64>>,
    duration: Arc<Mutex<f64>>,
    video_width: Arc<AtomicU32>,
    video_height: Arc<AtomicU32>,
}

// Flutter-specific API
#[no_mangle]
pub extern "C" fn bova_flutter_initialize() -> *mut c_char {
    // 初始化成功返回null，失败返回错误信息
    std::ptr::null_mut()
}

/// 创建新的播放器实例，返回播放器ID（>0表示成功，<=0表示失败）
#[no_mangle]
pub extern "C" fn bova_mpv_create_player() -> c_longlong {
    let player_id = {
        let mut next_id = NEXT_PLAYER_ID.lock().unwrap();
        let id = *next_id;
        *next_id += 1;
        id
    };
    
    let instance = PlayerInstance {
        #[cfg(feature = "mpv")]
        handles: None,
        is_playing: Arc::new(AtomicBool::new(false)),
        current_position: Arc::new(Mutex::new(0.0)),
        duration: Arc::new(Mutex::new(0.0)),
        video_width: Arc::new(AtomicU32::new(0)),
        video_height: Arc::new(AtomicU32::new(0)),
    };
    
    PLAYERS.lock().unwrap().insert(player_id, instance);
    player_id
}

/// 打开媒体文件/URL
#[no_mangle]
pub extern "C" fn bova_mpv_open_media(player_id: c_longlong, url: *const c_char, hwaccel: c_int) -> c_int {
    #[cfg(not(feature = "mpv"))]
    {
        let _ = (player_id, url, hwaccel);
        eprintln!("[bova-ffi] MPV feature not enabled");
        return -1;
    }
    
    #[cfg(feature = "mpv")]
    {
        if url.is_null() {
            return -1;
        }
        
        let url_str = unsafe { CStr::from_ptr(url).to_string_lossy().to_string() };
        let config = PlaybackConfig {
            hwaccel: hwaccel != 0,
            subtitle_enabled: false,
            subtitle_index: None,
            engine: None,
        };
        
        match start_mpv_playback_handles(&url_str, &config) {
            Ok(handles) => {
                let mut players = PLAYERS.lock().unwrap();
                if let Some(instance) = players.get_mut(&player_id) {
                    instance.handles = Some(handles);
                    instance.is_playing.store(true, Ordering::Release);
                    
                    // 启动帧处理线程
                    let player_id_clone = player_id;
                    std::thread::spawn(move || {
                        process_video_frames(player_id_clone);
                    });
                    
                    0
                } else {
                    -2
                }
            }
            Err(e) => {
                eprintln!("[bova-ffi] Failed to open media: {}", e);
                -3
            }
        }
    }
}

#[cfg(feature = "mpv")]
fn process_video_frames(player_id: i64) {
    use crossbeam_channel::TryRecvError;
    
    loop {
        let should_continue = {
            let players = PLAYERS.lock().unwrap();
            if let Some(instance) = players.get(&player_id) {
                if let Some(ref handles) = instance.handles {
                    match handles.video_rx.try_recv() {
                        Ok(frame) => {
                            // 更新视频尺寸
                            instance.video_width.store(frame.width, Ordering::Release);
                            instance.video_height.store(frame.height, Ordering::Release);
                            
                            // 更新位置和时长
                            if let Some(pts) = frame.pts_ms {
                                *instance.current_position.lock().unwrap() = pts as f64 / 1000.0;
                            }
                            if let Some(dur) = frame.duration_ms {
                                *instance.duration.lock().unwrap() = dur as f64 / 1000.0;
                            }
                            
                            // 帧数据存储在全局缓存中供Flutter读取
                            store_latest_frame(player_id, frame);
                            true
                        }
                        Err(TryRecvError::Empty) => {
                            std::thread::sleep(std::time::Duration::from_millis(5));
                            true
                        }
                        Err(TryRecvError::Disconnected) => false,
                    }
                } else {
                    false
                }
            } else {
                false
            }
        };
        
        if !should_continue {
            break;
        }
    }
}

// 帧缓存
lazy_static::lazy_static! {
    static ref FRAME_CACHE: Arc<Mutex<HashMap<i64, bova_playback::VideoFrame>>> = 
        Arc::new(Mutex::new(HashMap::new()));
}

#[cfg(feature = "mpv")]
fn store_latest_frame(player_id: i64, frame: bova_playback::VideoFrame) {
    let mut cache = FRAME_CACHE.lock().unwrap();
    cache.insert(player_id, frame);
}

#[no_mangle]
pub extern "C" fn bova_flutter_open_media(file_path: *const c_char, config_json: *const c_char) -> *mut c_char {
    if file_path.is_null() {
        return CString::new("File path is null").unwrap().into_raw();
    }
    
    let _file_path_str = unsafe { CStr::from_ptr(file_path).to_string_lossy().to_string() };
    let _config_str = if config_json.is_null() {
        "{}".to_string()
    } else {
        unsafe { CStr::from_ptr(config_json).to_string_lossy().to_string() }
    };
    
    // 这里可以添加实际的媒体打开逻辑
    // 目前先返回成功（null指针）
    std::ptr::null_mut()
}

/// 播放/恢复
#[no_mangle]
pub extern "C" fn bova_mpv_play(player_id: c_longlong) -> c_int {
    #[cfg(not(feature = "mpv"))]
    {
        let _ = player_id;
        return -1;
    }
    
    #[cfg(feature = "mpv")]
    {
        let players = PLAYERS.lock().unwrap();
        if let Some(instance) = players.get(&player_id) {
            if let Some(ref handles) = instance.handles {
                if let Some(ref cmd_tx) = handles.cmd_tx {
                    let _ = cmd_tx.send(MpvCommand::Resume);
                    instance.is_playing.store(true, Ordering::Release);
                    return 0;
                }
            }
        }
        -2
    }
}

/// 暂停
#[no_mangle]
pub extern "C" fn bova_mpv_pause(player_id: c_longlong) -> c_int {
    #[cfg(not(feature = "mpv"))]
    {
        let _ = player_id;
        return -1;
    }
    
    #[cfg(feature = "mpv")]
    {
        let players = PLAYERS.lock().unwrap();
        if let Some(instance) = players.get(&player_id) {
            if let Some(ref handles) = instance.handles {
                if let Some(ref cmd_tx) = handles.cmd_tx {
                    let _ = cmd_tx.send(MpvCommand::Pause);
                    instance.is_playing.store(false, Ordering::Release);
                    return 0;
                }
            }
        }
        -2
    }
}

/// 停止并销毁播放器
#[no_mangle]
pub extern "C" fn bova_mpv_stop(player_id: c_longlong) -> c_int {
    #[cfg(not(feature = "mpv"))]
    {
        let _ = player_id;
        return -1;
    }
    
    #[cfg(feature = "mpv")]
    {
        let mut players = PLAYERS.lock().unwrap();
        if let Some(instance) = players.remove(&player_id) {
            if let Some(handles) = instance.handles {
                let _ = handles.stop_tx.send(());
            }
            
            // 清理帧缓存
            let mut cache = FRAME_CACHE.lock().unwrap();
            cache.remove(&player_id);
            
            return 0;
        }
        -2
    }
}

/// 获取时长（秒）
#[no_mangle]
pub extern "C" fn bova_mpv_get_duration(player_id: c_longlong) -> f64 {
    let players = PLAYERS.lock().unwrap();
    if let Some(instance) = players.get(&player_id) {
        *instance.duration.lock().unwrap()
    } else {
        0.0
    }
}

/// 获取当前位置（秒）
#[no_mangle]
pub extern "C" fn bova_mpv_get_position(player_id: c_longlong) -> f64 {
    let players = PLAYERS.lock().unwrap();
    if let Some(instance) = players.get(&player_id) {
        *instance.current_position.lock().unwrap()
    } else {
        0.0
    }
}

/// 跳转到指定位置（秒）
#[no_mangle]
pub extern "C" fn bova_mpv_seek(player_id: c_longlong, position: f64) -> c_int {
    #[cfg(not(feature = "mpv"))]
    {
        let _ = (player_id, position);
        return -1;
    }
    
    #[cfg(feature = "mpv")]
    {
        let players = PLAYERS.lock().unwrap();
        if let Some(instance) = players.get(&player_id) {
            if let Some(ref handles) = instance.handles {
                if let Some(ref cmd_tx) = handles.cmd_tx {
                    let _ = cmd_tx.send(MpvCommand::SeekAbsolute(position));
                    return 0;
                }
            }
        }
        -2
    }
}

/// 是否正在播放
#[no_mangle]
pub extern "C" fn bova_mpv_is_playing(player_id: c_longlong) -> c_int {
    let players = PLAYERS.lock().unwrap();
    if let Some(instance) = players.get(&player_id) {
        if instance.is_playing.load(Ordering::Acquire) { 1 } else { 0 }
    } else {
        0
    }
}

/// 获取视频宽度
#[no_mangle]
pub extern "C" fn bova_mpv_get_video_width(player_id: c_longlong) -> c_int {
    let players = PLAYERS.lock().unwrap();
    if let Some(instance) = players.get(&player_id) {
        instance.video_width.load(Ordering::Acquire) as c_int
    } else {
        0
    }
}

/// 获取视频高度
#[no_mangle]
pub extern "C" fn bova_mpv_get_video_height(player_id: c_longlong) -> c_int {
    let players = PLAYERS.lock().unwrap();
    if let Some(instance) = players.get(&player_id) {
        instance.video_height.load(Ordering::Acquire) as c_int
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn bova_flutter_play() -> *mut c_char {
    // 播放逻辑
    std::ptr::null_mut()
}

#[no_mangle]
pub extern "C" fn bova_flutter_pause() -> *mut c_char {
    // 暂停逻辑
    std::ptr::null_mut()
}

#[no_mangle]
pub extern "C" fn bova_flutter_stop() -> *mut c_char {
    // 停止逻辑
    std::ptr::null_mut()
}

#[no_mangle]
pub extern "C" fn bova_flutter_get_duration() -> f64 {
    // 返回媒体时长（秒）
    0.0
}

#[no_mangle]
pub extern "C" fn bova_flutter_get_position() -> f64 {
    // 返回当前播放位置（秒）
    0.0
}

#[no_mangle]
pub extern "C" fn bova_flutter_seek(_position: f64) -> *mut c_char {
    // 跳转到指定位置
    std::ptr::null_mut()
}

#[no_mangle]
pub extern "C" fn bova_flutter_is_playing() -> bool {
    // 返回是否正在播放
    false
}

/// 获取最新视频帧的RGBA数据（返回指针，需要调用者释放）
/// 返回null表示没有新帧
#[no_mangle]
pub extern "C" fn bova_mpv_get_latest_frame(
    player_id: c_longlong,
    out_width: *mut c_int,
    out_height: *mut c_int,
    out_data_len: *mut usize,
) -> *mut u8 {
    #[cfg(not(feature = "mpv"))]
    {
        let _ = (player_id, out_width, out_height, out_data_len);
        return std::ptr::null_mut();
    }
    
    #[cfg(feature = "mpv")]
    {
        let mut cache = FRAME_CACHE.lock().unwrap();
        if let Some(frame) = cache.remove(&player_id) {
            let width = frame.width as c_int;
            let height = frame.height as c_int;
            let data_len = frame.rgba.len();
            
            // 将数据复制到堆上
            let mut data = frame.rgba;
            let ptr = data.as_mut_ptr();
            std::mem::forget(data); // 防止Rust释放内存
            
            if !out_width.is_null() {
                unsafe { *out_width = width; }
            }
            if !out_height.is_null() {
                unsafe { *out_height = height; }
            }
            if !out_data_len.is_null() {
                unsafe { *out_data_len = data_len; }
            }
            
            ptr
        } else {
            std::ptr::null_mut()
        }
    }
}

/// 释放视频帧数据
#[no_mangle]
pub extern "C" fn bova_mpv_free_frame_data(data: *mut u8, data_len: usize) {
    if data.is_null() || data_len == 0 {
        return;
    }
    unsafe {
        drop(Vec::from_raw_parts(data, data_len, data_len));
    }
}

#[no_mangle]
pub extern "C" fn bova_flutter_set_hardware_accel(_enabled: bool) -> *mut c_char {
    // 设置硬件加速
    std::ptr::null_mut()
}

// 视频帧数据结构（与Flutter端匹配）
#[repr(C)]
pub struct VideoFrame {
    pub width: i32,
    pub height: i32,
    pub data: *const u8,
    pub data_len: usize,
    pub timestamp: f64,
}

#[no_mangle]
pub extern "C" fn bova_flutter_get_video_frame() -> *mut VideoFrame {
    // 获取视频帧数据（需要实际实现）
    std::ptr::null_mut()
}

#[no_mangle]
pub extern "C" fn bova_flutter_free_video_frame(frame: *mut VideoFrame) {
    if frame.is_null() { return; }
    unsafe {
        let frame_ref = &mut *frame;
        // 释放帧数据内存
        if !frame_ref.data.is_null() {
            drop(Vec::from_raw_parts(frame_ref.data as *mut u8, frame_ref.data_len, frame_ref.data_len));
        }
        drop(Box::from_raw(frame));
    }
}
