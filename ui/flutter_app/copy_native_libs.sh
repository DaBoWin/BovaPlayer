#!/bin/bash

# 复制MPV播放器库到Flutter应用包

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CORE_DIR="$SCRIPT_DIR/../../core"
BUILD_DIR="$SCRIPT_DIR/build/macos/Build/Products"

echo "Building bova-ffi library..."
cd "$CORE_DIR"
cargo build --release --package bova-ffi --features mpv

echo "Copying libraries to Flutter app..."
for config in Debug Release; do
    FRAMEWORKS_DIR="$BUILD_DIR/$config/bova_player_flutter.app/Contents/Frameworks"
    if [ -d "$FRAMEWORKS_DIR" ]; then
        echo "Copying to $FRAMEWORKS_DIR"
        
        # 复制bova_ffi库
        cp -f "$CORE_DIR/target/release/libbova_ffi.dylib" "$FRAMEWORKS_DIR/"
        
        # 不修改install_name，让它使用系统路径
        # 这样可以直接使用Homebrew安装的MPV和依赖
        
        echo "Library copied (using system MPV from Homebrew)"
    fi
done

echo "Done!"
echo "Note: Make sure MPV is installed via Homebrew: brew install mpv"
