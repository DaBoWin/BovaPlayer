-- ============================================
-- 兑换码 / 订阅台账 - Supabase SQL 迁移脚本
-- 在 Supabase Dashboard > SQL Editor 中执行
-- ============================================

-- 0. 基础扩展与 users 字段
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

ALTER TABLE public.users ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT FALSE;

-- ============================================
-- 1. 订阅台账表 subscriptions
--    说明：支付成功、兑换码兑换成功、手动补单都写入这里
-- ============================================
CREATE TABLE IF NOT EXISTS public.subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,

    subscription_type VARCHAR(32) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active',

    payment_method VARCHAR(50),
    source_type VARCHAR(30) NOT NULL DEFAULT 'payment',
    source_id UUID,

    merchant_order_id VARCHAR(255),
    transaction_id VARCHAR(255),
    amount_cny DECIMAL(10,2) NOT NULL DEFAULT 0,
    currency VARCHAR(10) NOT NULL DEFAULT 'CNY',

    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,

    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.subscriptions
    ADD COLUMN IF NOT EXISTS payment_method VARCHAR(50),
    ADD COLUMN IF NOT EXISTS source_type VARCHAR(30) NOT NULL DEFAULT 'payment',
    ADD COLUMN IF NOT EXISTS source_id UUID,
    ADD COLUMN IF NOT EXISTS merchant_order_id VARCHAR(255),
    ADD COLUMN IF NOT EXISTS transaction_id VARCHAR(255),
    ADD COLUMN IF NOT EXISTS amount_cny DECIMAL(10,2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS currency VARCHAR(10) NOT NULL DEFAULT 'CNY',
    ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

ALTER TABLE public.subscriptions DROP CONSTRAINT IF EXISTS subscriptions_subscription_type_check;
ALTER TABLE public.subscriptions DROP CONSTRAINT IF EXISTS subscriptions_status_check;
ALTER TABLE public.subscriptions DROP CONSTRAINT IF EXISTS subscriptions_payment_method_check;
ALTER TABLE public.subscriptions DROP CONSTRAINT IF EXISTS subscriptions_source_type_check;

ALTER TABLE public.subscriptions
    ADD CONSTRAINT subscriptions_subscription_type_check
        CHECK (subscription_type IN (
            'pro_monthly',
            'pro_yearly',
            'lifetime',
            'redeem_pro',
            'redeem_lifetime',
            'manual_pro',
            'manual_lifetime'
        )),
    ADD CONSTRAINT subscriptions_status_check
        CHECK (status IN ('pending', 'active', 'expired', 'cancelled', 'failed')),
    ADD CONSTRAINT subscriptions_payment_method_check
        CHECK (
            payment_method IS NULL OR
            payment_method IN ('alipay', 'wechat', 'stripe', 'paypal', 'redeem_code', 'manual')
        ),
    ADD CONSTRAINT subscriptions_source_type_check
        CHECK (source_type IN ('payment', 'redeem_code', 'manual'));

CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON public.subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON public.subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_subscriptions_source_type ON public.subscriptions(source_type);
CREATE INDEX IF NOT EXISTS idx_subscriptions_merchant_order_id ON public.subscriptions(merchant_order_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_transaction_id ON public.subscriptions(transaction_id);

-- ============================================
-- 1.1 支付订单表 payment_orders
--    说明：支付创建 / 查询 / 回调闭环都围绕此表
-- ============================================
CREATE TABLE IF NOT EXISTS public.payment_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,

    plan_id VARCHAR(32) NOT NULL CHECK (plan_id IN ('pro_monthly', 'pro_yearly', 'lifetime')),
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'failed', 'cancelled', 'expired')),

    payment_method VARCHAR(50) NOT NULL CHECK (payment_method IN ('alipay', 'wechat', 'stripe', 'paypal')),
    provider VARCHAR(30) NOT NULL DEFAULT 'yipay',
    channel VARCHAR(50),

    merchant_order_id VARCHAR(255) NOT NULL UNIQUE,
    provider_order_id VARCHAR(255),
    transaction_id VARCHAR(255),

    amount_cny DECIMAL(10,2) NOT NULL,
    currency VARCHAR(10) NOT NULL DEFAULT 'CNY',
    subject TEXT NOT NULL,
    body TEXT,

    payment_url TEXT,
    qr_code_url TEXT,

    expires_at TIMESTAMPTZ,
    paid_at TIMESTAMPTZ,
    notified_at TIMESTAMPTZ,
    closed_at TIMESTAMPTZ,

    subscription_id UUID REFERENCES public.subscriptions(id) ON DELETE SET NULL,
    raw_create_response JSONB NOT NULL DEFAULT '{}'::jsonb,
    raw_notify_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payment_orders_user_id ON public.payment_orders(user_id);
