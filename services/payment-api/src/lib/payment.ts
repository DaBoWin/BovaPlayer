import { createHash, randomUUID } from 'node:crypto';

export type PlanConfig = {
  planId: 'pro_monthly' | 'pro_yearly' | 'lifetime';
  amountCny: number;
  subject: string;
  body: string;
  subscriptionType: 'pro_monthly' | 'pro_yearly' | 'lifetime';
  expiresDays?: number;
};

export const planConfigs: Record<string, PlanConfig> = {
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

export function buildMerchantOrderId(userId: string, planId: string) {
  const compactUserId = userId.replace(/-/g, '').slice(0, 12);
  const randomPart = randomUUID().replace(/-/g, '').slice(0, 12);
  return `BP${Date.now()}${compactUserId}${planId.slice(0, 4).toUpperCase()}${randomPart}`;
}

export function normalizePaymentState(value?: string | null) {
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

export function signYipay(params: Record<string, string>, key: string) {
  const payload = Object.keys(params)
    .filter((item) => item !== 'sign' && item !== 'sign_type' && params[item] !== '')
    .sort()
    .map((item) => `${item}=${params[item]}`)
    .join('&');

  return createHash('md5').update(`${payload}${key}`).digest('hex');
}

export function verifyYipaySign(params: Record<string, string>, key: string) {
  const received = (params.sign ?? '').trim().toLowerCase();
  if (!received) {
    return false;
  }

  return signYipay(params, key).toLowerCase() === received;
}

export function coerceStringRecord(input: Record<string, unknown>) {
  const result: Record<string, string> = {};
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
