# 播放问题排查

## 当前问题：播放没有反应

错误信息：`[tcp @ 0x15d7db2d0] ffurl_read returned 0xffffffc4`

这表示网络连接问题。

## 已实施的修复

1. ✅ 添加 HTTP headers（X-Emby-Token）
2. ✅ 添加 mediaSourceId 参数到 stream URL
3. ✅ 添加详细的调试日志

## 如果问题仍然存在

### 方案 1：测试本地文件播放

先测试本地文件播放是否正常：
1. 点击底部导航栏的"本地播放"
2. 选择一个本地视频文件
3. 如果本地播放正常，说明 media_kit 工作正常，问题在于 Emby 流配置

### 方案 2：使用 HLS 流

Emby 支持 HLS 流，这通常更稳定：

```dart
String _streamUrl(String itemId) {
  final server = _activeServer!;
  // 使用 HLS 流
  return '${server.url}/Videos/$itemId/master.m3u8?api_key=${server.accessToken}';
}
```

### 方案 3：使用转码流

如果直接播放失败，可以使用转码流：

```dart
String _streamUrl(String itemId) {
  final server = _activeServer!;
  final userId = server.userId!;
  
  // 使用转码流
  return '${server.url}/Videos/$itemId/stream.mp4?'
      'Static=false&'
      'MediaSourceId=$itemId&'
      'DeviceId=bova-flutter&'
      'api_key=${server.accessToken}&'
      'VideoCodec=h264&'
      'AudioCodec=aac&'
      'MaxStreamingBitrate=140000000';
}
```

### 方案 4：检查 Emby 服务器设置

1. 登录 Emby 服务器管理界面
2. 检查"转码"设置
3. 确保允许外部播放器访问
4. 检查网络设置，确保没有 IP 限制

### 方案 5：使用 egui 版本的 URL

egui 版本可以播放，说明 URL 格式是正确的。确保 Flutter 版本使用完全相同的 URL：

```dart
String _streamUrl(String itemId) {
  final server = _activeServer!;
  // 与 egui 版本完全相同
  return '${server.url}/Videos/$itemId/stream?static=true&api_key=${server.accessToken}';
}
```

## 调试步骤

1. 点击播放时，查看控制台输出的完整 URL
2. 复制 URL 到浏览器测试是否可以下载
3. 如果浏览器可以下载，说明 URL 正确，问题在于 media_kit 配置
4. 如果浏览器也无法访问，说明 URL 或认证有问题

## 查看日志

运行应用时，会看到类似这样的日志：

```
[EmbyPage] 准备播放: 电影名称
[EmbyPage] Item ID: 123456
[EmbyPage] Stream URL: https://emby.example.com/Videos/123456/stream?...
[EmbyPage] HTTP Headers: {X-Emby-Token: xxx, User-Agent: BovaPlayer/1.0}
[MediaKitPlayer] 开始初始化播放器
[MediaKitPlayer] Stream URL: ...
[MediaKitPlayer] HTTP Headers: ...
```

请分享这些日志以便进一步诊断。
