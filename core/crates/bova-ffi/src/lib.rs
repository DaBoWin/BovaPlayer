//! C ABI for BovaPlayer minimal core

use libc::{c_char, c_int, c_longlong, c_void};
use std::ffi::{CStr, CString};

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

// Flutter-specific API
#[no_mangle]
pub extern "C" fn bova_flutter_initialize() -> *mut c_char {
    // 初始化成功返回null，失败返回错误信息
    std::ptr::null_mut()
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
