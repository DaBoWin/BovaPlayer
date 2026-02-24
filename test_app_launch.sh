#!/bin/bash

# 测试应用启动和日志监控脚本

echo "=========================================="
echo "BovaPlayer macOS 应用测试脚本"
echo "=========================================="
echo ""

APP_PATH="ui/flutter_app/build/macos/Build/Products/Release/bova_player_flutter.app"

# 检查应用是否存在
if [ ! -d "$APP_PATH" ]; then
    echo "❌ 应用未找到: $APP_PATH"
    echo "请先构建应用:"
    echo "  cd ui/flutter_app"
    echo "  flutter build macos --release"
    exit 1
fi

echo "✅ 找到应用: $APP_PATH"
echo ""

# 检查 entitlements
echo "📋 检查 Entitlements 配置..."
echo ""
echo "Debug Profile:"
grep -A 1 "com.apple.security.app-sandbox" ui/flutter_app/macos/Runner/DebugProfile.entitlements
echo ""
echo "Release Profile:"
grep -A 1 "com.apple.security.app-sandbox" ui/flutter_app/macos/Runner/Release.entitlements
echo ""

# 启动应用
echo "🚀 启动应用..."
open "$APP_PATH"

# 等待应用启动
sleep 2

# 检查应用是否在运行
if pgrep -x "bova_player_flutter" > /dev/null; then
    echo "✅ 应用已启动"
    echo ""
    echo "📊 实时日志监控（按 Ctrl+C 停止）..."
    echo "=========================================="
    echo ""
    
    # 监控日志
    log stream --predicate 'process == "bova_player_flutter"' --level info 2>&1 | while read line; do
        # 高亮显示错误和警告
        if echo "$line" | grep -qi "error\|crash\|exception\|fail"; then
            echo "🔴 $line"
        elif echo "$line" | grep -qi "warn"; then
            echo "🟡 $line"
        elif echo "$line" | grep -qi "MediaKitPlayer"; then
            echo "🎬 $line"
        else
            echo "$line"
        fi
    done
else
    echo "❌ 应用启动失败"
    echo ""
    echo "查看最近的崩溃日志:"
    log show --predicate 'process == "bova_player_flutter"' --last 1m --info | grep -i "error\|crash"
fi
