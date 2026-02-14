#!/bin/bash
set -e

echo "🤖 Building BovaPlayer for Android..."

# 检查 Flutter 是否安装
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Please install Flutter first:"
    echo "   https://flutter.dev/docs/get-started/install"
    exit 1
fi

# 检查 Android SDK
if [ -z "$ANDROID_HOME" ] && [ -z "$ANDROID_SDK_ROOT" ]; then
    echo "❌ Android SDK not found. Please set ANDROID_HOME or ANDROID_SDK_ROOT"
    exit 1
fi

cd ui/flutter_app

echo "📥 Getting Flutter dependencies..."
flutter pub get

echo "🔨 Building Rust library for Android..."
cd ../../core

# 添加 Android targets
ANDROID_TARGETS=("aarch64-linux-android" "armv7-linux-androideabi" "x86_64-linux-android")
for target in "${ANDROID_TARGETS[@]}"; do
    if ! rustup target list --installed | grep -q "$target"; then
        echo "📥 Installing $target..."
        rustup target add "$target"
    fi
done

# 构建 Android 库
echo "📦 Building for arm64-v8a..."
cargo build --release --lib --target aarch64-linux-android -p bova-ffi

echo "📦 Building for armeabi-v7a..."
cargo build --release --lib --target armv7-linux-androideabi -p bova-ffi

echo "📦 Building for x86_64..."
cargo build --release --lib --target x86_64-linux-android -p bova-ffi

cd ../ui/flutter_app

# 构建 APK
echo "📱 Building Android APK..."
flutter build apk --release

# 构建 App Bundle (for Google Play)
echo "📦 Building Android App Bundle..."
flutter build appbundle --release

echo "✅ Android build complete!"
echo "📱 APK: ui/flutter_app/build/app/outputs/flutter-apk/app-release.apk"
echo "📦 AAB: ui/flutter_app/build/app/outputs/bundle/release/app-release.aab"
echo ""
echo "💡 To install on device: flutter install"
