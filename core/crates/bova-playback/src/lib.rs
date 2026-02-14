//! bova-playback: software playback (demux + video decode + swscale to RGBA)
//! Feature-gated with `ffmpeg` or `mpv`. Without it, returns a no-op stub.

use crossbeam_channel::{bounded, Receiver, Sender};
use std::sync::atomic::{AtomicU32, Ordering};
use std::sync::Arc;

#[cfg(feature = "mpv")]
mod mpv_player;
#[cfg(feature = "mpv")]
pub use mpv_player::MpvPlayer;
#[cfg(feature = "mpv")]
pub use mpv_player::start_mpv_playback_handles;

// 播放引擎类型
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PlaybackEngine {
    FFmpeg,
    MPV,
}

// 播放命令
#[derive(Debug, Clone)]
pub enum PlaybackCommand {
    LoadFile(String),
    Play,
    Pause,
    Stop,
    Seek(f64),
    SetVolume(f64),
}

// 播放事件
#[derive(Debug, Clone)]
pub enum PlaybackEvent {
    FileLoaded,
    Started,
    Paused,
    Resumed,
    Stopped,
    Finished,
    PositionChanged(f64),
    Error(String),
}

// 播放状态
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PlaybackState {
    Stopped,
    Playing,
    Paused,
}

#[derive(Debug, Clone)]
pub struct VideoFrame {
    pub width: u32,
    pub height: u32,
    pub rgba: Vec<u8>,
    pub pts_ms: Option<i64>,
    pub duration_ms: Option<i64>,
}

#[derive(Debug, Clone)]
pub struct SubtitleFrame {
    pub text: String,
    pub start_ms: i64,
    pub end_ms: i64,
    pub style: SubtitleStyle,
}

#[derive(Debug, Clone, Default)]
pub struct SubtitleStyle {
    pub font_size: f32,
    pub font_color: [u8; 4], // RGBA
    pub background_color: [u8; 4], // RGBA
    pub position: SubtitlePosition,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SubtitlePosition {
    Bottom,
    Top,
    Middle,
}

impl Default for SubtitlePosition {
    fn default() -> Self {
        Self::Bottom
    }
}

/// Info about an available subtitle track (embedded or external)
#[derive(Debug, Clone)]
pub struct SubtitleTrackInfo {
    pub id: i64,
    pub lang: Option<String>,
    pub title: Option<String>,
    pub external: bool,
}

impl std::fmt::Display for SubtitleTrackInfo {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let lang = self.lang.as_deref().unwrap_or("?");
        let title = self.title.as_deref().unwrap_or("");
        let ext = if self.external { " [外部]" } else { "" };
        if title.is_empty() {
            write!(f, "#{} ({}){}", self.id, lang, ext)
        } else {
            write!(f, "#{} {} ({}){}", self.id, title, lang, ext)
        }
    }
}

/// Commands that can be sent to the MPV player thread
#[derive(Debug, Clone)]
pub enum MpvCommand {
    SelectSubtitle(i64),      // set sid=N
    DisableSubtitle,          // set sid=no
    LoadExternalSub(String),  // sub-add <path>
    SetSubVisibility(bool),   // sub-visibility yes/no
    SeekAbsolute(f64),        // seek <seconds> absolute
    Pause,                    // set pause=yes
    Resume,                   // set pause=no
    SetVolume(f64),           // set volume=N (0-100)
}

