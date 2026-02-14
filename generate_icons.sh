#!/bin/bash

# BovaPlayer 图标生成脚本
# 需要安装: brew install imagemagick librsvg

echo "🎨 开始生成 BovaPlayer 应用图标..."

# 检查依赖
if ! command -v rsvg-convert &> /dev/null; then
    echo "❌ 错误: 需要安装 librsvg"
    echo "   macOS: brew install librsvg"
    echo "   Ubuntu: sudo apt-get install librsvg2-bin"
    exit 1
fi

if ! command -v convert &> /dev/null; then
    echo "❌ 错误: 需要安装 imagemagick"
    echo "   macOS: brew install imagemagick"
    echo "   Ubuntu: sudo apt-get install imagemagick"
    exit 1
fi

# 创建输出目录
mkdir -p ui/flutter_app/assets
mkdir -p ui/flutter_app/assets/icons

# 1. 将 SVG 转换为高分辨率 PNG (1024x1024)
echo "📦 生成主图标 (1024x1024)..."
rsvg-convert -w 1024 -h 1024 ui/flutter_app/assets/logo.svg -o ui/flutter_app/assets/logo.png

# 2. 生成前景图标（用于 Android 自适应图标）
echo "📦 生成前景图标..."
rsvg-convert -w 1024 -h 1024 ui/flutter_app/assets/logo.svg -o ui/flutter_app/assets/logo_foreground.png

# 3. 生成各种尺寸的图标
echo "📦 生成多尺寸图标..."
sizes=(16 32 64 128 256 512 1024)
for size in "${sizes[@]}"; do
    convert ui/flutter_app/assets/logo.png -resize ${size}x${size} ui/flutter_app/assets/icons/logo_${size}.png
    echo "   ✓ ${size}x${size}"
done

# 4. 生成 Windows ICO 文件
echo "📦 生成 Windows ICO..."
convert ui/flutter_app/assets/logo.png -define icon:auto-resize=256,128,64,48,32,16 ui/flutter_app/assets/icons/app_icon.ico

# 5. 使用 flutter_launcher_icons 生成平台图标
echo "📦 使用 Flutter 工具生成平台图标..."
cd ui/flutter_app
flutter pub add dev:flutter_launcher_icons
flutter pub get
flutter pub run flutter_launcher_icons
cd ../..

echo "✅ 图标生成完成！"
echo ""
echo "生成的文件:"
echo "  - ui/flutter_app/assets/logo.png (1024x1024)"
echo "  - ui/flutter_app/assets/logo_foreground.png"
echo "  - ui/flutter_app/assets/icons/* (多尺寸)"
echo "  - ui/flutter_app/assets/icons/app_icon.ico (Windows)"
echo ""
echo "平台图标已自动配置到:"
echo "  - Android: android/app/src/main/res/mipmap-*/"
echo "  - iOS: ios/Runner/Assets.xcassets/AppIcon.appiconset/"
echo "  - macOS: macos/Runner/Assets.xcassets/AppIcon.appiconset/"
echo "  - Windows: windows/runner/resources/"
