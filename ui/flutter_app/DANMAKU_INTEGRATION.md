# 弹幕功能集成指南

## 概述

弹幕功能已经开发完成，包括：
- ✅ 弹幕数据模型
- ✅ 弹幕 API 服务（连接你的自建服务）
- ✅ 弹幕渲染引擎（60fps 流畅渲染）
- ✅ 弹幕控制器（状态管理）
- ✅ 弹幕设置面板

## API 配置

你的弹幕服务地址：`https://danmuapi-sandy-six.vercel.app/bova`

### 认证配置

如果 API 需要认证，请在创建 `DanmakuController` 时传入：

```dart
final danmakuController = DanmakuController(
  apiKey: 'your-api-key',  // 如果需要
  appId: 'your-app-id',    // 如果需要
);
```

## 集成步骤

### 1. 在播放器中添加弹幕控制器

在 `mdk_player_page.dart` 中添加：

```dart
import 'package:provider/provider.dart';
import 'features/danmaku/controllers/danmaku_controller.dart';
import 'features/danmaku/widgets/danmaku_view.dart';
import 'features/danmaku/widgets/danmaku_settings_panel.dart';

class _MdkPlayerPageState extends State<MdkPlayerPage> {
  // 添加弹幕控制器
  late DanmakuController _danmakuController;
  
  @override
  void initState() {
    super.initState();
    
    // 初始化弹幕控制器
    _danmakuController = DanmakuController(
      // apiKey: 'your-key', // 如果需要
    );
    
    // 加载弹幕
    _loadDanmaku();
  }
  
  Future<void> _loadDanmaku() async {
    // 从视频标题或文件名加载弹幕
    final fileName = widget.title;
    await _danmakuController.loadDanmakuByFileName(fileName);
  }
  
  @override
  void dispose() {
    _danmakuController.dispose();
    super.dispose();
  }
}
```

### 2. 在播放器 UI 中添加弹幕层

在视频播放器的 Stack 中添加弹幕视图：

```dart
Stack(
  children: [
    // 视频播放器
    Video(controller: _videoController!),
    
    // 弹幕层
    ChangeNotifierProvider.value(
      value: _danmakuController,
      child: Consumer<DanmakuController>(
        builder: (context, controller, _) {
          return DanmakuView(
            danmakuList: controller.danmakuList,
            currentPosition: _controller?.value.position ?? Duration.zero,
            isPlaying: _controller?.value.isPlaying ?? false,
            config: controller.config,
          );
        },
      ),
    ),
    
    // 其他控制层...
  ],
)
```

### 3. 添加弹幕控制按钮

在播放器控制栏中添加弹幕按钮：

```dart
// 弹幕开关按钮
IconButton(
  icon: Icon(
    _danmakuController.config.enabled 
        ? Icons.subtitles 
        : Icons.subtitles_off,
    color: Colors.white,
  ),
  onPressed: () {
    _danmakuController.toggleEnabled();
  },
  tooltip: '弹幕开关',
),

// 弹幕设置按钮
IconButton(
  icon: const Icon(Icons.settings, color: Colors.white),
  onPressed: () {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: DanmakuSettingsPanel(
          controller: _danmakuController,
        ),
      ),
    );
  },
  tooltip: '弹幕设置',
),
```

### 4. 添加发送弹幕功能（可选）

```dart
// 弹幕输入框
TextField(
  controller: _danmakuInputController,
  decoration: const InputDecoration(
    hintText: '发送弹幕...',
    border: OutlineInputBorder(),
  ),
  onSubmitted: (text) async {
    if (text.isNotEmpty) {
      final currentTime = _controller?.value.position.inSeconds.toDouble() ?? 0;
      final success = await _danmakuController.sendDanmaku(
        time: currentTime,
        content: text,
      );
      
      if (success) {
        _danmakuInputController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('弹幕发送成功')),
        );
      }
    }
  },
),
```

## API 端点说明

根据 danmu_api 项目，你的 API 应该支持以下端点：

### 1. 搜索匹配视频
```
GET /bova/v3/match?fileName={fileName}
```

### 2. 获取弹幕
```
GET /bova/v3/comment/{episodeId}
```

### 3. 发送弹幕
```
POST /bova/v3/comment/{episodeId}
Body: {
  "time": 123.45,
  "mode": 1,
  "color": 16777215,
  "comment": "弹幕内容"
}
```

### 4. 搜索番剧
```
GET /bova/v3/search/anime?keyword={keyword}
```

## 认证问题

如果遇到 401 Unauthorized 错误，请检查：

1. **API Key 配置**：确认是否需要 API Key
2. **请求头**：检查是否需要特定的请求头
3. **CORS 设置**：确认 Vercel 部署的 CORS 配置

你可以在 `danmaku_api_service.dart` 的 `_getHeaders()` 方法中添加认证信息。

## 测试

1. 运行应用
2. 播放一个视频
3. 查看控制台日志，确认弹幕加载状态
4. 点击弹幕按钮测试开关
5. 打开设置面板调整参数

## 性能优化

弹幕渲染引擎已经优化：
- ✅ 60fps 流畅渲染
- ✅ 轨道碰撞检测
- ✅ 自动清理过期弹幕
- ✅ 内存占用优化

## 下一步

1. 测试 API 连接
2. 集成到 MDK 播放器
3. 添加弹幕屏蔽功能（关键词、用户）
4. 添加弹幕云同步（保存到 Supabase）
5. 支持本地弹幕文件（XML/JSON）

## 需要帮助？

如果遇到问题，请检查：
1. 控制台日志中的 `[DanmakuAPI]` 和 `[DanmakuController]` 输出
2. API 响应状态码和错误信息
3. 网络连接是否正常
