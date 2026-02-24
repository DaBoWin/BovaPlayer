#!/bin/bash

# 递归修复所有 framework 的依赖

set -e

FRAMEWORKS_DIR="packages/media_kit_libs_macos_video_full/macos/Frameworks"

echo "🔍 检查所有 framework 的依赖..."

# 查找所有 framework 中的二进制文件
find "$FRAMEWORKS_DIR" -type f -name "*" -path "*/Versions/A/*" ! -name "*.plist" ! -name "Info" 2>/dev/null | while read -r binary; do
    # 跳过符号链接
    if [ -L "$binary" ]; then
        continue
    fi
    
    # 检查是否是 Mach-O 文件
    if file "$binary" | grep -q "Mach-O"; then
        framework_name=$(basename "$binary")
        
        # 检查是否有 Homebrew 依赖
        homebrew_deps=$(otool -L "$binary" 2>/dev/null | grep "/opt/homebrew" || true)
        
        if [ -n "$homebrew_deps" ]; then
            echo ""
            echo "⚠️  $framework_name 有 Homebrew 依赖:"
            echo "$homebrew_deps"
            
            # 修复每个依赖
            echo "$homebrew_deps" | while read -r line; do
                dep_path=$(echo "$line" | awk '{print $1}')
                
                # 提取库名
                dep_lib=$(basename "$dep_path")
                dep_name=$(echo "$dep_lib" | sed 's/^lib//' | sed 's/\.dylib$//' | sed 's/\.[0-9]*$//')
                dep_framework="$(echo "$dep_name" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')"
                
                # 检查对应的 framework 是否存在
                if [ -d "$FRAMEWORKS_DIR/${dep_framework}.xcframework" ]; then
                    new_path="@rpath/${dep_framework}.framework/Versions/A/$dep_framework"
                    echo "  修复: $dep_lib -> @rpath"
                    install_name_tool -change "$dep_path" "$new_path" "$binary" 2>/dev/null || true
                else
                    echo "  ⚠️  找不到 ${dep_framework}.xcframework，跳过"
                fi
            done
        fi
    fi
done

echo ""
echo "✅ 所有 framework 依赖已修复！"
echo ""
echo "📋 最终验证 - 检查是否还有 Homebrew 依赖:"

has_homebrew=0
find "$FRAMEWORKS_DIR" -type f -name "*" -path "*/Versions/A/*" ! -name "*.plist" ! -name "Info" 2>/dev/null | while read -r binary; do
    if [ -L "$binary" ]; then
        continue
    fi
    
    if file "$binary" | grep -q "Mach-O"; then
        if otool -L "$binary" 2>/dev/null | grep -q "/opt/homebrew"; then
            framework_name=$(basename "$binary")
            echo ""
            echo "⚠️  $framework_name 仍有 Homebrew 依赖:"
            otool -L "$binary" | grep "/opt/homebrew"
            has_homebrew=1
        fi
    fi
done

if [ $has_homebrew -eq 0 ]; then
    echo "✅ 所有 framework 都没有 Homebrew 依赖了！"
fi

echo ""
echo "🎉 完成！现在可以清理并重新构建应用了。"
