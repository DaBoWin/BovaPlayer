# 播放优化总结

## 已完成的优化

### 1. StartTimeTicks 实现（核心优化）
- ✅ 在 `emby_page.dart` 中读取保存的播放位置
- ✅ 将位置转换为 Emby ticks 格式（1秒 = 10,000,000 ticks）
- ✅ 在所有播放 URL 中添加 `StartTimeTicks` 参数
- ✅ 将 `Static=true` 改为 `Static=false` 以启用 HTTP Range 请求
- ✅ 通过 `UnifiedPlayerPage` 传递参数到 `MdkPlayerPage`
- ✅ `MdkPlayerPage` 检测到 `StartTimeTicks` 时跳过 seek 对话框

### 2. MDK 低延迟配置
- ✅ 减少缓冲区：从 100MB-2GB 降至 10MB-500MB
- ✅ 启用低延迟模式：`lowLatency: 1`
- ✅ 添加 `nobuffer` 标志减少缓冲
- ✅ 减少分析时间：`analyzeduration` 从 2s 降至 0.5s
- ✅ 减少探测大小：`probesize` 从 10MB 降至 2MB
- ✅ 启用快速 seek：`+fastseek+discardcorrupt+nobuffer`

### 3. 异步加载优化
- ✅ 字幕加载改为异步，不阻塞播放启动
- ✅ 使用 `Future.microtask()` 延迟非关键任务

## 工作原理

### 继续播放流程
1. 用户点击"继续播放"
2. `emby_page.dart` 读取保存的播放位置（例如：1156秒）
3. 转换为 ticks：1156 × 10,000,000 = 11,560,000,000 ticks
4. 构建 URL：`https://server/Videos/itemId/stream?Static=false&StartTimeTicks=11,560,000,000&api_key=xxx`
5. Emby 服务器从该时间点开始发送数据（不需要下载前面的数据）
6. MDK 播放器检测到 URL 包含 `StartTimeTicks`，直接播放，不显示 seek 对话框

### HTTP Range 请求
- `Static=false` 允许客户端发送 HTTP Range 请求
- 快进时，播放器可以请求特定字节范围
- 服务器只发送请求的数据段，无需传输整个文件

## 测试步骤

### 重要：必须完全重启应用
由于 MDK 全局配置只在应用启动时初始化一次，必须：
1. 完全退出应用（不是热重载）
2. 重新运行 `flutter run`
3. 测试继续播放功能

### 测试场景
1. **继续播放测试**
   - 播放一个视频到中间位置（例如 19:16）
   - 退出播放器
   - 点击"继续播放"
   - 预期：视频应该立即从 19:16 开始播放，无需等待

2. **快进测试**
   - 播放视频
   - 拖动进度条到不同位置
   - 预期：快进应该快速响应，无需下载中间数据

3. **首次播放测试**
   - 播放一个新视频
   - 预期：应该快速启动，分析时间短

## 日志检查

查看以下关键日志：
```
[MdkPlayer] MDK 全局配置已初始化（低延迟模式）
[EmbyPage] 找到保存的播放位置: XXX秒 (XXX ticks)
[EmbyPage] 添加 StartTimeTicks 参数，从 XXX秒 开始播放
[EmbyPage] 已将 Static=true 改为 Static=false
[MdkPlayer] URL 包含 StartTimeTicks，服务器将从 XX:XX 开始发送数据
```

## 如果仍然慢

### 检查 Emby 服务器
1. 确认服务器支持 HTTP Range 请求
2. 检查服务器日志，确认它正在处理 `StartTimeTicks` 参数
3. 确认网络连接稳定

### 调整缓冲设置
如果需要更激进的低延迟设置，可以在 `mdk_player_page.dart` 中进一步减少：
```dart
'buffer': '5000+200000',  // 最小5MB，最大200MB
'avformat.analyzeduration': 100000,  // 0.1秒
'avformat.probesize': 500000,  // 500KB
```

### 显示加载指示器
如果 seek 仍需要时间，可以添加加载指示器让用户知道正在缓冲。

## 文件修改列表
- `ui/flutter_app/lib/emby_page.dart` - 添加 StartTimeTicks 支持
- `ui/flutter_app/lib/unified_player_page.dart` - 传递参数
- `ui/flutter_app/lib/mdk_player_page.dart` - 低延迟配置和 StartTimeTicks 检测

## 下一步
如果测试后仍有问题，请提供：
1. 完整的日志输出
2. 网络速度和服务器响应时间
3. 具体的慢在哪个环节（启动？seek？继续播放？）