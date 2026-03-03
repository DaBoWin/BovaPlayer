-- 修复 RLS 策略以允许用户注册
-- 创建日期: 2026-03-02
-- 说明: 允许新用户在注册时插入 users 和 user_settings 表

-- ============================================
-- 1. 删除旧的插入策略
-- ============================================

DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.users;

-- ============================================
-- 2. 创建新的插入策略（允许注册）
-- ============================================

-- 允许任何已认证的用户插入自己的记录
-- 这在注册时是必需的，因为 Supabase Auth 会先创建 auth.users 记录
-- 然后我们的代码才能插入 public.users 记录
CREATE POLICY "Allow user registration"
  ON public.users
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);

-- ============================================
-- 3. 更新 user_settings 表策略
-- ============================================

-- 删除旧策略
DROP POLICY IF EXISTS "Users can insert own settings" ON public.user_settings;

-- 创建新策略（允许注册时插入）
CREATE POLICY "Allow settings creation on registration"
  ON public.user_settings
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- ============================================
-- 完成
-- ============================================
-- 现在用户可以在注册时插入自己的记录了
