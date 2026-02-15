# 📱 BovaPlayer 图标更新指南

## 快速开始

### 1️⃣ 准备你的图标

创建一个 **512x512 像素** 的 PNG 图片：
- 格式：PNG
- 尺寸：512x512 px
- 背景：透明或纯色
- 设计：简洁现代

**推荐工具：**
- 🎨 [Figma](https://www.figma.com) - 专业设计工具
- 🖼️ [Canva](https://www.canva.com) - 简单易用
- 🎭 [Icon Kitchen](https://icon.kitchen/) - 在线图标生成器

### 2️⃣ 替换图标文件

```bash
# 将你的图标复制到项目中
cp /path/to/your/icon.png ui/flutter_app/assets/icon.png
```

### 3️⃣ 运行更新脚本

```bash
cd ui/flutter_app
./update_icon.sh
```

或者手动执行：

```bash
cd ui/flutter_app
flutter pub get
flutter pub run flutter_launcher_icons
```

### 4️⃣ 重新构建应用

```bash
flutter clean
flutter build apk --release
```

---

## 🎨 设计建议

### 配色方案（匹配 APP 主题）

```
主色：#1F2937 (高级黑)
辅色：#FFFFFF (白色)
强调色：#3B82F6 (蓝色) 或 #10B981 (绿色)
```

### 设计元素

**选项 1：字母 Logo**
- 使用 "B" 或 "BP" 字母
- 现代无衬线字体
- 简洁大方

**选项 2：播放图标**
- 播放按钮 ▶️
- 结合视频/媒体元素
- 圆形或方形背景

**选项 3：组合设计**
- 字母 + 图标
- 渐变效果
- 立体感设计

---

## 📐 Android Adaptive Icon

Android 8.0+ 支持自适应图标，由两部分组成：

### 前景图（Foreground）
- 主要图标内容
- 透明背景
- 放在 `assets/icon_foreground.png`

### 背景（Background）
- 纯色或渐变
- 在 `pubspec.yaml` 中配置：
  ```yaml
  adaptive_icon_background: "#1F2937"
  ```

### 安全区域
- 图标内容应在中心 **66%** 区域内
- 避免重要元素被裁剪

---

## 🔧 高级配置

### 修改 pubspec.yaml

```yaml
flutter_launcher_icons:
  android: true
  ios: false
  
  # 标准图标（必需）
  image_path: "assets/icon.png"
  
  # Adaptive Icon 配置（Android 8.0+）
  adaptive_icon_background: "#1F2937"
  adaptive_icon_foreground: "assets/icon_foreground.png"
  
  # 或者使用同一个图标
  # adaptive_icon_foreground: "assets/icon.png"
  
  # 圆形图标（可选）
  # adaptive_icon_round: "assets/icon_round.png"
```

### 只更新特定尺寸

```yaml
flutter_launcher_icons:
  android: "ic_launcher"  # 自定义名称
  image_path: "assets/icon.png"
  min_sdk_android: 21  # 最低 SDK 版本
```

---

## 🐛 常见问题

### Q: 图标没有更新？
**A:** 尝试以下步骤：
```bash
flutter clean
flutter pub get
flutter pub run flutter_launcher_icons
flutter build apk --release
```

### Q: 图标显示模糊？
**A:** 确保使用 512x512 或更高分辨率的图标

### Q: Adaptive Icon 显示不正确？
**A:** 检查前景图是否在安全区域内（中心 66%）

### Q: 如何测试不同形状的图标？
**A:** 在 Android 设置中可以切换图标形状：
- 设置 → 显示 → 图标形状

---

## 📱 查看效果

### 在模拟器中测试

```bash
flutter run --release
```

### 在真机上测试

```bash
flutter build apk --release
adb install build/app/outputs/flutter-apk/app-release.apk
```

### 检查生成的图标

```bash
# 查看所有生成的图标文件
ls -la android/app/src/main/res/mipmap-*/ic_launcher*
```

---

## 🎯 最佳实践

1. ✅ 使用 512x512 或更高分辨率
2. ✅ 保持设计简洁，避免过多细节
3. ✅ 测试不同的图标形状（圆形、方形、圆角方形）
4. ✅ 确保在浅色和深色背景下都清晰可见
5. ✅ 使用矢量图（SVG）作为源文件，导出为 PNG
6. ✅ 保留源文件（PSD、Figma、SVG）以便后续修改

---

## 📚 参考资源

- [Flutter Launcher Icons 文档](https://pub.dev/packages/flutter_launcher_icons)
- [Android Adaptive Icons 指南](https://developer.android.com/guide/practices/ui_guidelines/icon_design_adaptive)
- [Material Design Icons](https://fonts.google.com/icons)
- [Icon Kitchen](https://icon.kitchen/) - 在线图标生成器
- [Android Asset Studio](https://romannurik.github.io/AndroidAssetStudio/)

---

## 💡 提示

如果你需要帮助设计图标，可以：
1. 使用 AI 工具生成（如 DALL-E、Midjourney）
2. 在 Fiverr 或 Upwork 找设计师
3. 使用现有的图标库（注意版权）
4. 参考其他优秀应用的图标设计

---

**祝你设计出完美的图标！** 🎨✨
