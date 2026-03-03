import 'package:supabase_flutter/supabase_flutter.dart';
import 'env_config.dart';

/// Supabase 配置
/// 
/// 包含 Supabase 项目的连接信息和客户端初始化
class SupabaseConfig {
  // Supabase 客户端实例（延迟初始化）
  static SupabaseClient? _instance;

  /// 初始化 Supabase 客户端
  static Future<void> initialize() async {
    if (_instance != null) {
      return; // 已经初始化
    }

    await Supabase.initialize(
      url: EnvConfig.supabaseUrl,
      anonKey: EnvConfig.supabaseAnonKey,
      debug: EnvConfig.supabaseDebug,
    );

    _instance = Supabase.instance.client;
  }

  /// 获取 Supabase 客户端
  static SupabaseClient get client {
    if (_instance == null) {
      throw Exception('Supabase not initialized. Call SupabaseConfig.initialize() first.');
    }
    return _instance!;
  }

  /// 获取认证客户端
  static GoTrueClient get auth => client.auth;

  /// 获取数据库客户端
  static PostgrestQueryBuilder from(String table) => client.from(table);

  /// 获取存储客户端
  static SupabaseStorageClient get storage => client.storage;
}
