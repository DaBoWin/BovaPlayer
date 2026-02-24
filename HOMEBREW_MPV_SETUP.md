# 使用 Homebrew MPV 库 - 完整指南

## 方案对比

### 原始方案 2：直接修改 pub cache
- ❌ 每次 `flutter clean` 后需要重新复制
- ❌ 团队成员都需要手动操作
- ❌ 容易忘记，导致构建失败

### 推荐方案 2.5：创建本地 override 包
- ✅ 只需配置一次
- ✅ 可以提交到 Git，团队共享
- ✅ `flutter clean` 后自动生效
- ✅ 更容易维护

---

## 推荐方案 2.5：创建本地 override 包

### 步骤 1：安装 Homebrew MPV

```bash
brew install mpv
```

### 步骤 2：创建本地包目录结构

```bash
cd ~/code/BovaPlayer
mkdir -p packages/media_kit_libs_macos_video_full/macos/Frameworks
```

### 步骤 3：复制 Homebrew MPV 库

```bash
# 查找 Homebrew MPV 库位置
MPV_LIB=$(brew list mpv | grep "libmpv.*\.dylib$" | head -n 1)
echo "Found MPV library at: $MPV_LIB"

# 创建 framework 结构
cd ~/code/BovaPlayer/packages/media_kit_libs_macos_video_full/macos/Frameworks
mkdir -p libmpv.framework/Versions/A

# 复制库文件
cp "$MPV_LIB" libmpv.framework/Versions/A/libmpv

# 创建符号链接
cd libmpv.framework
ln -sf Versions/A/libmpv libmpv
ln -sf Versions/A Versions/Current

# 复制依赖库（如果需要）
cd ~/code/BovaPlayer/packages/media_kit_libs_macos_video_full/macos/Frameworks
for lib in $(otool -L "$MPV_LIB" | grep /opt/homebrew | awk '{print $1}'); do
    lib_name=$(basename "$lib")
    echo "Copying dependency: $lib_name"
    mkdir -p "$lib_name.framework/Versions/A"
    cp "$lib" "$lib_name.framework/Versions/A/$lib_name"
    cd "$lib_name.framework"
    ln -sf "Versions/A/$lib_name" "$lib_name"
    ln -sf Versions/A Versions/Current
    cd ..
done
```

### 步骤 4：创建 pubspec.yaml

```bash
cd ~/code/BovaPlayer/packages/media_kit_libs_macos_video_full
cat > pubspec.yaml << 'EOF'
name: media_kit_libs_macos_video_full
description: Full flavor MPV library for macOS (with TrueHD support)
version: 1.0.4+homebrew
publish_to: none

environment:
  sdk: '>=3.0.0 <4.0.0'
  flutter: '>=3.0.0'

flutter:
  plugin:
    platforms:
      macos:
        pluginClass: MediaKitLibsMacosVideoPlugin
EOF
```

### 步骤 5：创建插件类

```bash
mkdir -p ~/code/BovaPlayer/packages/media_kit_libs_macos_video_full/macos/Classes
cat > ~/code/BovaPlayer/packages/media_kit_libs_macos_video_full/macos/Classes/MediaKitLibsMacosVideoPlugin.swift << 'EOF'
import Cocoa
import FlutterMacOS

public class MediaKitLibsMacosVideoPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    // This plugin only provides native libraries, no platform channels needed
  }
}
EOF
```

### 步骤 6：创建 podspec

```bash
cat > ~/code/BovaPlayer/packages/media_kit_libs_macos_video_full/macos/media_kit_libs_macos_video_full.podspec << 'EOF'
Pod::Spec.new do |s|
  s.name             = 'media_kit_libs_macos_video_full'
  s.version          = '1.0.4'
  s.summary          = 'Full flavor MPV library for macOS'
  s.homepage         = 'https://github.com/media-kit/media-kit'
  s.license          = { :type => 'LGPL-2.1', :file => '../LICENSE' }
  s.author           = { 'BovaPlayer' => 'bova@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.platform         = :osx, '10.13'
  s.vendored_frameworks = 'Frameworks/*.framework'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
EOF
```

### 步骤 7：在主项目中使用 dependency_overrides

