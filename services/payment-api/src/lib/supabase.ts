import { createClient, type SupabaseClient } from '@supabase/supabase-js';

import { config } from './config.js';

export function createAdminClient(): SupabaseClient {
  return createClient(config.supabaseUrl, config.supabaseServiceRoleKey, {
    auth: { persistSession: false },
  });
}

export async function requireUser(authorizationHeader?: string | null) {
  const supabase = createClient(config.supabaseUrl, config.supabaseAnonKey, {
    global: {
      headers: {
        Authorization: authorizationHeader ?? '',
      },
    },
    auth: { persistSession: false },
  });

  const {
    data: { user },
    error,
  } = await supabase.auth.getUser();

  if (error || !user) {
    const response = new Error('未登录或登录态已失效');
    (response as Error & { status?: number }).status = 401;
    throw response;
  }

  return user;
}
