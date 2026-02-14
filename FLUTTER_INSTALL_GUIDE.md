# Flutter SDK 安装指南

由于网络问题导致自动安装失败，请按照以下步骤手动安装Flutter：

## 方法一：手动下载安装（推荐）

1. 访问Flutter官网下载页面：
   https://flutter.dev/docs/get-started/install/macos

2. 下载最新的Flutter SDK (macOS arm64版本)

3. 解压到您选择的目录：
   ```bash
   cd ~/development
   unzip ~/Downloads/flutter_macos_arm64_3.35.3-stable.zip
   ```

4. 添加Flutter到PATH环境变量：
   ```bash
   echo 'export PATH="$PATH:$HOME/development/flutter/bin"' >> ~/.zshrc
   source ~/.zshrc
   ```

5. 运行Flutter doctor检查安装：
   ```bash
   flutter doctor
   ```

## 方法二：使用镜像源安装

如果官网下载慢，可以使用国内镜像：

```bash
# 使用清华镜像
export PUB_HOSTED_URL=https://mirrors.tuna.tsinghua.edu.cn/dart-pub
export FLUTTER_STORAGE_BASE_URL=https://mirrors.tuna.tsinghua.edu.cn/flutter

git clone https://mirrors.tuna.tsinghua.edu.cn/git/flutter-sdk.git ~/flutter
```

## 启用桌面支持

安装完成后，启用macOS桌面支持：

```bash
flutter config --enable-macos-desktop
```

## 测试Flutter应用

安装完成后，运行：

```bash
cd ui/flutter_app
./run_desktop.sh
```

## 当前替代方案

在安装Flutter期间，您可以使用现有的Rust GUI：

```bash
cd core
cargo run --bin bova-gui
```

这个Rust GUI已经包含了完整的播放功能，支持硬件加速和视频渲染。