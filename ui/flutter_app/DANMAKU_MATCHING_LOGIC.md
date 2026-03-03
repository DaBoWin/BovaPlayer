# 弹幕匹配逻辑说明

## 当前实现

### 匹配流程
1. **播放器启动时**：调用 `_loadDanmaku()` 方法
2. **传递视频标题**：使用 `widget.title`（从 Emby 获取的视频标题）
3. **调用匹配 API**：`GET /api/v2/match?fileName={视频标题}`
4. **选择第一个结果**：如果返回多个匹配，使用 `matches.first`
5. **获取弹幕**：使用匹配到的 `episodeId` 获取弹幕列表

### 代码位置
- **匹配调用**：`lib/features/danmaku/controllers/danmaku_controller.dart` 第 118-145 行
- **API 实现**：`lib/features/danmaku/services/danmaku_api_service.dart` 第 38-82 行
- **播放器集成**：`lib/mdk_player_page.dart` 第 332 行

### 当前参数
```dart
// 只传递文件名
final matches = await _apiService.searchMatch(fileName: fileName);

// API 调用
GET /api/v2/match?fileName=视频标题
```

## 匹配准确性问题

### 可能的问题
1. **文件名不标准**：Emby 的标题可能与弹幕库中的标题不完全一致
2. **多季多集混淆**：电视剧的不同季、不同集可能匹配错误
3. **同名作品**：不同年份的同名电影/电视剧可能匹配错误
4. **翻译差异**：中文名、英文名、日文名可能导致匹配失败

### 示例
```
Emby 标题: "子夜归 S01E01"
弹幕库标题: "子夜归 第1季 第1集"
结果: 可能匹配失败
```

## 改进方案

### 方案 1：增强匹配参数（推荐）
```dart
// 传递更多信息
final matches = await _apiService.searchMatch(
  fileName: fileName,
  fileHash: fileHash,        // 文件 MD5/SHA1
  fileSize: fileSize,        // 文件大小（字节）
  videoDuration: duration,   // 视频时长（秒）
);
```

**优点**：
- 匹配更精确
- 减少误匹配
- 支持文件哈希匹配（最准确）

**缺点**：
- 需要计算文件哈希（耗时）
- 需要获取文件大小和时长

### 方案 2：智能文件名清理
```dart
String cleanFileName(String fileName) {
  // 移除季集信息
  fileName = fileName.replaceAll(RegExp(r'S\d+E\d+'), '');
  // 移除年份
  fileName = fileName.replaceAll(RegExp(r'\(\d{4}\)'), '');
  // 移除分辨率
  fileName = fileName.replaceAll(RegExp(r'\d{3,4}p'), '');
  // 移除编码信息
  fileName = fileName.replaceAll(RegExp(r'(HEVC|H\.264|x264|x265)'), '');
  return fileName.trim();
}
```

**优点**：
- 简单快速
- 不需要额外信息
- 提高匹配成功率

**缺点**：
- 可能过度清理
- 仍然可能有同名作品问题

### 方案 3：多候选匹配 + 用户选择
```dart
// 返回所有匹配结果
final matches = await _apiService.searchMatch(fileName: fileName);

if (matches.length > 1) {
  // 显示对话框让用户选择
  final selectedMatch = await showMatchDialog(matches);
  episodeId = selectedMatch['episodeId'];
} else {
  episodeId = matches.first['episodeId'];
}
```

**优点**：
- 用户可以手动选择正确的匹配
- 适合处理歧义情况
- 提高准确性

**缺点**：
- 需要用户交互
- 体验不够流畅

### 方案 4：使用搜索 API（备用方案）
```dart
// 如果 match API 失败，尝试搜索 API
if (matches.isEmpty) {
  final searchResults = await _apiService.searchAnime(fileName);
  if (searchResults.isNotEmpty) {
    // 显示搜索结果让用户选择
  }
}
```

**优点**：
- 提供备用匹配方式
- 用户可以手动搜索
- 覆盖更多场景

**缺点**：
- 需要用户交互
- 增加复杂度

## 推荐实施顺序

### 第一阶段：快速改进（当前可做）
1. ✅ 添加详细的匹配日志（已完成）
2. 🔄 智能文件名清理
3. 🔄 显示匹配结果信息（标题、集数等）

### 第二阶段：增强匹配（需要更多信息）
1. 获取视频时长（从播放器）
2. 传递时长参数到匹配 API
3. 支持多候选匹配

### 第三阶段：完整方案（可选）
1. 计算文件哈希（后台任务）
2. 缓存匹配结果
3. 手动搜索功能
4. 匹配历史记录

## 当前日志输出

```
========================================
[弹幕] 开始匹配: 子夜归 S01E01
========================================
[弹幕] ✅ 匹配成功: 子夜归
[弹幕] 剧集ID: 12345
[弹幕] ✅ 加载成功: 1234 条弹幕
[弹幕] 弹幕开关: 开启
========================================
```

## 调试建议

如果弹幕没有显示，检查日志：
1. **未找到匹配**：文件名可能不标准，需要清理或手动搜索
2. **匹配成功但无弹幕**：该视频可能真的没有弹幕
3. **匹配成功有弹幕但不显示**：检查弹幕开关、渲染逻辑

## API 文档参考

根据你提供的 API 项目（https://github.com/huangxd-/danmu_api），支持的匹配参数：
- `fileName`: 文件名（必需）
- `fileHash`: 文件哈希（可选，最精确）
- `fileSize`: 文件大小（可选）
- `matchMode`: 匹配模式（可选，如 'hashAndFileName'）

当前我们只使用了 `fileName`，这是最基础的匹配方式。
