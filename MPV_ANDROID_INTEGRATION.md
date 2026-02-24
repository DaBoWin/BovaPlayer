# MPV-Android 集成指南

## 概述

已完成 mpv-android 的集成，实现智能播放器选择策略。

## 新的播放器架构（Android）

```
播放器优先级：
1. ExoPlayer (BetterPlayer) - 简单格式（MP4/H.264/AAC）
   ✅ 省电、性能好
   ✅ 硬件解码
   ❌ 不支持 TrueHD、PGS 字幕

2. mpv-android - 复杂格式（MKV/HEVC/TrueHD/PGS）
   ✅ 完整的 FFmpeg 支持
   ✅ 支持所有音频格式（TrueHD、DTS-HD MA）
   ✅ 支持所有字幕格式（ASS、PGS、VOBSUB）
   ✅ 软件解码，兼容性极强

3. Media Kit (libmpv) - 最后备选
   ✅ 跨平台一致性
   ❌ Android 上功能不完整
```

## 已完成的工作

### 1. Flutter 层

- ✅ 创建 `mpv_android_player_page.dart`
  - 完整的播放器 UI
  - 播放控制（播放/暂停/跳转）
  - 进度显示
  - 通过 Platform Channel 与原生通信

- ✅ 更新 `unified_player_page.dart`
  - 智能格式检测
  - 自动选择最佳播放器

### 2. Android 原生层

- ✅ 创建 `MpvPlayerPlugin.kt`
  - Method Channel 实现
  - MPV 命令封装
  - Platform View 集成

- ✅ 创建 `MpvPlatformView.kt`
  - MPV 视图渲染
  - MPV 配置（硬件解码、音频、字幕）
  - 网络优化

- ✅ 更新 `MainActivity.kt`
  - 注册 MPV 插件

### 3. 构建配置

- ✅ 添加 mpv-android 依赖到 `build.gradle.kts`
- ✅ 添加 JitPack 仓库到 `build.gradle.kts`

## MPV 配置

已配置的 MPV 选项：

```kotlin
// 硬件解码
hwdec = mediacodec-copy

// 音频配置
audio-channels = stereo
audio-samplerate = 48000
audio-fallback-to-null = yes  // TrueHD 失败时不中断

// 字幕配置
sub-auto = fuzzy
sub-codepage = utf8

// 网络配置
cache = yes
cache-secs = 10
demuxer-max-bytes = 50M

// TLS 配置
tls-verify = no
```

## 使用方法

### 自动选择（推荐）

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => UnifiedPlayerPage(
      url: videoUrl,
      title: videoTitle,
      httpHeaders: headers,
      subtitles: subtitles,
    ),
  ),
);
```

### 手动指定 mpv-android

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => MpvAndroidPlayerPage(
      url: videoUrl,
      title: videoTitle,
      httpHeaders: headers,
      subtitles: subtitles,
    ),
  ),
);
```

## 下一步优化

### 1. 智能格式检测（高优先级）

当前的格式检测比较简单，建议从 Emby API 获取详细的媒体信息：

```dart
// 从 MediaSource 获取音频编码信息
bool _hasComplexAudio(Map<String, dynamic> mediaSource) {
  final streams = mediaSource['MediaStreams'] as List?;
  if (streams == null) return false;
  
  for (var stream in streams) {
    if (stream['Type'] == 'Audio') {
      final codec = stream['Codec']?.toString().toLowerCase() ?? '';
      // TrueHD, DTS-HD MA 等需要 mpv
      if (codec.contains('truehd') || 
          codec.contains('dts') || 
          codec.contains('eac3')) {
        return true;
      }
    }
    
    if (stream['Type'] == 'Subtitle') {
      final codec = stream['Codec']?.toString().toLowerCase() ?? '';
      // PGS, VOBSUB 等需要 mpv
      if (codec.contains('pgs') || 
          codec.contains('vobsub') || 
          codec.contains('dvdsub')) {
        return true;
      }
    }
  }
  
  return false;
}
```

### 2. 错误处理和回退

```dart
// 在 MpvAndroidPlayerPage 中添加错误回退
if (_hasError) {
  // 显示错误并提供切换到 Media Kit 的选项
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('MPV 播放失败'),
      content: Text('是否尝试使用备用播放器？'),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => MediaKitPlayerPage(...),
              ),
            );
          },
          child: Text('使用备用播放器'),
        ),
      ],
    ),
  );
}
```

### 3. 性能优化

- 添加播放器预加载
- 优化 Platform View 性能
- 添加硬件解码失败时的软件解码回退

### 4. 功能增强

- 添加字幕选择 UI
- 添加音轨选择 UI
- 添加播放速度控制
- 添加画面比例调整

## 测试建议

1. **简单格式测试**（应使用 ExoPlayer）
   - MP4 + H.264 + AAC
   - 验证省电和性能

2. **复杂格式测试**（应使用 mpv-android）
   - MKV + HEVC + TrueHD
   - MKV + H.264 + PGS 字幕
   - 验证所有格式都能播放

3. **错误处理测试**
   - 网络中断
   - 不支持的格式
   - 验证错误提示和回退

## 依赖信息

```gradle
// mpv-android (包含完整的 FFmpeg)
implementation("is.xyz.mpv:libmpv:latest.release")
```

## 注意事项

1. **APK 大小**：mpv-android 包含完整的 FFmpeg，会增加约 30-50MB 的 APK 大小
2. **权限**：需要网络权限和存储权限
3. **兼容性**：支持 Android 5.0+ (API 21+)
4. **性能**：软件解码会消耗更多 CPU，建议在真机上测试

## 故障排除

### 问题 1: MPV 初始化失败

```
解决方案：
1. 检查 mpv-android 依赖是否正确添加
2. 检查 JitPack 仓库是否配置
3. 清理并重新构建项目
```

### 问题 2: 视频不显示

```
解决方案：
1. 检查 Platform View 是否正确注册
2. 检查 MPV 配置是否正确
3. 查看 logcat 日志
```

### 问题 3: TrueHD 音频无声

```
解决方案：
1. 检查 audio-fallback-to-null 配置
2. 检查音频输出设备
3. 尝试降混音到立体声
```

## 参考资料

- [mpv-android GitHub](https://github.com/mpv-android/mpv-android)
- [MPV 手册](https://mpv.io/manual/stable/)
- [FFmpeg 文档](https://ffmpeg.org/documentation.html)
