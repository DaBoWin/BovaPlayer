-- 更新媒体服务器表结构
-- 将加密字段从 access_token_encrypted 改为 password_encrypted
-- 添加 username 字段
-- 创建日期: 2026-03-03

-- 1. 添加新字段
ALTER TABLE public.media_servers 
  ADD COLUMN IF NOT EXISTS username VARCHAR(100),
  ADD COLUMN IF NOT EXISTS password_encrypted TEXT;

-- 2. 更新注释
COMMENT ON COLUMN public.media_servers.username IS '媒体服务器用户名（明文）';
COMMENT ON COLUMN public.media_servers.password_encrypted IS '使用用户密码加密的服务器密码';

-- 3. 可选：如果需要删除旧字段（谨慎操作，会丢失数据）
-- ALTER TABLE public.media_servers DROP COLUMN IF EXISTS access_token_encrypted;

-- 4. 更新表注释
COMMENT ON TABLE public.media_servers IS '媒体服务器列表 - 存储加密的密码而非 access_token';

-- 完成
-- 说明：
-- - username: 存储明文用户名
-- - password_encrypted: 存储使用用户密码加密的服务器密码
-- - 跨设备同步时，使用用户密码解密后可直接登录媒体服务器
