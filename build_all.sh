#!/bin/bash
set -e

echo "🚀 Building BovaPlayer for all platforms..."
echo ""

# macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "================================"
    echo "Building for macOS..."
    echo "================================"
    bash build_macos.sh
    echo ""
fi

# Windows (cross-compile from macOS/Linux)
echo "================================"
echo "Building for Windows..."
echo "================================"
bash build_windows.sh || echo "⚠️  Windows build failed (this is normal if cross-compilation tools are not installed)"
echo ""

# Android
echo "================================"
echo "Building for Android..."
echo "================================"
bash build_android.sh || echo "⚠️  Android build failed (this is normal if Flutter/Android SDK are not installed)"
echo ""

echo "✅ All builds complete!"
echo ""
echo "📦 Build artifacts:"
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "  macOS: core/target/release/BovaPlayer.app"
    echo "         core/target/release/BovaPlayer-macOS-v0.0.1.dmg"
fi
echo "  Windows: core/target/windows-release/BovaPlayer.exe"
echo "           core/target/BovaPlayer-Windows-v0.0.1.zip"
echo "  Android: ui/flutter_app/build/app/outputs/flutter-apk/app-release.apk"
echo "           ui/flutter_app/build/app/outputs/bundle/release/app-release.aab"
