#!/bin/bash

# 设置 Homebrew 库路径
export DYLD_FALLBACK_LIBRARY_PATH="/opt/homebrew/lib:$DYLD_FALLBACK_LIBRARY_PATH"

# 直接运行应用的可执行文件
APP_PATH="ui/flutter_app/build/macos/Build/Products/Debug/bova_player_flutter.app"
EXEC_PATH="$APP_PATH/Contents/MacOS/bova_player_flutter"

if [ ! -f "$EXEC_PATH" ]; then
    echo "错误: 找不到应用可执行文件"
    echo "请先运行: cd ui/flutter_app && flutter build macos --debug"
    exit 1
fi

echo "启动应用，使用 Homebrew 库路径..."
echo "DYLD_FALLBACK_LIBRARY_PATH=$DYLD_FALLBACK_LIBRARY_PATH"

# 直接执行
"$EXEC_PATH"
