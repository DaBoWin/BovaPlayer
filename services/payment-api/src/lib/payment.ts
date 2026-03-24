import { createHash, randomUUID } from 'node:crypto';

import type { SupabaseClient } from '@supabase/supabase-js';

export type PlanId = 'pro_monthly' | 'pro_yearly' | 'lifetime';

export type PlanConfig = {
  planId: PlanId;
  amountCny: number;
  subject: string;
  body: string;
  subscriptionType: PlanId;
  expiresDays?: number;
  currency?: string;
  displayName?: string;
  description?: string;
  billingPeriod?: string;
  accountType?: 'pro' | 'lifetime';
  maxServers?: number;
  maxDevices?: number;
  storageQuotaMb?: number;
  isActive?: boolean;
  sortOrder?: number;
  metadata?: Record<string, unknown>;
};

export const supportedPlanIds: PlanId[] = ['pro_monthly', 'pro_yearly', 'lifetime'];

export const fallbackPlanConfigs: Record<PlanId, PlanConfig> = {
  pro_monthly: {
    planId: 'pro_monthly',
    amountCny: 6.9,
    subject: 'BovaPlayer Pro 月付',
    body: 'BovaPlayer Pro 月付订阅',
    subscriptionType: 'pro_monthly',
    expiresDays: 30,
    currency: 'CNY',
    displayName: 'Pro 月付',
    description: 'BovaPlayer Pro 月付订阅',
    billingPeriod: 'monthly',
    accountType: 'pro',
    maxServers: -1,
    maxDevices: 5,
    storageQuotaMb: 1024,
    isActive: true,
    sortOrder: 10,
    metadata: {},
  },
  pro_yearly: {
    planId: 'pro_yearly',
    amountCny: 68,
    subject: 'BovaPlayer Pro 年付',
    body: 'BovaPlayer Pro 年付订阅',
    subscriptionType: 'pro_yearly',
    expiresDays: 365,
    currency: 'CNY',
    displayName: 'Pro 年付',
    description: 'BovaPlayer Pro 年付订阅',
    billingPeriod: 'yearly',
    accountType: 'pro',
    maxServers: -1,
    maxDevices: 5,
    storageQuotaMb: 1024,
    isActive: true,
    sortOrder: 20,
    metadata: {},
  },
  lifetime: {
    planId: 'lifetime',
    amountCny: 69,
    subject: 'BovaPlayer 永久版',
    body: 'BovaPlayer 永久版订阅',
    subscriptionType: 'lifetime',
    currency: 'CNY',
    displayName: '永久版',
    description: 'BovaPlayer 永久版订阅',
    billingPeriod: 'lifetime',
    accountType: 'lifetime',
    maxServers: -1,
    maxDevices: -1,
    storageQuotaMb: 5120,
    isActive: true,
    sortOrder: 30,
    metadata: {},
  },
};

type PricingConfigRow = {
  plan_id: string;
  price_cny: number | string;
  subject: string | null;
  body: string | null;
  subscription_type: string | null;
  duration_days: number | null;
  currency: string | null;
  display_name: string | null;
  description: string | null;
  billing_period: string | null;
  account_type: 'pro' | 'lifetime' | null;
  max_servers: number | null;
  max_devices: number | null;
  storage_quota_mb: number | null;
  is_active: boolean | null;
  sort_order: number | null;
  metadata: Record<string, unknown> | null;
};

function isSupportedPlanId(value: string): value is PlanId {
  return supportedPlanIds.includes(value as PlanId);
}

function toOptionalNumber(value: unknown) {
  if (value == null) {
    return undefined;
  }

  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : undefined;
}

export function buildPlanConfigFromRow(row: PricingConfigRow): PlanConfig | null {
  if (!isSupportedPlanId(row.plan_id)) {
    return null;
  }

  const amountCny = toOptionalNumber(row.price_cny);
  if (amountCny == null) {
    return null;
  }

  const fallback = fallbackPlanConfigs[row.plan_id];
  const subject = row.subject?.trim() || fallback.subject;
  const body = row.body?.trim() || fallback.body;
  const subscriptionType: PlanId = isSupportedPlanId(row.subscription_type ?? '')
    ? (row.subscription_type as PlanId)
    : fallback.subscriptionType;
  const currency = row.currency?.trim() || fallback.currency || 'CNY';

  return {
    planId: row.plan_id,
    amountCny,
    subject,
    body,
    subscriptionType,
    expiresDays: row.duration_days ?? fallback.expiresDays,
    currency,
    displayName: row.display_name?.trim() || fallback.displayName,
    description: row.description?.trim() || fallback.description,
    billingPeriod: row.billing_period?.trim() || fallback.billingPeriod,
    accountType: row.account_type ?? fallback.accountType,
    maxServers: row.max_servers ?? fallback.maxServers,
    maxDevices: row.max_devices ?? fallback.maxDevices,
    storageQuotaMb: row.storage_quota_mb ?? fallback.storageQuotaMb,
    isActive: row.is_active ?? fallback.isActive,
    sortOrder: row.sort_order ?? fallback.sortOrder,
    metadata: row.metadata ?? fallback.metadata,
  };
}

export async function getPricingConfig(
  supabase: SupabaseClient,
  planId: string,
): Promise<PlanConfig | null> {
  if (!isSupportedPlanId(planId)) {
    return null;
  }

  const { data, error } = await supabase
    .from('pricing_configs')
    .select(
      'plan_id, price_cny, subject, body, subscription_type, duration_days, currency, display_name, description, billing_period, account_type, max_servers, max_devices, storage_quota_mb, is_active, sort_order, metadata',
    )
    .eq('plan_id', planId)
    .eq('is_active', true)
    .maybeSingle<PricingConfigRow>();

  if (error) {
    throw new Error(`读取价格配置失败: ${error.message}`);
  }

  if (!data) {
    return null;
  }

  return buildPlanConfigFromRow(data);
}

export async function listActivePricingConfigs(
  supabase: SupabaseClient,
): Promise<PlanConfig[]> {
  const { data, error } = await supabase
    .from('pricing_configs')
    .select(
      'plan_id, price_cny, subject, body, subscription_type, duration_days, currency, display_name, description, billing_period, account_type, max_servers, max_devices, storage_quota_mb, is_active, sort_order, metadata',
    )
    .eq('is_active', true)
    .order('sort_order', { ascending: true })
    .order('plan_id', { ascending: true });

  if (error) {
    throw new Error(`读取价格配置列表失败: ${error.message}`);
  }

  return (data ?? [])
    .map((row) => buildPlanConfigFromRow(row as PricingConfigRow))
    .filter((item): item is PlanConfig => item != null);
}

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