#[cfg(feature = "ffmpeg")]
pub fn start_playback_with(url: &str, cfg: PlaybackConfig) -> anyhow::Result<PlaybackHandles> {
    use ffmpeg_next as ffmpeg;
    use std::thread;
    let _ = ffmpeg::init();
    // 降低 FFmpeg 日志等级，抑制 AAC 时间戳告警等噪声
    #[allow(deprecated)]
    {
        use ffmpeg_next::util::log::Level;
        ffmpeg_next::util::log::set_level(Level::Error);
    }

    // channels
    let (video_tx, video_rx) = bounded::<VideoFrame>(32); // 增加视频帧缓冲区大小
    let (audio_tx, audio_rx) = bounded::<AudioFrame>(64); // 增加音频帧缓冲区大小
    let (subtitle_tx, subtitle_rx) = bounded::<SubtitleFrame>(32); // 字幕帧缓冲区
    let (stop_tx, stop_rx) = bounded::<()>(1);
    let (eos_tx, eos_rx) = bounded::<()>(1);

    let url = url.to_string();
    let hw = cfg.hwaccel;
    let subtitle_enabled = cfg.subtitle_enabled;
    let subtitle_index = cfg.subtitle_index;
    thread::spawn(move || {
        if let Err(e) = playback_thread(&url, &video_tx, &audio_tx, &subtitle_tx, &stop_rx, hw, subtitle_enabled, subtitle_index) {
            eprintln!("playback_thread error: {e:?}");
        }
        let _ = eos_tx.send(());
    });

    Ok(PlaybackHandles { video_rx, audio_rx, subtitle_rx, stop_tx, eos_rx, cmd_tx: None, track_info_rx: None, target_render_w: Arc::new(AtomicU32::new(640)), target_render_h: Arc::new(AtomicU32::new(360)) })
}

#[cfg(not(feature = "ffmpeg"))]
pub fn start_playback_with(url: &str, cfg: PlaybackConfig) -> anyhow::Result<PlaybackHandles> {
    // ffmpeg disabled: try MPV if enabled
    #[cfg(feature = "mpv")]
    {
        return start_mpv_playback_handles(url, &cfg);
    }
    #[cfg(not(feature = "mpv"))]
    {
        start_playback(url)
    }
}

#[derive(Debug, Clone)]
pub struct AudioFrame {
    pub channels: u16,
    pub sample_rate: u32,
    pub samples: Vec<i16>, // interleaved
    pub pts_ms: Option<i64>,
}

#[derive(Debug, Clone)]
pub struct PlaybackHandles {
    pub video_rx: Receiver<VideoFrame>,
    pub audio_rx: Receiver<AudioFrame>,
    pub subtitle_rx: Receiver<SubtitleFrame>,
    pub stop_tx: Sender<()>,
    pub eos_rx: Receiver<()>,
    /// Send commands to the MPV thread (subtitle selection, etc.)
    pub cmd_tx: Option<Sender<MpvCommand>>,
    /// Receive track info from the MPV thread
    pub track_info_rx: Option<Receiver<Vec<SubtitleTrackInfo>>>,
    /// Dynamic render size — GUI writes, render thread reads
    pub target_render_w: Arc<AtomicU32>,
    pub target_render_h: Arc<AtomicU32>,
}

#[derive(Debug, Clone, Default)]
pub struct PlaybackConfig {
    pub hwaccel: bool,
    pub subtitle_enabled: bool,
    pub subtitle_index: Option<u32>,
    pub engine: Option<PlaybackEngine>,
}

// MPV播放器启动函数 (command-based API) — legacy, not actively used
#[cfg(feature = "mpv")]
pub fn start_mpv_playback(url: &str) -> anyhow::Result<(Sender<PlaybackCommand>, Receiver<PlaybackEvent>)> {
    let (cmd_tx, _cmd_rx) = bounded::<PlaybackCommand>(32);
    let (_event_tx, event_rx) = bounded::<PlaybackEvent>(32);
    
    // The command-based API is deprecated in favor of start_mpv_playback_handles
    eprintln!("[bova-playback] Warning: start_mpv_playback is deprecated, use start_mpv_playback_handles");
    
    Ok((cmd_tx, event_rx))
}

#[cfg(not(feature = "mpv"))]
pub fn start_mpv_playback(_url: &str) -> anyhow::Result<(Sender<PlaybackCommand>, Receiver<PlaybackEvent>)> {
    Err(anyhow::anyhow!("MPV feature not enabled"))
}

