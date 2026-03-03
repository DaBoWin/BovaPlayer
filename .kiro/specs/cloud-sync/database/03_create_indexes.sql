-- BovaPlayer 数据库索引
-- 创建日期: 2026-03-02
-- 说明: 优化查询性能

-- ============================================
-- 1. 用户表索引
-- ============================================

-- 邮箱索引（已有 UNIQUE 约束，自动创建索引）
-- CREATE INDEX idx_users_email ON public.users(email);

-- 账号类型索引（用于统计）
CREATE INDEX idx_users_account_type ON public.users(account_type);

-- 创建时间索引（用于排序）
CREATE INDEX idx_users_created_at ON public.users(created_at DESC);

-- ============================================
-- 2. 设备表索引
-- ============================================

-- 用户 ID 索引（最常用的查询）
CREATE INDEX idx_devices_user_id ON public.devices(user_id);

-- 设备 ID 索引（已有 UNIQUE 约束）
-- CREATE INDEX idx_devices_device_id ON public.devices(device_id);

-- 最后活跃时间索引
CREATE INDEX idx_devices_last_active ON public.devices(last_active_at DESC);

-- 复合索引：用户 + 设备类型
CREATE INDEX idx_devices_user_type ON public.devices(user_id, device_type);

-- ============================================
-- 3. 媒体服务器表索引
-- ============================================

-- 用户 ID 索引
CREATE INDEX idx_media_servers_user_id ON public.media_servers(user_id);

-- 服务器类型索引
CREATE INDEX idx_media_servers_type ON public.media_servers(server_type);

-- 活跃状态索引
CREATE INDEX idx_media_servers_active ON public.media_servers(is_active);

-- 复合索引：用户 + 活跃状态
CREATE INDEX idx_media_servers_user_active ON public.media_servers(user_id, is_active);

-- 最后同步时间索引
CREATE INDEX idx_media_servers_synced ON public.media_servers(last_synced_at DESC);

-- ============================================
-- 4. 网络连接表索引
-- ============================================

-- 用户 ID 索引
CREATE INDEX idx_network_connections_user_id ON public.network_connections(user_id);

-- 协议类型索引
CREATE INDEX idx_network_connections_protocol ON public.network_connections(protocol);

-- 活跃状态索引
CREATE INDEX idx_network_connections_active ON public.network_connections(is_active);

-- 复合索引：用户 + 协议
CREATE INDEX idx_network_connections_user_protocol ON public.network_connections(user_id, protocol);

-- 最后使用时间索引
CREATE INDEX idx_network_connections_last_used ON public.network_connections(last_used_at DESC);

-- ============================================
-- 5. 播放历史表索引
-- ============================================

-- 用户 ID 索引
CREATE INDEX idx_play_history_user_id ON public.play_history(user_id);

-- 服务器 ID 索引
CREATE INDEX idx_play_history_server_id ON public.play_history(server_id);

-- 媒体项 ID 索引
CREATE INDEX idx_play_history_item_id ON public.play_history(item_id);

-- 最后播放时间索引（最重要，用于"继续观看"）
CREATE INDEX idx_play_history_last_played ON public.play_history(last_played_at DESC);

-- 复合索引：用户 + 最后播放时间
CREATE INDEX idx_play_history_user_played ON public.play_history(user_id, last_played_at DESC);

-- 复合索引：用户 + 服务器 + 媒体项（已有 UNIQUE 约束）
-- CREATE INDEX idx_play_history_user_server_item ON public.play_history(user_id, server_id, item_id);

-- 媒体类型索引
CREATE INDEX idx_play_history_item_type ON public.play_history(item_type);

-- 进度百分比索引（用于查找未看完的）
CREATE INDEX idx_play_history_progress ON public.play_history(progress_percent);

-- ============================================
-- 6. 收藏表索引
-- ============================================

-- 用户 ID 索引
CREATE INDEX idx_favorites_user_id ON public.favorites(user_id);

-- 服务器 ID 索引
CREATE INDEX idx_favorites_server_id ON public.favorites(server_id);

-- 媒体项 ID 索引
CREATE INDEX idx_favorites_item_id ON public.favorites(item_id);

-- 创建时间索引
CREATE INDEX idx_favorites_created_at ON public.favorites(created_at DESC);

-- 复合索引：用户 + 创建时间
CREATE INDEX idx_favorites_user_created ON public.favorites(user_id, created_at DESC);

-- 媒体类型索引
CREATE INDEX idx_favorites_item_type ON public.favorites(item_type);

-- ============================================
-- 7. 用户设置表索引
-- ============================================

-- 用户 ID 索引（已有 UNIQUE 约束）
-- CREATE INDEX idx_user_settings_user_id ON public.user_settings(user_id);

-- 同步模式索引
CREATE INDEX idx_user_settings_sync_mode ON public.user_settings(sync_mode);

-- 同步启用状态索引
CREATE INDEX idx_user_settings_sync_enabled ON public.user_settings(sync_enabled);

-- ============================================
-- 8. 订阅记录表索引
-- ============================================

-- 用户 ID 索引
CREATE INDEX idx_subscriptions_user_id ON public.subscriptions(user_id);

-- 订阅类型索引
CREATE INDEX idx_subscriptions_type ON public.subscriptions(subscription_type);

-- 状态索引
CREATE INDEX idx_subscriptions_status ON public.subscriptions(status);

-- 到期时间索引
CREATE INDEX idx_subscriptions_expires ON public.subscriptions(expires_at);

-- 复合索引：用户 + 状态
CREATE INDEX idx_subscriptions_user_status ON public.subscriptions(user_id, status);

-- 复合索引：状态 + 到期时间（用于查找即将过期的订阅）
CREATE INDEX idx_subscriptions_status_expires ON public.subscriptions(status, expires_at);

-- 创建时间索引
CREATE INDEX idx_subscriptions_created_at ON public.subscriptions(created_at DESC);

-- ============================================
-- 9. 同步日志表索引
-- ============================================

-- 用户 ID 索引
CREATE INDEX idx_sync_logs_user_id ON public.sync_logs(user_id);

-- 设备 ID 索引
CREATE INDEX idx_sync_logs_device_id ON public.sync_logs(device_id);

-- 同步类型索引
CREATE INDEX idx_sync_logs_type ON public.sync_logs(sync_type);

-- 同步方向索引
CREATE INDEX idx_sync_logs_direction ON public.sync_logs(sync_direction);

-- 状态索引
CREATE INDEX idx_sync_logs_status ON public.sync_logs(status);

-- 创建时间索引
CREATE INDEX idx_sync_logs_created_at ON public.sync_logs(created_at DESC);

-- 复合索引：用户 + 创建时间
CREATE INDEX idx_sync_logs_user_created ON public.sync_logs(user_id, created_at DESC);

-- 复合索引：用户 + 同步类型 + 状态
CREATE INDEX idx_sync_logs_user_type_status ON public.sync_logs(user_id, sync_type, status);

-- ============================================
-- 10. 全文搜索索引（可选）
-- ============================================

-- 媒体服务器名称全文搜索
CREATE INDEX idx_media_servers_name_gin ON public.media_servers 
  USING gin(to_tsvector('english', name));

-- 播放历史媒体名称全文搜索
CREATE INDEX idx_play_history_name_gin ON public.play_history 
  USING gin(to_tsvector('english', item_name));

-- 收藏媒体名称全文搜索
CREATE INDEX idx_favorites_name_gin ON public.favorites 
  USING gin(to_tsvector('english', item_name));

-- ============================================
-- 完成
-- ============================================
-- 索引创建完成
-- 查询性能已优化
