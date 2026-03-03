# Seek 优化说明

## 快进工作原理

### HTTP Range 请求机制
当你快进到某个时间点时，MDK 播放器会：

1. **计算目标字节位置**
   - 根据视频时长和文件大小，估算目标时间点对应的字节位置
   - 例如：视频 2 小时，文件 4GB，快进到 1 小时 ≈ 2GB 位置

2. **发送 HTTP Range 请求**
   - 请求头：`Range: bytes=2000000000-`
   - 服务器只返回从 2GB 开始的数据
   - 不需要下载前面的 2GB 数据

3. **快速开始播放**
   - MDK 收到数据后立即开始解码
   - 无需等待下载完整文件

### 必要条件

#### 1. URL 必须支持 Range 请求
✅ 已实现：`Static=false`
```dart
// emby_page.dart
if (playbackUrl.contains('Static=true')) {
  playbackUrl = playbackUrl.replaceAll('Static=true', 'Static=false');
}
```

#### 2. MDK 配置启用 seekable
✅ 已配置：
```dart
'avio.seekable': 1,  // 启用 seekable
'avformat.fflags': '+fastseek+discardcorrupt+nobuffer',  // 快速 seek
'avformat.seek2any': 1,  // 允许 seek 到任意位置
```

#### 3. 服务器支持 HTTP Range
Emby 服务器默认支持 HTTP Range 请求（当 `Static=false` 时）

## 当前实现

### 手势 Seek（左右滑动）
```dart
void _handleHorizontalDragEnd(DragEndDetails details) {
  // 计算目标位置
  final targetSeconds = _seekTargetPosition!.inSeconds;
  
  // 调用 seekTo - MDK 会自动使用 HTTP Range
  _controller!.seekTo(_seekTargetPosition!);
}
```

### 进度条 Seek（拖动进度条）
```dart
onHorizontalDragEnd: (details) {
  // 计算目标位置
  final targetPosition = Duration(milliseconds: _dragPosition.toInt());
  
  // 调用 seekTo - MDK 会自动使用 HTTP Range
  _controller?.seekTo(targetPosition);
}
```

### 继续播放（StartTimeTicks）
```dart
// URL 包含 StartTimeTicks，服务器直接从该位置开始发送数据
if (widget.url.contains('StartTimeTicks=')) {
  await _controller!.play();  // 直接播放，无需 seek
}
```

## 为什么 Seek 可能慢

### 1. 网络延迟
- HTTP Range 请求需要往返时间
- 服务器处理 Range 请求需要时间
- 解决方案：无法避免，但已经是最优方案

### 2. 关键帧问题
- 视频只能从关键帧（I-frame）开始解码
- 如果目标位置不是关键帧，需要找到前一个关键帧
- 解决方案：`+fastseek` 标志已启用

### 3. 缓冲策略
- MDK 可能会预缓冲一些数据
- 解决方案：已设置 `nobuffer` 和低延迟模式

### 4. 视频编码
- HEVC/H.265 比 H.264 seek 慢（关键帧间隔更大）
- 高码率视频需要下载更多数据
- 解决方案：无法避免，这是视频本身的特性

## 测试 Seek 性能

### 查看日志
```
[MdkPlayer] 执行 seek: 从 100 秒 -> 1000 秒 (距离: 900 秒)
[MdkPlayer] URL 包含 Static=false: true
[MdkPlayer] MDK 应该使用 HTTP Range 请求快速跳转
```

### 预期行为
- **短距离 seek（< 30秒）**：应该 < 1 秒
- **中距离 seek（30-300秒）**：应该 1-3 秒
- **长距离 seek（> 300秒）**：可能 3-5 秒

### 如果仍然很慢

#### 检查网络
```bash
# 测试到 Emby 服务器的延迟
ping your-emby-server.com

# 测试 HTTP Range 支持
curl -I -H "Range: bytes=0-1000" "your-video-url"
# 应该返回 206 Partial Content
```

#### 检查 Emby 服务器
1. 确认 URL 包含 `Static=false`
2. 查看 Emby 服务器日志，确认它在处理 Range 请求
3. 检查服务器 CPU/磁盘性能

#### 进一步优化
如果需要更激进的设置：
```dart
// 减少缓冲
'buffer': '5000+200000',  // 5MB-200MB

// 更激进的 seek
'avformat.analyzeduration': 100000,  // 0.1秒
'avformat.probesize': 500000,  // 500KB
```

## 与 StartTimeTicks 的区别

### StartTimeTicks（继续播放）
- 在 URL 中指定起始位置
- 服务器从该位置开始发送数据
- 播放器直接播放，无需 seek
- **最快**：无需额外的 HTTP 请求

### Seek（快进）
- 播放器已经在播放
- 需要发送新的 HTTP Range 请求
- 需要等待服务器响应
- **稍慢**：需要额外的网络往返

## 总结

你的配置已经是最优的：
- ✅ `Static=false` 启用 HTTP Range
- ✅ MDK 配置支持快速 seek
- ✅ 低延迟模式减少缓冲

Seek 操作会自动使用 HTTP Range 请求，不会下载中间的数据。如果仍然感觉慢，主要是网络延迟和视频编码特性导致的，这是无法完全避免的。

重启应用后测试，查看日志确认 `Static=false` 生效。
