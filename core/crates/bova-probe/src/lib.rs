//! Media probe utilities for BovaPlayer.
//! If built without the `ffmpeg` feature, returns placeholder info (no I/O).

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StreamInfo {
    pub index: u32,
    pub kind: String,       // video/audio/subtitle
    pub codec: String,
    pub profile: Option<String>,
    pub width: Option<u32>,
    pub height: Option<u32>,
    pub channels: Option<u32>,
    pub sample_rate: Option<u32>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MediaInfo {
    pub url: String,
    pub duration_ms: Option<u64>,
    pub bit_rate: Option<u64>,
    pub streams: Vec<StreamInfo>,
}

#[cfg(not(feature = "ffmpeg"))]
pub fn probe(url: &str) -> MediaInfo {
    // Placeholder: echo back URL and return an empty stream list.
    MediaInfo {
        url: url.to_string(),
        duration_ms: None,
        bit_rate: None,
        streams: vec![],
    }
}

#[cfg(feature = "ffmpeg")]
pub fn probe(url: &str) -> MediaInfo {
    use ffmpeg_next as ffmpeg;
    // Initialize FFmpeg once; ignore repeated init errors
    let _ = ffmpeg::init();

    let ictx = match ffmpeg::format::input(&url) {
        Ok(ctx) => ctx,
        Err(_) => {
            return MediaInfo { url: url.to_string(), duration_ms: None, bit_rate: None, streams: vec![] };
        }
    };

    // ffmpeg-next v7: duration()/bit_rate() return i64; use >0 guard and assume milliseconds for duration
    let d = ictx.duration();
    let duration_ms = if d > 0 { Some(d as u64) } else { None };
    let b = ictx.bit_rate();
    let bit_rate = if b > 0 { Some(b as u64) } else { None };

    let mut streams = Vec::new();
    for (idx, st) in ictx.streams().enumerate() {
        let codec_params = st.parameters();
        let codec_id = codec_params.id();
        let codec_name = format!("{:?}", codec_id);
        let kind = match st.parameters().medium() {
            ffmpeg::media::Type::Video => "video",
            ffmpeg::media::Type::Audio => "audio",
            ffmpeg::media::Type::Subtitle => "subtitle",
            _ => "other",
        }.to_string();
        let mut sinfo = StreamInfo {
            index: idx as u32,
            kind,
            codec: codec_name,
            profile: None,
            width: None,
            height: None,
            channels: None,
            sample_rate: None,
        };

        // 通过 decoder context 读取参数（v7 风格）
        if let Ok(ctx) = ffmpeg::codec::context::Context::from_parameters(codec_params) {
            match st.parameters().medium() {
                ffmpeg::media::Type::Video => {
                    if let Ok(vd) = ctx.decoder().video() {
                        sinfo.width = Some(vd.width());
                        sinfo.height = Some(vd.height());
                    }
                }
                ffmpeg::media::Type::Audio => {
                    if let Ok(ad) = ctx.decoder().audio() {
                        sinfo.channels = Some(ad.channels() as u32);
                        sinfo.sample_rate = Some(ad.rate() as u32);
                    }
                }
                _ => {}
            }
        }

        streams.push(sinfo);
    }

    MediaInfo { url: url.to_string(), duration_ms, bit_rate, streams }
}
