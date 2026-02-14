#!/bin/bash

# 检查是否安装了Flutter
if ! command -v flutter &> /dev/null; then
    echo "错误: 未找到Flutter SDK"
    echo "请先安装Flutter: https://flutter.dev/docs/get-started/install"
    exit 1
fi

# 检查是否启用了桌面支持
if ! flutter config --enable-macos-desktop | grep -q "true"; then
    echo "启用macOS桌面支持..."
    flutter config --enable-macos-desktop
fi

# 获取依赖
echo "获取Flutter依赖..."
flutter pub get

# 运行应用
echo "启动BovaPlayer Flutter应用..."
flutter run -d macos