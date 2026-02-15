#!/bin/bash

# BovaPlayer 图标更新脚本

echo "🎨 BovaPlayer 图标更新工具"
echo "================================"
echo ""

# 检查是否在正确的目录
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ 错误：请在 ui/flutter_app 目录下运行此脚本"
    exit 1
fi

# 检查图标文件是否存在
if [ ! -f "assets/icon.png" ]; then
    echo "❌ 错误：找不到 assets/icon.png"
    echo "请先将你的图标文件（512x512 PNG）放到 assets/icon.png"
    exit 1
fi

echo "✓ 找到图标文件: assets/icon.png"
echo ""

# 检查图标尺寸（需要 ImageMagick）
if command -v identify &> /dev/null; then
    SIZE=$(identify -format "%wx%h" assets/icon.png)
    echo "📐 图标尺寸: $SIZE"
    if [ "$SIZE" != "512x512" ]; then
        echo "⚠️  警告：建议使用 512x512 的图标以获得最佳效果"
    fi
    echo ""
fi

# 安装依赖
echo "📦 安装依赖..."
flutter pub get

# 生成图标
echo ""
echo "🔨 生成应用图标..."
flutter pub run flutter_launcher_icons

# 检查生成结果
if [ -f "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png" ]; then
    echo ""
    echo "✅ 图标生成成功！"
    echo ""
    echo "生成的文件："
    echo "  - android/app/src/main/res/mipmap-*/ic_launcher.png"
    echo "  - android/app/src/main/res/mipmap-*/ic_launcher_round.png"
    echo ""
    echo "📱 下一步："
    echo "  1. 运行 'flutter clean' 清理缓存"
    echo "  2. 运行 'flutter build apk --release' 重新构建"
    echo "  3. 安装新的 APK 查看效果"
else
    echo ""
    echo "❌ 图标生成失败，请检查错误信息"
    exit 1
fi
