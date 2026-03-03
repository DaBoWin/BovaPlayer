-- 使用触发器自动创建用户记录
-- 创建日期: 2026-03-02
-- 说明: 当用户在 Supabase Auth 注册时，自动在 public.users 和 public.user_settings 创建记录

-- ============================================
-- 1. 创建触发器函数
-- ============================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  -- 在 public.users 表中创建用户记录
  INSERT INTO public.users (
    id, 
    email, 
    username, 
    account_type, 
    max_servers, 
    max_devices, 
    storage_quota_mb, 
    storage_used_mb, 
    device_count
  )
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'username', NULL),
    'free',
    10,
    2,
    100,
    0,
    0
  )
  ON CONFLICT (id) DO NOTHING;

  -- 在 public.user_settings 表中创建设置记录
  INSERT INTO public.user_settings (
    user_id, 
    sync_enabled, 
    sync_mode
  )
  VALUES (
    NEW.id,
    true,
    'supabase'
  )
  ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 2. 创建触发器
-- ============================================

-- 删除旧触发器（如果存在）
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- 创建新触发器
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- 3. 验证触发器
-- ============================================

-- 查看触发器是否创建成功
SELECT 
  trigger_name,
  event_manipulation,
  event_object_table,
  action_statement
FROM information_schema.triggers
WHERE trigger_name = 'on_auth_user_created';

-- ============================================
-- 完成
-- ============================================
-- 
-- 触发器已创建！
-- 
-- 工作原理：
-- 1. 用户通过 Supabase Auth 注册
-- 2. auth.users 表插入新记录
-- 3. 触发器自动执行
-- 4. 在 public.users 创建用户记录
-- 5. 在 public.user_settings 创建设置记录
-- 
-- 注意：
-- - 触发器使用 SECURITY DEFINER，以管理员权限运行
-- - 不受 RLS 策略限制
-- - 用户名从 raw_user_meta_data 中提取
-- - 使用 ON CONFLICT DO NOTHING 避免重复插入
--
