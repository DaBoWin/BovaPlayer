import { config } from '../lib/config.js';
import { jsonError, jsonOk } from '../lib/http.js';
import { buildMerchantOrderId, coerceStringRecord, planConfigs, signYipay, } from '../lib/payment.js';
import { createAdminClient, requireUser } from '../lib/supabase.js';
function extractRedirectUrlFromHtml(html, baseUrl) {
    const match = html.match(/window\.location\.replace\(\s*['\"]([^'\"]+)['\"]\s*\)/i);
    const redirectPath = match?.[1]?.trim();
    if (!redirectPath) {
        return '';
    }
    try {
        return new URL(redirectPath, baseUrl).toString();
    }
    catch {
        return redirectPath;
    }
}
export async function createPaymentOrder(req, res) {
    try {
        const user = await requireUser(req.header('Authorization'));
        const body = (req.body ?? {});
        const planId = String(body.plan ?? '').trim();
        const paymentMethod = String(body.payment_method ?? 'alipay').trim().toLowerCase();
        const plan = planConfigs[planId];
        if (!plan) {
            return res.status(400).json(jsonError('无效的订阅方案'));
        }
        if (paymentMethod !== 'alipay') {
            return res.status(400).json(jsonError('当前仅支持支付宝支付'));
        }
        const supabase = createAdminClient();
        const merchantOrderId = buildMerchantOrderId(user.id, planId);
        const paymentOrderId = crypto.randomUUID();
        const now = new Date();
        const expiresAt = new Date(now.getTime() + 15 * 60 * 1000);
        const notifyUrl = `${config.apiPublicBaseUrl.replace(/\/$/, '')}/api/payment/notify/yipay`;
        const returnUrl = `${config.paymentReturnUrl.replace(/\/$/, '')}/api/payment/return/yipay`;
        const gatewayParams = coerceStringRecord({
            pid: config.yipayPid,
            type: 'alipay',
            out_trade_no: merchantOrderId,
            notify_url: notifyUrl,
            return_url: returnUrl,
            name: plan.subject,
            money: plan.amountCny.toFixed(2),
            sitename: 'BovaPlayer',
            body: plan.body,
        });
        const gatewayBody = new URLSearchParams({
            ...gatewayParams,
            sign: signYipay(gatewayParams, config.yipayKey),
            sign_type: 'MD5',
        });
        const gatewayResponse = await fetch(config.yipayApiUrl, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: gatewayBody,
        });
        const gatewayText = await gatewayResponse.text();
        let gatewayJson = {};
        try {
            gatewayJson = JSON.parse(gatewayText);
        }
        catch {
            gatewayJson = { raw: gatewayText };
        }
        if (!gatewayResponse.ok) {
            return res.status(502).json({
                message: '易支付下单失败',
                detail: gatewayText,
            });
        }
        let paymentUrl = String(gatewayJson.payurl ?? gatewayJson.pay_url ?? gatewayJson.payment_url ?? '').trim();
        let qrCodeUrl = String(gatewayJson.qrcode ?? gatewayJson.qr_code ?? '').trim();
        const providerOrderId = String(gatewayJson.trade_no ?? gatewayJson.order_id ?? '').trim();
        if (!paymentUrl) {
            const redirectUrl = extractRedirectUrlFromHtml(gatewayText, gatewayResponse.url || config.yipayApiUrl);
            if (redirectUrl) {
                paymentUrl = redirectUrl;
                if (!qrCodeUrl && /\/pay\/qrcode\//i.test(redirectUrl)) {
                    qrCodeUrl = redirectUrl;
                }
            }
        }
        if (!paymentUrl) {
            return res.status(502).json({
                message: '易支付响应缺少支付链接',
                detail: gatewayJson,
            });
        }
        const { error } = await supabase.from('payment_orders').insert({
            id: paymentOrderId,
            user_id: user.id,
            plan_id: plan.planId,
            status: 'pending',
            payment_method: paymentMethod,
            provider: 'yipay',
            channel: 'alipay',
            merchant_order_id: merchantOrderId,
            provider_order_id: providerOrderId || null,
            amount_cny: plan.amountCny,
            currency: 'CNY',
            subject: plan.subject,
            body: plan.body,
            payment_url: paymentUrl,
            qr_code_url: qrCodeUrl || null,
            expires_at: expiresAt.toISOString(),
            raw_create_response: gatewayJson,
            metadata: {
                supabase_user_id: user.id,
            },
        });
        if (error) {
            return res.status(500).json(jsonError(`支付订单入库失败: ${error.message}`));
        }
        return res.json(jsonOk({
            id: paymentOrderId,
            order_id: paymentOrderId,
            plan: plan.planId,
            amount_cny: plan.amountCny,
            payment_url: paymentUrl,
            qr_code_url: qrCodeUrl || null,
            status: 'pending',
            merchant_order_id: merchantOrderId,
            channel: 'alipay',
            expires_at: expiresAt.toISOString(),
        }));
    }
    catch (error) {
        const status = typeof error === 'object' && error && 'status' in error ? Number(error.status) : 500;
        const message = error instanceof Error ? error.message : '创建支付订单失败';
        return res.status(status).json(jsonError(message));
    }
}
