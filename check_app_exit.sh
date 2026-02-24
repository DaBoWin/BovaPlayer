#!/bin/bash

echo "启动应用并监控退出..."

# 启动应用
open ui/flutter_app/build/macos/Build/Products/Release/bova_player_flutter.app &

# 等待应用启动
sleep 3

# 获取进程 ID
PID=$(pgrep -x "bova_player_flutter")

if [ -z "$PID" ]; then
    echo "❌ 应用未启动"
    exit 1
fi

echo "✅ 应用已启动，PID: $PID"
echo ""
echo "监控应用日志（按 Ctrl+C 停止）..."
echo "=========================================="

# 实时监控日志
log stream --predicate "process == 'bova_player_flutter'" --level debug 2>&1 &
LOG_PID=$!

# 等待应用退出
while kill -0 $PID 2>/dev/null; do
    sleep 1
done

# 停止日志监控
kill $LOG_PID 2>/dev/null

echo ""
echo "=========================================="
echo "❌ 应用已退出"
echo ""
echo "检查退出原因..."

# 检查最近的崩溃报告
LATEST_CRASH=$(ls -t ~/Library/Logs/DiagnosticReports/bova_player_flutter*.ips 2>/dev/null | head -1)

if [ ! -z "$LATEST_CRASH" ]; then
    CRASH_TIME=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$LATEST_CRASH")
    echo "发现崩溃报告: $LATEST_CRASH"
    echo "时间: $CRASH_TIME"
    echo ""
    echo "崩溃原因:"
    cat "$LATEST_CRASH" | grep -A 5 "termination\|exception" | head -20
else
    echo "未发现崩溃报告，应用可能是正常退出"
    echo ""
    echo "检查最近的系统日志..."
    log show --predicate "process == 'bova_player_flutter'" --last 1m --info 2>&1 | grep -i "exit\|quit\|terminate" | tail -10
fi