CREATE INDEX IF NOT EXISTS idx_payment_orders_status ON public.payment_orders(status);
CREATE INDEX IF NOT EXISTS idx_payment_orders_plan_id ON public.payment_orders(plan_id);
CREATE INDEX IF NOT EXISTS idx_payment_orders_provider ON public.payment_orders(provider);
CREATE INDEX IF NOT EXISTS idx_payment_orders_provider_order_id ON public.payment_orders(provider_order_id);
CREATE INDEX IF NOT EXISTS idx_payment_orders_transaction_id ON public.payment_orders(transaction_id);
CREATE INDEX IF NOT EXISTS idx_payment_orders_subscription_id ON public.payment_orders(subscription_id);
CREATE INDEX IF NOT EXISTS idx_payment_orders_created_at ON public.payment_orders(created_at DESC);

ALTER TABLE public.payment_orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users_read_own_payment_orders" ON public.payment_orders;
CREATE POLICY "users_read_own_payment_orders" ON public.payment_orders
    FOR SELECT
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "admin_read_all_payment_orders" ON public.payment_orders;
CREATE POLICY "admin_read_all_payment_orders" ON public.payment_orders
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid()
              AND is_admin = true
        )
    );

ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users_read_own_subscriptions" ON public.subscriptions;
CREATE POLICY "users_read_own_subscriptions" ON public.subscriptions
    FOR SELECT
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "admin_read_all_subscriptions" ON public.subscriptions;
CREATE POLICY "admin_read_all_subscriptions" ON public.subscriptions
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid()
              AND is_admin = true
        )
    );

-- ============================================
-- 2. redemption_codes 表
-- ============================================
CREATE TABLE IF NOT EXISTS public.redemption_codes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    code_type TEXT NOT NULL CHECK (code_type IN ('pro', 'lifetime')),
    duration_days INT,
    is_used BOOLEAN DEFAULT FALSE,
    used_by UUID REFERENCES auth.users(id),
    used_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id),
    note TEXT
);

CREATE INDEX IF NOT EXISTS idx_redemption_codes_code ON public.redemption_codes(code);
CREATE INDEX IF NOT EXISTS idx_redemption_codes_is_used ON public.redemption_codes(is_used);
CREATE INDEX IF NOT EXISTS idx_redemption_codes_created_by ON public.redemption_codes(created_by);

ALTER TABLE public.redemption_codes ENABLE ROW LEVEL SECURITY;

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
-- 3. redemption_logs 表
--    说明：每次兑换都写日志，便于追溯
-- ============================================
CREATE TABLE IF NOT EXISTS public.redemption_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    redemption_code_id UUID NOT NULL REFERENCES public.redemption_codes(id) ON DELETE CASCADE,
    code TEXT NOT NULL,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    subscription_id UUID REFERENCES public.subscriptions(id) ON DELETE SET NULL,

    code_type TEXT NOT NULL CHECK (code_type IN ('pro', 'lifetime')),
    granted_account_type VARCHAR(20) NOT NULL CHECK (granted_account_type IN ('pro', 'lifetime')),
    granted_duration_days INT,
    previous_account_type VARCHAR(20),
    previous_expires_at TIMESTAMPTZ,
    new_expires_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_redemption_logs_user_id ON public.redemption_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_redemption_logs_code_id ON public.redemption_logs(redemption_code_id);
CREATE INDEX IF NOT EXISTS idx_redemption_logs_subscription_id ON public.redemption_logs(subscription_id);
CREATE INDEX IF NOT EXISTS idx_redemption_logs_created_at ON public.redemption_logs(created_at DESC);

