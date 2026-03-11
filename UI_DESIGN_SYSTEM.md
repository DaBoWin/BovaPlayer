# BovaPlayer UI 设计系统

## 设计理念

**精致极简主义 + 流体动效**

### 核心原则
1. **温暖的中性色调** - 摆脱冷色调 AI 美学，使用温暖的石墨色和琥珀色
2. **精致的微交互** - 每个交互都有流畅的动效反馈
3. **内容优先** - UI 退居幕后，让内容成为焦点
4. **统一的视觉语言** - 所有页面保持一致的设计风格

---

## 颜色系统

### 主色调 - 温暖的石墨色
```dart
neutral900: #1C1917  // 主文字
neutral800: #292524
neutral700: #44403C
neutral600: #57534E
neutral500: #78716C
neutral400: #A8A29E
neutral300: #D6D3D1
neutral200: #E7E5E4
neutral100: #F5F5F4
neutral50:  #FAFAF9
```

### 强调色 - 温暖的琥珀色
```dart
accent600: #D97706  // 主要强调色
accent500: #F59E0B
accent400: #FBBF24
```

### 功能色
```dart
success: #059669  // 翡翠绿
warning: #EA580C  // 橙色
error:   #DC2626  // 红色
info:    #0891B2  // 青色
```

### Pro/Lifetime 用户
```dart
Pro:      紫罗兰渐变 (#7C3AED → #A855F7)
Lifetime: 金色渐变 (#EA580C → #F59E0B)
```

---

## 排版系统

### 字体大小
```dart
text3xl:  30px  // 页面标题
text2xl:  24px  // 区块标题
textXl:   20px  // 卡片标题
textLg:   18px  // 副标题
textBase: 16px  // 正文
textSm:   14px  // 辅助文字
textXs:   12px  // 标签
```

### 字重
```dart
Light:     300
Regular:   400
Medium:    500
Semibold:  600
Bold:      700
```

### 行高
```dart
Tight:    1.25  // 标题
Normal:   1.5   // 正文
Relaxed:  1.75  // 长文本
```

---

## 间距系统

基于 4px 网格：
```dart
space1:  4px
space2:  8px
space3:  12px
space4:  16px
space5:  20px
space6:  24px
space8:  32px
space10: 40px
space12: 48px
space16: 64px
space20: 80px
```

---

## 圆角系统

```dart
radiusXs:   4px   // 小元素
radiusSm:   8px   // 按钮、输入框
radiusMd:   12px  // 卡片
radiusLg:   16px  // 大卡片
radiusXl:   20px  // 模态框
radius2xl:  24px  // 抽屉
radiusFull: 9999px // 圆形
```

---

## 阴影系统

```dart
shadowSm:  微妙的阴影（卡片）
shadowMd:  中等阴影（悬浮卡片）
shadowLg:  大阴影（模态框）
shadowXl:  超大阴影（抽屉）
```

---

## 动画系统

### 时长
```dart
durationFast:   150ms  // 快速反馈
durationNormal: 250ms  // 标准动画
durationSlow:   350ms  // 复杂动画
```

### 缓动曲线
```dart
easeOutQuart: 自然减速（推荐）
easeOutQuint: 更强的减速
easeOutExpo:  指数减速
```

**禁止使用**：bounce、elastic（感觉过时）

---

## 组件库

### 1. BovaButton - 按钮

```dart
// 主要按钮
BovaButton(
  text: '登录',
  onPressed: () {},
  style: BovaButtonStyle.primary,
  size: BovaButtonSize.medium,
)

// 次要按钮
BovaButton(
  text: '取消',
  onPressed: () {},
  style: BovaButtonStyle.secondary,
)

// 幽灵按钮
BovaButton(
  text: '了解更多',
  onPressed: () {},
  style: BovaButtonStyle.ghost,
)

// 带图标
BovaButton(
  text: '添加',
  icon: Icons.add,
  onPressed: () {},
)

// 加载状态
BovaButton(
  text: '提交中',
  isLoading: true,
  onPressed: null,
)
```

### 2. BovaCard - 卡片

```dart
// 基础卡片
BovaCard(
  child: Text('内容'),
  onTap: () {},
)

// 媒体卡片
BovaMediaCard(
  imageUrl: 'https://...',
  title: '电影标题',
  subtitle: '2024 · 动作',
  onTap: () {},
  badge: Container(...), // 可选徽章
)
```

### 3. BovaTextField - 输入框

```dart
// 基础输入框
BovaTextField(
  label: '邮箱',
  hint: '请输入邮箱地址',
  prefixIcon: Icons.email,
  controller: _emailController,
)

// 密码输入框
BovaTextField(
  label: '密码',
  hint: '请输入密码',
  prefixIcon: Icons.lock,
  obscureText: true,
  suffixIcon: IconButton(...),
)

// 搜索框
BovaSearchField(
  hint: '搜索电影、剧集...',
  onChanged: (value) {},
)
```

---

## 响应式设计

### 断点
```dart
Mobile:  < 768px
Tablet:  768px - 1024px
Desktop: >= 1024px
```

### 使用方法
```dart
if (DesignSystem.isMobile(context)) {
  // 移动端布局
} else if (DesignSystem.isTablet(context)) {
  // 平板布局
} else {
  // 桌面端布局
}
```

### 移动端适配要点
1. **触摸目标**：最小 44x44px
2. **字体大小**：不小于 14px
3. **间距**：增加触摸区域间距
4. **导航**：底部导航栏（带毛玻璃效果）
5. **手势**：支持滑动、长按等手势

