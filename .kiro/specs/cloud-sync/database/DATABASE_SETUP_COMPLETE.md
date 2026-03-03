# ✅ 数据库设置完成指南

## 🎉 第一步已完成！

你已经成功执行了 `01_create_tables.sql`，所有 9 张表都已创建。

---

## ⚠️ 重要：还需要执行 2 个脚本

### 为什么需要执行这些脚本？

1. **RLS 策略脚本** - 保护数据安全
   - 当前所有表都显示 "UNRESTRICTED"（未受限）
   - 这意味着任何人都可以访问所有数据 ❌
   - 执行 RLS 脚本后，用户只能访问自己的数据 ✅

2. **索引脚本** - 优化查询性能
   - 加快数据查询速度
   - 提升应用响应速度
   - 减少数据库负载

---

## 📋 执行步骤

### Step 1: 执行 RLS 策略脚本（必需）⭐

1. **打开 Supabase Dashboard**
   - https://supabase.com/dashboard
   - 选择你的项目（coljzupoztgupdmadmnr）

2. **进入 SQL Editor**
   - 点击左侧的 **SQL Editor**
   - 点击 **New query**

3. **复制并执行脚本**
   - 打开文件：`.kiro/specs/cloud-sync/database/02_create_rls_policies.sql`
   - 复制全部内容
   - 粘贴到 SQL Editor
   - 点击 **Run** 按钮

4. **验证结果**
   - 返回 **Table Editor**
   - 刷新页面
   - 所有表的 "UNRESTRICTED" 标签应该消失
   - 表名旁边应该显示 🔒 锁图标

### Step 2: 执行索引脚本（推荐）

1. **在 SQL Editor 中创建新查询**
   - 点击 **New query**

2. **复制并执行脚本**
   - 打开文件：`.kiro/specs/cloud-sync/database/03_create_indexes.sql`
   - 复制全部内容
   - 粘贴到 SQL Editor
   - 点击 **Run** 按钮

3. **验证结果**
   - 执行成功后会显示 "Success"
   - 索引已创建，查询性能已优化

---

## 🔍 验证清单

执行完所有脚本后，检查以下内容：

### 表结构验证
- [ ] 9 张表都已创建
- [ ] 所有表都有 RLS 保护（不再显示 UNRESTRICTED）
- [ ] 可以在 Table Editor 中查看表结构

### RLS 策略验证
```sql
-- 在 SQL Editor 中运行此查询
SELECT schemaname, tablename, policyname 
FROM pg_policies 
WHERE schemaname = 'public'
ORDER BY tablename, policyname;
```

应该看到每张表都有多个策略（SELECT, INSERT, UPDATE, DELETE）

### 索引验证
```sql
-- 在 SQL Editor 中运行此查询
SELECT 
  tablename,
  indexname,
  indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;
```

应该看到大量索引已创建

---

## 📊 数据库架构总览

### 核心表（9 张）

| 表名 | 用途 | RLS 状态 | 索引数量 |
|------|------|---------|---------|
| **users** | 用户信息 | ✅ 已保护 | 3 个 |
| **devices** | 用户设备 | ✅ 已保护 | 4 个 |
| **media_servers** | 媒体服务器 | ✅ 已保护 | 6 个 |
| **network_connections** | 网络连接 | ✅ 已保护 | 6 个 |
| **play_history** | 播放历史 | ✅ 已保护 | 8 个 |
| **favorites** | 收藏列表 | ✅ 已保护 | 6 个 |
| **user_settings** | 用户设置 | ✅ 已保护 | 3 个 |
| **subscriptions** | 订阅记录 | ✅ 已保护 | 7 个 |
| **sync_logs** | 同步日志 | ✅ 已保护 | 8 个 |

### RLS 策略总数
- **用户表**: 3 个策略（SELECT, UPDATE, INSERT）
- **其他表**: 每张表 4 个策略（SELECT, INSERT, UPDATE, DELETE）
- **总计**: 约 35 个 RLS 策略

### 索引总数
- **单列索引**: 约 40 个
- **复合索引**: 约 15 个
- **全文搜索索引**: 3 个
- **总计**: 约 58 个索引

---

## 🔒 安全特性

### RLS 保护机制

执行 RLS 脚本后，以下安全规则生效：

