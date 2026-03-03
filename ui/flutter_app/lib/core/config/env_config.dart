import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 环境配置
/// 
/// 管理应用的环境变量和配置
class EnvConfig {
  // Supabase 配置
  static String get supabaseUrl => dotenv.get('SUPABASE_URL', fallback: '');
  static String get supabaseAnonKey => dotenv.get('SUPABASE_ANON_KEY', fallback: '');
  static bool get supabaseDebug => dotenv.get('SUPABASE_DEBUG', fallback: 'false') == 'true';

  // 应用环境
  static String get environment => dotenv.get('ENVIRONMENT', fallback: 'development');

  // 是否为生产环境
  static bool get isProduction => environment == 'production';

  // 是否为开发环境
  static bool get isDevelopment => environment == 'development';

  // 是否为测试环境
  static bool get isTest => environment == 'test';

  // API 基础 URL
  static String get apiBaseUrl => dotenv.get('API_BASE_URL', fallback: 'https://api.bovaplayer.com');

  // 是否启用日志
  static bool get enableLogging => dotenv.get('ENABLE_LOGGING', fallback: 'true') == 'true';

  // 是否启用分析
  static bool get enableAnalytics => dotenv.get('ENABLE_ANALYTICS', fallback: 'false') == 'true';

  // GitHub OAuth Client ID
  static String get githubClientId => dotenv.get('GITHUB_CLIENT_ID', fallback: '');

  // GitHub OAuth Redirect URI
  static String get githubRedirectUri => dotenv.get('GITHUB_REDIRECT_URI', fallback: 'bovaplayer://auth/github/callback');

  /// 打印配置信息（仅开发环境）
  static void printConfig() {
    if (!isDevelopment) return;

    print('=== Environment Configuration ===');
    print('Environment: $environment');
    print('API Base URL: $apiBaseUrl');
    print('Enable Logging: $enableLogging');
    print('Enable Analytics: $enableAnalytics');
    print('================================');
  }
}
