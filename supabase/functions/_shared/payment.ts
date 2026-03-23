import { createClient, type SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { createHash } from 'node:crypto';

export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
};

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

export function json(data: unknown, init?: ResponseInit) {
  return new Response(JSON.stringify(data), {
    ...init,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      ...corsHeaders,
      ...(init?.headers ?? {}),
    },
  });
}

export function getEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) {
    throw new Error(`Missing env: ${name}`);
  }
  return value;
}

export function createAdminClient(): SupabaseClient {
  return createClient(
    getEnv('SUPABASE_URL'),
    getEnv('SUPABASE_SERVICE_ROLE_KEY'),
    {
      auth: { persistSession: false },
    },
  );
}

export async function requireUser(req: Request) {
  const supabase = createClient(
    getEnv('SUPABASE_URL'),
    getEnv('SUPABASE_ANON_KEY'),
    {
      global: {
        headers: {
          Authorization: req.headers.get('Authorization') ?? '',
        },
      },
      auth: { persistSession: false },
    },
  );

  const {
    data: { user },
    error,
  } = await supabase.auth.getUser();

  if (error || !user) {
    throw new Response(JSON.stringify({ message: '未登录或登录态已失效' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json; charset=utf-8', ...corsHeaders },
    });
  }

  return user;
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

export function buildMerchantOrderId(userId: string, planId: string) {
  const compactUserId = userId.replace(/-/g, '').slice(0, 12);
  const randomPart = crypto.randomUUID().replace(/-/g, '').slice(0, 12);
  return `BP${Date.now()}${compactUserId}${planId.slice(0, 4).toUpperCase()}${randomPart}`;
}

export function signYipay(params: Record<string, string>, key: string) {
  const payload = Object.keys(params)
    .filter((k) => k !== 'sign' && k !== 'sign_type' && params[k] !== '')
    .sort()
    .map((k) => `${k}=${params[k]}`)
    .join('&');

  return createHash('md5').update(`${payload}${key}`).digest('hex');
}

export function verifyYipaySign(params: Record<string, string>, key: string) {
  const received = (params.sign ?? '').trim().toLowerCase();
  if (!received) return false;
  const expected = signYipay(params, key).toLowerCase();
  return received === expected;
}

export function centsFromAmount(amount: number) {
  return Math.round(amount * 100);
}

export function isoNow() {
  return new Date().toISOString();
}

export function coerceStringRecord(input: Record<string, unknown>) {
  const result: Record<string, string> = {};
  for (const [key, value] of Object.entries(input)) {
    if (value == null) continue;
    result[key] = String(value);
  }
  return result;
}

export async function parseBody(req: Request) {
  const contentType = req.headers.get('content-type') ?? '';
  if (contentType.includes('application/json')) {
    return await req.json();
  }
  if (contentType.includes('application/x-www-form-urlencoded')) {
    const form = await req.formData();
    return Object.fromEntries(form.entries());
  }
  return {};
}
