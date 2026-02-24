#!/bin/bash

echo "简单测试：启动应用并等待..."

# 清理旧日志
rm -f /tmp/bova_test.log

# 启动应用并捕获输出
open ui/flutter_app/build/macos/Build/Products/Release/bova_player_flutter.app

# 等待应用启动
sleep 3

# 检查应用是否在运行
if pgrep -x "bova_player_flutter" > /dev/null; then
    echo "✅ 应用已启动"
    echo ""
    echo "请在应用中点击播放按钮..."
    echo "按 Enter 键查看日志..."
    read
    
    # 显示最近的日志
    log show --predicate 'process == "bova_player_flutter"' --last 30s --info 2>&1 | tail -100
else
    echo "❌ 应用启动失败"
fi
