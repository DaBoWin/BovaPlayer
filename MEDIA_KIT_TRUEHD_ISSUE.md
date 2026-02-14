# media_kit TrueHD 音频支持问题

## 问题描述

当前使用的 `media_kit_libs_macos_video 1.1.4` 不支持 TrueHD 音频编解码器。

播放包含 TrueHD 音轨的视频时会出现错误:
```
Failed to initialize a decoder for codec 'truehd'
```

## 原因分析

`media_kit_libs_macos_video` 使用的是 [libmpv-darwin-build](https://github.com/media-kit/libmpv-darwin-build) 项目打包的 MPV 库。

该项目提供三种 flavor:
- **default**: 基础解码器（当前 pub.dev 使用的版本）
- **full**: 更多解码器支持
- **encodersgpl**: 包含编码器（GPL 许可）

pub.dev 上发布的 `media_kit_libs_macos_video` 使用的是 **default** flavor，不包含 TrueHD 解码器。

## 依赖版本说明

```
media_kit_libs_video 1.0.7          # 元包（meta-package）
├── media_kit_libs_macos_video 1.1.4  # macOS 实现
├── media_kit_libs_ios_video 1.1.4    # iOS 实现
├── media_kit_libs_android_video 1.3.8 # Android 实现
├── media_kit_libs_linux 1.2.1        # Linux 实现
└── media_kit_libs_windows_video 1.0.11 # Windows 实现
```

`media_kit_libs_video` 是一个元包，它会根据平台自动引入对应的实现包。这是正常的依赖结构。

## 解决方案

### 方案 1: 使用 Emby 音频转码（推荐）

让 Emby 服务器转码音频，视频直通：

```dart
// 视频直通，音频转码为 AAC
final url = '$baseUrl/Videos/$itemId/stream.mp4?'
    'Static=false&'
    'MediaSourceId=$itemId&'
    'VideoCodec=copy&'        // 视频直通
    'AudioCodec=aac&'          // 音频转码为 AAC
    'AudioBitrate=320000&'     // 320kbps 高质量音频
    'api_key=${server.accessToken}';
```

优点:
- 保持视频质量（直通）
- 音频转码为通用格式（AAC）
- 兼容性好

缺点:
- 需要服务器转码，增加服务器负载
- 音频质量略有损失（但 320kbps AAC 已经很高）

### 方案 2: 选择其他音轨

如果视频有多个音轨，可以让用户选择非 TrueHD 的音轨：

```dart
// 获取媒体信息
final response = await http.get(
  Uri.parse('$baseUrl/emby/Items/$itemId?Fields=MediaStreams&api_key=$token'),
);

// 解析音轨列表
final audioStreams = mediaInfo['MediaStreams']
    .where((s) => s['Type'] == 'Audio')
    .toList();

// 显示音轨选择器，让用户选择非 TrueHD 音轨
// 然后使用 AudioStreamIndex 参数指定音轨
final url = '$baseUrl/Videos/$itemId/stream?'
    'static=true&'
    'AudioStreamIndex=$selectedIndex&'
    'api_key=$token';
```

### 方案 3: 自定义编译 MPV（高级）

从源码编译包含 TrueHD 支持的 MPV 库：

1. Clone [libmpv-darwin-build](https://github.com/media-kit/libmpv-darwin-build)
2. 修改配置以包含 TrueHD 解码器
3. 编译 **full** flavor
4. 替换 `media_kit_libs_macos_video` 中的库文件

这需要:
- Nix 包管理器
- Xcode
- 熟悉 Flutter 插件结构

### 方案 4: 使用系统 MPV（实验性）

安装系统级 MPV 并配置 media_kit 使用它：

```bash
brew install mpv
```

但 media_kit 默认使用打包的库，需要修改插件代码才能使用系统 MPV。

## 当前实现

当前代码使用**直接播放**（方案 1 的视频直通部分），遇到 TrueHD 会失败。

如需支持 TrueHD 视频，建议实现方案 1（音频转码）或方案 2（音轨选择）。

## 相关链接

- [media_kit GitHub](https://github.com/media-kit/media-kit)
- [libmpv-darwin-build](https://github.com/media-kit/libmpv-darwin-build)
- [media_kit_libs_macos_video on pub.dev](https://pub.dev/packages/media_kit_libs_macos_video)
- [MPV 支持的音频格式](https://mpv.io/manual/master/#audio)
