import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import {
  corsHeaders,
  createAdminClient,
  getEnv,
  isoNow,
  normalizePaymentState,
  parseBody,
  verifyYipaySign,
} from '../_shared/payment.ts';

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST' && req.method !== 'GET') {
    return new Response('method not allowed', { status: 405, headers: corsHeaders });
  }

  try {
    const body = await parseBody(req);
    const payload = body && typeof body === 'object' ? body : {};
    const params: Record<string, string> = {};
    for (const [key, value] of Object.entries(payload)) {
      params[key] = String(value ?? '');
    }

    if (!verifyYipaySign(params, getEnv('YIPAY_KEY'))) {
      return new Response('fail', { status: 400, headers: corsHeaders });
    }

    const merchantOrderId = (params.out_trade_no ?? '').trim();
    const transactionId = (params.trade_no ?? '').trim();
    const rawStatus = (params.trade_status ?? params.status ?? '').trim();
    const normalizedStatus = normalizePaymentState(rawStatus);
    const paidAmount = Number.parseFloat(params.money ?? '0');

    if (!merchantOrderId) {
      return new Response('fail', { status: 400, headers: corsHeaders });
    }

    const supabase = createAdminClient();
    const { data: order, error: orderError } = await supabase
      .from('payment_orders')
      .select('id, merchant_order_id, transaction_id, provider_order_id, status')
      .eq('merchant_order_id', merchantOrderId)
      .maybeSingle();

    if (orderError || !order) {
      return new Response('fail', { status: 404, headers: corsHeaders });
    }

    if (normalizedStatus !== 'paid') {
      if (order.status === 'paid') {
        return new Response('success', { status: 200, headers: corsHeaders });
      }

      const { error: updateError } = await supabase
        .from('payment_orders')
        .update({
          status: normalizedStatus,
          transaction_id: transactionId || order.transaction_id,
          provider_order_id: transactionId || order.provider_order_id,
          notified_at: isoNow(),
          raw_notify_payload: params,
          closed_at:
            normalizedStatus === 'cancelled' || normalizedStatus === 'expired'
              ? isoNow()
              : null,
        })
        .eq('id', order.id);

      if (updateError) {
        return new Response('fail', { status: 500, headers: corsHeaders });
      }

      return new Response('success', { status: 200, headers: corsHeaders });
    }

    const { data: rpcResult, error: rpcError } = await supabase.rpc('complete_payment_order', {
      p_merchant_order_id: merchantOrderId,
      p_transaction_id: transactionId,
      p_paid_amount: Number.isFinite(paidAmount) ? paidAmount : 0,
      p_provider: 'yipay',
      p_notify_payload: params,
    });

    if (rpcError) {
      console.error(rpcError);
      return new Response('fail', { status: 500, headers: corsHeaders });
    }

    const success = Boolean(rpcResult?.success);
    return new Response(success ? 'success' : 'fail', {
      status: success ? 200 : 400,
      headers: corsHeaders,
    });
  } catch (error) {
    console.error(error);
    return new Response('fail', { status: 500, headers: corsHeaders });
  }
});
