# BovaPlayer 移动端适配指南

## 设计原则

基于 #adapt-skill 的指导，移动端适配不是简单的缩放，而是重新思考体验。

---

## 核心适配策略

### 1. 布局适配

#### 桌面端 → 移动端
```
桌面端：多列布局
移动端：单列布局

桌面端：侧边导航
移动端：底部导航栏

桌面端：悬浮卡片
移动端：全宽卡片（减少边距）

桌面端：固定宽度容器
移动端：流式布局
```

#### 响应式网格
```dart
// 媒体卡片网格
GridView.builder(
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: DesignSystem.isMobile(context) ? 2 : 
                    DesignSystem.isTablet(context) ? 3 : 4,
    childAspectRatio: 0.7,
    crossAxisSpacing: DesignSystem.space3,
    mainAxisSpacing: DesignSystem.space3,
  ),
)
```

### 2. 触摸交互

#### 触摸目标尺寸
```dart
// 最小触摸目标
const minTouchTarget = 44.0; // iOS 标准
const comfortableTouchTarget = 48.0; // Material 标准

// 按钮
BovaButton(
  size: BovaButtonSize.large, // 52px 高度
)

// 图标按钮
IconButton(
  iconSize: 24,
  padding: EdgeInsets.all(12), // 总尺寸 48x48
)
```

#### 触摸区域间距
```dart
// 移动端增加间距
final spacing = DesignSystem.isMobile(context) 
    ? DesignSystem.space4 
    : DesignSystem.space3;
```

#### 手势支持
```dart
// 滑动返回
GestureDetector(
  onHorizontalDragEnd: (details) {
    if (details.primaryVelocity! > 0) {
      Navigator.pop(context);
    }
  },
)

// 长按菜单
GestureDetector(
  onLongPress: () {
    _showContextMenu();
  },
)

// 双击缩放
GestureDetector(
  onDoubleTap: () {
    _toggleZoom();
  },
)
```

### 3. 导航适配

#### 底部导航栏（移动端）
```dart
// 带毛玻璃效果的底部导航
ClipRRect(
  child: BackdropFilter(
    filter: ImageFilter.blur(
      sigmaX: DesignSystem.blurMedium,
      sigmaY: DesignSystem.blurMedium,
    ),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        border: Border(
          top: BorderSide(
            color: DesignSystem.neutral200,
            width: 1,
          ),
        ),
      ),
      child: BottomNavigationBar(
        // ...
      ),
    ),
  ),
)
```

#### 侧边抽屉（桌面端）
```dart
// 桌面端使用持久侧边栏
if (DesignSystem.isDesktop(context))
  NavigationRail(
    // ...
  )
else
  Drawer(
    // ...
  )
```

### 4. 内容适配

#### 文字大小
```dart
// 移动端不小于 14px
final fontSize = DesignSystem.isMobile(context)
    ? DesignSystem.textSm  // 14px
    : DesignSystem.textXs; // 12px
```

#### 渐进式披露
```dart
// 移动端：折叠详情
ExpansionTile(
  title: Text('详细信息'),
  children: [
    // 详细内容
  ],
)

// 桌面端：直接显示
if (DesignSystem.isDesktop(context))
  Column(
    children: [
      // 详细内容
    ],
  )
```

#### 图片优化
```dart
// 响应式图片
Image.network(
  imageUrl,
  width: DesignSystem.isMobile(context) ? 150 : 200,
  height: DesignSystem.isMobile(context) ? 225 : 300,
  fit: BoxFit.cover,
)
```

### 5. 播放器适配

#### 横屏模式
```dart
// 自动旋转到横屏
SystemChrome.setPreferredOrientations([
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
]);

// 全屏播放
SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
```

#### 控制栏位置
```dart
// 移动端：底部控制栏
Positioned(
  bottom: 0,
  left: 0,
  right: 0,
  child: PlayerControls(),
)

// 桌面端：悬浮控制栏
Positioned(
  bottom: 20,
  left: 20,
  right: 20,
  child: PlayerControls(),
)
```

#### 手势控制
```dart
// 左右滑动：快进/快退
// 上下滑动（左侧）：亮度
// 上下滑动（右侧）：音量
// 双击：播放/暂停
// 长按：倍速播放
```

---

## 页面适配清单

### 1. 登录/注册页面

#### 移动端
- [x] 单列表单布局
- [x] 大号按钮（52px）
- [x] 简化输入框
- [x] 底部链接居中
- [x] 键盘弹出时自动滚动

#### 平板
- [x] 居中卡片（最大宽度 440px）
- [x] 增加边距
- [x] 保持桌面端样式

### 2. 媒体库页面

#### 移动端
- [ ] 2列网格布局
- [ ] 全宽搜索栏
- [ ] 底部导航栏
- [ ] 下拉刷新
- [ ] 无限滚动加载

#### 平板
- [ ] 3列网格布局
- [ ] 侧边筛选面板
- [ ] 保持底部导航