ALTER TABLE public.redemption_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users_read_own_redemption_logs" ON public.redemption_logs;
CREATE POLICY "users_read_own_redemption_logs" ON public.redemption_logs
    FOR SELECT
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "admin_read_all_redemption_logs" ON public.redemption_logs;
CREATE POLICY "admin_read_all_redemption_logs" ON public.redemption_logs
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid()
              AND is_admin = true
        )
    );

-- ============================================
-- 4. 自动更新 updated_at
-- ============================================
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_subscriptions_updated_at ON public.subscriptions;
CREATE TRIGGER update_subscriptions_updated_at
    BEFORE UPDATE ON public.subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_payment_orders_updated_at ON public.payment_orders;
CREATE TRIGGER update_payment_orders_updated_at
    BEFORE UPDATE ON public.payment_orders
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================
-- 5. 兑换码兑换 RPC
--    逻辑：锁码 -> 写 subscriptions -> 写 redemption_logs -> 更新 users
-- ============================================
CREATE OR REPLACE FUNCTION public.redeem_code(p_code TEXT, p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_code_record RECORD;
    v_user_record RECORD;
    v_now TIMESTAMPTZ := NOW();
    v_new_expires TIMESTAMPTZ;
    v_subscription_id UUID;
    v_redemption_log_id UUID;
    v_subscription_type VARCHAR(32);
    v_granted_account_type VARCHAR(20);
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', '未登录'
        );
    END IF;

    IF auth.uid() <> p_user_id THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', '无权限兑换其他用户账号'
        );
    END IF;

    SELECT id, account_type, pro_expires_at
    INTO v_user_record
    FROM public.users
    WHERE id = p_user_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', '用户不存在'
        );
    END IF;

    SELECT *
    INTO v_code_record
    FROM public.redemption_codes
    WHERE code = UPPER(TRIM(p_code))
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', '兑换码无效'
        );
    END IF;

    IF v_code_record.is_used THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', '兑换码已被使用'
        );
    END IF;

    IF v_code_record.expires_at IS NOT NULL AND v_code_record.expires_at < v_now THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', '兑换码已过期'
        );
    END IF;

    IF v_code_record.code_type = 'lifetime' THEN
        v_subscription_type := 'redeem_lifetime';
        v_granted_account_type := 'lifetime';
        v_new_expires := NULL;
    ELSE
        v_subscription_type := 'redeem_pro';
        v_granted_account_type := 'pro';
        v_new_expires := GREATEST(
            COALESCE(v_user_record.pro_expires_at, v_now),
            v_now
        ) + make_interval(days => COALESCE(v_code_record.duration_days, 30));
    END IF;

    INSERT INTO public.subscriptions (
        user_id,
        subscription_type,
        status,
        payment_method,
        source_type,
        source_id,
        amount_cny,
        currency,
        started_at,
        expires_at,
        metadata
    ) VALUES (
        p_user_id,
        v_subscription_type,
        'active',
        'redeem_code',
        'redeem_code',
        v_code_record.id,
        0,
        'CNY',
        v_now,
        v_new_expires,
        jsonb_build_object(
            'code', v_code_record.code,
            'code_type', v_code_record.code_type,
            'duration_days', v_code_record.duration_days,
            'note', v_code_record.note
        )
    )
    RETURNING id INTO v_subscription_id;

    UPDATE public.redemption_codes
    SET is_used = true,
        used_by = p_user_id,
        used_at = v_now
    WHERE id = v_code_record.id;

    INSERT INTO public.redemption_logs (
        redemption_code_id,
        code,
        user_id,
        subscription_id,
        code_type,
        granted_account_type,
        granted_duration_days,
        previous_account_type,
        previous_expires_at,
        new_expires_at,
        metadata
    ) VALUES (
        v_code_record.id,
        v_code_record.code,
        p_user_id,
        v_subscription_id,
        v_code_record.code_type,
        v_granted_account_type,
        v_code_record.duration_days,
        v_user_record.account_type,
        v_user_record.pro_expires_at,
        v_new_expires,
        jsonb_build_object(
            'note', v_code_record.note,
            'redeemed_at', v_now
        )
    )
    RETURNING id INTO v_redemption_log_id;

    IF v_code_record.code_type = 'lifetime' THEN
        UPDATE public.users
        SET account_type = 'lifetime',
            pro_expires_at = NULL,
            max_servers = -1,
            max_devices = -1,
            storage_quota_mb = 5120,
            updated_at = v_now
        WHERE id = p_user_id;

        RETURN jsonb_build_object(
            'success', true,
            'message', '恭喜！已升级为永久版',
            'account_type', 'lifetime',
            'subscription_id', v_subscription_id,
            'redemption_log_id', v_redemption_log_id
        );
    END IF;

    UPDATE public.users
    SET account_type = 'pro',
        pro_expires_at = v_new_expires,
        max_servers = -1,
        max_devices = 5,
        storage_quota_mb = 1024,
        updated_at = v_now
    WHERE id = p_user_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', '恭喜！已升级为 Pro 版，有效期至 ' || to_char(v_new_expires, 'YYYY-MM-DD'),
        'account_type', 'pro',
        'expires_at', v_new_expires,
        'subscription_id', v_subscription_id,
        'redemption_log_id', v_redemption_log_id
    );
