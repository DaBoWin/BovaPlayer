# TrueHD 音频支持解决方案

## 问题
当前 `media_kit_libs_video 1.0.4` 使用 **default flavor** 的 MPV 库，不包含 TrueHD 解码器。

## 解决方案：使用 full flavor MPV 库

### 方案 1：自己编译 full flavor MPV（推荐）

#### 步骤 1：安装 Nix 包管理器

```bash
# macOS 安装 Nix
sh <(curl -L https://nixos.org/nix/install)
```

#### 步骤 2：克隆 libmpv-darwin-build 仓库

```bash
git clone https://github.com/media-kit/libmpv-darwin-build.git
cd libmpv-darwin-build
```

#### 步骤 3：编译 full flavor 库

```bash
# 设置版本号
echo "v1.0.0" > nix/utils/default/version.nix

# 编译 macOS universal full flavor 库
nix build -v .#mk-out-archive-libs-macos-universal-video-full

# 查看编译结果
ls -lh result/
```

编译完成后，你会得到：
- `libmpv-libs_v1.0.0_macos-universal-video-full.tar.gz`

#### 步骤 4：替换 media_kit_libs_video 中的库文件

```bash
# 1. 找到 media_kit_libs_video 的安装位置
cd ~/.pub-cache/hosted/pub.dev/media_kit_libs_macos_video-1.0.4/

# 2. 备份原始库
cp -r macos/Frameworks macos/Frameworks.backup

# 3. 解压 full flavor 库
tar -xzf ~/libmpv-darwin-build/result/libmpv-libs_v1.0.0_macos-universal-video-full.tar.gz

# 4. 替换库文件
# 将解压出来的 .framework 文件复制到 macos/Frameworks/
cp -r libmpv-libs/macos-universal-video-full/*.framework macos/Frameworks/
```

#### 步骤 5：清理并重新构建

```bash
cd ~/code/BovaPlayer/ui/flutter_app

# 清理构建缓存
flutter clean

# 重新获取依赖
flutter pub get

# 重新构建 macOS 应用
flutter build macos --release
```

### 方案 2：使用预编译的 full flavor 库（如果可用）

如果 media_kit 官方发布了 full flavor 的包，可以直接在 `pubspec.yaml` 中指定：

```yaml
dependencies:
  media_kit: ^1.1.10
  media_kit_video: ^2.0.1
  # 如果有 full flavor 包（目前不存在）
  # media_kit_libs_macos_video_full: ^1.0.4
  media_kit_libs_video: ^1.0.4
```

### 方案 3：使用 dependency_overrides（临时方案）

如果你编译了自己的 full flavor 库，可以创建一个本地包：

1. 创建本地包目录：
```bash
mkdir -p ~/flutter_packages/media_kit_libs_macos_video_full
```

2. 复制 media_kit_libs_macos_video 的结构，替换为 full flavor 库

3. 在 `pubspec.yaml` 中使用 dependency_overrides：
```yaml
dependency_overrides:
  media_kit_libs_macos_video:
    path: ~/flutter_packages/media_kit_libs_macos_video_full
```

## 验证 TrueHD 支持

编译完成后，运行应用并播放包含 TrueHD 音轨的视频，检查日志：

```bash
flutter run -d macos
```

如果成功，你应该看到：
- ✅ 没有 "Failed to initialize a decoder for codec 'truehd'" 错误
- ✅ 音频正常播放
- ✅ 日志显示 TrueHD 音轨被正确解码

## 注意事项

1. **许可证**：full flavor 使用 LGPL-2.1 许可证，允许商业使用
2. **文件大小**：full flavor 库比 default flavor 大约大 20-30%
3. **编译时间**：首次编译可能需要 30-60 分钟
4. **Nix 依赖**：需要安装 Nix 包管理器和 Xcode

## 其他平台

### Android
Android 需要编译 Android 版本的 full flavor 库：
```bash
# 参考 media-kit/libmpv-android-video-build
```

### iOS
iOS 使用相同的 libmpv-darwin-build 仓库：
```bash
nix build -v .#mk-out-archive-libs-ios-arm64-video-full
```

### Windows
Windows 需要使用 libmpv-win32-video-build 仓库。

## 总结

使用 full flavor MPV 库是支持 TrueHD 的最佳方案：
- ✅ 完整的编解码器支持（包括 TrueHD、DTS-HD MA 等）
- ✅ 无需转码，保持原始音质
- ✅ 支持商业使用（LGPL-2.1）
- ✅ 与 media_kit 完全兼容

唯一的缺点是需要自己编译，但这是一次性工作，编译完成后可以一直使用。
