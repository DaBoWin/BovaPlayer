import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import {
  corsHeaders,
  createAdminClient,
  getEnv,
  json,
  normalizePaymentState,
  parseBody,
  verifyYipaySign,
} from '../_shared/payment.ts';

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST' && req.method !== 'GET') {
    return json({ message: 'Method Not Allowed' }, { status: 405 });
  }

  try {
    const body = await parseBody(req);
    const payload = body && typeof body === 'object' ? body : {};
    const params: Record<string, string> = {};
    for (const [key, value] of Object.entries(payload)) {
      params[key] = String(value ?? '');
    }

    if (!verifyYipaySign(params, getEnv('YIPAY_KEY'))) {
      return redirectWithStatus('fail');
    }

    const merchantOrderId = (params.out_trade_no ?? '').trim();
    const transactionId = (params.trade_no ?? '').trim();
    const rawStatus = (params.trade_status ?? params.status ?? '').trim();
    const normalizedStatus = normalizePaymentState(rawStatus);

    if (!merchantOrderId) {
      return redirectWithStatus('fail');
    }

    const supabase = createAdminClient();
    const { data: order, error: orderError } = await supabase
      .from('payment_orders')
      .select('id, user_id, status')
      .eq('merchant_order_id', merchantOrderId)
      .maybeSingle();

    if (orderError || !order) {
      return redirectWithStatus('fail');
    }

    if (normalizedStatus === 'paid') {
      const paidAmount = Number.parseFloat(params.money ?? '0');
      const { data: rpcResult, error: rpcError } = await supabase.rpc('complete_payment_order', {
        p_merchant_order_id: merchantOrderId,
        p_transaction_id: transactionId,
        p_paid_amount: Number.isFinite(paidAmount) ? paidAmount : 0,
        p_provider: 'yipay',
        p_notify_payload: params,
      });

      if (rpcError || !rpcResult?.success) {
        return redirectWithStatus('fail');
      }

      return redirectWithStatus('success');
    }

    if (normalizedStatus === 'cancelled' || normalizedStatus === 'expired') {
      return redirectWithStatus('pending');
    }

    return redirectWithStatus('pending');
  } catch (error) {
    console.error(error);
    return redirectWithStatus('fail');
  }
});

function redirectWithStatus(status: 'success' | 'pending' | 'fail') {
  const target = `${getEnv('PAYMENT_RETURN_URL').replace(/\/$/, '')}/#/account?pay=${status}`;
  return Response.redirect(target, 302);
}