END;
$$;

-- ============================================
-- 5.1 支付回调落账 RPC
--    逻辑：锁 payment_orders -> 校验金额/状态 -> 写 subscriptions -> 更新 users
-- ============================================
CREATE OR REPLACE FUNCTION public.complete_payment_order(
    p_merchant_order_id TEXT,
    p_transaction_id TEXT,
    p_paid_amount NUMERIC,
    p_provider TEXT DEFAULT 'yipay',
    p_notify_payload JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_order RECORD;
    v_user RECORD;
    v_subscription_id UUID;
    v_now TIMESTAMPTZ := NOW();
    v_expires_at TIMESTAMPTZ;
    v_subscription_type VARCHAR(32);
BEGIN
    SELECT *
    INTO v_order
    FROM public.payment_orders
    WHERE merchant_order_id = TRIM(p_merchant_order_id)
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', '支付订单不存在'
        );
    END IF;

    IF v_order.status = 'paid' AND v_order.subscription_id IS NOT NULL THEN
        RETURN jsonb_build_object(
            'success', true,
            'message', '订单已处理',
            'order_id', v_order.id,
            'subscription_id', v_order.subscription_id,
            'already_processed', true
        );
    END IF;

    IF v_order.status IN ('failed', 'cancelled', 'expired') THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', '订单状态不允许完成支付'
        );
    END IF;

    IF ROUND(COALESCE(p_paid_amount, 0)::numeric, 2) <> ROUND(COALESCE(v_order.amount_cny, 0)::numeric, 2) THEN
        UPDATE public.payment_orders
        SET status = 'failed',
            notified_at = v_now,
            raw_notify_payload = COALESCE(p_notify_payload, '{}'::jsonb),
            metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
                'amount_mismatch', true,
                'callback_amount', p_paid_amount,
                'provider', p_provider
            )
        WHERE id = v_order.id;

        RETURN jsonb_build_object(
            'success', false,
            'message', '支付金额校验失败'
        );
    END IF;

    SELECT id, account_type, pro_expires_at
    INTO v_user
    FROM public.users
    WHERE id = v_order.user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', '用户不存在'
        );
    END IF;

    CASE v_order.plan_id
        WHEN 'pro_monthly' THEN
            v_subscription_type := 'pro_monthly';
            v_expires_at := GREATEST(COALESCE(v_user.pro_expires_at, v_now), v_now) + INTERVAL '30 days';
        WHEN 'pro_yearly' THEN
            v_subscription_type := 'pro_yearly';
            v_expires_at := GREATEST(COALESCE(v_user.pro_expires_at, v_now), v_now) + INTERVAL '365 days';
        WHEN 'lifetime' THEN
            v_subscription_type := 'lifetime';
            v_expires_at := NULL;
        ELSE
            RETURN jsonb_build_object(
                'success', false,
                'message', '不支持的订阅方案'
            );
    END CASE;

    INSERT INTO public.subscriptions (
        user_id,
        subscription_type,
        status,
        payment_method,
        source_type,
        source_id,
        merchant_order_id,
        transaction_id,
        amount_cny,
        currency,
        started_at,
        expires_at,
        metadata
    ) VALUES (
        v_order.user_id,
        v_subscription_type,
        'active',
        v_order.payment_method,
        'payment',
        v_order.id,
        v_order.merchant_order_id,
        NULLIF(TRIM(p_transaction_id), ''),
        v_order.amount_cny,
        v_order.currency,
        v_now,
        v_expires_at,
        jsonb_build_object(
            'provider', COALESCE(NULLIF(TRIM(p_provider), ''), v_order.provider),
            'provider_order_id', NULLIF(TRIM(p_transaction_id), ''),
            'payment_order_id', v_order.id,
            'notify_payload', COALESCE(p_notify_payload, '{}'::jsonb)
        )
    )
    RETURNING id INTO v_subscription_id;

    IF v_order.plan_id = 'lifetime' THEN
        UPDATE public.users
        SET account_type = 'lifetime',
            pro_expires_at = NULL,
            max_servers = -1,
            max_devices = -1,
            storage_quota_mb = 5120,
            updated_at = v_now
        WHERE id = v_order.user_id;
    ELSE
        UPDATE public.users
        SET account_type = 'pro',
            pro_expires_at = v_expires_at,
            max_servers = -1,
            max_devices = 5,
            storage_quota_mb = 1024,
            updated_at = v_now
        WHERE id = v_order.user_id;
    END IF;

    UPDATE public.payment_orders
    SET status = 'paid',
        transaction_id = NULLIF(TRIM(p_transaction_id), ''),
        provider_order_id = COALESCE(NULLIF(TRIM(p_transaction_id), ''), provider_order_id),
        paid_at = COALESCE(paid_at, v_now),
        notified_at = v_now,
        subscription_id = v_subscription_id,
        raw_notify_payload = COALESCE(p_notify_payload, '{}'::jsonb),
        metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
            'provider', COALESCE(NULLIF(TRIM(p_provider), ''), provider),
            'completed_at', v_now
        )
    WHERE id = v_order.id;

    RETURN jsonb_build_object(
        'success', true,
        'message', '支付处理成功',
        'order_id', v_order.id,
        'subscription_id', v_subscription_id,
        'account_type', CASE WHEN v_order.plan_id = 'lifetime' THEN 'lifetime' ELSE 'pro' END,
        'expires_at', v_expires_at
    );
