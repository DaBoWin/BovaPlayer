-- ============================================
-- 兑换码系统 - Supabase SQL 迁移脚本
-- 在 Supabase Dashboard > SQL Editor 中执行
-- ============================================

-- 0. 给 users 表添加 is_admin 字段（如果还没有）
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT FALSE;

-- 1. 创建 redemption_codes 表
CREATE TABLE IF NOT EXISTS public.redemption_codes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    code_type TEXT NOT NULL CHECK (code_type IN ('pro', 'lifetime')),
    duration_days INT, -- Pro 码的有效天数，lifetime 为 NULL
    is_used BOOLEAN DEFAULT FALSE,
    used_by UUID REFERENCES auth.users(id),
    used_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ, -- 兑换码本身的过期时间
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id),
    note TEXT -- 备注（如"送给某某"）
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_redemption_codes_code ON public.redemption_codes(code);
CREATE INDEX IF NOT EXISTS idx_redemption_codes_is_used ON public.redemption_codes(is_used);
CREATE INDEX IF NOT EXISTS idx_redemption_codes_created_by ON public.redemption_codes(created_by);

-- RLS
ALTER TABLE public.redemption_codes ENABLE ROW LEVEL SECURITY;

-- 管理员可以查看所有兑换码（is_admin = true 的用户）
DROP POLICY IF EXISTS "admin_read_codes" ON public.redemption_codes;
CREATE POLICY "admin_read_codes" ON public.redemption_codes
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid()
            AND is_admin = true
        )
    );

-- 管理员可以插入兑换码
DROP POLICY IF EXISTS "admin_insert_codes" ON public.redemption_codes;
CREATE POLICY "admin_insert_codes" ON public.redemption_codes
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid()
            AND is_admin = true
        )
    );

-- ============================================
-- 2. 兑换码兑换 RPC 函数
-- ============================================
CREATE OR REPLACE FUNCTION public.redeem_code(p_code TEXT, p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_code_record RECORD;
    v_new_expires TIMESTAMPTZ;
BEGIN
    -- 查找兑换码
    SELECT * INTO v_code_record
    FROM public.redemption_codes
    WHERE code = UPPER(TRIM(p_code));

    -- 验证码是否存在
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', '兑换码无效'
        );
    END IF;

    -- 验证是否已使用
    IF v_code_record.is_used THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', '兑换码已被使用'
        );
    END IF;

    -- 验证是否过期
    IF v_code_record.expires_at IS NOT NULL AND v_code_record.expires_at < NOW() THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', '兑换码已过期'
        );
    END IF;

    -- 标记兑换码为已使用
    UPDATE public.redemption_codes
    SET is_used = true,
        used_by = p_user_id,
        used_at = NOW()
    WHERE id = v_code_record.id;

    -- 更新用户账号类型
    IF v_code_record.code_type = 'lifetime' THEN
        UPDATE public.users
        SET account_type = 'lifetime',
            pro_expires_at = NULL,
            max_servers = -1,
            max_devices = -1,
            storage_quota_mb = 5120,
            updated_at = NOW()
        WHERE id = p_user_id;

        RETURN jsonb_build_object(
            'success', true,
            'message', '恭喜！已升级为永久版',
            'account_type', 'lifetime'
        );
    ELSE
        -- Pro 码：计算过期时间
        v_new_expires := GREATEST(
            COALESCE(
                (SELECT pro_expires_at FROM public.users WHERE id = p_user_id),
                NOW()
            ),
            NOW()
        ) + (v_code_record.duration_days || ' days')::INTERVAL;

        UPDATE public.users
        SET account_type = 'pro',
            pro_expires_at = v_new_expires,
            max_servers = -1,
            max_devices = 5,
            storage_quota_mb = 1024,
            updated_at = NOW()
        WHERE id = p_user_id;

        RETURN jsonb_build_object(
            'success', true,
            'message', '恭喜！已升级为 Pro 版，有效期至 ' || to_char(v_new_expires, 'YYYY-MM-DD'),
            'account_type', 'pro',
            'expires_at', v_new_expires
        );
    END IF;
END;
$$;

