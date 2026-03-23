import { createClient } from '@supabase/supabase-js';
import { config } from './config.js';
export function createAdminClient() {
    return createClient(config.supabaseUrl, config.supabaseServiceRoleKey, {
        auth: { persistSession: false },
    });
}
export async function requireUser(authorizationHeader) {
    const supabase = createClient(config.supabaseUrl, config.supabaseAnonKey, {
        global: {
            headers: {
                Authorization: authorizationHeader ?? '',
            },
        },
        auth: { persistSession: false },
    });
    const { data: { user }, error, } = await supabase.auth.getUser();
    if (error || !user) {
        const response = new Error('未登录或登录态已失效');
        response.status = 401;
        throw response;
    }
    return user;
}
