import { config } from '../lib/config.js';
import { parseCallbackParams } from '../lib/http.js';
import { isoNow, normalizePaymentState, verifyYipaySign } from '../lib/payment.js';
import { createAdminClient } from '../lib/supabase.js';
export async function handleYipayNotify(req, res) {
    try {
        const params = parseCallbackParams(req);
        if (!verifyYipaySign(params, config.yipayKey)) {
            return res.status(400).send('fail');
        }
        const merchantOrderId = (params.out_trade_no ?? '').trim();
        const transactionId = (params.trade_no ?? '').trim();
        const rawStatus = (params.trade_status ?? params.status ?? '').trim();
        const normalizedStatus = normalizePaymentState(rawStatus);
        const paidAmount = Number.parseFloat(params.money ?? '0');
        if (!merchantOrderId) {
            return res.status(400).send('fail');
        }
        const supabase = createAdminClient();
        const { data: order, error: orderError } = await supabase
            .from('payment_orders')
            .select('id, merchant_order_id, transaction_id, provider_order_id, status')
            .eq('merchant_order_id', merchantOrderId)
            .maybeSingle();
        if (orderError || !order) {
            return res.status(404).send('fail');
        }
        if (normalizedStatus !== 'paid') {
            if (order.status === 'paid') {
                return res.status(200).send('success');
            }
            const { error: updateError } = await supabase
                .from('payment_orders')
                .update({
                status: normalizedStatus,
                transaction_id: transactionId || order.transaction_id,
                provider_order_id: transactionId || order.provider_order_id,
                notified_at: isoNow(),
                raw_notify_payload: params,
                closed_at: normalizedStatus === 'cancelled' || normalizedStatus === 'expired'
                    ? isoNow()
                    : null,
            })
                .eq('id', order.id);
            if (updateError) {
                return res.status(500).send('fail');
            }
            return res.status(200).send('success');
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
            return res.status(500).send('fail');
        }
        const success = Boolean(rpcResult?.success);
        return res.status(success ? 200 : 400).send(success ? 'success' : 'fail');
    }
    catch (error) {
        console.error(error);
        return res.status(500).send('fail');
    }
}