-- ============================================
-- 3. 批量生成兑换码 RPC 函数
-- ============================================
CREATE OR REPLACE FUNCTION public.generate_codes(
    p_type TEXT,           -- 'pro' 或 'lifetime'
    p_count INT,           -- 生成数量
    p_duration_days INT DEFAULT 30,   -- Pro 码有效天数
    p_expires_days INT DEFAULT 365,   -- 兑换码本身过期天数
    p_note TEXT DEFAULT NULL          -- 备注
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_is_admin BOOLEAN;
    v_codes TEXT[] := '{}';
    v_code TEXT;
    i INT;
BEGIN
    -- 验证调用者是管理员
    SELECT is_admin INTO v_is_admin
    FROM public.users
    WHERE id = auth.uid();

    IF v_is_admin IS NOT TRUE THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', '无权限：仅管理员可生成兑换码'
        );
    END IF;

    -- 验证参数
    IF p_type NOT IN ('pro', 'lifetime') THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', '无效的兑换码类型'
        );
    END IF;

    IF p_count < 1 OR p_count > 100 THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', '生成数量必须在 1-100 之间'
        );
    END IF;

    -- 批量生成
    FOR i IN 1..p_count LOOP
        -- 生成格式: BOVA-XXXX-XXXX-XXXX
        v_code := 'BOVA-' ||
            UPPER(SUBSTRING(md5(gen_random_uuid()::TEXT) FROM 1 FOR 4)) || '-' ||
            UPPER(SUBSTRING(md5(gen_random_uuid()::TEXT) FROM 1 FOR 4)) || '-' ||
            UPPER(SUBSTRING(md5(gen_random_uuid()::TEXT) FROM 1 FOR 4));

        INSERT INTO public.redemption_codes (
            code, code_type, duration_days, expires_at, created_by, note
        ) VALUES (
            v_code,
            p_type,
            CASE WHEN p_type = 'pro' THEN p_duration_days ELSE NULL END,
            NOW() + (p_expires_days || ' days')::INTERVAL,
            auth.uid(),
            p_note
        );

        v_codes := array_append(v_codes, v_code);
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'message', '成功生成 ' || p_count || ' 个兑换码',
        'codes', to_jsonb(v_codes)
    );
END;
$$;

-- ============================================
-- 4. 查询兑换码列表 RPC 函数
-- ============================================
CREATE OR REPLACE FUNCTION public.list_codes(
    p_filter TEXT DEFAULT 'all'  -- 'all', 'unused', 'used', 'expired'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_is_admin BOOLEAN;
    v_result JSONB;
BEGIN
    -- 验证调用者是管理员
    SELECT is_admin INTO v_is_admin
    FROM public.users
    WHERE id = auth.uid();

    IF v_is_admin IS NOT TRUE THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', '无权限'
        );
    END IF;

    SELECT jsonb_build_object(
        'success', true,
        'codes', COALESCE(jsonb_agg(
            jsonb_build_object(
                'id', rc.id,
                'code', rc.code,
                'code_type', rc.code_type,
                'duration_days', rc.duration_days,
                'is_used', rc.is_used,
                'used_by', rc.used_by,
                'used_at', rc.used_at,
                'expires_at', rc.expires_at,
                'created_at', rc.created_at,
                'note', rc.note,
                'is_expired', (rc.expires_at IS NOT NULL AND rc.expires_at < NOW()),
                'used_by_email', u.email
            ) ORDER BY rc.created_at DESC
        ), '[]'::jsonb)
    ) INTO v_result
    FROM public.redemption_codes rc
    LEFT JOIN public.users u ON rc.used_by = u.id
    WHERE
        CASE p_filter
            WHEN 'unused' THEN NOT rc.is_used AND (rc.expires_at IS NULL OR rc.expires_at >= NOW())
            WHEN 'used' THEN rc.is_used
            WHEN 'expired' THEN rc.expires_at IS NOT NULL AND rc.expires_at < NOW() AND NOT rc.is_used
            ELSE TRUE
        END;

    RETURN v_result;
END;
$$;

-- ============================================
-- 完成！
-- ============================================
-- 
-- 重要：执行完上面的 SQL 后，手动把自己设为管理员：
-- UPDATE public.users SET is_admin = true WHERE email = '你的邮箱';
