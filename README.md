# BovaPlayer (Minimal Workspace)

This is the initial minimal Rust workspace for BovaPlayer core development.

## Layout

- `core/` — Rust workspace with three crates:
  - `bova-core` — core API stubs (open/play/pause/seek/stop)
  - `bova-ffi` — C ABI exposing minimal functions for future UI bindings
  - `bova-cli` — simple CLI using `bova-core`
  - `bova-probe` — media probe utilities (`--probe` in CLI), FFmpeg feature gated
  - `bova-gui` — minimal desktop GUI using `eframe/egui` demonstrating controls and event logs

## Build

First, install Rust toolchain (cargo):

- Official: https://www.rust-lang.org/tools/install
- Homebrew (macOS): `brew install rust`

```
cd core
cargo build
```

## Run CLI

```
cd core
# Probe media info (placeholder without FFmpeg)
cargo run -p bova-cli -- ./sample.mp4 --probe

# Run stub playback control flow (no real decoding yet)
cargo run -p bova-cli -- ./sample.mp4
```

## Run GUI (Desktop)

The GUI uses eframe/egui with a native window. It wires to `bova-core` and shows:
- Open / Play / Pause / Stop / Seek 控件
- 实时事件日志（JSON）

```
cd core
cargo run -p bova-gui
```
在窗口中输入 URL（或保持默认 `./sample.mp4`），点击 Open/Play/Pause/Stop/Seek，底部会滚动显示 JSON 事件。

Note: This is a stub; it does not actually decode or render media yet. It's for wiring and API iteration.

## Next

- Integrate FFmpeg (soft decode) in `bova-core`
- Add basic event bus and stats JSON
- Introduce unit tests for state transitions
- Prepare `bova-ffi` bindings for Flutter/Qt
