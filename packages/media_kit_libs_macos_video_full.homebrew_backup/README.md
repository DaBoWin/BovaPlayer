# media_kit_libs_macos_video_full

这是一个本地 Flutter 包，使用 Homebrew MPV 库以支持 TrueHD 音频解码。

## 包含的库

- **libmpv** (v0.40.0) - 主 MPV 库
- **libass** - 字幕渲染
- **libavcodec, libavfilter, libavformat, libavutil** - FFmpeg 编解码器
- **libplacebo** - GPU 加速视频处理
- **libswresample, libswscale** - 音视频重采样
- 以及其他依赖库

## 支持的音频格式

包括但不限于：
- ✅ TrueHD (Dolby TrueHD)
- ✅ DTS-HD MA
- ✅ AAC, AC3, EAC3
- ✅ FLAC, ALAC
- ✅ Opus, Vorbis
- ✅ MP3, MP2

## 使用方法

此包通过 `dependency_overrides` 自动替换官方的 `media_kit_libs_macos_video` 包。

在 `ui/flutter_app/pubspec.yaml` 中已配置：

```yaml
dependency_overrides:
  media_kit_libs_macos_video:
    path: ../../packages/media_kit_libs_macos_video_full
```

## 维护

### 更新 Homebrew MPV

当 Homebrew MPV 更新后，需要重新复制库文件：

```bash
# 更新 MPV
brew upgrade mpv

# 重新复制库文件
cd ~/code/BovaPlayer
rm -rf packages/media_kit_libs_macos_video_full/macos/Frameworks
mkdir -p packages/media_kit_libs_macos_video_full/macos/Frameworks

# 运行复制脚本（参考 HOMEBREW_MPV_SETUP.md）
```

## 团队协作

其他开发者只需要：

1. 安装 Homebrew MPV：
   ```bash
   brew install mpv
   ```

2. 运行 Flutter 命令：
   ```bash
   cd ui/flutter_app
   flutter pub get
   flutter build macos
   ```

## 许可证

此包使用 Homebrew MPV 库，遵循 LGPL-2.1 许可证。

## 版本信息

- MPV 版本：0.40.0
- 创建日期：2026-02-20
- 来源：Homebrew (/opt/homebrew/lib/libmpv.dylib)
