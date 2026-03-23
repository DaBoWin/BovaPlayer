-- BovaPlayer 云同步数据库表结构
-- 创建日期: 2026-03-02
-- 数据库: PostgreSQL 15+
-- 说明: 在 Supabase SQL Editor 中执行此脚本

-- 启用 UUID 扩展
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- 1. 用户表 (users)
-- ============================================
-- 说明: 扩展 Supabase Auth 的用户信息
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email VARCHAR(255) UNIQUE NOT NULL,
  username VARCHAR(50),
  avatar_url TEXT,
  
  -- 账号类型
  account_type VARCHAR(20) DEFAULT 'free' CHECK (account_type IN ('free', 'pro', 'lifetime')),
  pro_expires_at TIMESTAMP WITH TIME ZONE,
  
  -- 限额
  max_servers INTEGER DEFAULT 10,
  max_devices INTEGER DEFAULT 2,
  storage_quota_mb INTEGER DEFAULT 100,
  
  -- 统计
  storage_used_mb INTEGER DEFAULT 0,
  device_count INTEGER DEFAULT 0,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE public.users IS '用户信息表';
COMMENT ON COLUMN public.users.account_type IS '账号类型: free, pro, lifetime';
COMMENT ON COLUMN public.users.pro_expires_at IS 'Pro 账号到期时间';

-- ============================================
-- 2. 设备表 (devices)
-- ============================================
CREATE TABLE IF NOT EXISTS public.devices (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  
  device_name VARCHAR(100) NOT NULL,
  device_type VARCHAR(20) NOT NULL CHECK (device_type IN ('android', 'ios', 'windows', 'macos', 'linux')),
  device_id VARCHAR(255) NOT NULL,
  
  last_active_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  UNIQUE(user_id, device_id)
);

COMMENT ON TABLE public.devices IS '用户设备表';
COMMENT ON COLUMN public.devices.device_id IS '设备唯一标识（UUID 或设备指纹）';

-- ============================================
-- 3. 媒体服务器表 (media_servers)
-- ============================================
CREATE TABLE IF NOT EXISTS public.media_servers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  
  server_type VARCHAR(20) NOT NULL CHECK (server_type IN ('emby', 'jellyfin', 'plex')),
  name VARCHAR(100) NOT NULL,
  url TEXT NOT NULL,
  
  -- 加密的认证信息
  access_token_encrypted TEXT,
  user_id_server VARCHAR(100),
  
  is_active BOOLEAN DEFAULT true,
  last_synced_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE public.media_servers IS '媒体服务器列表';
COMMENT ON COLUMN public.media_servers.access_token_encrypted IS 'AES-256 加密的访问令牌';
COMMENT ON COLUMN public.media_servers.user_id_server IS '媒体服务器上的用户 ID';

-- ============================================
-- 4. 网络连接表 (network_connections)
-- ============================================
CREATE TABLE IF NOT EXISTS public.network_connections (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  
  protocol VARCHAR(20) NOT NULL CHECK (protocol IN ('smb', 'ftp')),
  name VARCHAR(100) NOT NULL,
  host VARCHAR(255) NOT NULL,
  port INTEGER NOT NULL,
  
  -- 注意: 密码不存储，仅存储连接元数据
  username VARCHAR(100),
  share_name VARCHAR(100), -- SMB only
  workgroup VARCHAR(100),  -- SMB only
  
  is_active BOOLEAN DEFAULT true,
  last_used_at TIMESTAMP WITH TIME ZONE,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE public.network_connections IS '网络连接元数据（不含密码）';
COMMENT ON COLUMN public.network_connections.username IS '用户名（明文，密码仅本地存储）';

-- ============================================
-- 5. 播放历史表 (play_history)
-- ============================================
CREATE TABLE IF NOT EXISTS public.play_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  server_id UUID REFERENCES public.media_servers(id) ON DELETE CASCADE,
  
  item_id VARCHAR(100) NOT NULL,
  item_name TEXT NOT NULL,
  item_type VARCHAR(20) NOT NULL CHECK (item_type IN ('movie', 'episode', 'video', 'music')),
  
  -- 播放位置
  position_seconds INTEGER NOT NULL DEFAULT 0,
  duration_seconds INTEGER NOT NULL DEFAULT 0,
  progress_percent DECIMAL(5,2) DEFAULT 0,
  
  -- 元数据
  thumbnail_url TEXT,
  season_number INTEGER,
  episode_number INTEGER,
  
  last_played_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  UNIQUE(user_id, server_id, item_id)
);

COMMENT ON TABLE public.play_history IS '播放历史记录';
COMMENT ON COLUMN public.play_history.progress_percent IS '播放进度百分比 (0-100)';

