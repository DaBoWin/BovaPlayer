#!/bin/bash

# 修复 MPV Framework 的依赖路径
# 这个脚本会将所有 Homebrew 依赖改为 @rpath，并复制缺失的库

set -e

FRAMEWORKS_DIR="packages/media_kit_libs_macos_video_full/macos/Frameworks"
MPV_FRAMEWORK="$FRAMEWORKS_DIR/Mpv.xcframework/macos-arm64_x86_64/Mpv.framework/Versions/A/Mpv"

echo "🔧 修复 MPV 依赖路径..."

# 需要复制和修复的额外依赖库
EXTRA_LIBS=(
    "libplacebo.351:libplacebo"
    "libmujs:mujs"
    "liblcms2.2:little-cms2"
    "libarchive.13:libarchive"
    "libavdevice.61:ffmpeg"
    "libbluray.2:libbluray"
    "libluajit-5.1.2:luajit"
    "librubberband.3:rubberband"
    "libvapoursynth-script.0:vapoursynth"
    "libzimg.2:zimg"
)

# 为每个额外的库创建 framework
for lib_info in "${EXTRA_LIBS[@]}"; do
    IFS=':' read -r lib_name brew_name <<< "$lib_info"
    
    # 查找库文件
    lib_path=$(find /opt/homebrew/opt/$brew_name/lib -name "$lib_name.dylib" 2>/dev/null | head -1)
    
    if [ -z "$lib_path" ]; then
        echo "⚠️  警告: 找不到 $lib_name.dylib，跳过"
        continue
    fi
    
    # 提取 framework 名称（去掉版本号和 lib 前缀）
    framework_name=$(echo "$lib_name" | sed 's/^lib//' | sed 's/\.[0-9]*$//' | sed 's/-[0-9].*$//')
    framework_name="$(echo "$framework_name" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')"
    
    echo "📦 处理 $framework_name ($lib_name)..."
    
    # 创建 framework 结构
    framework_dir="$FRAMEWORKS_DIR/${framework_name}.xcframework/macos-arm64_x86_64/${framework_name}.framework"
    mkdir -p "$framework_dir/Versions/A/Resources"
    
    # 复制库文件
    cp "$lib_path" "$framework_dir/Versions/A/$framework_name"
    
    # 创建符号链接
    cd "$framework_dir"
    ln -sf A Versions/Current
    ln -sf Versions/Current/$framework_name $framework_name
    ln -sf Versions/Current/Resources Resources
    
    # 创建 Info.plist
    cat > "Versions/A/Resources/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$framework_name</string>
    <key>CFBundleIdentifier</key>
    <string>com.homebrew.$framework_name</string>
    <key>CFBundleName</key>
    <string>$framework_name</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
</dict>
</plist>
EOF
    
    cd - > /dev/null
    
    # 创建 xcframework Info.plist
    cat > "$FRAMEWORKS_DIR/${framework_name}.xcframework/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>AvailableLibraries</key>
    <array>
        <dict>
            <key>LibraryIdentifier</key>
            <string>macos-arm64_x86_64</string>
            <key>LibraryPath</key>
            <string>${framework_name}.framework</string>
            <key>SupportedArchitectures</key>
            <array>
                <string>arm64</string>
                <string>x86_64</string>
            </array>
            <key>SupportedPlatform</key>
            <string>macos</string>
        </dict>
    </array>
    <key>CFBundlePackageType</key>
    <string>XFWK</string>
    <key>XCFrameworkFormatVersion</key>
    <string>1.0</string>
</dict>
</plist>
EOF
    
    # 修改库的 install name
    install_name_tool -id "@rpath/${framework_name}.framework/Versions/A/$framework_name" \
        "$framework_dir/Versions/A/$framework_name"
    
    echo "✅ $framework_name 创建完成"
done

echo ""
echo "🔧 修复 MPV 的依赖引用..."

# 修复 MPV 中的所有 Homebrew 路径
for lib_info in "${EXTRA_LIBS[@]}"; do
    IFS=':' read -r lib_name brew_name <<< "$lib_info"
    
    framework_name=$(echo "$lib_name" | sed 's/^lib//' | sed 's/\.[0-9]*$//' | sed 's/-[0-9].*$//')
    framework_name="$(echo "$framework_name" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')"
    
    old_path="/opt/homebrew/opt/$brew_name/lib/$lib_name.dylib"
    new_path="@rpath/${framework_name}.framework/Versions/A/$framework_name"
    
    # 检查是否存在这个依赖
    if otool -L "$MPV_FRAMEWORK" | grep -q "$old_path"; then
        echo "  修复: $lib_name -> @rpath"
        install_name_tool -change "$old_path" "$new_path" "$MPV_FRAMEWORK" 2>/dev/null || true
    fi
done

echo ""
echo "✅ 所有依赖已修复！"
echo ""
echo "📋 验证依赖:"
otool -L "$MPV_FRAMEWORK" | grep -E "(homebrew|@rpath)" | head -20

echo ""
echo "🎉 完成！现在可以重新构建应用了。"
