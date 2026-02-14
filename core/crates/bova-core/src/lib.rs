//! BovaPlayer core API stubs (v0)
//! This crate defines a minimal, synchronous control surface for early wiring.

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use parking_lot::Mutex;
use serde::{Deserialize, Serialize};
use thiserror::Error;

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub enum HwAccelPolicy {
    Auto,
    Force,
    Disable,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ToneMapMode {
    Off,
    Auto,
    Hable,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ScalerKind {
    Bilinear,
    Lanczos,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MediaOptions {
    pub hwaccel: HwAccelPolicy,
    pub threads: u8,
    pub preferred_audio_langs: Vec<String>,
    pub preferred_sub_langs: Vec<String>,
    pub tone_map: ToneMapMode,
    pub scaler: ScalerKind,
    pub network_cache_ms: u32,
    pub extra: serde_json::Value,
}

impl Default for MediaOptions {
    fn default() -> Self {
        Self {
            hwaccel: HwAccelPolicy::Auto,
            threads: 0,
            preferred_audio_langs: Vec::new(),
            preferred_sub_langs: Vec::new(),
            tone_map: ToneMapMode::Auto,
            scaler: ScalerKind::Lanczos,
            network_cache_ms: 1000,
            extra: serde_json::Value::Null,
        }
    }
}

#[derive(Debug, Error)]
pub enum PlayerError {
    #[error("invalid state: {0}")]
    InvalidState(&'static str),
    #[error("open failed: {0}")]
    OpenFailed(String),
    #[error("seek failed: {0}")]
    SeekFailed(String),
}

#[derive(Debug, Clone)]
pub struct MediaHandle {
    pub url: String,
}

#[derive(Debug, Clone)]
pub enum TrackSelector {
    AudioByIndex(u32),
    SubtitleByIndex(u32),
    SubtitleEnable(bool),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum PropertyValue {
    Bool(bool),
    Int(i64),
    Float(f64),
    Str(String),
    Json(serde_json::Value),
}

pub trait Player: Send + Sync {
    fn open(&mut self, url: &str, opts: MediaOptions) -> Result<MediaHandle, PlayerError>;
    fn play(&mut self) -> Result<(), PlayerError>;
    fn pause(&mut self) -> Result<(), PlayerError>;
    fn stop(&mut self) -> Result<(), PlayerError>;
    fn seek(&mut self, pos_ms: i64, accurate: bool) -> Result<(), PlayerError>;
    fn select_track(&mut self, sel: TrackSelector) -> Result<(), PlayerError>;
    fn set_property(&mut self, _key: &str, _val: PropertyValue) -> Result<(), PlayerError> { Ok(()) }
    fn get_property(&self, _key: &str) -> Option<PropertyValue> { None }
}

#[derive(Default)]
pub struct BovaPlayer {
    state: Arc<Mutex<State>>,
    playing: Arc<AtomicBool>,
    listeners: Arc<Mutex<Vec<EventCallback>>>,
}

#[derive(Debug, Default)]
struct State {
    opened: bool,
    current: Option<MediaHandle>,
    position_ms: i64,
    subtitle_enabled: bool,
    current_subtitle_index: Option<u32>,
}

impl BovaPlayer {
    pub fn new() -> Self { Self::default() }

    pub fn on_event(&mut self, cb: EventCallback) {
        self.listeners.lock().push(cb);
    }

    fn emit(&self, kind: EventKind, payload: serde_json::Value) {
        let evt = Event { kind, payload };
        let json = serde_json::to_string(&evt).unwrap_or_else(|_| "{}".to_string());
        for cb in self.listeners.lock().iter() {
            cb(&json);
        }
    }
}

impl Player for BovaPlayer {
    fn open(&mut self, url: &str, _opts: MediaOptions) -> Result<MediaHandle, PlayerError> {
        let handle = MediaHandle { url: url.to_string() };
        let mut st = self.state.lock();
        st.opened = true;
        st.current = Some(handle.clone());
        st.position_ms = 0;
        drop(st);
        self.emit(EventKind::Opened, serde_json::json!({"url": url}));
        Ok(handle)
    }

    fn play(&mut self) -> Result<(), PlayerError> {
        if !self.state.lock().opened { return Err(PlayerError::InvalidState("not opened")); }
        self.playing.store(true, Ordering::SeqCst);
        self.emit(EventKind::Play, serde_json::json!({}));
        Ok(())
    }

    fn pause(&mut self) -> Result<(), PlayerError> {
        if !self.state.lock().opened { return Err(PlayerError::InvalidState("not opened")); }
        self.playing.store(false, Ordering::SeqCst);
        self.emit(EventKind::Pause, serde_json::json!({}));
        Ok(())
    }

    fn stop(&mut self) -> Result<(), PlayerError> {
        self.playing.store(false, Ordering::SeqCst);
        let mut st = self.state.lock();
        st.opened = false;
        st.current = None;
        st.position_ms = 0;
        drop(st);
        self.emit(EventKind::Stop, serde_json::json!({}));
        Ok(())
    }

    fn seek(&mut self, pos_ms: i64, _accurate: bool) -> Result<(), PlayerError> {
        if !self.state.lock().opened { return Err(PlayerError::InvalidState("not opened")); }
        self.state.lock().position_ms = pos_ms.max(0);
        self.emit(EventKind::Seek, serde_json::json!({"position_ms": pos_ms.max(0)}));
        Ok(())
    }
    
    fn select_track(&mut self, sel: TrackSelector) -> Result<(), PlayerError> { 
        match sel {
            TrackSelector::AudioByIndex(idx) => {
                self.emit(EventKind::SubtitleChanged, serde_json::json!({"audio_index": idx}));
            }
            TrackSelector::SubtitleByIndex(idx) => {
                let mut state = self.state.lock();
                state.current_subtitle_index = Some(idx);
                drop(state);
                self.emit(EventKind::SubtitleChanged, serde_json::json!({"subtitle_index": idx}));
            }
            TrackSelector::SubtitleEnable(enabled) => {
                let mut state = self.state.lock();
                state.subtitle_enabled = enabled;
                drop(state);
                self.emit(EventKind::SubtitleChanged, serde_json::json!({"subtitle_enabled": enabled}));
            }
        }
        Ok(())
    }
}

/// Convenience constructor for consumers that don't want the trait object yet.
pub fn create_player() -> BovaPlayer { BovaPlayer::new() }

// --- Events ---

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum EventKind { Opened, Play, Pause, Stop, Seek, SubtitleChanged }

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Event {
    pub kind: EventKind,
    pub payload: serde_json::Value,
}

pub type EventCallback = Arc<dyn Fn(&str) + Send + Sync>;
