# 注册功能修复指南

## 📅 日期：2026-03-02

---

## 🎯 问题描述

用户注册时遇到错误：
- `new row violates row-level security policy for table "users"`
- `For security purposes, you can only request this after 45 seconds`

## ✅ 解决方案：使用数据库触发器

我们采用**方案 1：数据库触发器**来自动创建用户记录，避免 RLS 问题。

---

## 📋 操作步骤

### 步骤 1：执行数据库脚本

1. 打开 Supabase Dashboard
   - 访问：https://supabase.com/dashboard
   - 选择项目：coljzupoztgupdmadmnr

2. 进入 SQL Editor
   - 点击左侧菜单的 **SQL Editor**
   - 点击 **New query**

3. 执行触发器脚本
   - 打开文件：`.kiro/specs/cloud-sync/database/06_trigger_for_registration.sql`
   - 复制全部内容
   - 粘贴到 SQL Editor
   - 点击 **Run** 按钮（或按 Ctrl+Enter）

4. 验证执行结果
   - 应该看到 "Success" 消息
   - 最后会显示触发器信息

### 步骤 2：等待速率限制解除

如果你刚才尝试注册失败，需要等待 **45 秒**后再试。

Supabase 有速率限制来防止滥用：
- 注册请求：每 45 秒一次
- 这是正常的安全措施

### 步骤 3：测试注册功能

1. 运行应用
   ```bash
   cd ui/flutter_app
   flutter run -d macos
   ```

2. 点击"立即注册"

3. 填写注册信息
   - 用户名：张三（可选）
   - 邮箱：test@example.com
   - 密码：Test1234（至少 8 位，包含字母和数字）
   - 确认密码：Test1234

4. 点击"注册"按钮

5. 等待注册完成
   - 应该看到"注册成功！请查收验证邮件"
   - 自动返回登录页面

### 步骤 4：验证数据库记录

1. 在 Supabase Dashboard，点击 **Table Editor**

2. 查看 `users` 表
   - 应该能看到新用户记录
   - 包含：id, email, username, account_type 等

3. 查看 `user_settings` 表
   - 应该能看到对应的设置记录
   - user_id 与 users.id 相同

---

## 🔧 技术细节

### 触发器工作原理

```sql
-- 当用户注册时
auth.users (Supabase Auth)
  ↓ INSERT 新记录
  ↓ 触发器自动执行
  ↓
public.users (自动创建)
  - id: 从 auth.users.id 复制
  - email: 从 auth.users.email 复制
  - username: 从 raw_user_meta_data 提取
  - account_type: 'free' (默认)
  - max_servers: 10
  - max_devices: 2
  - storage_quota_mb: 100
  ↓
public.user_settings (自动创建)
  - user_id: 从 auth.users.id 复制
  - sync_enabled: true
  - sync_mode: 'supabase'
```

### 代码更新

**之前的注册流程**：
```dart
1. 调用 Supabase Auth 注册
2. 手动插入 users 表 ❌ (RLS 阻止)
3. 手动插入 user_settings 表 ❌ (RLS 阻止)
```

**现在的注册流程**：
```dart
1. 调用 Supabase Auth 注册
2. 触发器自动创建 users 和 user_settings ✅
3. 获取用户信息 ✅
```

### 更新的文件

- `ui/flutter_app/lib/features/auth/data/repositories/auth_repository_impl.dart`
  - 移除了 `_createUserRecord()` 方法
  - 简化了 `register()` 方法
  - 添加了 500ms 延迟，确保触发器执行完成

- `.kiro/specs/cloud-sync/database/06_trigger_for_registration.sql`
  - 新的触发器脚本

---

## 🐛 故障排除

### 问题 1：注册后提示"用户记录不存在"

**原因**：触发器可能没有执行成功

**解决**：
1. 检查触发器是否创建成功
   ```sql
   SELECT * FROM information_schema.triggers 
   WHERE trigger_name = 'on_auth_user_created';
   ```

2. 如果没有结果，重新执行触发器脚本

### 问题 2：仍然提示"45 seconds"错误

**原因**：速率限制还没解除

**解决**：
- 等待 45 秒后再试
- 或者使用不同的邮箱地址

### 问题 3：触发器脚本执行失败

**原因**：可能是权限问题

**解决**：
1. 确保你使用的是项目所有者账号
2. 检查 SQL 语法是否正确
3. 查看错误信息，根据提示修复

### 问题 4：注册成功但无法登录

**原因**：邮箱未验证

**解决**：
1. 检查邮箱收件箱（包括垃圾邮件）
2. 点击验证链接
3. 或者在 Supabase Dashboard 手动验证：
   - 进入 Authentication → Users
   - 找到用户，点击 "..."
   - 选择 "Confirm email"

---

## ✅ 验证清单

- [ ] 执行了触发器脚本
- [ ] 看到 "Success" 消息
- [ ] 等待了 45 秒（如果之前注册失败）
- [ ] 使用新邮箱地址测试
- [ ] 注册成功，看到成功提示
- [ ] 在 Supabase Table Editor 看到新用户记录
- [ ] users 表有记录
- [ ] user_settings 表有记录

---

## 📊 预期结果

### 注册成功后

**应用界面**：
```
✅ 注册成功！请查收验证邮件
→ 自动返回登录页面
```

**数据库 - users 表**：
```
id: abc-123-def-456
email: test@example.com
username: 张三
account_type: free
max_servers: 10
max_devices: 2
storage_quota_mb: 100
storage_used_mb: 0
device_count: 0
created_at: 2026-03-02 20:00:00
```

**数据库 - user_settings 表**：
```
user_id: abc-123-def-456
sync_enabled: true
sync_mode: supabase
created_at: 2026-03-02 20:00:00
```

---

## 🎉 完成

触发器方案的优势：
- ✅ 绕过 RLS 限制
- ✅ 自动化，无需客户端代码处理
- ✅ 更安全，使用数据库管理员权限
- ✅ 简化代码，减少出错可能

现在注册功能应该可以正常工作了！

---

**更新时间**: 2026-03-02  
**开发者**: Kiro AI Assistant  
**状态**: ✅ 已修复，等待测试
