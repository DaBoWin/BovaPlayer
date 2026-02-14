# BovaPlayer UI 设计指南

## 配色方案

参考提供的设计图，采用温暖、优雅的配色：

### 主色调
- **主色**: `#D4A574` (暖金色)
- **次色**: `#C8956E` (棕褐色)
- **强调色**: `#A67C52` (深棕色)

### 辅助色
- **浅色背景**: `#F5EFE7` (米白色)
- **卡片背景**: `#E8C9A0` (浅金色)
- **深色背景**: `#2C2416` (深棕黑)
- **文字主色**: `#FFFFFF` (白色)
- **文字次色**: `#E8C9A0` (浅金色)

### 渐变色
```dart
// 主渐变
LinearGradient(
  colors: [Color(0xFFD4A574), Color(0xFFC8956E), Color(0xFFA67C52)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
)

// 卡片渐变
LinearGradient(
  colors: [Color(0xFFE8C9A0), Color(0xFFD4A574)],
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
)
```

## 卡片设计

### 圆角
- **大卡片**: 24.0
- **中卡片**: 16.0
- **小卡片**: 12.0
- **按钮**: 20.0

### 阴影
```dart
BoxShadow(
  color: Colors.black.withOpacity(0.1),
  blurRadius: 20,
  offset: Offset(0, 10),
)
```

### 卡片内边距
- **大**: 24.0
- **中**: 16.0
- **小**: 12.0

## 图标风格

- 使用圆角图标
- 图标颜色使用主色调或白色
- 图标大小: 24-32

## 字体

### 标题
- **大标题**: 32, FontWeight.bold
- **中标题**: 24, FontWeight.w600
- **小标题**: 18, FontWeight.w500

### 正文
- **正文**: 14, FontWeight.normal
- **说明**: 12, FontWeight.w400

## Logo 设计

Logo 采用动态渐变金色播放按钮设计，支持动画效果：

### 特点
- **渐变色**: 金色 (#FFD700) → 橙色 (#FFA500) → 深橙色 (#FF8C00)
- **动态效果**: 流体形状旋转、光点闪烁
- **层次**: 光晕背景 + 流体装饰 + 白色圆形 + 播放三角形
- **装饰**: 四角动态光点

### 使用方法

#### 1. SVG 静态图标
```dart
// 在 pubspec.yaml 中添加
flutter:
  assets:
    - assets/logo.svg

// 使用
import 'package:flutter_svg/flutter_svg.dart';

SvgPicture.asset(
  'assets/logo.svg',
  width: 120,
  height: 120,
)
```

#### 2. Flutter 动态 Widget
```dart
import 'package:bova_player_flutter/widgets/animated_logo.dart';

// 动画版本
AnimatedLogo(
  size: 120,
  animate: true,
)

// 静态版本
StaticLogo(
  size: 120,
)

// 自定义颜色
AnimatedLogo(
  size: 120,
  colors: [
    Color(0xFFD4A574), // 自定义金色
    Color(0xFFC8956E), // 自定义棕色
    Color(0xFFA67C52), // 自定义深棕色
  ],
)
```

#### 3. 不同场景使用
```dart
// 启动页 - 大尺寸动画
AnimatedLogo(size: 200, animate: true)

// 导航栏 - 小尺寸静态
StaticLogo(size: 32)

// 关于页面 - 中尺寸动画
AnimatedLogo(size: 120, animate: true)
```

## 应用图标生成

使用 `logo.svg` 生成各平台图标：

### iOS
```bash
# 使用 flutter_launcher_icons 包
flutter pub add dev:flutter_launcher_icons
```

### Android
- 1024x1024 (Google Play)
- 512x512 (xxxhdpi)
- 192x192 (xxhdpi)
- 144x144 (xhdpi)
- 96x96 (hdpi)
- 72x72 (mdpi)

### macOS
- 1024x1024 (AppIcon)
- 512x512
- 256x256
- 128x128
- 64x64
- 32x32
- 16x16

### Windows
- 256x256 (ico)

## 动画效果

- **卡片点击**: 缩放 0.95, 持续 150ms
- **页面切换**: 淡入淡出, 持续 300ms
- **加载动画**: 使用主色调的圆形进度指示器
