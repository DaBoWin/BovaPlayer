# 密码加密同步更新

## 更新日期
2026-03-03

## 更新内容

### 核心变更
将云同步的加密字段从 `access_token` 改为 `password`（媒体服务器密码）

### 原因
- 用户希望直接加密并同步媒体服务器的密码
- 跨设备同步后，可以使用解密的密码自动登录服务器
- 更符合用户的使用习惯

## 技术实现

### 1. 数据库变更
**文件**: `.kiro/specs/cloud-sync/database/07_update_media_servers_encryption.sql`

```sql
ALTER TABLE public.media_servers 
  ADD COLUMN IF NOT EXISTS username VARCHAR(100),
  ADD COLUMN IF NOT EXISTS password_encrypted TEXT;
```

**字段说明**:
- `username`: 媒体服务器用户名（明文）
- `password_encrypted`: 使用用户密码加密的服务器密码

### 2. 同步逻辑更新
**文件**: `ui/flutter_app/lib/features/sync/data/repositories/sync_repository_impl.dart`

**上传到云端**:
```dart
// 加密密码
final encryptedPassword = EncryptionService.encryptWithMasterPassword(
  password,        // 服务器密码
  _userPassword!,  // 用户密码（密钥）
  _userId!,        // 用户ID（盐值）
);

// 上传
localServers.add({
  'server_type': 'emby',
  'name': item['name'],
  'url': item['url'],
  'username': username,
  'password_encrypted': encryptedPassword,
  'user_id_server': item['userId'] ?? '',
});
```

**从云端下载**:
```dart
// 解密密码
final decryptedPassword = EncryptionService.decryptWithMasterPassword(
  encryptedPassword,
  _userPassword!,
  _userId!,
);

// 保存到本地
embyServers.add({
  'name': s['name'],
  'url': s['url'],
  'username': username,
  'password': decryptedPassword,  // 解密后的密码
  'accessToken': null,
  'userId': s['user_id_server'] ?? '',
});
```

### 3. 本地存储更新
**文件**: `ui/flutter_app/lib/media_library_page.dart`

添加服务器时保存密码：
```dart
list.add({
  'name': name,
  'url': url,
  'username': username,
  'password': password,  // 新增：保存密码
  'accessToken': loginResult['accessToken'],
  'userId': loginResult['userId'],
});
```

### 4. UI 改进
**文件**: `ui/flutter_app/lib/media_library_page.dart`

添加密码显示/隐藏功能：
```dart
class _PasswordField extends StatefulWidget {
  // 带眼睛图标的密码输入框
  // 点击眼睛可以切换显示/隐藏密码
}
```

## 数据流程

### 添加服务器
```
用户输入 → 保存到本地 → 触发同步 → 加密密码 → 上传到云端
```

### 跨设备同步
```
新设备登录 → 下载云端数据 → 解密密码 → 保存到本地 → 可直接使用
```

## 安全性

### 加密方式
- **算法**: HMAC-SHA256 + XOR（演示用）
- **密钥**: 用户密码
- **盐值**: 用户ID
- **生产建议**: 使用 AES-256-GCM

### 安全特性
1. ✅ 云端只存储加密后的密码
2. ✅ 只有知道用户密码才能解密
3. ✅ 用户密码仅在内存中，不存储到磁盘
4. ✅ 跨设备同步需要相同的用户密码

## 使用场景

### 场景 1: 单设备使用
1. 添加 Emby 服务器（输入密码）
2. 密码加密后同步到云端
3. 本地保存明文密码用于登录

### 场景 2: 多设备同步
1. 设备 A 添加服务器并同步
2. 设备 B 登录（使用相同的用户密码）
3. 自动下载并解密服务器密码
4. 设备 B 可以直接访问服务器

### 场景 3: 编辑服务器
1. 修改服务器密码
2. 重新加密并更新云端
3. 其他设备同步后获取新密码

## 相关文件

### 核心文件
- `lib/core/security/encryption_service.dart` - 加密服务
- `lib/features/sync/data/repositories/sync_repository_impl.dart` - 同步实现
- `lib/media_library_page.dart` - 媒体库页面（添加/编辑服务器）

### 数据库
- `.kiro/specs/cloud-sync/database/07_update_media_servers_encryption.sql` - 数据库迁移脚本

### 文档
- `ui/flutter_app/ENCRYPTED_SYNC_GUIDE.md` - 加密同步使用指南

## 测试建议

### 1. 单设备测试
- [ ] 添加 Emby 服务器
- [ ] 检查本地是否保存了密码
- [ ] 检查云端是否保存了加密的密码
- [ ] 重启应用，验证可以访问服务器

### 2. 跨设备测试
- [ ] 设备 A 添加服务器
- [ ] 设备 B 登录并同步
- [ ] 验证设备 B 可以访问服务器
- [ ] 验证密码正确解密

### 3. 编辑测试
- [ ] 编辑服务器密码
- [ ] 验证云端更新
- [ ] 其他设备同步后验证新密码

### 4. 安全测试
- [ ] 登出后验证内存中的密码被清除
- [ ] 使用错误的用户密码登录，验证无法解密
- [ ] 检查云端数据库，确认密码是加密的

## 注意事项

1. **数据库迁移**: 需要在 Supabase 中执行 `07_update_media_servers_encryption.sql`
2. **向后兼容**: 旧的 `access_token_encrypted` 字段暂时保留，可以手动删除
3. **用户密码**: 必须在登录时设置，否则无法加密/解密
4. **密码强度**: 建议用户使用强密码保护账号

## 下一步

1. 在 Supabase 中执行数据库迁移脚本
2. 测试添加/编辑/删除服务器功能
3. 测试跨设备同步
4. 考虑升级加密算法到 AES-256-GCM
