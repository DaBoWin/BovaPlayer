-- BovaPlayer 行级安全策略 (Row Level Security)
-- 创建日期: 2026-03-02
-- 说明: 确保用户只能访问自己的数据

-- ============================================
-- 1. 启用 RLS
-- ============================================

-- 用户表
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- 设备表
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;

-- 媒体服务器表
ALTER TABLE public.media_servers ENABLE ROW LEVEL SECURITY;

-- 网络连接表
ALTER TABLE public.network_connections ENABLE ROW LEVEL SECURITY;

-- 播放历史表
ALTER TABLE public.play_history ENABLE ROW LEVEL SECURITY;

-- 收藏表
ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;

-- 用户设置表
ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;

-- 订阅记录表
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

-- 同步日志表
ALTER TABLE public.sync_logs ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 2. 用户表策略
-- ============================================

-- 用户可以查看自己的信息
CREATE POLICY "Users can view own data"
  ON public.users
  FOR SELECT
  USING (auth.uid() = id);

-- 用户可以更新自己的信息
CREATE POLICY "Users can update own data"
  ON public.users
  FOR UPDATE
  USING (auth.uid() = id);

-- 允许注册时插入用户记录（通过触发器或服务端）
CREATE POLICY "Enable insert for authenticated users"
  ON public.users
  FOR INSERT
  WITH CHECK (auth.uid() = id);

-- ============================================
-- 3. 设备表策略
-- ============================================

-- 用户可以查看自己的设备
CREATE POLICY "Users can view own devices"
  ON public.devices
  FOR SELECT
  USING (auth.uid() = user_id);

-- 用户可以添加自己的设备
CREATE POLICY "Users can insert own devices"
  ON public.devices
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- 用户可以更新自己的设备
CREATE POLICY "Users can update own devices"
  ON public.devices
  FOR UPDATE
  USING (auth.uid() = user_id);

-- 用户可以删除自己的设备
CREATE POLICY "Users can delete own devices"
  ON public.devices
  FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================
-- 4. 媒体服务器表策略
-- ============================================

-- 用户可以查看自己的服务器
CREATE POLICY "Users can view own servers"
  ON public.media_servers
  FOR SELECT
  USING (auth.uid() = user_id);

-- 用户可以添加自己的服务器
CREATE POLICY "Users can insert own servers"
  ON public.media_servers
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- 用户可以更新自己的服务器
CREATE POLICY "Users can update own servers"
  ON public.media_servers
  FOR UPDATE
  USING (auth.uid() = user_id);

-- 用户可以删除自己的服务器
CREATE POLICY "Users can delete own servers"
  ON public.media_servers
  FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================
-- 5. 网络连接表策略
-- ============================================

-- 用户可以查看自己的网络连接
CREATE POLICY "Users can view own connections"
  ON public.network_connections
  FOR SELECT
  USING (auth.uid() = user_id);

-- 用户可以添加自己的网络连接
CREATE POLICY "Users can insert own connections"
  ON public.network_connections
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- 用户可以更新自己的网络连接
CREATE POLICY "Users can update own connections"
  ON public.network_connections
  FOR UPDATE
  USING (auth.uid() = user_id);

-- 用户可以删除自己的网络连接
CREATE POLICY "Users can delete own connections"
  ON public.network_connections
  FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================
-- 6. 播放历史表策略
-- ============================================

-- 用户可以查看自己的播放历史
CREATE POLICY "Users can view own history"
  ON public.play_history
  FOR SELECT
  USING (auth.uid() = user_id);

-- 用户可以添加自己的播放历史
CREATE POLICY "Users can insert own history"
  ON public.play_history
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- 用户可以更新自己的播放历史
CREATE POLICY "Users can update own history"
  ON public.play_history
  FOR UPDATE
  USING (auth.uid() = user_id);

-- 用户可以删除自己的播放历史
CREATE POLICY "Users can delete own history"
  ON public.play_history
  FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================
-- 7. 收藏表策略
-- ============================================

-- 用户可以查看自己的收藏
CREATE POLICY "Users can view own favorites"
  ON public.favorites
  FOR SELECT
  USING (auth.uid() = user_id);

-- 用户可以添加自己的收藏
CREATE POLICY "Users can insert own favorites"
  ON public.favorites
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- 用户可以删除自己的收藏
CREATE POLICY "Users can delete own favorites"
  ON public.favorites
  FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================
-- 8. 用户设置表策略
-- ============================================

-- 用户可以查看自己的设置
CREATE POLICY "Users can view own settings"
  ON public.user_settings
  FOR SELECT
  USING (auth.uid() = user_id);

-- 用户可以插入自己的设置
CREATE POLICY "Users can insert own settings"
  ON public.user_settings
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- 用户可以更新自己的设置
CREATE POLICY "Users can update own settings"
  ON public.user_settings
  FOR UPDATE
  USING (auth.uid() = user_id);

-- ============================================
-- 9. 订阅记录表策略
-- ============================================

-- 用户可以查看自己的订阅记录
CREATE POLICY "Users can view own subscriptions"
  ON public.subscriptions
  FOR SELECT
  USING (auth.uid() = user_id);

-- 只允许通过服务端插入订阅记录（支付回调）
-- 用户不能直接插入订阅记录

-- ============================================
-- 10. 同步日志表策略
-- ============================================

-- 用户可以查看自己的同步日志
CREATE POLICY "Users can view own sync logs"
  ON public.sync_logs
  FOR SELECT
  USING (auth.uid() = user_id);

-- 用户可以插入自己的同步日志
CREATE POLICY "Users can insert own sync logs"
  ON public.sync_logs
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- ============================================
-- 完成
-- ============================================
-- RLS 策略配置完成
-- 现在所有表都受到行级安全保护
-- 用户只能访问自己的数据
