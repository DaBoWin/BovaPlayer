#!/bin/bash
set -e

echo "🍎 Building BovaPlayer for macOS..."

cd core

# 构建 release 版本
echo "📦 Building Rust binary..."
cargo build --release --bin bova-gui

# 创建 macOS app bundle
echo "📱 Creating macOS app bundle..."
APP_NAME="BovaPlayer"
APP_DIR="target/release/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

# 清理旧的 bundle
rm -rf "${APP_DIR}"

# 创建目录结构
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# 复制可执行文件
cp "target/release/bova-gui" "${MACOS_DIR}/${APP_NAME}"

# 创建 Info.plist
cat > "${CONTENTS_DIR}/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.bova.player</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.0.1</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.13</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

# 创建 DMG（可选）
echo "💿 Creating DMG..."
DMG_NAME="BovaPlayer-macOS-v0.0.1.dmg"
hdiutil create -volname "${APP_NAME}" -srcfolder "${APP_DIR}" -ov -format UDZO "target/release/${DMG_NAME}"

echo "✅ macOS build complete!"
echo "📦 App bundle: ${APP_DIR}"
echo "💿 DMG: core/target/release/${DMG_NAME}"
