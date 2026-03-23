export function getEnv(name: string): string {
  const value = process.env[name]?.trim();
  if (!value) {
    throw new Error(`Missing env: ${name}`);
  }
  return value;
}

export function getOptionalEnv(name: string): string | undefined {
  const value = process.env[name]?.trim();
  return value ? value : undefined;
}

export const config = {
  port: Number.parseInt(process.env.PORT ?? '8787', 10) || 8787,
  supabaseUrl: getEnv('SUPABASE_URL'),
  supabaseAnonKey: getEnv('SUPABASE_ANON_KEY'),
  supabaseServiceRoleKey: getEnv('SUPABASE_SERVICE_ROLE_KEY'),
  apiPublicBaseUrl: getEnv('API_PUBLIC_BASE_URL'),
  paymentReturnUrl: getEnv('PAYMENT_RETURN_URL'),
  yipayApiUrl: getEnv('YIPAY_API_URL'),
  yipayPid: getEnv('YIPAY_PID'),
  yipayKey: getEnv('YIPAY_KEY'),
};