1. **用户隔离**
   - 用户 A 无法看到用户 B 的数据
   - 所有查询自动过滤 `user_id`

2. **自动验证**
   - 插入数据时自动验证 `user_id`
   - 更新/删除时自动检查权限

3. **防止越权**
   - 无法修改其他用户的数据
   - 无法删除其他用户的记录

### 示例

```sql
-- 用户 A 登录后执行
SELECT * FROM media_servers;
-- 只返回用户 A 的服务器

-- 用户 A 尝试访问用户 B 的数据
SELECT * FROM media_servers WHERE user_id = 'user-b-id';
-- 返回空结果（被 RLS 阻止）
```

---

## 🚀 性能优化

### 索引优化的查询

执行索引脚本后，以下查询将显著加速：

1. **继续观看列表**
   ```sql
   SELECT * FROM play_history 
   WHERE user_id = 'xxx' 
   ORDER BY last_played_at DESC 
   LIMIT 10;
   ```
   - 使用索引：`idx_play_history_user_played`
   - 性能提升：10-100 倍

2. **服务器列表**
   ```sql
   SELECT * FROM media_servers 
   WHERE user_id = 'xxx' AND is_active = true;
   ```
   - 使用索引：`idx_media_servers_user_active`
   - 性能提升：5-50 倍

3. **收藏列表**
   ```sql
   SELECT * FROM favorites 
   WHERE user_id = 'xxx' 
   ORDER BY created_at DESC;
   ```
   - 使用索引：`idx_favorites_user_created`
   - 性能提升：10-100 倍

---

## 🧪 测试数据库

### 创建测试用户

```sql
-- 在 SQL Editor 中执行
INSERT INTO public.users (
  id,
  email,
  username,
  account_type,
  max_servers,
  max_devices,
  storage_quota_mb
) VALUES (
  'test-user-id-123',
  'test@example.com',
  'testuser',
  'free',
  10,
  2,
  100
);
```

### 创建测试服务器

```sql
INSERT INTO public.media_servers (
  user_id,
  server_type,
  name,
  url,
  is_active
) VALUES (
  'test-user-id-123',
  'emby',
  '测试服务器',
  'https://emby.example.com',
  true
);
```

### 查询测试数据

```sql
-- 查看用户
SELECT * FROM users WHERE email = 'test@example.com';

-- 查看服务器
SELECT * FROM media_servers WHERE user_id = 'test-user-id-123';
```

---

## ❌ 常见问题

### Q: RLS 脚本执行失败？

**错误**: `policy "xxx" for table "xxx" already exists`

**解决**:
```sql
-- 删除现有策略
DROP POLICY IF EXISTS "policy_name" ON table_name;

-- 然后重新执行 RLS 脚本
```

### Q: 索引脚本执行失败？

**错误**: `relation "idx_xxx" already exists`

**解决**:
```sql
-- 删除现有索引
DROP INDEX IF EXISTS idx_xxx;

-- 然后重新执行索引脚本
```

### Q: 表仍然显示 UNRESTRICTED？

**原因**: RLS 脚本未成功执行

**解决**:
1. 检查 SQL Editor 的错误信息
2. 确保完整执行了 RLS 脚本
3. 刷新 Table Editor 页面

---

## 📚 下一步

数据库设置完成后：

1. ✅ **运行安装脚本**
   ```bash
   cd ui/flutter_app
   ./setup_cloud_sync.sh
   ```

2. ✅ **配置认证**
   - 在 Supabase Dashboard 启用 Email 认证
   - （可选）配置 GitHub OAuth

3. ✅ **运行应用**
   ```bash
   flutter run
   ```

4. ✅ **测试功能**
   - 注册新用户
   - 登录
   - 查看数据库中的用户记录

---

## 📞 需要帮助？

如果遇到问题：

1. 查看 SQL Editor 的错误信息
2. 检查脚本是否完整执行
3. 参考 Supabase 文档：https://supabase.com/docs
4. 查看项目文档：`SUPABASE_SETUP_GUIDE.md`

---

**数据库设置状态**: ⏳ 等待执行 RLS 和索引脚本  
**下一步**: 执行 `02_create_rls_policies.sql` 和 `03_create_indexes.sql`  
**预计时间**: 5 分钟

