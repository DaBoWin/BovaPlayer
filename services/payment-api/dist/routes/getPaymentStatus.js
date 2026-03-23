import { jsonError, jsonOk } from '../lib/http.js';
import { normalizePaymentState } from '../lib/payment.js';
import { createAdminClient, requireUser } from '../lib/supabase.js';
export async function getPaymentStatus(req, res) {
    try {
        const user = await requireUser(req.header('Authorization'));
        const orderId = String(req.params.orderId ?? '').trim();
        if (!orderId) {
            return res.status(400).json(jsonError('缺少订单 ID'));
        }
        const supabase = createAdminClient();
        const { data: order, error } = await supabase
            .from('payment_orders')
            .select('id, user_id, plan_id, status, merchant_order_id, transaction_id, amount_cny, currency, payment_method, channel, provider, expires_at, paid_at, created_at, updated_at, subscription_id')
            .eq('id', orderId)
            .maybeSingle();
        if (error) {
            return res.status(500).json(jsonError(`查询订单失败: ${error.message}`));
        }
        if (!order || order.user_id !== user.id) {
            return res.status(404).json(jsonError('订单不存在'));
        }
        const state = normalizePaymentState(order.status);
        return res.json(jsonOk({
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
        }));
    }
    catch (error) {
        const status = typeof error === 'object' && error && 'status' in error ? Number(error.status) : 500;
        const message = error instanceof Error ? error.message : '查询支付状态失败';
        return res.status(status).json(jsonError(message));
    }
}