-- ============================================
-- 6. 收藏表 (favorites)
-- ============================================
CREATE TABLE IF NOT EXISTS public.favorites (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  server_id UUID REFERENCES public.media_servers(id) ON DELETE CASCADE,
  
  item_id VARCHAR(100) NOT NULL,
  item_name TEXT NOT NULL,
  item_type VARCHAR(20) NOT NULL CHECK (item_type IN ('movie', 'series', 'episode', 'video', 'music')),
  thumbnail_url TEXT,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  UNIQUE(user_id, server_id, item_id)
);

COMMENT ON TABLE public.favorites IS '用户收藏列表';

-- ============================================
-- 7. 用户设置表 (user_settings)
-- ============================================
CREATE TABLE IF NOT EXISTS public.user_settings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE UNIQUE,
  
  -- 设置 JSON
  settings_json JSONB DEFAULT '{}',
  
  -- 同步配置
  sync_enabled BOOLEAN DEFAULT true,
  sync_mode VARCHAR(20) DEFAULT 'supabase' CHECK (sync_mode IN ('supabase', 'github')),
  github_repo VARCHAR(255), -- Pro/Lifetime only
  
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE public.user_settings IS '用户设置和同步配置';
COMMENT ON COLUMN public.user_settings.settings_json IS '播放器设置、主题等（JSONB 格式）';
COMMENT ON COLUMN public.user_settings.github_repo IS 'GitHub 仓库名称（格式: username/repo）';

-- ============================================
-- 8. 订阅记录表 (subscriptions)
-- ============================================
CREATE TABLE IF NOT EXISTS public.subscriptions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,

  subscription_type VARCHAR(32) NOT NULL CHECK (
    subscription_type IN (
      'pro_monthly', 'pro_yearly', 'lifetime',
      'redeem_pro', 'redeem_lifetime',
      'manual_pro', 'manual_lifetime'
    )
  ),
  status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('pending', 'active', 'expired', 'cancelled', 'failed')),

  -- 来源 / 支付信息
  payment_method VARCHAR(50) CHECK (payment_method IN ('alipay', 'wechat', 'stripe', 'paypal', 'redeem_code', 'manual')),
  source_type VARCHAR(30) NOT NULL DEFAULT 'payment' CHECK (source_type IN ('payment', 'redeem_code', 'manual')),
  source_id UUID,
  merchant_order_id VARCHAR(255),
  transaction_id VARCHAR(255),
  amount_cny DECIMAL(10,2) NOT NULL DEFAULT 0,
  currency VARCHAR(10) NOT NULL DEFAULT 'CNY',
  metadata JSONB NOT NULL DEFAULT '{}',

  started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE,
  cancelled_at TIMESTAMP WITH TIME ZONE,

  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE public.subscriptions IS '订阅记录和支付/兑换台账';
COMMENT ON COLUMN public.subscriptions.amount_cny IS '支付金额（人民币）';
COMMENT ON COLUMN public.subscriptions.source_type IS '来源类型: payment, redeem_code, manual';

-- ============================================
-- 9. 兑换日志表 (redemption_logs)
-- ============================================
CREATE TABLE IF NOT EXISTS public.redemption_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  redemption_code_id UUID NOT NULL REFERENCES public.redemption_codes(id) ON DELETE CASCADE,
  code TEXT NOT NULL,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  subscription_id UUID REFERENCES public.subscriptions(id) ON DELETE SET NULL,

  code_type VARCHAR(20) NOT NULL CHECK (code_type IN ('pro', 'lifetime')),
  granted_account_type VARCHAR(20) NOT NULL CHECK (granted_account_type IN ('pro', 'lifetime')),
  granted_duration_days INTEGER,
  previous_account_type VARCHAR(20),
  previous_expires_at TIMESTAMP WITH TIME ZONE,
  new_expires_at TIMESTAMP WITH TIME ZONE,

  metadata JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE public.redemption_logs IS '兑换码兑换日志，可追溯到订阅台账';

-- ============================================
-- 10. 同步日志表 (sync_logs)
-- ============================================
CREATE TABLE IF NOT EXISTS public.sync_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  device_id UUID REFERENCES public.devices(id) ON DELETE SET NULL,
  
  sync_type VARCHAR(50) NOT NULL,
  sync_direction VARCHAR(10) NOT NULL CHECK (sync_direction IN ('upload', 'download')),
  status VARCHAR(20) NOT NULL CHECK (status IN ('success', 'failed', 'partial')),
  
  items_count INTEGER DEFAULT 0,
  error_message TEXT,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE public.sync_logs IS '同步操作日志';
COMMENT ON COLUMN public.sync_logs.sync_type IS '同步类型: servers, history, favorites, settings';

-- ============================================
-- 触发器: 自动更新 updated_at
-- ============================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 应用到需要的表
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_media_servers_updated_at BEFORE UPDATE ON public.media_servers
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_network_connections_updated_at BEFORE UPDATE ON public.network_connections
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_settings_updated_at BEFORE UPDATE ON public.user_settings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 完成
-- ============================================
-- 所有表创建完成
-- 下一步: 执行 02_create_indexes.sql
