# TrueHD 音频支持 - 替代方案

## 问题总结

MPV 官方 releases (https://github.com/mpv-player/mpv/releases/tag/v0.41.0) **不提供预编译的 libmpv 库文件**，只提供播放器应用程序本身。

要获得支持 TrueHD 的 libmpv 库，有以下几种方案：

---

## 方案 1：完成 Nix 编译（需要下载 Xcode 12.3）

### 当前状态
编译失败，原因：缺少 Xcode 12.3 依赖

### 完成步骤

1. **下载 Xcode 12.3**（约 5GB）
   - 访问：https://developer.apple.com/services-account/download?path=/Developer_Tools/Xcode_12.3/Xcode_12.3.xip
   - 需要 Apple Developer 账号（免费账号即可）

2. **解压并添加到 Nix store**
   ```bash
   # 解压 Xcode（会自动打开 Archive Utility）
   open -W Xcode_12.3.xip
   
   # 删除 xip 文件
   rm -rf Xcode_12.3.xip
   
   # 添加到 Nix store
   nix-store --add-fixed --recursive sha256 Xcode.app
   
   # 删除本地 Xcode.app
   rm -rf Xcode.app
   ```

3. **重新运行编译**
   ```bash
   cd ~/code/BovaPlayer/libmpv-darwin-build
   nix build -v .#mk-out-archive-libs-macos-universal-video-full
   ```

### 优点
- ✅ 完整的 TrueHD 支持
- ✅ 可以自定义编译选项
- ✅ 获得最新版本的 MPV

### 缺点
- ❌ 需要下载 5GB Xcode
- ❌ 编译时间较长（30-60 分钟）
- ❌ 需要 Apple Developer 账号

---

## 方案 2：使用 Homebrew 安装的 MPV 库

### 步骤

1. **安装 Homebrew MPV**
   ```bash
   brew install mpv
   ```

2. **查找 libmpv 库位置**
   ```bash
   brew list mpv | grep libmpv
   # 通常在 /opt/homebrew/lib/libmpv.dylib (Apple Silicon)
   # 或 /usr/local/lib/libmpv.dylib (Intel)
   ```

3. **复制到 media_kit_libs_macos_video**
   ```bash
   # 找到 media_kit_libs_macos_video 位置
   cd ~/.pub-cache/hosted/pub.dev/media_kit_libs_macos_video-1.0.4/
   
   # 备份原始库
   cp -r macos/Frameworks macos/Frameworks.backup
   
   # 创建 framework 结构
   mkdir -p macos/Frameworks/libmpv.framework/Versions/A
   
   # 复制 Homebrew 的 libmpv
   cp /opt/homebrew/lib/libmpv.dylib macos/Frameworks/libmpv.framework/Versions/A/libmpv
   
   # 创建符号链接
   cd macos/Frameworks/libmpv.framework
   ln -s Versions/A/libmpv libmpv
   ln -s Versions/A Versions/Current
   ```

4. **清理并重新构建**
   ```bash
   cd ~/code/BovaPlayer/ui/flutter_app
   flutter clean
   flutter pub get
   flutter build macos
   ```

### 优点
- ✅ 无需下载 Xcode
- ✅ 快速（几分钟）
- ✅ Homebrew 的 MPV 通常包含完整编解码器

### 缺点
- ❌ 可能与 media_kit 不完全兼容
- ❌ 需要手动维护
- ❌ 可能缺少某些依赖库

---

## 方案 3：使用 MPVKit（第三方预编译库）

MPVKit 是一个第三方项目，提供预编译的 MPV 库：
https://github.com/cxfksword/MPVKit

### 步骤

1. **克隆 MPVKit**
   ```bash
   git clone https://github.com/cxfksword/MPVKit.git
   cd MPVKit
   ```

2. **编译 MPV**
   ```bash
   swift run build enable-openssl enable-libsmbclient enable-libass enable-ffmpeg enable-mpv
   ```

3. **查找编译结果**
   ```bash
   # 编译完成后，查找 .framework 文件
   find . -name "*.framework" -type d
   ```

4. **复制到 media_kit_libs_macos_video**
   ```bash
   # 参考方案 2 的步骤 3-4
   ```

### 优点
- ✅ 专门为 iOS/macOS 优化
- ✅ 包含完整编解码器
- ✅ 支持 SMB 等网络协议

### 缺点
- ❌ 仍需要编译
- ❌ 第三方项目，维护频率不确定

---

## 方案 4：实现音频转码（临时方案）

如果以上方案都不可行，可以让 Emby 服务器转码 TrueHD 音频：

### 修改播放 URL

```dart
// 在 network_manager.dart 中修改
String getStreamUrl(String itemId) {
  return '$baseUrl/Videos/$itemId/stream.mp4?'
      'Static=false&'
      'MediaSourceId=$itemId&'
      'VideoCodec=copy&'        // 视频直通
      'AudioCodec=aac&'          // 音频转码为 AAC
      'AudioBitrate=320000&'     // 320kbps 高质量
      'api_key=${server.accessToken}';
}
```

### 优点
- ✅ 立即可用
- ✅ 无需修改客户端
- ✅ 兼容性好

### 缺点
- ❌ 音频质量略有损失
- ❌ 增加服务器负载
- ❌ 不是真正的 TrueHD 直接播放

---

## 推荐方案

### 如果你有时间和网络条件
**推荐方案 1**：完成 Nix 编译
- 这是最正规的方案
- 一次性工作，编译完成后可以一直使用
- 获得完整的 TrueHD 支持

### 如果你想快速测试
**推荐方案 2**：使用 Homebrew MPV
- 最快的方案（几分钟）
- 可以快速验证 TrueHD 是否能正常播放
- 如果有问题，再考虑方案 1

### 如果你不想折腾
**推荐方案 4**：实现音频转码
- 立即可用
- 320kbps AAC 音质已经很好
- 对大多数用户来说足够了

---

## 下一步

请告诉我你想使用哪个方案，我会帮你完成具体的实现步骤。

如果选择方案 1，我可以等你下载完 Xcode 12.3 后继续编译。
如果选择方案 2 或 3，我可以立即帮你实现。
如果选择方案 4，我可以修改代码实现音频转码。
