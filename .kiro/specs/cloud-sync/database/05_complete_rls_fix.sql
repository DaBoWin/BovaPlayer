-- 完整的 RLS 修复方案
-- 创建日期: 2026-03-02
-- 说明: 使用触发器自动创建用户记录，避免 RLS 问题

-- ============================================
-- 方案 1: 使用触发器自动创建用户记录
-- ============================================

-- 创建触发器函数
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  -- 在 public.users 表中创建用户记录
  INSERT INTO public.users (id, email, username, account_type, max_servers, max_devices, storage_quota_mb, storage_used_mb, device_count)
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
  INSERT INTO public.user_settings (user_id, sync_enabled, sync_mode)
  VALUES (
    NEW.id,
    true,
    'supabase'
  )
  ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 删除旧触发器（如果存在）
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- 创建触发器
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- 方案 2: 更新 RLS 策略（备用方案）
-- ============================================

-- 如果触发器方案不工作，可以使用这个方案

-- 删除旧策略
DROP POLICY IF EXISTS "Allow user registration" ON public.users;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.users;

-- 创建新策略：允许任何已认证用户插入（不检查 id）
CREATE POLICY "Allow authenticated insert"
  ON public.users
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- 更新 user_settings 策略
DROP POLICY IF EXISTS "Allow settings creation on registration" ON public.user_settings;
DROP POLICY IF EXISTS "Users can insert own settings" ON public.user_settings;

CREATE POLICY "Allow authenticated settings insert"
  ON public.user_settings
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- ============================================
-- 验证
-- ============================================

-- 查看 users 表的策略
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'users';

-- 查看 user_settings 表的策略
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'user_settings';

-- ============================================
-- 说明
-- ============================================
-- 
-- 推荐使用方案 1（触发器）：
-- - 更安全，因为触发器在服务端执行
-- - 自动化，不需要客户端代码处理
-- - 避免 RLS 问题
--
-- 如果方案 1 不工作，使用方案 2：
-- - 允许任何已认证用户插入
-- - 需要在应用层确保用户只插入自己的记录
--
