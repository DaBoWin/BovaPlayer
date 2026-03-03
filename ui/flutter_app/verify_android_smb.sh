#!/bin/bash

# Android SMB 功能验证脚本
# 用于快速检查 Android SMB 实现是否完整

echo "🔍 Android SMB 功能验证"
echo "========================"
echo ""

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查计数
PASS=0
FAIL=0
WARN=0

# 检查函数
check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓${NC} 文件存在: $1"
        ((PASS++))
        return 0
    else
        echo -e "${RED}✗${NC} 文件缺失: $1"
        ((FAIL++))
        return 1
    fi
}

check_content() {
    if grep -q "$2" "$1" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} 内容检查通过: $3"
        ((PASS++))
        return 0
    else
        echo -e "${RED}✗${NC} 内容检查失败: $3"
        ((FAIL++))
        return 1
    fi
}

check_warning() {
    if grep -q "$2" "$1" 2>/dev/null; then
        echo -e "${YELLOW}⚠${NC} 警告: $3"
        ((WARN++))
        return 1
    else
        echo -e "${GREEN}✓${NC} 检查通过: $3"
        ((PASS++))
        return 0
    fi
}

echo "1️⃣  检查核心文件"
echo "-------------------"
check_file "android/app/src/main/kotlin/com/example/bova_player_flutter/SmbHandler.kt"
check_file "android/app/build.gradle.kts"
check_file "android/app/src/main/AndroidManifest.xml"
check_file "lib/services/smb_service.dart"
check_file "lib/network_browser_page.dart"
echo ""

echo "2️⃣  检查依赖配置"
echo "-------------------"
check_content "android/app/build.gradle.kts" "jcifs-ng" "jcifs-ng 依赖已添加"
check_content "android/app/build.gradle.kts" "2.1.10" "jcifs-ng 版本正确"
echo ""

echo "3️⃣  检查权限配置"
echo "-------------------"
check_content "android/app/src/main/AndroidManifest.xml" "android.permission.INTERNET" "网络权限已配置"
check_content "android/app/src/main/AndroidManifest.xml" "android.permission.ACCESS_NETWORK_STATE" "网络状态权限已配置"
echo ""

echo "4️⃣  检查 SmbHandler 实现"
echo "-------------------"
check_content "android/app/src/main/kotlin/com/example/bova_player_flutter/SmbHandler.kt" "jcifs.smb.SmbFile" "SmbFile 导入正确"
check_content "android/app/src/main/kotlin/com/example/bova_player_flutter/SmbHandler.kt" "jcifs.CIFSContext" "CIFSContext 导入正确"
check_content "android/app/src/main/kotlin/com/example/bova_player_flutter/SmbHandler.kt" "NtlmPasswordAuthenticator" "NTLM 认证实现"
check_warning "android/app/src/main/kotlin/com/example/bova_player_flutter/SmbHandler.kt" "TODO" "没有 TODO 标记"
echo ""

echo "5️⃣  检查方法实现"
echo "-------------------"
check_content "android/app/src/main/kotlin/com/example/bova_player_flutter/SmbHandler.kt" "fun connect" "connect 方法存在"
check_content "android/app/src/main/kotlin/com/example/bova_player_flutter/SmbHandler.kt" "fun disconnect" "disconnect 方法存在"
check_content "android/app/src/main/kotlin/com/example/bova_player_flutter/SmbHandler.kt" "fun listDirectory" "listDirectory 方法存在"
check_content "android/app/src/main/kotlin/com/example/bova_player_flutter/SmbHandler.kt" "fun readFile" "readFile 方法存在"
echo ""

echo "6️⃣  检查 MainActivity 集成"
echo "-------------------"
check_content "android/app/src/main/kotlin/com/example/bova_player_flutter/MainActivity.kt" "SMBHandler" "SMBHandler 已注册"
check_content "android/app/src/main/kotlin/com/example/bova_player_flutter/MainActivity.kt" "com.bovaplayer/smb" "SMB Channel 已配置"
echo ""

echo "7️⃣  检查 Dart 服务"
echo "-------------------"
check_content "lib/services/smb_service.dart" "MethodChannel" "MethodChannel 已配置"
check_content "lib/services/smb_service.dart" "com.bovaplayer/smb" "Channel 名称匹配"
check_content "lib/services/smb_service.dart" "_connectAndroid" "Android 连接方法存在"
check_content "lib/services/smb_service.dart" "_listDirectoryAndroid" "Android 列表方法存在"
check_content "lib/services/smb_service.dart" "_readFileBytesAndroid" "Android 读取方法存在"
echo ""

echo "8️⃣  检查文档"
echo "-------------------"
check_file "ANDROID_SMB_TEST.md"
check_file "ANDROID_SMB_EXAMPLE.md"
check_file "ANDROID_SMB_COMPLETION.md"
echo ""

echo "9️⃣  检查日志记录"
echo "-------------------"
check_content "android/app/src/main/kotlin/com/example/bova_player_flutter/SmbHandler.kt" "Log.d" "日志记录已实现"
check_content "android/app/src/main/kotlin/com/example/bova_player_flutter/SmbHandler.kt" "Log.e" "错误日志已实现"
echo ""

echo "🔟  检查错误处理"
echo "-------------------"
check_content "android/app/src/main/kotlin/com/example/bova_player_flutter/SmbHandler.kt" "try" "异常处理已实现"
check_content "android/app/src/main/kotlin/com/example/bova_player_flutter/SmbHandler.kt" "catch" "catch 块已实现"
check_content "android/app/src/main/kotlin/com/example/bova_player_flutter/SmbHandler.kt" "result.error" "错误返回已实现"
echo ""

# 总结
echo "========================"
echo "📊 验证结果"
echo "========================"
echo -e "${GREEN}通过: $PASS${NC}"
echo -e "${RED}失败: $FAIL${NC}"
echo -e "${YELLOW}警告: $WARN${NC}"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}✅ 所有检查通过！Android SMB 实现完整。${NC}"
    echo ""
    echo "📝 下一步:"
    echo "  1. 构建应用: flutter build apk --debug"
    echo "  2. 安装到设备: flutter install"
    echo "  3. 执行测试: 参考 ANDROID_SMB_TEST.md"
    echo ""
    exit 0
else
    echo -e "${RED}❌ 发现 $FAIL 个问题，请检查并修复。${NC}"
    echo ""
    exit 1
fi