END;
$$;

-- ============================================
-- 6. 批量生成兑换码 RPC
-- ============================================
CREATE OR REPLACE FUNCTION public.generate_codes(
    p_type TEXT,
    p_count INT,
    p_duration_days INT DEFAULT 30,
    p_expires_days INT DEFAULT 365,
    p_note TEXT DEFAULT NULL
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
    SELECT is_admin INTO v_is_admin
    FROM public.users
    WHERE id = auth.uid();

    IF v_is_admin IS NOT TRUE THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', '无权限：仅管理员可生成兑换码'
        );
    END IF;

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

    FOR i IN 1..p_count LOOP
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
            NOW() + make_interval(days => p_expires_days),
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
-- 7. 查询兑换码列表 RPC
-- ============================================
CREATE OR REPLACE FUNCTION public.list_codes(
    p_filter TEXT DEFAULT 'all'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_is_admin BOOLEAN;
    v_result JSONB;
BEGIN
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
                'used_by_email', u.email,
                'subscription_id', rl.subscription_id,
                'redemption_log_id', rl.id
            ) ORDER BY rc.created_at DESC
        ), '[]'::jsonb)
    ) INTO v_result
    FROM public.redemption_codes rc
    LEFT JOIN public.users u ON rc.used_by = u.id
    LEFT JOIN public.redemption_logs rl ON rl.redemption_code_id = rc.id
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
-- 完成
-- ============================================
-- 重要：执行完上面的 SQL 后，手动把自己设为管理员：
-- UPDATE public.users SET is_admin = true WHERE email = '你的邮箱';
