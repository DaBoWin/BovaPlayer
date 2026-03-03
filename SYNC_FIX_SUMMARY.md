# 同步功能修复总结

## 修复日期
2026-03-03

## 问题描述

### 问题 1: 编辑服务器后不同步
- **现象**: 在媒体库页面编辑服务器信息后，数据没有同步到云端
- **原因**: `_triggerSync()` 方法只打印日志，没有真正调用同步服务

### 问题 2: "未设置用户密码"错误
- **现象**: 应用重启后或某些情况下触发同步时报错 "未设置用户密码，无法加密数据"
- **原因**: 用户密码只在登录时设置到内存，应用重启后密码丢失

### 问题 3: Android 端登录后没有双向合并
- **现象**: Mac 端上传数据后，Android 端登录没有下载云端数据
- **原因**: 双向合并逻辑有 bug，使用了错误的变量导致本地服务器被覆盖

## 修复方案

### 修复 1: 实现真正的同步触发

**文件**: `lib/features/auth/presentation/providers/auth_provider.dart`

添加公开方法 `triggerSync()`：
```dart
/// 手动触发同步（供其他页面调用）
Future<void> triggerSync() async {
  if (_syncService == null) {
    debugPrint('[Auth] 同步服务未初始化');
    return;
  }
  
  // 检查是否有用户密码
  final syncRepo = _syncService!.repository as SyncRepositoryImpl;
  if (!syncRepo.hasUserPassword) {
    debugPrint('[Auth] ⚠️  用户密码未设置，无法同步加密数据');
    debugPrint('[Auth] 提示：请重新登录以启用同步功能');
    return;
  }
  
  try {
    debugPrint('[Auth] 手动触发同步...');
    await _syncService!.performIncrementalSync();
    debugPrint('[Auth] 同步完成');
  } catch (e) {
    debugPrint('[Auth] 同步失败: $e');
  }
}
```

**文件**: `lib/media_library_page.dart`

修改 `_triggerSync()` 调用 AuthProvider：
```dart
void _triggerSync() {
  try {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (authProvider.isAuthenticated) {
      print('[MediaLibrary] 触发同步...');
      authProvider.triggerSync();
    } else {
      print('[MediaLibrary] 用户未登录，跳过同步');
    }
  } catch (e) {
    print('[MediaLibrary] 触发同步失败: $e');
  }
}
```

### 修复 2: 添加密码检查

**文件**: `lib/features/sync/data/repositories/sync_repository_impl.dart`

添加 `hasUserPassword` getter：
```dart
/// 检查是否已设置用户密码
bool get hasUserPassword => _userPassword != null;
```

这样可以在同步前检查密码是否可用，避免抛出异常。

### 修复 3: 修复双向合并逻辑

**文件**: `lib/features/sync/data/repositories/sync_repository_impl.dart`

**问题代码**:
```dart
// 错误：使用 localEmbyJson（可能是旧数据）
final embyServers = localEmbyJson != null 
    ? List<Map<String, dynamic>>.from(jsonDecode(localEmbyJson))
    : <Map<String, dynamic>>[];
```

**修复后**:
```dart
// 正确：重新读取当前本地数据
final currentLocalJson = _prefs.getString('emby_servers');
final embyServers = currentLocalJson != null 
    ? List<Map<String, dynamic>>.from(jsonDecode(currentLocalJson))
    : <Map<String, dynamic>>[];

// 创建本地服务器的 URL 集合（用于快速查找）
final localUrls = embyServers.map((s) => s['url'] as String).toSet();

// 只下载本地没有的服务器
if (!localUrls.contains(url) && cloud['server_type'] == 'emby') {
  // ... 下载逻辑
}
```

## 使用说明

### 正常流程

1. **登录时**
   - 用户输入密码登录
   - 密码被设置到内存中
   - 自动触发首次同步

2. **编辑服务器时**
   - 修改服务器信息
   - 保存到本地
   - 自动触发同步到云端

3. **跨设备同步**
   - 设备 A 添加/编辑服务器
   - 数据加密后上传到云端
   - 设备 B 登录后自动下载并解密

### 密码丢失场景

如果应用重启后用户密码丢失（未登录状态），同步会被跳过并打印提示：

```
[Auth] ⚠️  用户密码未设置，无法同步加密数据
[Auth] 提示：请重新登录以启用同步功能
```

**解决方法**: 用户需要重新登录以恢复同步功能。

## 测试步骤

### 测试 1: 编辑服务器同步

1. Mac 端登录
2. 编辑一个 Emby 服务器（修改名称或密码）
3. 保存
4. 查看控制台日志，应该看到：
   ```
   [MediaLibrary] 触发同步...
   [Auth] 手动触发同步...
   [Sync] 开始完整同步...
   [Sync] 🔄 更新云端服务器: xxx
   [Sync] ✅ 双向合并完成
   ```
5. 检查 Supabase 数据库，确认数据已更新

### 测试 2: 跨设备同步

1. Mac 端添加服务器 A
2. 等待同步完成
3. Android 端登录（使用相同账号）
4. 查看媒体库，应该能看到服务器 A
5. Android 端添加服务器 B
6. Mac 端重新登录或手动同步
7. Mac 端应该能看到服务器 B

### 测试 3: 双向合并

1. Mac 端有服务器 A
2. 上传到云端
3. Android 端本地有服务器 B
4. Android 端登录并同步
5. Android 端应该同时有服务器 A 和 B
6. 云端也应该同时有服务器 A 和 B

## 已知限制

1. **密码不持久化**: 用户密码只在内存中，应用重启后需要重新登录
2. **同步需要登录**: 只有登录状态下才能同步
3. **加密算法**: 当前使用 HMAC-SHA256 + XOR，生产环境建议升级到 AES-256-GCM

## 下一步优化

1. **添加同步状态指示器**: 在 UI 上显示同步进度
2. **密码输入弹窗**: 当需要同步但密码不在内存时，弹窗让用户输入密码
3. **后台同步**: 定期自动同步，而不是只在编辑时同步
4. **冲突解决**: 处理多设备同时编辑同一服务器的情况
5. **升级加密算法**: 使用 AES-256-GCM 替代当前的 XOR 加密

## 相关文件

- `lib/features/auth/presentation/providers/auth_provider.dart` - 认证提供者
- `lib/features/sync/data/repositories/sync_repository_impl.dart` - 同步仓库实现
- `lib/media_library_page.dart` - 媒体库页面
- `PASSWORD_ENCRYPTION_UPDATE.md` - 密码加密更新文档
- `ENCRYPTED_SYNC_GUIDE.md` - 加密同步使用指南