// 统一的播放器启动函数
pub fn start_playback_engine(url: &str, engine: PlaybackEngine) -> anyhow::Result<(Sender<PlaybackCommand>, Receiver<PlaybackEvent>)> {
    match engine {
        PlaybackEngine::MPV => start_mpv_playback(url),
        PlaybackEngine::FFmpeg => {
            // 为FFmpeg创建兼容的接口
            #[cfg(feature = "ffmpeg")]
            {
                let handles = start_playback(url)?;
                let (cmd_tx, _cmd_rx) = bounded::<PlaybackCommand>(32);
                let (event_tx, event_rx) = bounded::<PlaybackEvent>(32);
                
                // 启动FFmpeg兼容层
                std::thread::spawn(move || {
                    // 简单的事件转换
                    let _ = event_tx.send(PlaybackEvent::FileLoaded);
                    let _ = event_tx.send(PlaybackEvent::Started);
                });
                
                Ok((cmd_tx, event_rx))
            }
            #[cfg(not(feature = "ffmpeg"))]
            {
                Err(anyhow::anyhow!("FFmpeg feature not enabled"))
            }
        }
    }
}

#[cfg(not(feature = "ffmpeg"))]
pub fn start_playback(_url: &str) -> anyhow::Result<PlaybackHandles> {
    let (video_tx, video_rx) = bounded::<VideoFrame>(32); // 增加视频帧缓冲区大小
    let (_audio_tx, audio_rx) = bounded::<AudioFrame>(64); // 增加音频帧缓冲区大小
    let (_subtitle_tx, subtitle_rx) = bounded::<SubtitleFrame>(32); // 字幕帧缓冲区
    let (stop_tx, _stop_rx) = bounded::<()>(1);
    let (_eos_tx, eos_rx) = bounded::<()>(1);
    // no-op producer
    let _ = video_tx;
    Ok(PlaybackHandles { video_rx, audio_rx, subtitle_rx, stop_tx, eos_rx, cmd_tx: None, track_info_rx: None, target_render_w: Arc::new(AtomicU32::new(640)), target_render_h: Arc::new(AtomicU32::new(360)) })
}

#[cfg(feature = "ffmpeg")]
pub fn start_playback(url: &str) -> anyhow::Result<PlaybackHandles> {
    // use anyhow::Context; // 暂时未使用
    // use crossbeam_channel::select; // 暂时未使用
    use ffmpeg_next as ffmpeg;
    use std::thread;

    // init ffmpeg
    let _ = ffmpeg::init();
    #[allow(deprecated)]
    {
        use ffmpeg_next::util::log::Level;
        ffmpeg_next::util::log::set_level(Level::Error);
    }

    // channels
    let (video_tx, video_rx) = bounded::<VideoFrame>(32); // 增加视频帧缓冲区大小
    let (audio_tx, audio_rx) = bounded::<AudioFrame>(64); // 增加音频帧缓冲区大小
    let (subtitle_tx, subtitle_rx) = bounded::<SubtitleFrame>(32); // 字幕帧缓冲区
    let (stop_tx, stop_rx) = bounded::<()>(1);
    let (eos_tx, eos_rx) = bounded::<()>(1);

    let url = url.to_string();
    thread::spawn(move || {
        if let Err(e) = playback_thread(&url, &video_tx, &audio_tx, &subtitle_tx, &stop_rx, false, false, None) {
            eprintln!("playback_thread error: {e:?}");
        }
        let _ = eos_tx.send(());
    });

    Ok(PlaybackHandles { video_rx, audio_rx, subtitle_rx, stop_tx, eos_rx, cmd_tx: None, track_info_rx: None, target_render_w: Arc::new(AtomicU32::new(640)), target_render_h: Arc::new(AtomicU32::new(360)) })
}

