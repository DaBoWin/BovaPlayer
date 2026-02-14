use bova_playback::{start_playback_with, PlaybackConfig};
use bova_probe::probe;
use clap::Parser;
use std::time::Duration;

/// Minimal CLI to exercise BovaPlayer core API stubs.
#[derive(Parser, Debug)]
#[command(author="BovaPlayer", version="0.0.1", about="Bova CLI Demo", long_about=None)]
struct Args {
    /// URL or file path
    url: String,

    /// Probe only (print media info)
    #[arg(long)]
    probe: bool,

    /// Use hardware acceleration
    #[arg(short = 'H', long)]
    hardware: bool,
}

fn main() {
    let args = Args::parse();

    if args.probe {
        let info = probe(&args.url);
        println!("{}", serde_json::to_string_pretty(&info).unwrap());
        return;
    }

    println!("Opening: {}", args.url);
    
    let config = PlaybackConfig {
        hwaccel: args.hardware,
        subtitle_enabled: false,
        subtitle_index: None,
        engine: Some(bova_playback::PlaybackEngine::FFmpeg),
    };
    
    if args.hardware {
        println!("Using hardware acceleration");
    }
    
    let handles = match start_playback_with(&args.url, config) {
        Ok(h) => h,
        Err(e) => {
            eprintln!("Playback failed to start: {e}");
            std::process::exit(1);
        }
    };

    println!("Playing... Press Ctrl+C to stop.");

    // Simple playback loop that shows we're receiving frames
    let mut frame_count = 0;
    let start_time = std::time::Instant::now();
    
    while frame_count < 100 { // Limit to 100 frames for demo
        match handles.video_rx.recv_timeout(Duration::from_millis(100)) {
            Ok(frame) => {
                frame_count += 1;
                if frame_count % 10 == 0 {
                    println!("Received frame {}: {}x{}", frame_count, frame.width, frame.height);
                }
            }
            Err(_) => {
                // Timeout or channel closed
                if handles.eos_rx.try_recv().is_ok() {
                    println!("End of stream reached");
                    break;
                }
            }
        }
        
        // Check for stop signal
        if std::thread::panicking() {
            break;
        }
    }

    // Send stop signal
    let _ = handles.stop_tx.send(());
    println!("Playback stopped after {} frames ({:.2}s)", frame_count, start_time.elapsed().as_secs_f32());
}
