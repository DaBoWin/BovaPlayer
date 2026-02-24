#!/bin/bash

# 修复 MPV Framework 使其直接使用 Homebrew 库的绝对路径

set -e

MPV_FRAMEWORK="packages/media_kit_libs_macos_video_full/macos/Frameworks/Mpv.xcframework/macos-arm64_x86_64/Mpv.framework/Versions/A/Mpv"

echo "🔧 修复 MPV 依赖路径为 Homebrew 绝对路径..."

# 获取所有 Homebrew 依赖
homebrew_deps=$(otool -L "$MPV_FRAMEWORK" | grep "/opt/homebrew" | awk '{print $1}')

if [ -z "$homebrew_deps" ]; then
    echo "✅ MPV 已经没有需要修复的 Homebrew 路径"
    exit 0
fi

echo "找到以下 Homebrew 依赖:"
echo "$homebrew_deps"
echo ""

# 不修改路径，保持 Homebrew 绝对路径
# 这样应用运行时会直接从 Homebrew 加载库

echo "✅ MPV 将直接使用 Homebrew 库"
echo ""
echo "📋 当前依赖:"
otool -L "$MPV_FRAMEWORK" | grep -E "(@rpath|/opt/homebrew)" | head -20

echo ""
echo "🎉 完成！应用将直接使用 Homebrew 的 MPV 及其依赖。"
echo ""
echo "⚠️  注意: 用户需要安装 Homebrew MPV:"
echo "   brew install mpv"