```bash
cd ~/code/BovaPlayer/ui/flutter_app
```

在 `pubspec.yaml` 中添加：

```yaml
dependency_overrides:
  media_kit_libs_macos_video:
    path: ../../packages/media_kit_libs_macos_video_full
```

### 步骤 8：清理并重新构建

```bash
cd ~/code/BovaPlayer/ui/flutter_app
flutter clean
flutter pub get
flutter build macos
```

---

## 验证 TrueHD 支持

### 1. 检查库文件

```bash
cd ~/code/BovaPlayer/ui/flutter_app/build/macos/Build/Products/Release/bova_player_flutter.app/Contents/Frameworks
ls -lh libmpv.framework/Versions/A/libmpv
```

### 2. 检查支持的解码器

```bash
# 使用 Homebrew MPV 查看支持的解码器
mpv --audio-decoder=help | grep truehd
```

应该看到：
```
truehd              - TrueHD
```

### 3. 运行应用测试

```bash
cd ~/code/BovaPlayer/ui/flutter_app
flutter run -d macos
```

播放包含 TrueHD 音轨的视频，检查日志是否有错误。

---

## 后续维护

### 当 Homebrew MPV 更新时

```bash
# 更新 Homebrew MPV
brew upgrade mpv

# 重新复制库文件（重复步骤 3）
cd ~/code/BovaPlayer/packages/media_kit_libs_macos_video_full/macos/Frameworks
rm -rf libmpv.framework
# ... 重复步骤 3 的命令
```

### 团队协作

1. **提交到 Git**：
   ```bash
   cd ~/code/BovaPlayer
   git add packages/media_kit_libs_macos_video_full
   git commit -m "Add Homebrew MPV library override for TrueHD support"
   ```

2. **其他开发者**：
   - 只需要安装 Homebrew MPV：`brew install mpv`
   - 运行 `flutter pub get` 即可

3. **在 README 中说明**：
   ```markdown
   ## macOS 开发环境设置
   
   本项目使用 Homebrew MPV 库以支持 TrueHD 音频解码。
   
   ### 安装依赖
   \`\`\`bash
   brew install mpv
   \`\`\`
   
   ### 构建应用
   \`\`\`bash
   cd ui/flutter_app
   flutter pub get
   flutter build macos
   \`\`\`
   ```

---

## 潜在问题和解决方案

### 问题 1：库文件路径错误

**症状**：运行时报错 `Library not loaded: @rpath/libmpv.framework/Versions/A/libmpv`

**解决**：
```bash
# 检查库文件的 rpath
otool -L ~/code/BovaPlayer/ui/flutter_app/build/macos/Build/Products/Release/bova_player_flutter.app/Contents/Frameworks/libmpv.framework/Versions/A/libmpv

# 如果路径不对，使用 install_name_tool 修复
install_name_tool -id "@rpath/libmpv.framework/Versions/A/libmpv" \
  ~/code/BovaPlayer/packages/media_kit_libs_macos_video_full/macos/Frameworks/libmpv.framework/Versions/A/libmpv
```

### 问题 2：依赖库缺失

**症状**：运行时报错 `Library not loaded: /opt/homebrew/lib/libavcodec.dylib`

**解决**：复制所有依赖库（参考步骤 3 的依赖库复制部分）

### 问题 3：版本不兼容

**症状**：播放时崩溃或功能异常

**解决**：
1. 检查 Homebrew MPV 版本：`brew info mpv`
2. 如果版本差异太大，考虑使用方案 1（编译特定版本）

---

## 总结

### 优点
- ✅ 配置一次，永久生效
- ✅ 可以提交到 Git，团队共享
- ✅ `flutter clean` 后自动生效
- ✅ 快速（几分钟）
- ✅ 完整的 TrueHD 支持

### 缺点
- ⚠️ 依赖 Homebrew MPV
- ⚠️ 版本可能不完全匹配
- ⚠️ 需要手动维护依赖库

### 适用场景
- ✅ 快速开发和测试
- ✅ 个人项目或小团队
- ✅ 不想下载 5GB Xcode

### 不适用场景
- ❌ 需要精确控制 MPV 版本
- ❌ 需要自定义编译选项
- ❌ 商业发布（建议使用方案 1）
