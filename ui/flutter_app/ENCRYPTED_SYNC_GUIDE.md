# 加密同步使用指南

## 概述

BovaPlayer 使用基于用户密码的加密方案来保护媒体服务器的敏感信息。这确保了即使云端数据被泄露，攻击者也无法获取你的服务器密码。

## 加密内容

### 媒体服务器
- **加密字段**: 服务器密码 (password)
- **明文字段**: 服务器名称、URL、用户名
- **加密方式**: 使用用户密码 + 用户ID 作为密钥

### 网络连接 (SMB/FTP)
- **不同步密码**: 出于安全考虑，SMB/FTP 密码仅存储在本地
- **同步内容**: 连接元数据（主机、端口、用户名等）

## 工作原理

### 1. 登录时
```dart
// 用户登录成功后，密码被保存到内存
authProvider.login(email, password);
// → syncRepository.setUserPassword(password)
```

### 2. 上传到云端
```dart
// 本地密码 → 加密 → 上传
plainPassword = "myServerPassword123"
encryptedPassword = encrypt(plainPassword, userPassword, userId)
// → 上传到 Supabase: password_encrypted
```

### 3. 从云端下载
```dart
// 下载 → 解密 → 保存到本地
encryptedPassword = download_from_cloud()
plainPassword = decrypt(encryptedPassword, userPassword, userId)
// → 保存到本地 SharedPreferences
```

### 4. 登出时
```dart
// 清除内存中的密码
authProvider.logout();
// → syncRepository.clearUserPassword()
```

## 安全特性

### ✅ 优点
1. **端到端加密**: 云端只存储加密后的密码
2. **用户密码作为密钥**: 只有知道用户密码才能解密
3. **跨设备同步**: 在新设备登录后，使用相同的用户密码可以解密所有服务器密码
4. **自动登录**: 解密后的密码可以直接用于登录媒体服务器

### ⚠️ 注意事项
1. **用户密码很重要**: 忘记用户密码将无法解密服务器密码
2. **密码不存储在磁盘**: 用户密码仅在内存中，重启应用需要重新登录
3. **首次同步**: 添加服务器后会自动触发同步

## 数据库结构

### media_servers 表
```sql
CREATE TABLE media_servers (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL,
  server_type VARCHAR(20),  -- 'emby', 'jellyfin', 'plex'
  name VARCHAR(100),         -- 服务器名称（明文）
  url TEXT,                  -- 服务器地址（明文）
  username VARCHAR(100),     -- 用户名（明文）
  password_encrypted TEXT,   -- 加密的密码 ✨
  user_id_server VARCHAR(100), -- 服务器上的用户ID
  ...
);
```

## 使用示例

### 添加服务器
```dart
// 1. 用户输入服务器信息
final server = {
  'name': '我的 Emby',
  'url': 'https://emby.example.com',
  'username': 'admin',
  'password': 'myPassword123',  // 明文密码
};

// 2. 保存到本地
await prefs.setString('emby_servers', jsonEncode([server]));

// 3. 自动触发同步
await syncRepository.syncMediaServers();
// → 密码被加密后上传到云端
```

### 新设备登录
```dart
// 1. 用户在新设备登录
await authProvider.login('user@example.com', 'userPassword');

// 2. 自动执行首次同步
await syncRepository.syncAll();
// → 从云端下载加密的密码
// → 使用用户密码解密
// → 保存到本地

// 3. 用户可以直接访问所有服务器
// 密码已经解密并保存在本地
```

## 加密算法

当前使用 HMAC-SHA256 + XOR 加密（演示用）：

```dart
// 加密
encryptedPassword = EncryptionService.encryptWithMasterPassword(
  plainPassword,    // 服务器密码
  userPassword,     // 用户密码（密钥）
  userId,           // 用户ID（盐值）
);

// 解密
plainPassword = EncryptionService.decryptWithMasterPassword(
  encryptedPassword,
  userPassword,
  userId,
);
```

**生产环境建议**: 使用 AES-256-GCM 替代当前的 XOR 加密。

## 故障排查

### 问题：同步失败 "未设置用户密码"
**原因**: 用户密码未保存到内存  
**解决**: 确保登录成功后调用了 `setUserPassword()`

### 问题：解密失败
**原因**: 用户密码错误或数据损坏  
**解决**: 
1. 确认用户密码正确
2. 检查云端数据是否完整
3. 重新添加服务器

### 问题：新设备无法获取服务器密码
**原因**: 用户密码不匹配  
**解决**: 使用相同的用户密码登录

## 最佳实践

1. **定期同步**: 添加/修改服务器后自动触发同步
2. **安全的用户密码**: 使用强密码保护账号
3. **备份**: 定期导出服务器列表作为备份
4. **多设备**: 在所有设备上使用相同的用户密码

## 相关文件

- `lib/core/security/encryption_service.dart` - 加密服务
- `lib/features/sync/data/repositories/sync_repository_impl.dart` - 同步实现
- `lib/features/auth/presentation/providers/auth_provider.dart` - 认证提供者
- `.kiro/specs/cloud-sync/database/07_update_media_servers_encryption.sql` - 数据库迁移
