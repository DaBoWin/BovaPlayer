import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import {
  buildMerchantOrderId,
  coerceStringRecord,
  corsHeaders,
  createAdminClient,
  getEnv,
  json,
  planConfigs,
  requireUser,
  signYipay,
} from '../_shared/payment.ts';

function extractRedirectUrlFromHtml(html: string, baseUrl: string): string {
  const match = html.match(/window\.location\.replace\(\s*['\"]([^'\"]+)['\"]\s*\)/i);
  const redirectPath = match?.[1]?.trim();
  if (!redirectPath) {
    return '';
  }

  try {
    return new URL(redirectPath, baseUrl).toString();
  } catch {
    return redirectPath;
  }
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return json({ message: 'Method Not Allowed' }, { status: 405 });
  }

  try {
    const user = await requireUser(req);
    const body = await req.json();
    const planId = String(body?.plan ?? '').trim();
    const paymentMethod = String(body?.payment_method ?? 'alipay').trim().toLowerCase();

    const plan = planConfigs[planId];
    if (!plan) {
      return json({ message: '无效的订阅方案' }, { status: 400 });
    }

    if (paymentMethod !== 'alipay') {
      return json({ message: '当前仅支持支付宝支付' }, { status: 400 });
    }

    const supabase = createAdminClient();
    const merchantOrderId = buildMerchantOrderId(user.id, planId);
    const paymentOrderId = crypto.randomUUID();
    const now = new Date();
    const expiresAt = new Date(now.getTime() + 15 * 60 * 1000);

    const notifyUrl = `${getEnv('API_PUBLIC_BASE_URL').replace(/\/$/, '')}/api/payment/notify/yipay`;
    const returnUrl = `${getEnv('API_PUBLIC_BASE_URL').replace(/\/$/, '')}/api/payment/return/yipay`;

    const gatewayParams = coerceStringRecord({
      pid: getEnv('YIPAY_PID'),
      type: 'alipay',
      out_trade_no: merchantOrderId,
      notify_url: notifyUrl,
      return_url: returnUrl,
      name: plan.subject,
      money: plan.amountCny.toFixed(2),
      sitename: 'BovaPlayer',
      body: plan.body,
    });
    const sign = signYipay(gatewayParams, getEnv('YIPAY_KEY'));

    const gatewayBody = new URLSearchParams({
      ...gatewayParams,
      sign,
      sign_type: 'MD5',
    });

    const gatewayResponse = await fetch(getEnv('YIPAY_API_URL'), {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: gatewayBody,
    });

    const gatewayText = await gatewayResponse.text();
    let gatewayJson: Record<string, unknown> = {};
    try {
      gatewayJson = JSON.parse(gatewayText);
    } catch {
      gatewayJson = { raw: gatewayText };
    }

    if (!gatewayResponse.ok) {
      return json(
        {
          message: '易支付下单失败',
          detail: gatewayText,
        },
        { status: 502 },
      );
    }

    let paymentUrl = String(
      gatewayJson.payurl ?? gatewayJson.pay_url ?? gatewayJson.payment_url ?? '',
    ).trim();
    let qrCodeUrl = String(gatewayJson.qrcode ?? gatewayJson.qr_code ?? '').trim();
    const providerOrderId = String(gatewayJson.trade_no ?? gatewayJson.order_id ?? '').trim();

    if (!paymentUrl) {
      const redirectUrl = extractRedirectUrlFromHtml(
        gatewayText,
        gatewayResponse.url || getEnv('YIPAY_API_URL'),
      );
      if (redirectUrl) {
        paymentUrl = redirectUrl;
        if (!qrCodeUrl && /\/pay\/qrcode\//i.test(redirectUrl)) {
          qrCodeUrl = redirectUrl;
        }
      }
    }

    if (!paymentUrl) {
      return json(
        {
          message: '易支付响应缺少支付链接',
          detail: gatewayJson,
        },
        { status: 502 },
      );
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
      return json({ message: `支付订单入库失败: ${error.message}` }, { status: 500 });
    }

    return json({
      success: true,
      data: {
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
      },
    });
  } catch (error) {
    if (error instanceof Response) {
      return error;
    }
    return json(
      {
        message: error instanceof Error ? error.message : '创建支付订单失败',
      },
      { status: 500 },
    );
  }
});
