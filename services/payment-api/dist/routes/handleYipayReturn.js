import { config } from '../lib/config.js';
import { parseCallbackParams } from '../lib/http.js';
import { normalizePaymentState, verifyYipaySign } from '../lib/payment.js';
import { createAdminClient } from '../lib/supabase.js';
export async function handleYipayReturn(req, res) {
    try {
        const params = parseCallbackParams(req);
        if (!verifyYipaySign(params, config.yipayKey)) {
            return redirectWithStatus(res, 'fail');
        }
        const merchantOrderId = (params.out_trade_no ?? '').trim();
        const transactionId = (params.trade_no ?? '').trim();
        const rawStatus = (params.trade_status ?? params.status ?? '').trim();
        const normalizedStatus = normalizePaymentState(rawStatus);
        if (!merchantOrderId) {
            return redirectWithStatus(res, 'fail');
        }
        const supabase = createAdminClient();
        const { data: order, error: orderError } = await supabase
            .from('payment_orders')
            .select('id, user_id, status')
            .eq('merchant_order_id', merchantOrderId)
            .maybeSingle();
        if (orderError || !order) {
            return redirectWithStatus(res, 'fail');
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
                return redirectWithStatus(res, 'fail');
            }
            return redirectWithStatus(res, 'success');
        }
        if (normalizedStatus === 'cancelled' || normalizedStatus === 'expired') {
            return redirectWithStatus(res, 'pending');
        }
        return redirectWithStatus(res, 'pending');
    }
    catch (error) {
        console.error(error);
        return redirectWithStatus(res, 'fail');
    }
}
function redirectWithStatus(res, status) {
    const target = `${config.paymentReturnUrl.replace(/\/$/, '')}/account?pay=${status}`;
    return res.redirect(302, target);
}
