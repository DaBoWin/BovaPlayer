import { createHash, randomUUID } from 'node:crypto';
export const planConfigs = {
    pro_monthly: {
        planId: 'pro_monthly',
        amountCny: 9,
        subject: 'BovaPlayer Pro 月付',
        body: 'BovaPlayer Pro 月付订阅',
        subscriptionType: 'pro_monthly',
        expiresDays: 30,
    },
    pro_yearly: {
        planId: 'pro_yearly',
        amountCny: 68,
        subject: 'BovaPlayer Pro 年付',
        body: 'BovaPlayer Pro 年付订阅',
        subscriptionType: 'pro_yearly',
        expiresDays: 365,
    },
    lifetime: {
        planId: 'lifetime',
        amountCny: 298,
        subject: 'BovaPlayer 永久版',
        body: 'BovaPlayer 永久版订阅',
        subscriptionType: 'lifetime',
    },
};
export function buildMerchantOrderId(userId, planId) {
    const compactUserId = userId.replace(/-/g, '').slice(0, 12);
    const randomPart = randomUUID().replace(/-/g, '').slice(0, 12);
    return `BP${Date.now()}${compactUserId}${planId.slice(0, 4).toUpperCase()}${randomPart}`;
}
export function normalizePaymentState(value) {
    switch ((value ?? '').trim().toLowerCase()) {
        case 'paid':
        case 'success':
        case 'succeeded':
        case 'completed':
        case 'complete':
        case 'trade_success':
        case 'trade_finished':
            return 'paid';
        case 'failed':
        case 'error':
            return 'failed';
        case 'cancelled':
        case 'canceled':
        case 'closed':
        case 'trade_closed':
            return 'cancelled';
        case 'expired':
        case 'timeout':
        case 'timeout_closed':
            return 'expired';
        default:
            return 'pending';
    }
}
export function signYipay(params, key) {
    const payload = Object.keys(params)
        .filter((item) => item !== 'sign' && item !== 'sign_type' && params[item] !== '')
        .sort()
        .map((item) => `${item}=${params[item]}`)
        .join('&');
    return createHash('md5').update(`${payload}${key}`).digest('hex');
}
export function verifyYipaySign(params, key) {
    const received = (params.sign ?? '').trim().toLowerCase();
    if (!received) {
        return false;
    }
    return signYipay(params, key).toLowerCase() === received;
}
export function coerceStringRecord(input) {
    const result = {};
    for (const [key, value] of Object.entries(input)) {
        if (value == null) {
            continue;
        }
        result[key] = String(value);
    }
    return result;
}
export function isoNow() {
    return new Date().toISOString();
}
