# media_kit 集成说明

## 概述

已将 Flutter 播放器从自定义 MPV FFI 切换到 `media_kit` 库。media_kit 是目前 Flutter 集成 MPV 最成熟的方案，提供：

- 完整的 MPV 功能封装
- 跨平台支持（Android、iOS、macOS、Windows、Linux）
- 简单易用的 API
- 内置字幕支持
- 硬件加速
- 多种视频格式支持

## 安装步骤

### 1. 安装依赖

```bash
cd ui/flutter_app
flutter pub get
```

### 2. 平台特定配置

#### macOS

无需额外配置，`media_kit_libs_video` 会自动下载 MPV 库。

#### Android

在 `android/app/build.gradle` 中确保 minSdkVersion >= 16：

```gradle
android {
    defaultConfig {
        minSdkVersion 16
    }
}
```

#### Windows

无需额外配置，库会自动下载。

#### Linux

需要安装系统 MPV 库：

```bash
# Ubuntu/Debian
sudo apt install libmpv-dev mpv

# Fedora
sudo dnf install mpv-libs-devel

# Arch
sudo pacman -S mpv
```

## 功能特性

### 已实现功能

- ✅ 视频播放（支持所有 MPV 支持的格式）
- ✅ 播放控制（播放/暂停、快进/快退）
- ✅ 进度条拖动
- ✅ 倍速播放（0.5x - 2.0x）
- ✅ 画面比例调整（适应/填充/拉伸）
- ✅ 字幕切换（自动检测内嵌字幕）
- ✅ 锁屏功能
- ✅ 自动隐藏控制栏
- ✅ 硬件加速

### 字幕支持

media_kit 自动支持：
- 内嵌字幕（MKV、MP4 等容器格式）
- 外部字幕文件（SRT、ASS、SSA 等）
- 字幕轨道切换
- 字幕样式渲染

## 使用方法

### 基本播放

```dart
import 'package:bova_player_flutter/media_kit_player_page.dart';

Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => MediaKitPlayerPage(
      streamUrl: 'https://your-video-url.mp4',
      title: '视频标题',
    ),
  ),
);
```

### 播放 Emby 内容

已在 `emby_page.dart` 中集成，点击任何媒体项即可播放。

## 性能优化

media_kit 相比自定义 FFI 方案的优势：

1. **更好的性能**：使用原生 MPV 渲染，无需 CustomPainter
2. **更低的 CPU 占用**：直接使用平台视图，无需帧拷贝
3. **更流畅的播放**：硬件加速支持更完善
4. **更少的内存占用**：无需在 Dart 和 Native 之间传递帧数据

## 故障排除

### macOS 权限问题

如果遇到权限错误，确保 `macos/Runner/DebugProfile.entitlements` 包含：

```xml
<key>com.apple.security.cs.allow-jit</key>
<true/>
<key>com.apple.security.cs.allow-unsigned-executable-memory</key>
<true/>
```

### Android 播放失败

检查网络权限在 `android/app/src/main/AndroidManifest.xml`：

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

### 字幕不显示

确保字幕文件编码为 UTF-8，或使用 Emby 的字幕烧录功能。

## 文件说明

- `lib/media_kit_player_page.dart` - 新的 media_kit 播放器页面
- `lib/mpv_player_page.dart` - 旧的自定义 MPV FFI 播放器（已弃用）
- `lib/enhanced_player.dart` - 旧的 video_player 播放器（已弃用）

## 下一步

可以删除以下不再需要的文件：
- `lib/mpv_player.dart`
- `lib/mpv_player_page.dart`
- `lib/enhanced_player.dart`
- `copy_native_libs.sh`

以及 Rust FFI 相关代码（如果不需要其他功能）。

## 参考资料

- [media_kit 官方文档](https://pub.dev/packages/media_kit)
- [media_kit GitHub](https://github.com/media-kit/media-kit)
- [MPV 文档](https://mpv.io/manual/stable/)
