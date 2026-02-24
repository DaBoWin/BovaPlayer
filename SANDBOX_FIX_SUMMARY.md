# macOS App Sandbox 修复总结

## 问题诊断

### 症状
- ✅ `flutter run` 运行时视频播放正常
- ❌ 直接打开构建的 `.app` 文件后，点击播放按钮应用崩溃退出

### 根本原因
**App Sandbox 配置不一致**

1. **Debug Profile** (`DebugProfile.entitlements`): 沙盒已禁用 (`<false/>`)
2. **Release Profile** (`Release.entitlements`): 沙盒仍然启用 (`<true/>`)

当使用 `flutter run` 时，使用 Debug 配置（沙盒禁用），所以播放正常。
当使用 `flutter build macos` 或直接打开 `.app` 时，使用 Release 配置（沙盒启用），导致网络访问被阻止，播放失败。

## 解决方案

### 已实施的修复
更新了 `Release.entitlements` 文件，禁用 App Sandbox 并添加必要的权限：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.app-sandbox</key>
	<false/>
	<key>com.apple.security.cs.allow-jit</key>
	<true/>
	<key>com.apple.security.network.server</key>
	<true/>
	<key>com.apple.security.network.client</key>
	<true/>
	<key>com.apple.security.files.user-selected.read-only</key>
	<true/>
	<key>com.apple.security.files.user-selected.read-write</key>
	<true/>
</dict>
</plist>
```

### 权限说明
- `com.apple.security.app-sandbox`: 禁用沙盒（设为 `false`）
- `com.apple.security.cs.allow-jit`: 允许 JIT 编译（Flutter 需要）
- `com.apple.security.network.server`: 允许作为网络服务器
- `com.apple.security.network.client`: 允许网络客户端访问（HTTPS 流媒体）
- `com.apple.security.files.user-selected.read-only`: 允许读取用户选择的文件
- `com.apple.security.files.user-selected.read-write`: 允许读写用户选择的文件

## 测试步骤

### 1. 重新构建应用
```bash
cd ui/flutter_app
flutter clean
flutter build macos --release
```

### 2. 测试直接启动
```bash
open build/macos/Build/Products/Release/bova_player_flutter.app
```

### 3. 验证播放功能
1. 打开应用
2. 连接到 Emby 服务器
3. 选择一个视频
4. 点击播放按钮
5. **预期结果**: 视频应该正常播放，不会崩溃

### 4. 检查日志（如果仍有问题）
```bash
# 实时查看应用日志
log stream --predicate 'process == "bova_player_flutter"' --level debug

# 或查看最近的崩溃报告
log show --predicate 'process == "bova_player_flutter"' --last 1m --info
```

## 为什么之前能播放？

根据用户反馈"今天最开始是可以播放的"，可能的原因：

1. **之前的构建使用了 Debug 配置**: 如果之前使用 `flutter run` 或 `flutter build macos --debug`，沙盒是禁用的
2. **配置文件被修改**: 在调试过程中，`DebugProfile.entitlements` 被修改为禁用沙盒，但 `Release.entitlements` 没有同步更新
3. **缓存问题**: 旧的构建可能使用了不同的配置

## 长期解决方案

### 选项 1: 保持沙盒禁用（当前方案）
- ✅ 简单直接，适合开发和测试
- ❌ 不能上架 Mac App Store
- ✅ 适合企业内部分发或直接分发

### 选项 2: 启用沙盒并配置正确的权限
如果需要上架 Mac App Store，需要：

1. 启用沙盒 (`com.apple.security.app-sandbox` = `true`)
2. 添加网络访问权限
3. 可能需要添加临时例外（Temporary Exceptions）用于 HTTPS 访问
4. 配置 `Info.plist` 添加 `NSAppTransportSecurity` 设置

```xml
<!-- 在 Info.plist 中添加 -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

### 选项 3: 使用 Hardened Runtime（推荐用于分发）
对于非 App Store 分发，使用 Hardened Runtime + 公证：

1. 保持沙盒禁用
2. 启用 Hardened Runtime
3. 添加必要的 entitlements
4. 使用 Apple Developer ID 签名
5. 提交公证（Notarization）

## 当前状态

- ✅ `DebugProfile.entitlements` 已更新（沙盒禁用）
- ✅ `Release.entitlements` 已更新（沙盒禁用）
- ✅ 应用已重新构建
- ⏳ 等待用户测试确认

## 下一步

1. **立即测试**: 打开构建的应用，尝试播放视频
2. **如果仍然崩溃**: 
   - 检查控制台日志
   - 查看崩溃报告
   - 可能需要检查代码签名问题
3. **如果播放成功**: 
   - 优化缓冲设置（当前 50 秒太慢）
   - 考虑长期分发策略

## 缓冲优化（下一步）

当前缓冲配置：
- `demuxer-max-bytes`: 150MB
- `cache-secs`: 15 秒
- `demuxer-lavf-analyzeduration`: 5 秒

可以尝试的优化：
- 减少 `demuxer-max-bytes` 到 50MB
- 减少 `cache-secs` 到 5 秒
- 减少 `analyzeduration` 到 2 秒
- 启用 `cache-pause-initial=no` 立即开始播放