#[cfg(feature = "ffmpeg")]
fn playback_thread(url: &str, video_tx: &Sender<VideoFrame>, audio_tx: &Sender<AudioFrame>, subtitle_tx: &Sender<SubtitleFrame>, stop_rx: &Receiver<()>, hwaccel: bool, subtitle_enabled: bool, subtitle_index: Option<u32>) -> anyhow::Result<()> {
    use anyhow::Context;
    use crossbeam_channel::select;
    use ffmpeg_next as ffmpeg;

    // open input
    let mut ictx = ffmpeg::format::input(&url).with_context(|| format!("open input failed: {url}"))?;

    // find best streams
    let vs = ictx
        .streams()
        .best(ffmpeg::media::Type::Video)
        .context("no video stream")?;
    let stream_index = vs.index();
    let v_time_base = vs.time_base();

    let audio_index_opt: Option<usize> = ictx
        .streams()
        .best(ffmpeg::media::Type::Audio)
        .map(|s| s.index());
        
    // 查找字幕流
    let subtitle_index_opt: Option<usize> = if subtitle_enabled {
        if let Some(idx) = subtitle_index {
            // 使用指定的字幕流
            let idx_usize = idx as usize;
            if idx_usize < ictx.streams().count() {
                let stream = ictx.streams().nth(idx_usize).unwrap();
                if stream.parameters().medium() == ffmpeg::media::Type::Subtitle {
                    Some(idx_usize)
                } else {
                    eprintln!("[bova-playback] 指定的字幕流索引 {} 不是字幕类型", idx);
                    None
                }
            } else {
                eprintln!("[bova-playback] 指定的字幕流索引 {} 超出范围", idx);
                None
            }
        } else {
            // 自动选择最佳字幕流
            ictx.streams().best(ffmpeg::media::Type::Subtitle).map(|s| s.index())
        }
    } else {
        None
    };
    
    if let Some(idx) = subtitle_index_opt {
        eprintln!("[bova-playback] 已选择字幕流: {}", idx);
    }

    // open video decoder (v7 style)
    let codec_params = vs.parameters();
    let mut context = ffmpeg::codec::context::Context::from_parameters(codec_params).context("from_parameters")?;

    // 尝试附加 VideoToolbox 硬件设备（macOS），失败则忽略回退
    // 先缓存 AVCodecContext 指针，避免 decoder().video() 移动 context 后无法访问
    let mut ctx_ptr_saved: *mut ffmpeg_next::ffi::AVCodecContext = std::ptr::null_mut();
    if hwaccel {
        // Try attach VideoToolbox device; if not present, fallback silently
        unsafe {
            use ffmpeg_next::ffi;
            let name = std::ffi::CString::new("videotoolbox").unwrap();
            let dev_type = ffi::av_hwdevice_find_type_by_name(name.as_ptr());
            // Attempt device creation regardless; av_hwdevice_ctx_create will fail if type is invalid
            let mut hw_dev: *mut ffi::AVBufferRef = std::ptr::null_mut();
            let r = ffi::av_hwdevice_ctx_create(
                &mut hw_dev,
                dev_type,
                std::ptr::null(),
                std::ptr::null_mut(),
                0,
            );
            if r >= 0 && !hw_dev.is_null() {
                let ctx_ptr = context.as_mut_ptr();
                ctx_ptr_saved = ctx_ptr;
                if !ctx_ptr.is_null() {
                    // 安装 get_format：优先选择名为 "videotoolbox_vld" 的像素格式
                    extern "C" fn vt_get_format(_ctx: *mut ffmpeg_next::ffi::AVCodecContext, fmts: *const ffmpeg_next::ffi::AVPixelFormat) -> ffmpeg_next::ffi::AVPixelFormat {
                        unsafe {
                            let mut i = 0isize;
                            let mut first: ffmpeg_next::ffi::AVPixelFormat = *fmts; // assume list not empty
                            loop {
                                let fmt = *fmts.offset(i);
                                if fmt as i32 == -1 { break; } // AV_PIX_FMT_NONE
                                let name_ptr = ffmpeg_next::ffi::av_get_pix_fmt_name(fmt);
                                if !name_ptr.is_null() {
                                    let c = std::ffi::CStr::from_ptr(name_ptr);
                                    if let Ok(s) = c.to_str() {
                                        if s == "videotoolbox_vld" { return fmt; }
                                    }
                                }
                                if i == 0 { first = fmt; }
                                i += 1;
                            }
                            first
                        }
                    }
                    (*ctx_ptr).get_format = Some(vt_get_format);
                    // 绑定设备
                    (*ctx_ptr).hw_device_ctx = hw_dev;
                    eprintln!("[bova-playback] VideoToolbox device attached");
                } else {
                    ffi::av_buffer_unref(&mut hw_dev);
                }
            } else {
                eprintln!("[bova-playback] create VideoToolbox device failed (code={r}) -> fallback software");
            }
        }
    }
    let mut dec = context.decoder().video().context("open video decoder")?;

    // 创建 hw_frames_ctx（在 decoder 打开后，通过 context 获取设备引用），失败回退
    if hwaccel {
        unsafe {
            use ffmpeg_next::ffi;
            let ctx_ptr = ctx_ptr_saved;
            if !ctx_ptr.is_null() {
                let dev = (*ctx_ptr).hw_device_ctx;
                if !dev.is_null() {
                    let frames_ref = ffi::av_hwframe_ctx_alloc(dev);
                    if !frames_ref.is_null() {
                        let frames_ctx = (*frames_ref).data as *mut ffi::AVHWFramesContext;
                        if !frames_ctx.is_null() {
                            // format: videotoolbox_vld；sw_format: NV12；尺寸：解码器宽高
                            let vt_name = std::ffi::CString::new("videotoolbox_vld").unwrap();
                            let sw_name = std::ffi::CString::new("nv12").unwrap();
                            let vt_fmt = ffi::av_get_pix_fmt(vt_name.as_ptr());
                            let sw_fmt = ffi::av_get_pix_fmt(sw_name.as_ptr());
                            (*frames_ctx).format = vt_fmt;
                            (*frames_ctx).sw_format = sw_fmt;
                            (*frames_ctx).width = dec.width() as i32;
                            (*frames_ctx).height = dec.height() as i32;
                            if ffi::av_hwframe_ctx_init(frames_ref) >= 0 {
                                (*ctx_ptr).hw_frames_ctx = frames_ref;
                                eprintln!("[bova-playback] hw_frames_ctx initialized");
                            } else {
                                ffi::av_buffer_unref(&mut (frames_ref as *mut _));
                                eprintln!("[bova-playback] hw_frames_ctx init failed -> fallback possible");
                            }
                        }
                    }
                }
            }
        }
    }

    // swscale: convert to RGBA
    let mut scaler: Option<ffmpeg::software::scaling::Context> = None;

    // audio decoder/resampler (lazy init on first audio packet)
    let mut adec_opt: Option<ffmpeg::decoder::Audio> = None;
    let mut ares_opt: Option<ffmpeg::software::resampling::Context> = None;
    let mut out_ch_layout = ffmpeg::channel_layout::ChannelLayout::STEREO;
    let out_rate = 48_000;
    let mut a_time_base_opt: Option<ffmpeg::Rational> = None;

    // read packets
    let mut hw_dl_ok: u64 = 0;
    let mut hw_dl_fail: u64 = 0;
    let mut v_frames: u64 = 0;

    // 字幕解码器（懒加载）
    let mut sdec_opt: Option<ffmpeg::decoder::Subtitle> = None;
    let mut subtitle_time_base_opt: Option<ffmpeg::Rational> = None;
    
    for (stream, packet) in ictx.packets() {
        // stop request
        select! {
            recv(stop_rx) -> _ => { break; }
            default => {}
        }

        if stream.index() == stream_index {
            // video packet
            if let Err(e) = dec.send_packet(&packet) {
                eprintln!("send_packet video err: {e:?}");
                continue;
            }
            let mut frame = ffmpeg::frame::Video::empty();
            if dec.receive_frame(&mut frame).is_ok() {
                let mut use_frame_ref = true;
                let mut sw_download = ffmpeg::frame::Video::empty();
                if hwaccel {
                    // 若为硬件帧，尝试下载为软件帧
                    unsafe {
                        use ffmpeg_next::ffi;
                        let src_ptr = frame.as_ptr();
                        let dst_ptr = sw_download.as_mut_ptr();
                        if !src_ptr.is_null() && !dst_ptr.is_null() {
                            // 预设下载后的格式与尺寸（与 hw_frames_ctx sw_format/尺寸一致）
                            sw_download.set_format(ffmpeg::format::Pixel::NV12);
                            sw_download.set_width(frame.width());
                            sw_download.set_height(frame.height());
                            let tr = ffi::av_hwframe_transfer_data(dst_ptr, src_ptr, 0);
                            if tr >= 0 {
                                use_frame_ref = false; // 使用 sw_download
                                hw_dl_ok = hw_dl_ok.saturating_add(1);
                            } else {
                                eprintln!("[bova-playback] hwframe transfer failed: {tr}, fallback to original frame");
                                hw_dl_fail = hw_dl_fail.saturating_add(1);
                            }
                        }
                    }
                }

                let (src_fw, src_fh) = if use_frame_ref { (frame.width(), frame.height()) } else { (sw_download.width(), sw_download.height()) };
                let src_w = src_fw;
                let src_h = src_fh;
                // init scaler if needed
                if scaler.is_none() || scaler.as_ref().unwrap().input().format != frame.format() {
                    scaler = Some(ffmpeg::software::scaling::Context::get(
                        if use_frame_ref { frame.format() } else { sw_download.format() },
                        src_w, src_h,
                        ffmpeg::format::Pixel::RGBA,
                        src_w, src_h,
                        ffmpeg::software::scaling::flag::Flags::BILINEAR,
                    ).context("init swscale")?);
                }
                let mut rgba = ffmpeg::frame::Video::empty();
                rgba.set_format(ffmpeg::format::Pixel::RGBA);
                rgba.set_width(src_w);
                rgba.set_height(src_h);
                if let Some(sc) = &mut scaler {
                    if use_frame_ref {
                        sc.run(&frame, &mut rgba).context("swscale run")?;
                    } else {
                        sc.run(&sw_download, &mut rgba).context("swscale run")?;
                    }
                }
                let linesize = rgba.stride(0);
                let data = rgba.data(0);
                let h = rgba.height() as usize;
                let w = rgba.width() as usize;
                let mut buf = Vec::with_capacity(w * h * 4);
                for y in 0..h {
                    let start = y * linesize as usize;
                    let end = start + w * 4;
                    buf.extend_from_slice(&data[start..end]);
                }
                // compute pts in ms
                let pts_ms = if use_frame_ref { frame.timestamp().map(|ts| ts_to_ms(ts, v_time_base)) } else { sw_download.timestamp().map(|ts| ts_to_ms(ts, v_time_base)) };
                let _ = video_tx.send(VideoFrame { width: w as u32, height: h as u32, rgba: buf, pts_ms, duration_ms: None });

                v_frames = v_frames.saturating_add(1);
                if v_frames % 120 == 0 && hwaccel {
                    eprintln!("[bova-playback] HW transfer stats: ok={}, fail={}", hw_dl_ok, hw_dl_fail);
                }
            }
        } else if let Some(si) = subtitle_index_opt {
            if stream.index() == si {
                // 字幕包处理
                if sdec_opt.is_none() {
                    // 懒加载字幕解码器
                    let scodec_params = stream.parameters();
                    if let Ok(scontext) = ffmpeg::codec::context::Context::from_parameters(scodec_params) {
                        if let Ok(sdec) = scontext.decoder().subtitle() {
                            sdec_opt = Some(sdec);
                            subtitle_time_base_opt = Some(stream.time_base());
                            eprintln!("[bova-playback] 字幕解码器初始化成功");
                        }
                    }
                }
                
                if let Some(sdec) = &mut sdec_opt {
                    let mut sub = ffmpeg::Subtitle::new();
                    if sdec.decode(&packet, &mut sub).is_ok() {
                        // 使用正确的API获取字幕矩形
                        for _rect in sub.rects() {
                            // 获取字幕显示时间范围
                            let start_time = packet.pts().unwrap_or(0);
                            let duration = packet.duration();
                            let end_time = start_time + duration;
                            
                            // 转换为毫秒
                            let start_ms = if let Some(tb) = subtitle_time_base_opt {
                                ts_to_ms(start_time, tb)
                            } else {
                                0
                            };
                            
                            let end_ms = if let Some(tb) = subtitle_time_base_opt {
                                ts_to_ms(end_time, tb)
                            } else {
                                start_ms + 3000 // 默认显示3秒
                            };
                            
                            // 提取字幕文本（暂时注释掉有问题的Rect API调用）
                            let text = String::new();
                            // TODO: 修复FFmpeg Rect API调用
                            // if let Some(ass) = &rect.ass {
                            //     text.push_str(ass);
                            // } else if let Some(txt) = &rect.text {
                            //     text.push_str(txt);
                            // }
                            
                            if !text.is_empty() {
                                // 创建字幕帧并发送
                                let style = SubtitleStyle {
                                    font_size: 24.0,
                                    font_color: [255, 255, 255, 255], // 白色
                                    background_color: [0, 0, 0, 128],  // 半透明黑色
                                    position: SubtitlePosition::Bottom,
                                };
                                
                                let subtitle_frame = SubtitleFrame {
                                    text,
                                    start_ms,
                                    end_ms,
                                    style,
                                };
                                
                                let _ = subtitle_tx.send(subtitle_frame);
                            }
                        }
                    }
                }
            }
        }
        
        if let Some(ai) = audio_index_opt {
            if stream.index() == ai {
                // lazy init audio decoder/resampler with current stream params
                if adec_opt.is_none() || ares_opt.is_none() {
                    let acodec_params = stream.parameters();
                    if let Ok(acontext) = ffmpeg::codec::context::Context::from_parameters(acodec_params) {
                        if let Ok(adec) = acontext.decoder().audio() {
                            out_ch_layout = ffmpeg::channel_layout::ChannelLayout::STEREO;
                            let in_fmt = adec.format();
                            let in_rate = adec.rate();
                            let in_ch_layout = adec.channel_layout();
                            a_time_base_opt = Some(stream.time_base());
                            if let Ok(ares) = ffmpeg::software::resampling::Context::get(
                                in_fmt,
                                in_ch_layout,
                                in_rate,
                                ffmpeg::format::Sample::I16(ffmpeg::format::sample::Type::Packed),
                                out_ch_layout,
                                out_rate,
                            ) {
                                adec_opt = Some(adec);
                                ares_opt = Some(ares);
                            }
                        }
                    }
                }
                if let (Some(adec), Some(ares)) = (&mut adec_opt, &mut ares_opt) {
                    if let Err(e) = adec.send_packet(&packet) {
                        eprintln!("send_packet audio err: {e:?}");
                        continue;
                    }
                    let mut afr = ffmpeg::frame::Audio::empty();
                    while adec.receive_frame(&mut afr).is_ok() {
                        let nb = afr.samples();
                        let mut out = ffmpeg::frame::Audio::empty();
                        out.set_format(ffmpeg::format::Sample::I16(ffmpeg::format::sample::Type::Packed));
                        out.set_channel_layout(out_ch_layout);
                        out.set_rate(out_rate);
                        out.set_samples(nb);
                        ares.run(&afr, &mut out).ok();
                        let planes = out.planes();
                        if planes > 0 {
                            let data = out.data(0); // &[u8]
                            let total_samples = (out.samples() as usize) * (out.channels() as usize);
                            let available_samples = data.len() / std::mem::size_of::<i16>();
                            let copy_samples = total_samples.min(available_samples);
                            let _bytes_needed = copy_samples * std::mem::size_of::<i16>();
                            // SAFETY: interpret first bytes_needed as i16 slice (packed interleaved)
                            let mut vec = Vec::<i16>::with_capacity(copy_samples);
                            unsafe {
                                let ptr = data.as_ptr() as *const i16;
                                vec.extend_from_slice(std::slice::from_raw_parts(ptr, copy_samples));
                            }
                            let pts_ms = a_time_base_opt.and_then(|tb| afr.timestamp().map(|ts| ts_to_ms(ts, tb)));
                            let _ = audio_tx.send(AudioFrame { channels: 2, sample_rate: out_rate as u32, samples: vec, pts_ms });
                        }
                    }
                }
            }
        }
    }

    // Best-effort flush (optional)
    let mut frame = ffmpeg::frame::Video::empty();
    while dec.receive_frame(&mut frame).is_ok() {}

    Ok(())
}

#[cfg(feature = "ffmpeg")]
fn ts_to_ms(ts: i64, tb: ffmpeg_next::Rational) -> i64 {
    // ts * num / den -> seconds, then *1000
    // Use i128 to reduce overflow risk
    let num = tb.numerator() as i128;
    let den = tb.denominator() as i128;
    if den == 0 { return 0; }
    ((ts as i128) * 1000 * num / den) as i64
}
