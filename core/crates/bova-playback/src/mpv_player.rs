//! MPV-based playback engine using libmpv2 with software render context.
//! Renders video frames to RGBA buffers and sends them via crossbeam channels,
//! matching the same `PlaybackHandles` interface as the FFmpeg engine.
//!
//! Features:
//! - Dynamic render resolution (reads target size from Arc<AtomicU32>)
//! - Subtitle track querying and selection via MpvCommand
//! - External subtitle file loading

use anyhow::Result;
use crossbeam_channel::{bounded, Receiver, Sender, TryRecvError};
use std::ffi::CString;
use std::sync::atomic::{AtomicBool, AtomicU32, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::Duration;

use crate::{
    AudioFrame, MpvCommand, PlaybackConfig, PlaybackHandles,
    SubtitleFrame, SubtitleTrackInfo, VideoFrame,
};

/// Start MPV playback and return `PlaybackHandles` (same interface as FFmpeg path).
#[cfg(feature = "mpv")]
pub fn start_mpv_playback_handles(url: &str, cfg: &PlaybackConfig) -> Result<PlaybackHandles> {
    let (video_tx, video_rx) = bounded::<VideoFrame>(8);
    let (_audio_tx, audio_rx) = bounded::<AudioFrame>(64);
    let (_subtitle_tx, subtitle_rx) = bounded::<SubtitleFrame>(32);
    let (stop_tx, stop_rx) = bounded::<()>(1);
    let (eos_tx, eos_rx) = bounded::<()>(1);
    let (cmd_tx, cmd_rx) = bounded::<MpvCommand>(16);
    let (track_info_tx, track_info_rx) = bounded::<Vec<SubtitleTrackInfo>>(4);

    // Shared atomics for dynamic render size
    let target_w = Arc::new(AtomicU32::new(640));
    let target_h = Arc::new(AtomicU32::new(360));
    let tw_clone = target_w.clone();
    let th_clone = target_h.clone();

    let url = url.to_string();
    let hwaccel = cfg.hwaccel;

    thread::spawn(move || {
        if let Err(e) = mpv_playback_thread(
            &url, &video_tx, &stop_rx, &cmd_rx, &track_info_tx,
            &tw_clone, &th_clone, hwaccel,
        ) {
            eprintln!("[bova-mpv] playback thread error: {e:?}");
        }
        let _ = eos_tx.send(());
    });

    Ok(PlaybackHandles {
        video_rx,
        audio_rx,
        subtitle_rx,
        stop_tx,
        eos_rx,
        cmd_tx: Some(cmd_tx),
        track_info_rx: Some(track_info_rx),
        target_render_w: target_w,
        target_render_h: target_h,
    })
}

#[cfg(not(feature = "mpv"))]
pub fn start_mpv_playback_handles(_url: &str, _cfg: &PlaybackConfig) -> Result<PlaybackHandles> {
    Err(anyhow::anyhow!("MPV feature not enabled"))
}

/// The core MPV playback thread. Uses libmpv2-sys raw FFI for SW render context.
#[cfg(feature = "mpv")]
fn mpv_playback_thread(
    url: &str,
    video_tx: &Sender<VideoFrame>,
    stop_rx: &Receiver<()>,
    cmd_rx: &Receiver<MpvCommand>,
    track_info_tx: &Sender<Vec<SubtitleTrackInfo>>,
    target_w: &Arc<AtomicU32>,
    target_h: &Arc<AtomicU32>,
    hwaccel: bool,
) -> Result<()> {
    use libmpv2_sys::*;
    use std::os::raw::{c_char, c_int, c_void};
    use std::ptr;

    // ── 1. Create and configure mpv handle ──
    let mpv = unsafe { mpv_create() };
    if mpv.is_null() {
        anyhow::bail!("mpv_create() returned null");
    }

    macro_rules! mpv_set_opt {
        ($name:expr, $val:expr) => {{
            let name = CString::new($name).unwrap();
            let val = CString::new($val).unwrap();
            unsafe { mpv_set_option_string(mpv, name.as_ptr(), val.as_ptr()) };
        }};
    }

    mpv_set_opt!("vo", "libmpv");
    mpv_set_opt!("ao", "coreaudio");
    if hwaccel {
        mpv_set_opt!("hwdec", "auto");
    } else {
        mpv_set_opt!("hwdec", "no");
    }
    mpv_set_opt!("force-window", "no");
    mpv_set_opt!("keep-open", "yes");
    mpv_set_opt!("pause", "yes");
    // Enable subtitle rendering in SW output
    mpv_set_opt!("sub-visibility", "yes");

    let init_err = unsafe { mpv_initialize(mpv) };
    if init_err < 0 {
        unsafe { mpv_destroy(mpv) };
        anyhow::bail!("mpv_initialize failed: {}", init_err);
    }

    eprintln!("[bova-mpv] mpv initialized");

    // ── 2. Create SW render context ──
    let frame_ready = Arc::new(AtomicBool::new(false));
    let frame_ready_clone = frame_ready.clone();

    extern "C" fn update_callback(ctx: *mut c_void) {
        let flag = unsafe { &*(ctx as *const AtomicBool) };
        flag.store(true, Ordering::Release);
    }

    let api_type_str = CString::new("sw").unwrap();
    let mut render_params_init = [
        mpv_render_param {
            type_: mpv_render_param_type_MPV_RENDER_PARAM_API_TYPE,
            data: api_type_str.as_ptr() as *mut c_void,
        },
        mpv_render_param {
            type_: mpv_render_param_type_MPV_RENDER_PARAM_INVALID,
            data: ptr::null_mut(),
        },
    ];

    let mut render_ctx: *mut mpv_render_context = ptr::null_mut();
    let rc = unsafe {
        mpv_render_context_create(&mut render_ctx, mpv, render_params_init.as_mut_ptr())
    };
    if rc < 0 {
        unsafe { mpv_destroy(mpv) };
        anyhow::bail!("mpv_render_context_create failed: {}", rc);
    }

    unsafe {
        mpv_render_context_set_update_callback(
            render_ctx,
            Some(update_callback),
            Arc::as_ptr(&frame_ready_clone) as *mut c_void,
        );
    }

    eprintln!("[bova-mpv] SW render context created");

    // ── 3. Load file ──
    let cmd_loadfile = CString::new("loadfile").unwrap();
    let cmd_url = CString::new(url).unwrap();
    let cmd_args: [*const c_char; 3] = [cmd_loadfile.as_ptr(), cmd_url.as_ptr(), ptr::null()];
    let load_err = unsafe { mpv_command(mpv, cmd_args.as_ptr() as *mut *const c_char) };
    if load_err < 0 {
        eprintln!("[bova-mpv] loadfile failed: {load_err}");
    }

    thread::sleep(Duration::from_millis(200));

    // Unpause
    let pause_name = CString::new("pause").unwrap();
    let pause_val = CString::new("no").unwrap();
    unsafe { mpv_set_property_string(mpv, pause_name.as_ptr(), pause_val.as_ptr()) };

    eprintln!("[bova-mpv] playing: {url}");

    // ── 4. Main render loop ──
    let sw_format = CString::new("rgba").unwrap();
    let mut frame_count: u64 = 0;

    // Render dimensions — start with target, updated dynamically
    let mut render_w: c_int = target_w.load(Ordering::Relaxed) as c_int;
    let mut render_h: c_int = target_h.load(Ordering::Relaxed) as c_int;
    let mut native_w: i64 = 0;
    let mut native_h: i64 = 0;
    let mut video_size_queried = false;
    let mut cached_duration_ms: Option<i64> = None;
    let mut tracks_queried = false;
    let mut buf: Vec<u8> = Vec::new();

    loop {
        // Check stop signal
        match stop_rx.try_recv() {
            Ok(_) => {
                eprintln!("[bova-mpv] stop signal received");
                break;
            }
            Err(TryRecvError::Disconnected) => break,
            Err(TryRecvError::Empty) => {}
        }

        // ── Process commands ──
        while let Ok(cmd) = cmd_rx.try_recv() {
            match cmd {
                MpvCommand::SelectSubtitle(id) => {
                    let prop = CString::new("sid").unwrap();
                    let val = id;
                    unsafe {
                        mpv_set_property(
                            mpv,
                            prop.as_ptr(),
                            mpv_format_MPV_FORMAT_INT64,
                            &val as *const i64 as *mut c_void,
                        );
                    }
                    eprintln!("[bova-mpv] subtitle track set to {id}");
                }
                MpvCommand::DisableSubtitle => {
                    let prop = CString::new("sid").unwrap();
                    let val = CString::new("no").unwrap();
                    unsafe { mpv_set_property_string(mpv, prop.as_ptr(), val.as_ptr()) };
                    eprintln!("[bova-mpv] subtitles disabled");
                }
                MpvCommand::LoadExternalSub(path) => {
                    let cmd_name = CString::new("sub-add").unwrap();
                    let cmd_path = CString::new(path.as_str()).unwrap();
                    let args: [*const c_char; 3] =
                        [cmd_name.as_ptr(), cmd_path.as_ptr(), ptr::null()];
                    let r = unsafe {
                        mpv_command(mpv, args.as_ptr() as *mut *const c_char)
                    };
                    if r >= 0 {
                        eprintln!("[bova-mpv] loaded external subtitle: {path}");
                        // Re-query tracks after loading
                        tracks_queried = false;
                    } else {
                        eprintln!("[bova-mpv] sub-add failed: {r}");
                    }
                }
                MpvCommand::SetSubVisibility(visible) => {
                    let prop = CString::new("sub-visibility").unwrap();
                    let val = CString::new(if visible { "yes" } else { "no" }).unwrap();
                    unsafe { mpv_set_property_string(mpv, prop.as_ptr(), val.as_ptr()) };
                    eprintln!("[bova-mpv] subtitle visibility: {visible}");
                }
                MpvCommand::SeekAbsolute(secs) => {
                    let cmd = CString::new("seek").unwrap();
                    let pos_str = CString::new(format!("{:.3}", secs)).unwrap();
                    let mode = CString::new("absolute").unwrap();
                    let args: [*const c_char; 4] = [
                        cmd.as_ptr(), pos_str.as_ptr(), mode.as_ptr(), ptr::null(),
                    ];
                    unsafe { mpv_command(mpv, args.as_ptr() as *mut *const c_char) };
                    eprintln!("[bova-mpv] seek to {secs:.1}s");
                }
                MpvCommand::Pause => {
                    let prop = CString::new("pause").unwrap();
                    let val = CString::new("yes").unwrap();
                    unsafe { mpv_set_property_string(mpv, prop.as_ptr(), val.as_ptr()) };
                    eprintln!("[bova-mpv] paused");
                }
                MpvCommand::Resume => {
                    let prop = CString::new("pause").unwrap();
                    let val = CString::new("no").unwrap();
                    unsafe { mpv_set_property_string(mpv, prop.as_ptr(), val.as_ptr()) };
                    eprintln!("[bova-mpv] resumed");
                }
                MpvCommand::SetVolume(vol) => {
                    let prop = CString::new("volume").unwrap();
                    let val = CString::new(format!("{:.1}", vol)).unwrap();
                    unsafe { mpv_set_property_string(mpv, prop.as_ptr(), val.as_ptr()) };
                }
            }
        }

        // EOS check — but not when paused
        let is_paused = unsafe {
            let pause_name = CString::new("pause").unwrap();
            let mut paused: i32 = 0;
            let r = mpv_get_property(
                mpv, pause_name.as_ptr(), mpv_format_MPV_FORMAT_FLAG,
                &mut paused as *mut i32 as *mut c_void,
            );
            r >= 0 && paused != 0
        };

        if !is_paused {
            unsafe {
                let idle_name = CString::new("idle-active").unwrap();
                let mut idle_val: i32 = 0;
                let format = mpv_format_MPV_FORMAT_FLAG;
                let r = mpv_get_property(
                    mpv,
                    idle_name.as_ptr(),
                    format,
                    &mut idle_val as *mut i32 as *mut c_void,
                );
                if r >= 0 && idle_val != 0 {
                    eprintln!("[bova-mpv] end of stream");
                    break;
                }
            }
        }

        // ── Query video native size once ──
        if !video_size_queried {
            unsafe {
                let w_name = CString::new("width").unwrap();
                let h_name = CString::new("height").unwrap();
                let mut w: i64 = 0;
                let mut h: i64 = 0;

                let rw = mpv_get_property(
                    mpv, w_name.as_ptr(), mpv_format_MPV_FORMAT_INT64,
                    &mut w as *mut i64 as *mut c_void,
                );
                let rh = mpv_get_property(
                    mpv, h_name.as_ptr(), mpv_format_MPV_FORMAT_INT64,
                    &mut h as *mut i64 as *mut c_void,
                );

                if rw >= 0 && rh >= 0 && w > 0 && h > 0 {
                    native_w = w;
                    native_h = h;
                    video_size_queried = true;
                    eprintln!("[bova-mpv] native video size: {native_w}x{native_h}");
                }
            }
        }

        // ── Dynamic render size ──
        // Read the GUI's desired size and compute render dimensions
        if video_size_queried {
            let tw = target_w.load(Ordering::Relaxed).max(160) as c_int;
            let th = target_h.load(Ordering::Relaxed).max(90) as c_int;
            
            // Fit native video into target box preserving aspect ratio
            let scale_w = tw as f64 / native_w as f64;
            let scale_h = th as f64 / native_h as f64;
            let scale = scale_w.min(scale_h).min(1.0); // never upscale beyond native
            
            let new_w = ((native_w as f64 * scale) as c_int).max(2) & !1; // ensure even
            let new_h = ((native_h as f64 * scale) as c_int).max(2) & !1;
            
            if new_w != render_w || new_h != render_h {
                render_w = new_w;
                render_h = new_h;
                eprintln!("[bova-mpv] render size adjusted: {render_w}x{render_h}");
            }
        }

        // ── Query subtitle tracks once file is loaded ──
        if video_size_queried && !tracks_queried {
            let tracks = query_subtitle_tracks(mpv);
            if !tracks.is_empty() {
                eprintln!("[bova-mpv] found {} subtitle tracks", tracks.len());
                for t in &tracks {
                    eprintln!("[bova-mpv]   {t}");
                }
                let _ = track_info_tx.try_send(tracks);
            }
            tracks_queried = true;
        }

        // ── Render frame ──
        if frame_ready.swap(false, Ordering::AcqRel) || frame_count == 0 {
            let stride = render_w as usize * 4;
            let buf_size = stride * render_h as usize;
            buf.resize(buf_size, 0);

            let mut sw_size: [c_int; 2] = [render_w, render_h];
            let stride_val = stride;

            let render_params = [
                mpv_render_param {
                    type_: mpv_render_param_type_MPV_RENDER_PARAM_SW_SIZE,
                    data: sw_size.as_mut_ptr() as *mut c_void,
                },
                mpv_render_param {
                    type_: mpv_render_param_type_MPV_RENDER_PARAM_SW_FORMAT,
                    data: sw_format.as_ptr() as *mut c_void,
                },
                mpv_render_param {
                    type_: mpv_render_param_type_MPV_RENDER_PARAM_SW_STRIDE,
                    data: &stride_val as *const usize as *mut c_void,
                },
                mpv_render_param {
                    type_: mpv_render_param_type_MPV_RENDER_PARAM_SW_POINTER,
                    data: buf.as_mut_ptr() as *mut c_void,
                },
                mpv_render_param {
                    type_: mpv_render_param_type_MPV_RENDER_PARAM_INVALID,
                    data: ptr::null_mut(),
                },
            ];

            let render_err = unsafe {
                mpv_render_context_render(render_ctx, render_params.as_ptr() as *mut mpv_render_param)
            };

            if render_err >= 0 {
                // Get current position
                let pts_ms = unsafe {
                    let pos_name = CString::new("time-pos").unwrap();
                    let mut pos: f64 = 0.0;
                    let r = mpv_get_property(
                        mpv, pos_name.as_ptr(), mpv_format_MPV_FORMAT_DOUBLE,
                        &mut pos as *mut f64 as *mut c_void,
                    );
                    if r >= 0 { Some((pos * 1000.0) as i64) } else { None }
                };

                // Query duration (cache after first read)
                if cached_duration_ms.is_none() {
                    unsafe {
                        let dur_name = CString::new("duration").unwrap();
                        let mut dur: f64 = 0.0;
                        let r = mpv_get_property(
                            mpv, dur_name.as_ptr(), mpv_format_MPV_FORMAT_DOUBLE,
                            &mut dur as *mut f64 as *mut c_void,
                        );
                        if r >= 0 && dur > 0.0 {
                            cached_duration_ms = Some((dur * 1000.0) as i64);
                            eprintln!("[bova-mpv] duration: {:.1}s", dur);
                        }
                    }
                }

                let vf = VideoFrame {
                    width: render_w as u32,
                    height: render_h as u32,
                    rgba: std::mem::take(&mut buf),
                    pts_ms,
                    duration_ms: cached_duration_ms,
                };

                let _ = video_tx.try_send(vf);

                frame_count += 1;
                if frame_count % 300 == 0 {
                    eprintln!("[bova-mpv] rendered {} frames ({}x{})", frame_count, render_w, render_h);
                }
            } else if render_err != -6 {
                eprintln!("[bova-mpv] render error: {}", render_err);
            }
        } else {
            thread::sleep(Duration::from_millis(1));
        }
    }

    // ── 5. Cleanup ──
    eprintln!("[bova-mpv] cleaning up, rendered {} frames total", frame_count);

    let cmd_stop = CString::new("stop").unwrap();
    let stop_args: [*const c_char; 2] = [cmd_stop.as_ptr(), ptr::null()];
    unsafe { mpv_command(mpv, stop_args.as_ptr() as *mut *const c_char) };

    unsafe {
        mpv_render_context_free(render_ctx);
        mpv_destroy(mpv);
    }

    eprintln!("[bova-mpv] shutdown complete");
    Ok(())
}

/// Query available subtitle tracks from MPV's track-list property
#[cfg(feature = "mpv")]
fn query_subtitle_tracks(mpv: *mut libmpv2_sys::mpv_handle) -> Vec<SubtitleTrackInfo> {
    use libmpv2_sys::*;
    use std::os::raw::c_void;

    let mut tracks = Vec::new();

    // Get track count
    let count_name = CString::new("track-list/count").unwrap();
    let mut count: i64 = 0;
    let r = unsafe {
        mpv_get_property(
            mpv, count_name.as_ptr(), mpv_format_MPV_FORMAT_INT64,
            &mut count as *mut i64 as *mut c_void,
        )
    };
    if r < 0 || count == 0 {
        return tracks;
    }

    for i in 0..count {
        // Check if this track is a subtitle track
        let type_name = CString::new(format!("track-list/{i}/type")).unwrap();
        let type_val = unsafe {
            let mut s: *mut std::os::raw::c_char = std::ptr::null_mut();
            let r = mpv_get_property(
                mpv, type_name.as_ptr(), mpv_format_MPV_FORMAT_STRING,
                &mut s as *mut *mut std::os::raw::c_char as *mut c_void,
            );
            if r >= 0 && !s.is_null() {
                let val = std::ffi::CStr::from_ptr(s).to_string_lossy().to_string();
                mpv_free(s as *mut c_void);
                Some(val)
            } else {
                None
            }
        };

        if type_val.as_deref() != Some("sub") {
            continue;
        }

        // Get track ID
        let id_name = CString::new(format!("track-list/{i}/id")).unwrap();
        let mut id: i64 = 0;
        unsafe {
            mpv_get_property(
                mpv, id_name.as_ptr(), mpv_format_MPV_FORMAT_INT64,
                &mut id as *mut i64 as *mut c_void,
            );
        }

        // Get language
        let lang_name = CString::new(format!("track-list/{i}/lang")).unwrap();
        let lang = get_mpv_string_property(mpv, &lang_name);

        // Get title
        let title_name = CString::new(format!("track-list/{i}/title")).unwrap();
        let title = get_mpv_string_property(mpv, &title_name);

        // Check if external
        let ext_name = CString::new(format!("track-list/{i}/external")).unwrap();
        let mut ext_val: i32 = 0;
        unsafe {
            mpv_get_property(
                mpv, ext_name.as_ptr(), mpv_format_MPV_FORMAT_FLAG,
                &mut ext_val as *mut i32 as *mut c_void,
            );
        }

        tracks.push(SubtitleTrackInfo {
            id,
            lang,
            title,
            external: ext_val != 0,
        });
    }

    tracks
}

#[cfg(feature = "mpv")]
fn get_mpv_string_property(mpv: *mut libmpv2_sys::mpv_handle, name: &CString) -> Option<String> {
    use libmpv2_sys::*;
    use std::os::raw::c_void;
    unsafe {
        let mut s: *mut std::os::raw::c_char = std::ptr::null_mut();
        let r = mpv_get_property(
            mpv, name.as_ptr(), mpv_format_MPV_FORMAT_STRING,
            &mut s as *mut *mut std::os::raw::c_char as *mut c_void,
        );
        if r >= 0 && !s.is_null() {
            let val = std::ffi::CStr::from_ptr(s).to_string_lossy().to_string();
            mpv_free(s as *mut c_void);
            Some(val)
        } else {
            None
        }
    }
}

/// MpvPlayer marker struct (kept for module-level exports)
pub struct MpvPlayer;