---

## 页面布局模式

### 1. 媒体库页面
```
┌─────────────────────────────┐
│  AppBar (52px)              │
├─────────────────────────────┤
│  搜索栏 + 筛选              │
├─────────────────────────────┤
│                             │
│  媒体卡片网格               │
│  (响应式列数)               │
│                             │
└─────────────────────────────┘
```

### 2. 播放器页面
```
┌─────────────────────────────┐
│                             │
│  视频播放区域               │
│  (16:9 或全屏)              │
│                             │
├─────────────────────────────┤
│  标题 + 信息                │
├─────────────────────────────┤
│  播放控制栏                 │
└─────────────────────────────┘
```

### 3. 认证页面
```
┌─────────────────────────────┐
│                             │
│      Logo + 标题            │
│                             │
│      表单区域               │
│      (居中，最大宽度400px)  │
│                             │
│      操作按钮               │
│                             │
└─────────────────────────────┘
```

---

## 动效指南

### 1. 按钮点击
- 按下：缩放到 0.96
- 释放：恢复到 1.0
- 时长：150ms
- 缓动：easeOutQuart

### 2. 卡片悬停
- 悬停：缩放到 1.02，增加阴影
- 离开：恢复原状
- 时长：250ms
- 缓动：easeOutQuart

### 3. 页面切换
- 淡入淡出 + 轻微位移
- 时长：350ms
- 缓动：easeOutQuint

### 4. 列表项动画
- 交错进入（stagger）
- 每项延迟 50ms
- 时长：250ms

---

## 可访问性

### 1. 颜色对比度
- 所有文字符合 WCAG AA 标准
- 主文字：4.5:1
- 大文字：3:1

### 2. 触摸目标
- 最小尺寸：44x44px（iOS）
- 推荐尺寸：48x48px（Material）

### 3. 键盘导航
- 所有交互元素可通过 Tab 访问
- 清晰的焦点指示器
- 支持快捷键

### 4. 屏幕阅读器
- 所有图片有 alt 文本
- 按钮有语义化标签
- 表单有清晰的标签

---

## 禁止使用的 AI 美学

### ❌ 不要使用
1. **深色主题 + 紫蓝渐变** - AI 的标志性配色
2. **玻璃态（Glassmorphism）** - 过度使用的模糊效果
3. **霓虹发光边框** - 看起来廉价
4. **纯黑 (#000) 或纯白 (#fff)** - 不自然
5. **灰色文字在彩色背景上** - 看起来褪色
6. **渐变文字** - 装饰性大于功能性
7. **所有内容都用卡片包裹** - 视觉噪音
8. **卡片嵌套卡片** - 层级混乱
9. **Bounce/Elastic 动画** - 感觉过时

### ✅ 应该使用
1. **温暖的中性色调** - 石墨色 + 琥珀色
2. **微妙的阴影** - 精致而不夸张
3. **流体动效** - 自然的减速曲线
4. **内容优先** - UI 退居幕后
5. **一致的视觉语言** - 统一的设计系统
6. **精心设计的留白** - 呼吸感
7. **清晰的层级** - 视觉引导
8. **有意义的动效** - 服务于交互

---

## 实施步骤

### 第一阶段：基础设施
- [x] 创建设计系统文件
- [x] 创建主题配置
- [x] 创建核心组件库

### 第二阶段：页面重构
- [ ] 更新登录/注册页面
- [ ] 更新媒体库页面
- [ ] 更新播放器页面
- [ ] 更新账户页面

### 第三阶段：细节优化
- [ ] 添加页面切换动画
- [ ] 优化加载状态
- [ ] 完善空状态设计
- [ ] 添加错误状态设计

### 第四阶段：移动端适配
- [ ] 优化触摸交互
- [ ] 调整移动端布局
- [ ] 添加手势支持
- [ ] 测试不同屏幕尺寸

---

## 使用示例

### 导入设计系统
```dart
import 'package:bova_player_flutter/core/theme/design_system.dart';
import 'package:bova_player_flutter/core/theme/app_theme.dart';
import 'package:bova_player_flutter/core/widgets/bova_button.dart';
import 'package:bova_player_flutter/core/widgets/bova_card.dart';
import 'package:bova_player_flutter/core/widgets/bova_text_field.dart';
```

### 应用主题
```dart
MaterialApp(
  theme: AppTheme.lightTheme,
  darkTheme: AppTheme.darkTheme,
  // ...
)
```

### 使用颜色
```dart
Container(
  color: DesignSystem.neutral50,
  child: Text(
    'Hello',
    style: TextStyle(
      color: DesignSystem.neutral900,
      fontSize: DesignSystem.textBase,
    ),
  ),
)
```

---

## 参考资源

- [Material Design 3](https://m3.material.io/)
- [iOS Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [Tailwind CSS Colors](https://tailwindcss.com/docs/customizing-colors)
- [Radix UI Colors](https://www.radix-ui.com/colors)

---

## 维护指南

1. **添加新颜色**：必须在 `design_system.dart` 中定义
2. **添加新组件**：遵循现有组件的命名和结构
3. **修改动画**：使用设计系统中定义的时长和缓动
4. **测试响应式**：在所有断点测试
5. **保持一致性**：新设计必须符合设计系统

---

**记住**：好的设计是隐形的。用户应该感受到流畅和精致，而不是被 UI 分散注意力。
