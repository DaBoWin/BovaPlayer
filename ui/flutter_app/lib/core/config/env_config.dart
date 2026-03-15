import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../providers/locale_provider.dart';

/// Environment config.
class EnvConfig {
  static String get supabaseUrl => dotenv.get('SUPABASE_URL', fallback: '');
  static String get supabaseAnonKey =>
      dotenv.get('SUPABASE_ANON_KEY', fallback: '');
  static bool get supabaseDebug =>
      dotenv.get('SUPABASE_DEBUG', fallback: 'false') == 'true';

  static String get environment =>
      dotenv.get('ENVIRONMENT', fallback: 'development');
  static bool get isProduction => environment == 'production';
  static bool get isDevelopment => environment == 'development';
  static bool get isTest => environment == 'test';

  static String get apiBaseUrl =>
      dotenv.get('API_BASE_URL', fallback: 'https://api.bovaplayer.com');
  static bool get enableLogging =>
      dotenv.get('ENABLE_LOGGING', fallback: 'true') == 'true';
  static bool get enableAnalytics =>
      dotenv.get('ENABLE_ANALYTICS', fallback: 'false') == 'true';

  static String get githubClientId =>
      dotenv.get('GITHUB_CLIENT_ID', fallback: '');
  static String get githubRedirectUri => dotenv.get(
        'GITHUB_REDIRECT_URI',
        fallback: 'bovaplayer://auth/github/callback',
      );

  static String get tmdbReadAccessToken =>
      dotenv.get('TMDB_READ_ACCESS_TOKEN', fallback: '');
  static String get tmdbApiKey => dotenv.get('TMDB_API_KEY', fallback: '');
  static String get tmdbBaseUrl =>
      dotenv.get('TMDB_BASE_URL', fallback: 'https://api.themoviedb.org/3');
  static String get tmdbImageBaseUrl => dotenv.get(
        'TMDB_IMAGE_BASE_URL',
        fallback: 'https://image.tmdb.org/t/p/',
      );
  static String get tmdbLanguage {
    final appLanguage = LocaleProvider.currentLanguageCode;
    if (appLanguage == 'zh') return 'zh-CN';
    if (appLanguage == 'en') return 'en-US';

    final fallback = dotenv.get('TMDB_LANGUAGE', fallback: 'en-US').trim();
    if (fallback == 'zh' || fallback == 'zh-CN') return 'zh-CN';
    if (fallback == 'en' || fallback == 'en-US') return 'en-US';
    return fallback.isEmpty ? 'en-US' : fallback;
  }

  static void printConfig() {
    if (!isDevelopment) return;

    print('=== Environment Configuration ===');
    print('Environment: $environment');
    print('API Base URL: $apiBaseUrl');
    print('Enable Logging: $enableLogging');
    print('Enable Analytics: $enableAnalytics');
    print(
      'TMDB Configured: ${tmdbReadAccessToken.isNotEmpty || tmdbApiKey.isNotEmpty}',
    );
    print('================================');
  }
}
