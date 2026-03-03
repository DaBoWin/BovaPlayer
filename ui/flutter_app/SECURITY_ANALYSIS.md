# BovaPlayer 云同步安全分析

## 当前状况（2026-03-03）

### 1. 媒体服务器认证信息

**存储位置**：Supabase `media_servers` 表

**存储内容**：
- ✅ 服务器名称、URL（公开信息）
- ❌ **`access_token` - 明文存储**（严重安全问题）
- ✅ `user_id_server`（服务器用户 ID）
- ✅ 用户名不存储在云端

**安全问题**：
```sql
-- 数据库表结构
CREATE TABLE public.media_servers (
  ...
  access_token_encrypted TEXT,  -- ⚠️ 字段名叫 "encrypted" 但实际是明文！
  user_id_server VARCHAR(100),
  ...
);
```

**风险评估**：
- 🔴 **高风险**：Access Token 可以完全访问用户的媒体服务器
- 🔴 如果数据库被攻破，攻击者可以：
  - 访问所有用户的媒体库
  - 查看播放历史
  - 修改服务器设置
  - 删除媒体内容

### 2. 网络连接（SMB/FTP）

**存储位置**：Supabase `network_connections` 表

**存储内容**：
- ✅ 协议、主机、端口（公开信息）
- ✅ 用户名（明文，可接受）
- ✅ **密码不存储在云端**（正确做法）
- ✅ SMB 共享名、工作组

**安全评估**：
- 🟢 **低风险**：密码仅本地存储
- 🟡 用户名泄露风险较低（通常是公开的）

### 3. 数据库访问控制

**Row Level Security (RLS)**：
```sql
-- 用户只能访问自己的数据
CREATE POLICY "Users can only access their own data"
ON public.media_servers
FOR ALL
USING (auth.uid() = user_id);
```

**保护措施**：
- ✅ RLS 确保用户 A 无法访问用户 B 的数据
- ✅ Supabase API 密钥不暴露在客户端
- ⚠️ 但如果数据库本身被攻破，RLS 无法保护

## 安全改进建议

### 方案 1：客户端加密（推荐）

**实现方式**：
1. 使用用户密码派生加密密钥（PBKDF2）
2. 在客户端加密 access_token
3. 上传加密后的数据到云端
4. 下载时在客户端解密

**优点**：
- ✅ 即使数据库被攻破，攻击者也无法解密
- ✅ 零知识架构（服务器不知道明文）
- ✅ 符合隐私最佳实践

**缺点**：
- ⚠️ 用户忘记密码无法恢复数据
- ⚠️ 需要在登录时输入密码（不能使用 OAuth）

**实现代码**：
```dart
// 已创建：lib/core/security/encryption_service.dart

// 上传时加密
final encrypted = EncryptionService.encryptText(
  accessToken,
  userPassword,  // 需要用户输入密码
  userId,
);

// 下载时解密
final decrypted = EncryptionService.decryptText(
  encrypted,
  userPassword,
  userId,
);
```

### 方案 2：Supabase Vault（简单但有限）

**实现方式**：
使用 Supabase 的 Vault 功能存储敏感数据

**优点**：
- ✅ 简单易用
- ✅ Supabase 管理加密密钥

**缺点**：
- ⚠️ 仍然依赖 Supabase 的安全性
- ⚠️ 不是零知识架构
- ⚠️ Vault 功能可能有使用限制

### 方案 3：混合方案

**实现方式**：
1. 敏感数据（access_token）使用客户端加密
2. 非敏感数据（服务器名称、URL）明文存储
3. 提供"记住密码"选项（本地安全存储）

**优点**：
- ✅ 平衡安全性和用户体验
- ✅ 用户可选择是否加密
- ✅ 支持生物识别解锁

## 当前代码问题

### 问题 1：字段命名误导

```dart
// sync_repository_impl.dart
'access_token_encrypted': item['accessToken'],  // ❌ 实际是明文
```

**修复**：
```dart
// 方案 A：重命名字段
'access_token': item['accessToken'],

// 方案 B：真正加密
'access_token_encrypted': EncryptionService.encryptText(
  item['accessToken'],
  userPassword,
  userId,
),
```

### 问题 2：缺少加密依赖

**需要添加**：
```yaml
# pubspec.yaml
dependencies:
  encrypt: ^5.0.3      # AES 加密
  crypto: ^3.0.3       # PBKDF2、HMAC
  flutter_secure_storage: ^9.0.0  # 安全存储密钥
```

## 实施计划

### 阶段 1：紧急修复（1-2 天）
1. ✅ 创建 `EncryptionService`
2. ⬜ 添加加密依赖
3. ⬜ 修改同步逻辑，加密 access_token
4. ⬜ 数据库迁移：重新加密现有数据

### 阶段 2：用户体验优化（3-5 天）
1. ⬜ 添加"记住密码"功能
2. ⬜ 支持生物识别解锁
3. ⬜ 提供"导出加密密钥"功能（备份）

### 阶段 3：高级功能（可选）
1. ⬜ 支持硬件安全模块（HSM）
2. ⬜ 多设备密钥同步
3. ⬜ 密钥轮换机制

## 用户通知

**重要**：如果实施加密，需要通知现有用户：

```
【安全升级通知】

为了保护您的隐私，我们将对云端存储的认证信息进行加密。

升级后：
• 首次登录需要输入密码
• 可选择"记住密码"或使用生物识别
• 即使数据库泄露，您的数据也是安全的

注意：忘记密码将无法恢复云端数据（本地数据不受影响）

建议：升级前导出本地数据作为备份
```

## 合规性

### GDPR（欧盟）
- ✅ 用户数据加密
- ✅ 用户可删除所有数据
- ⚠️ 需要明确的隐私政策

### CCPA（加州）
- ✅ 用户可导出数据
- ✅ 用户可删除数据

### 中国网络安全法
- ✅ 数据存储在境内（Supabase 可选区域）
- ⚠️ 需要实名认证（如果商业化）

## 总结

**当前状态**：
- 🔴 Access Token 明文存储 - **需要立即修复**
- 🟢 密码不存储在云端 - 正确
- 🟡 RLS 提供基本保护 - 不够

**推荐方案**：
实施客户端加密（方案 1），提供最佳安全性和隐私保护。

**优先级**：
1. 🔴 **高**：加密 access_token
2. 🟡 **中**：添加密钥管理
3. 🟢 **低**：高级安全功能
