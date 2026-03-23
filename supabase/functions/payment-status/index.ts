import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import {
  corsHeaders,
  createAdminClient,
  json,
  normalizePaymentState,
  requireUser,
} from '../_shared/payment.ts';

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'GET') {
    return json({ message: 'Method Not Allowed' }, { status: 405 });
  }

  try {
    const user = await requireUser(req);
    const url = new URL(req.url);
    const orderId = url.pathname.split('/').filter(Boolean).pop()?.trim();

    if (!orderId) {
      return json({ message: '缺少订单 ID' }, { status: 400 });
    }

    const supabase = createAdminClient();
    const { data: order, error } = await supabase
      .from('payment_orders')
      .select('id, user_id, plan_id, status, merchant_order_id, transaction_id, amount_cny, currency, payment_method, channel, provider, expires_at, paid_at, created_at, updated_at, subscription_id')
      .eq('id', orderId)
      .maybeSingle();

    if (error) {
      return json({ message: `查询订单失败: ${error.message}` }, { status: 500 });
    }

    if (!order || order.user_id !== user.id) {
      return json({ message: '订单不存在' }, { status: 404 });
    }

    const state = normalizePaymentState(order.status);
    return json({
      success: true,
      data: {
        order_id: order.id,
        id: order.id,
        status: state,
        paid: state === 'paid',
        subscription_id: order.subscription_id,
        merchant_order_id: order.merchant_order_id,
        transaction_id: order.transaction_id,
        amount_cny: order.amount_cny,
        currency: order.currency,
        payment_method: order.payment_method,
        channel: order.channel,
        provider: order.provider,
        paid_at: order.paid_at,
        expires_at: order.expires_at,
        created_at: order.created_at,
        updated_at: order.updated_at,
      },
    });
  } catch (error) {
    if (error instanceof Response) {
      return error;
    }
    return json(
      { message: error instanceof Error ? error.message : '查询支付状态失败' },
      { status: 500 },
    );
  }
});
