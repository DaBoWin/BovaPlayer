# 账号页面使用量统计修复

## 问题描述
用户反馈账号信息页面的使用量数据不正确：
- 服务器数量显示 0/10，实际已添加 2 个服务器
- 设备数量显示 0/2，实际已有 1 个设备登录
- 存储空间显示 0.0 MB / 100 MB，没有数据

## 根本原因
1. `users` 表中没有 `server_count` 字段，需要从 `media_servers` 表实时统计
2. `device_count` 字段可能没有正确更新
3. 获取用户信息时没有联合查询相关统计数据

## 解决方案

### 1. 修改 AuthRepositoryImpl._fetchUserInfo()
```dart
// 修改前：只查询 users 表
final data = await _supabase
    .from('users')
    .select()
    .eq('id', userId)
    .single();

// 修改后：联合查询统计数据
final userData = await _supabase
    .from('users')
    .select()
    .eq('id', userId)
    .single();

// 统计服务器数量
final serverCountResult = await _supabase
    .from('media_servers')
    .select('id', const FetchOptions(count: CountOption.exact))
    .eq('user_id', userId)
    .eq('is_active', true);

final serverCount = serverCountResult.count ?? 0;

// 合并数据
final enrichedData = {
  ...userData,
  'server_count': serverCount,
};
```

### 2. 添加刷新功能
在 AccountPage 的 AppBar 添加刷新按钮：
- 点击刷新按钮重新获取用户数据
- 显示加载指示器
- 刷新完成后显示提示

### 3. UI 优化
- 统一设计风格，匹配 media_library_page
- 背景色：#F5F5F5
- 卡片背景：白色
- 主色调：#1F2937
- 添加渐变图标和阴影效果

## 数据库表结构

### users 表
```sql
CREATE TABLE public.users (
  id UUID PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  username VARCHAR(50),
  avatar_url TEXT,
  account_type VARCHAR(20) DEFAULT 'free',
  pro_expires_at TIMESTAMP WITH TIME ZONE,
  max_servers INTEGER DEFAULT 10,
  max_devices INTEGER DEFAULT 2,
  storage_quota_mb INTEGER DEFAULT 100,
  storage_used_mb INTEGER DEFAULT 0,  -- ✓ 存在
  device_count INTEGER DEFAULT 0,      -- ✓ 存在
  -- server_count 不存在，需要从 media_servers 统计
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### media_servers 表
```sql
CREATE TABLE public.media_servers (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES public.users(id),
  server_type VARCHAR(20) NOT NULL,
  name VARCHAR(100) NOT NULL,
  url TEXT NOT NULL,
  is_active BOOLEAN DEFAULT true,
  ...
);
```

## 后续优化建议

### 1. 自动更新 device_count
创建触发器，当 devices 表有变化时自动更新 users.device_count：

```sql
CREATE OR REPLACE FUNCTION update_user_device_count()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.users
  SET device_count = (
    SELECT COUNT(*) FROM public.devices WHERE user_id = NEW.user_id
  )
  WHERE id = NEW.user_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_device_count_on_insert
AFTER INSERT ON public.devices
FOR EACH ROW EXECUTE FUNCTION update_user_device_count();

CREATE TRIGGER update_device_count_on_delete
AFTER DELETE ON public.devices
FOR EACH ROW EXECUTE FUNCTION update_user_device_count();
```

### 2. 添加 server_count 字段（可选）
如果频繁查询，可以在 users 表添加 server_count 字段并用触发器维护：

```sql
ALTER TABLE public.users ADD COLUMN server_count INTEGER DEFAULT 0;

CREATE OR REPLACE FUNCTION update_user_server_count()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.users
  SET server_count = (
    SELECT COUNT(*) FROM public.media_servers 
    WHERE user_id = COALESCE(NEW.user_id, OLD.user_id) AND is_active = true
  )
  WHERE id = COALESCE(NEW.user_id, OLD.user_id);
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_server_count_on_change
AFTER INSERT OR UPDATE OR DELETE ON public.media_servers
FOR EACH ROW EXECUTE FUNCTION update_user_server_count();
```

### 3. 缓存优化
- 在 AuthProvider 中缓存用户数据
- 定期自动刷新（如每 5 分钟）
- 在添加/删除服务器后自动刷新

## 测试步骤

1. 登录账号
2. 添加 Emby/SMB/FTP 服务器
3. 打开账号信息页面
4. 验证服务器数量是否正确显示
5. 点击刷新按钮
6. 验证数据是否更新

## 文件修改清单

- ✅ `ui/flutter_app/lib/features/auth/data/repositories/auth_repository_impl.dart`
  - 修改 `_fetchUserInfo()` 方法，添加服务器数量统计
  
- ✅ `ui/flutter_app/lib/features/auth/presentation/pages/account_page.dart`
  - 更新 UI 设计，匹配统一风格
  - 添加刷新按钮
  - 添加加载指示器

## 注意事项

1. 设备数量统计依赖 `devices` 表，需要确保设备登录时正确插入记录
2. 存储空间统计需要在上传数据时更新 `storage_used_mb` 字段
3. 当前实现每次刷新都会查询数据库，如果用户频繁刷新可能影响性能

## 完成时间
2026-03-02
