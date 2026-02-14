# 应用图标

## 当前状态
使用 Flutter 默认图标（蓝色 Flutter logo）

## 自定义图标
我们设计了一个由两个三角形组成的 "B" 形状 logo（参见 `lib/widgets/animated_logo.dart`）

## 生成自定义图标

### 方法 1：使用在线工具
1. 访问 https://www.canva.com 或 https://www.figma.com
2. 创建 512x512 的画布
3. 绘制我们的 logo 设计：
   - 背景色：#1A1A2E
   - 左三角形：#9D4EDD（描边 #C77DFF）
   - 右三角形：#7B2CBF（描边 #9D4EDD）
4. 导出为 PNG，保存为 `assets/icon.png`

### 方法 2：使用 flutter_launcher_icons
```bash
cd ui/flutter_app
# 1. 准备好 assets/icon.png (512x512)
# 2. 运行生成命令
flutter pub get
flutter pub run flutter_launcher_icons
```

这会自动生成所有尺寸的 Android 和 iOS 图标。

## Logo 设计规范
- 尺寸：512x512 px
- 格式：PNG，透明背景或深色背景
- 设计：两个三角形连接形成 "B" 字母
- 配色：紫色系（#9D4EDD, #7B2CBF, #C77DFF）
