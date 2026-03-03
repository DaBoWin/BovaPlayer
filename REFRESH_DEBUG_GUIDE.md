# 账号页面刷新功能调试指南

## 问题描述
用户点击账号页面的刷新按钮后，提示"数据为空"。

## 调试步骤

### 1. 查看控制台日志
运行应用后，点击刷新按钮，查看控制台输出：

```
[AccountPage] 开始刷新用户数据
[Auth] 开始刷新用户信息...
[AuthRepo] 获取用户信息: <user_id>
[AuthRepo] 用户数据: {...}
[AuthRepo] 服务器数量: X
[Auth] 刷新成功
[AccountPage] 刷新完成
```

### 2. 检查可能的错误

#### 错误 1：用户未登录
```
[Auth] 刷新失败：用户未登录
```
**解决方案**：确保用户已登录

#### 错误 2：数据库查询失败
```
[AuthRepo] 获取用户信息失败: <error>
```
**可能原因**：
- RLS 策略阻止查询
- 用户记录不存在
- 网络连接问题

**解决方案**：
1. 检查 Supabase Dashboard 中的 users 表
2. 验证 RLS 策略是否正确
3. 检查网络连接

#### 错误 3：服务器统计失败
```
[AuthRepo] 统计服务器数量失败: <error>
```
**可能原因**：
- media_servers 表不存在
- RLS 策略阻止查询

**解决方案**：
1. 检查 media_servers 表是否存在
2. 验证 RLS 策略

### 3. 验证数据库

#### 检查 users 表
在 Supabase SQL Editor 中执行：
```sql
SELECT * FROM public.users WHERE id = '<your_user_id>';
```

应该返回：
```json
{
  "id": "...",
  "email": "...",
  "username": "...",
  "account_type": "free",
  "max_servers": 10,
  "max_devices": 2,
  "storage_quota_mb": 100,
  "storage_used_mb": 0,
  "device_count": 0,
  "created_at": "...",
  "updated_at": "..."
}
```

#### 检查 media_servers 表
```sql
SELECT * FROM public.media_servers WHERE user_id = '<your_user_id>' AND is_active = true;
```

应该返回你添加的服务器列表。

#### 检查 RLS 策略
```sql
-- 查看 users 表的 RLS 策略
SELECT * FROM pg_policies WHERE tablename = 'users';

-- 查看 media_servers 表的 RLS 策略
SELECT * FROM pg_policies WHERE tablename = 'media_servers';
```

### 4. 手动测试查询

在 Supabase SQL Editor 中，使用你的用户 ID 测试查询：

```sql
-- 测试 1：获取用户信息
SELECT * FROM public.users WHERE id = '<your_user_id>';

-- 测试 2：统计服务器数量
SELECT COUNT(*) FROM public.media_servers 
WHERE user_id = '<your_user_id>' AND is_active = true;

-- 测试 3：获取服务器列表
SELECT id, name, server_type, url FROM public.media_servers 
WHERE user_id = '<your_user_id>' AND is_active = true;
```

### 5. 检查 RLS 策略

确保以下 RLS 策略存在：

#### users 表
```sql
-- 用户可以查看自己的信息
CREATE POLICY "Users can view own data"
ON public.users FOR SELECT
USING (auth.uid() = id);
```

#### media_servers 表
```sql
-- 用户可以查看自己的服务器
CREATE POLICY "Users can view own servers"
ON public.media_servers FOR SELECT
USING (auth.uid() = user_id);
```

### 6. 常见问题

#### Q: 刷新后提示"数据为空"
A: 检查以下几点：
1. 用户是否已登录（`authProvider.user != null`）
2. 数据库查询是否成功（查看日志）
3. RLS 策略是否正确

#### Q: 服务器数量显示为 0
A: 检查：
1. media_servers 表中是否有数据
2. is_active 字段是否为 true
3. user_id 是否匹配

#### Q: 刷新按钮无反应
A: 检查：
1. 是否在加载中（`authProvider.isLoading`）
2. 是否有错误日志
3. 网络连接是否正常

### 7. 临时解决方案

如果刷新功能仍然有问题，可以尝试：

1. **重新登录**：登出后重新登录
2. **清除缓存**：删除应用数据后重新登录
3. **手动同步**：在登录后手动触发同步

### 8. 代码检查清单

- [ ] `AuthProvider.refreshUser()` 正确调用 `_authService.refreshUser()`
- [ ] `AuthService.refreshUser()` 正确调用 `_repository.refreshUser()`
- [ ] `AuthRepositoryImpl.refreshUser()` 正确调用 `_fetchUserInfo()`
- [ ] `_fetchUserInfo()` 正确查询数据库
- [ ] 错误处理正确，不会吞掉异常
- [ ] 日志输出完整

### 9. 测试用例

```dart
// 测试 1：刷新成功
test('refresh user success', () async {
  final user = await authProvider.refreshUser();
  expect(user, isNotNull);
  expect(user.email, equals('test@example.com'));
});

// 测试 2：未登录时刷新
test('refresh when not logged in', () async {
  await authProvider.logout();
  await authProvider.refreshUser();
  // 应该不抛出异常，只是返回
});

// 测试 3：网络错误
test('refresh with network error', () async {
  // 模拟网络错误
  // 应该捕获异常并显示错误信息
});
```

## 修复记录

### 2026-03-02
1. 添加了更详细的错误日志
2. 改进了错误处理，统计服务器失败时使用 0
3. 在 AccountPage 添加了错误提示
4. 添加了用户数据为空的检查

## 下一步

如果问题仍然存在，请：
1. 提供完整的控制台日志
2. 提供 Supabase Dashboard 的截图
3. 提供用户 ID 和邮箱（用于调试）
