#!/bin/bash

# 修复剩余的依赖

set -e

FRAMEWORKS_DIR="packages/media_kit_libs_macos_video_full/macos/Frameworks"
MPV_FRAMEWORK="$FRAMEWORKS_DIR/Mpv.xcframework/macos-arm64_x86_64/Mpv.framework/Versions/A/Mpv"

echo "🔧 修复剩余的依赖..."

# 剩余的依赖
REMAINING_LIBS=(
    "libjpeg.8:jpeg-turbo"
    "libvulkan.1:vulkan-loader"
)

# 处理每个库
for lib_info in "${REMAINING_LIBS[@]}"; do
    IFS=':' read -r lib_name brew_name <<< "$lib_info"
    
    lib_path=$(find /opt/homebrew/opt/$brew_name/lib -name "$lib_name.dylib" 2>/dev/null | head -1)
    
    if [ -z "$lib_path" ]; then
        echo "⚠️  警告: 找不到 $lib_name.dylib，跳过"
        continue
    fi
    
    framework_name=$(echo "$lib_name" | sed 's/^lib//' | sed 's/\.[0-9]*$//')
    framework_name="$(echo "$framework_name" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')"
    
    echo "📦 处理 $framework_name ($lib_name)..."
    
    framework_dir="$FRAMEWORKS_DIR/${framework_name}.xcframework/macos-arm64_x86_64/${framework_name}.framework"
    mkdir -p "$framework_dir/Versions/A/Resources"
    
    cp "$lib_path" "$framework_dir/Versions/A/$framework_name"
    
    cd "$framework_dir"
    ln -sf A Versions/Current
    ln -sf Versions/Current/$framework_name $framework_name
    ln -sf Versions/Current/Resources Resources
    
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
    
    install_name_tool -id "@rpath/${framework_name}.framework/Versions/A/$framework_name" \
        "$framework_dir/Versions/A/$framework_name" 2>/dev/null || true
    
    echo "✅ $framework_name 创建完成"
done

echo ""
echo "🔧 修复 MPV 的依赖引用..."

for lib_info in "${REMAINING_LIBS[@]}"; do
    IFS=':' read -r lib_name brew_name <<< "$lib_info"
    
    framework_name=$(echo "$lib_name" | sed 's/^lib//' | sed 's/\.[0-9]*$//')
    framework_name="$(echo "$framework_name" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')"
    
    old_path="/opt/homebrew/opt/$brew_name/lib/$lib_name.dylib"
    new_path="@rpath/${framework_name}.framework/Versions/A/$framework_name"
    
    if otool -L "$MPV_FRAMEWORK" | grep -q "$old_path"; then
        echo "  修复: $lib_name -> @rpath"
        install_name_tool -change "$old_path" "$new_path" "$MPV_FRAMEWORK" 2>/dev/null || true
    fi
done

echo ""
echo "✅ 所有依赖已修复！"
echo ""
echo "📋 验证 Homebrew 依赖:"
if otool -L "$MPV_FRAMEWORK" | grep -q "/opt/homebrew"; then
    echo "⚠️  仍有 Homebrew 依赖:"
    otool -L "$MPV_FRAMEWORK" | grep "/opt/homebrew"
else
    echo "✅ 没有 Homebrew 依赖了！"
fi

echo ""
echo "🎉 完成！"
