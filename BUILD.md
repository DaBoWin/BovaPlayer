# BovaPlayer 构建指南

本文档说明如何为不同平台构建 BovaPlayer。

## 前置要求

### 所有平台
- Rust 工具链（推荐使用 rustup）
- Cargo

### macOS
- Xcode Command Line Tools
- 已安装（当前系统）

### Windows
- 在 Windows 上：Visual Studio 2019+ 或 MinGW-w64
- 交叉编译（从 macOS/Linux）：
  ```bash
  rustup target add x86_64-pc-windows-gnu
  brew install mingw-w64  # macOS
  ```

### Android
- Flutter SDK
- Android SDK (API 21+)
- Android NDK
- Rust Android targets:
  ```bash
  rustup target add aarch64-linux-android
  rustup target add armv7-linux-androideabi
  rustup target add x86_64-linux-android
  ```

## 快速构建

### macOS（当前平台）
```bash
./build_macos.sh
```

输出：
- `core/target/release/BovaPlayer.app` - macOS 应用程序包
- `core/target/release/BovaPlayer-macOS-v0.0.1.dmg` - 安装镜像

### Windows
**推荐：在 Windows 机器上构建**
```bash
cd core
cargo build --release --bin bova-gui
```

输出：`core/target/release/bova-gui.exe`

**交叉编译（实验性）：**
```bash
./build_windows.sh
```

### Android
```bash
./build_android.sh
```

输出：
- `ui/flutter_app/build/app/outputs/flutter-apk/app-release.apk` - APK 文件
- `ui/flutter_app/build/app/outputs/bundle/release/app-release.aab` - App Bundle（用于 Google Play）

### 构建所有平台
```bash
./build_all.sh
```

## 手动构建

### macOS 桌面应用
```bash
cd core
cargo build --release --bin bova-gui

# 创建 app bundle
APP_DIR="target/release/BovaPlayer.app"
mkdir -p "${APP_DIR}/Contents/MacOS"
cp target/release/bova-gui "${APP_DIR}/Contents/MacOS/BovaPlayer"
```

### Windows 桌面应用
```bash
cd core
cargo build --release --bin bova-gui --target x86_64-pc-windows-gnu
```

### Android 应用
```bash
cd ui/flutter_app
flutter pub get
flutter build apk --release
```

## 依赖项

### Rust Crates
- egui - GUI 框架
- eframe - egui 应用框架
- bova-core - 核心播放器逻辑
- bova-playback - MPV 播放引擎
- reqwest - HTTP 客户端（Emby API）
- image - 图片处理
- rodio - 音频播放

### 系统依赖
- macOS: 无额外依赖
- Windows: 可能需要 Visual C++ Redistributable
- Android: 需要 Android Runtime

## 发布清单

构建发布版本时：

1. ✅ 更新版本号（Cargo.toml, pubspec.yaml）
2. ✅ 运行测试
3. ✅ 构建所有平台
4. ✅ 测试每个平台的构建产物
5. ✅ 创建发布说明
6. ✅ 打标签并推送

## 故障排除

### macOS: "无法打开应用，因为它来自身份不明的开发者"
```bash
xattr -cr BovaPlayer.app
```

### Windows: 缺少 DLL
确保安装了 Visual C++ Redistributable 或将所需 DLL 与 exe 一起分发。

### Android: 构建失败
- 检查 ANDROID_HOME 环境变量
- 确保 Android SDK 和 NDK 已安装
- 运行 `flutter doctor` 检查环境

## 当前构建状态

✅ macOS - 已成功构建
⚠️  Windows - 需要在 Windows 上构建或配置交叉编译
⏳ Android - 需要 Flutter 环境

## 联系方式

如有问题，请提交 Issue。