#### 桌面端
- [ ] 4-6列网格布局
- [ ] 持久侧边栏
- [ ] 悬浮卡片效果

### 3. 播放器页面

#### 移动端
- [ ] 自动横屏
- [ ] 全屏沉浸式
- [ ] 手势控制
- [ ] 底部控制栏
- [ ] 弹幕适配（字体大小）

#### 平板
- [ ] 支持画中画
- [ ] 分屏模式
- [ ] 侧边信息面板

#### 桌面端
- [ ] 悬浮控制栏
- [ ] 键盘快捷键
- [ ] 鼠标悬停显示控制

### 4. 账户页面

#### 移动端
- [ ] 单列列表
- [ ] 大号头像
- [ ] 全宽按钮
- [ ] 分组设置项

#### 平板/桌面端
- [ ] 两列布局
- [ ] 左侧导航
- [ ] 右侧内容

---

## 断点系统

```dart
// 移动端
< 768px
- 单列布局
- 底部导航
- 全宽卡片
- 大触摸目标

// 平板
768px - 1024px
- 2-3列布局
- 底部导航或侧边栏
- 混合交互（触摸+鼠标）

// 桌面端
>= 1024px
- 多列布局
- 持久侧边栏
- 悬浮效果
- 鼠标优化
```

---

## 性能优化

### 1. 图片加载
```dart
// 使用缓存
CachedNetworkImage(
  imageUrl: url,
  placeholder: (context, url) => Shimmer(...),
  errorWidget: (context, url, error) => Icon(Icons.error),
)

// 懒加载
ListView.builder(
  itemBuilder: (context, index) {
    return LazyLoadImage(url: items[index].imageUrl);
  },
)
```

### 2. 列表优化
```dart
// 使用 ListView.builder 而不是 ListView
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    return ItemWidget(item: items[index]);
  },
)

// 虚拟滚动
ListView.builder(
  cacheExtent: 500, // 预加载范围
)
```

### 3. 动画优化
```dart
// 只动画 transform 和 opacity
AnimatedContainer(
  duration: DesignSystem.durationNormal,
  curve: DesignSystem.easeOutQuart,
  transform: Matrix4.translationValues(0, offset, 0),
  opacity: opacity,
)

// 避免动画 width、height、padding
```

---

## 测试清单

### 设备测试
- [ ] iPhone SE (小屏)
- [ ] iPhone 14 Pro (标准)
- [ ] iPhone 14 Pro Max (大屏)
- [ ] iPad (平板)
- [ ] Android 手机（不同尺寸）
- [ ] Android 平板

### 方向测试
- [ ] 竖屏模式
- [ ] 横屏模式
- [ ] 自动旋转

### 交互测试
- [ ] 触摸操作
- [ ] 手势操作
- [ ] 键盘输入
- [ ] 滚动性能

### 网络测试
- [ ] WiFi
- [ ] 4G
- [ ] 3G（慢速）
- [ ] 离线模式

---

## 实施步骤

### 第一阶段：基础适配（1-2天）
1. 更新设计系统（已完成）
2. 创建响应式组件库（已完成）
3. 实现断点判断逻辑（已完成）

### 第二阶段：页面重构（3-5天）
1. 重构登录/注册页面
2. 重构媒体库页面
3. 重构播放器页面
4. 重构账户页面

### 第三阶段：交互优化（2-3天）
1. 添加手势支持
2. 优化触摸反馈
3. 实现底部导航栏
4. 添加页面切换动画

### 第四阶段：测试和优化（2-3天）
1. 真机测试
2. 性能优化
3. 修复 bug
4. 细节打磨

---

## 常见问题

### Q: 如何处理键盘遮挡输入框？
```dart
Scaffold(
  resizeToAvoidBottomInset: true, // 自动调整
  body: SingleChildScrollView(
    // 可滚动内容
  ),
)
```

### Q: 如何实现安全区域适配？
```dart
SafeArea(
  child: YourWidget(),
)

// 或者手动处理
Padding(
  padding: EdgeInsets.only(
    top: MediaQuery.of(context).padding.top,
    bottom: MediaQuery.of(context).padding.bottom,
  ),
)
```

### Q: 如何优化大列表性能？
```dart
// 使用 ListView.builder
// 使用 const 构造函数
// 避免在 build 中创建新对象
// 使用 RepaintBoundary 隔离重绘
```

### Q: 如何处理不同屏幕密度？
```dart
// Flutter 自动处理 DPI
// 使用逻辑像素（dp）而不是物理像素
// 提供 2x、3x 图片资源
```

---

## 参考资源

- [Flutter 响应式设计](https://docs.flutter.dev/development/ui/layout/responsive)
- [Material Design 移动端指南](https://m3.material.io/foundations/layout/applying-layout/window-size-classes)
- [iOS Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/ios)
- [Android Design Guidelines](https://developer.android.com/design)

---

**记住**：移动端适配的目标是让用户感觉这是专门为他们的设备设计的，而不是桌面端的缩小版。
