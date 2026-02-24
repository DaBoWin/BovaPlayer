#!/bin/bash

echo "测试动态库加载..."
echo ""

# 设置环境变量来打印库加载信息
export DYLD_PRINT_LIBRARIES=1
export DYLD_PRINT_LIBRARIES_POST_LAUNCH=1

# 启动应用
ui/flutter_app/build/macos/Build/Products/Release/bova_player_flutter.app/Contents/MacOS/bova_player_flutter 2>&1 | tee dyld_output.log &

APP_PID=$!

echo "应用 PID: $APP_PID"
echo "等待 10 秒..."
sleep 10

if kill -0 $APP_PID 2>/dev/null; then
    echo "应用仍在运行"
    kill $APP_PID
else
    echo "应用已退出"
fi

echo ""
echo "检查是否有 Homebrew 库被加载..."
grep -i "homebrew\|/opt/" dyld_output.log || echo "未发现 Homebrew 库"
