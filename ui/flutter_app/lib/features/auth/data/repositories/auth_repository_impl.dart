import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/user.dart' as domain;
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';

/// 认证仓库实现
/// 
/// 使用 Supabase 实现认证功能
class AuthRepositoryImpl implements AuthRepository {
  final SupabaseClient _supabase;

  AuthRepositoryImpl({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  @override
  Future<domain.User> register({
    required String email,
    required String password,
    String? username,
  }) async {
    try {
      // 注册用户（触发器会自动创建 users 和 user_settings 记录）
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'username': username,
        },
      );

      if (response.user == null) {
        throw Exception('注册失败：未返回用户信息');
      }

      // 等待一小段时间，确保触发器执行完成
      await Future.delayed(const Duration(milliseconds: 500));

      // 获取完整用户信息（触发器已经创建了记录）
      return await _fetchUserInfo(response.user!.id);
    } on AuthException catch (e) {
      throw Exception('注册失败：${e.message}');
    } catch (e) {
      throw Exception('注册失败：$e');
    }
  }

  @override
  Future<domain.User> login({
    required String email,
    required String password,
  }) async {
    try {
      print('[AuthRepo] 开始登录: $email');
      
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('登录失败：未返回用户信息');
      }

      print('[AuthRepo] Supabase Auth 登录成功: ${response.user!.id}');
      
      // 获取用户信息
      try {
        final user = await _fetchUserInfo(response.user!.id);
        print('[AuthRepo] 获取用户信息成功');
        return user;
      } catch (e) {
        print('[AuthRepo] 获取用户信息失败: $e');
        // 如果获取用户信息失败，可能是触发器没有创建记录
        // 尝试手动创建
        print('[AuthRepo] 尝试手动创建用户记录...');
        await _createUserRecordManually(response.user!.id, response.user!.email!);
        return await _fetchUserInfo(response.user!.id);
      }
    } on AuthException catch (e) {
      print('[AuthRepo] Auth 异常: ${e.message}');
      throw Exception('登录失败：${e.message}');
    } catch (e) {
      print('[AuthRepo] 登录异常: $e');
      throw Exception('登录失败：$e');
    }
  }

  @override
  Future<domain.User> loginWithGitHub() async {
    try {
      final response = await _supabase.auth.signInWithOAuth(
        OAuthProvider.github,
        redirectTo: 'bovaplayer://auth/callback',
      );

      if (!response) {
        throw Exception('GitHub 登录失败');
      }

      // 等待认证完成
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('GitHub 登录失败：未获取到用户信息');
      }

      // 检查用户记录是否存在，不存在则创建
      await _ensureUserRecord(user.id, user.email!);

      return await _fetchUserInfo(user.id);
    } on AuthException catch (e) {
      throw Exception('GitHub 登录失败：${e.message}');
    } catch (e) {
      throw Exception('GitHub 登录失败：$e');
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
    } on AuthException catch (e) {
      throw Exception('登出失败：${e.message}');
    }
  }

  @override
  Future<domain.User?> getCurrentUser() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      return await _fetchUserInfo(user.id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw Exception('发送重置邮件失败：${e.message}');
    }
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } on AuthException catch (e) {
      throw Exception('重置密码失败：${e.message}');
    }
  }

  @override
  Future<domain.User> updateUser({
    String? username,
    String? avatarUrl,
  }) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('未登录');
      }

      // 更新用户元数据
      if (username != null || avatarUrl != null) {
        await _supabase.auth.updateUser(
          UserAttributes(
            data: {
              if (username != null) 'username': username,
              if (avatarUrl != null) 'avatar_url': avatarUrl,
            },
          ),
        );
      }

      // 更新数据库记录
      await _supabase.from('users').update({
        if (username != null) 'username': username,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', currentUser.id);

      return await _fetchUserInfo(currentUser.id);
    } on AuthException catch (e) {
      throw Exception('更新用户信息失败：${e.message}');
    } catch (e) {
      throw Exception('更新用户信息失败：$e');
    }
  }

  @override
  Future<domain.User> uploadAvatar(String filePath) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('未登录');

      final file = File(filePath);
      final ext = filePath.split('.').last.toLowerCase();
      final storagePath = 'avatars/$userId/avatar.$ext';

      // 上传到 Supabase Storage
      await _supabase.storage.from('avatars').upload(
        storagePath,
        file,
        fileOptions: const FileOptions(upsert: true),
      );

      // 获取公开 URL
      final publicUrl = _supabase.storage.from('avatars').getPublicUrl(storagePath);

      // 更新用户记录
      return await updateUser(avatarUrl: publicUrl);
    } catch (e) {
      throw Exception('上传头像失败：$e');
    }
  }

  @override
  Stream<domain.User?> get authStateChanges {
    return _supabase.auth.onAuthStateChange.asyncMap((state) async {
      final user = state.session?.user;
      if (user == null) return null;

      try {
        return await _fetchUserInfo(user.id);
      } catch (e) {
        return null;
      }
    });
  }

  @override
  Future<domain.User> refreshUser() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('未登录');
    }

    return await _fetchUserInfo(user.id);
  }

  /// 确保用户记录存在（用于 OAuth 登录）
  Future<void> _ensureUserRecord(String userId, String email) async {
    final existing = await _supabase
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (existing == null) {
      // OAuth 登录时，如果触发器没有创建记录，手动创建
      // 注意：这种情况很少见，因为触发器应该已经处理了
      throw Exception('用户记录不存在，请重新登录');
    }
  }

  /// 手动创建用户记录（备用方案）
  Future<void> _createUserRecordManually(String userId, String email) async {
    try {
      // 尝试插入 users 记录
      await _supabase.from('users').insert({
        'id': userId,
        'email': email,
        'account_type': 'free',
        'max_servers': 10,
        'max_devices': 2,
        'storage_quota_mb': 100,
        'storage_used_mb': 0,
        'device_count': 0,
      });

      // 尝试插入 user_settings 记录
      await _supabase.from('user_settings').insert({
        'user_id': userId,
        'sync_enabled': true,
        'sync_mode': 'supabase',
      });
      
      print('[AuthRepo] 手动创建用户记录成功');
    } catch (e) {
      print('[AuthRepo] 手动创建用户记录失败: $e');
      // 如果失败，可能是 RLS 问题或记录已存在
      // 继续尝试获取用户信息
    }
  }

  /// 获取用户信息
  Future<domain.User> _fetchUserInfo(String userId) async {
    try {
      print('[AuthRepo] 获取用户信息: $userId');
      
      // 获取用户基本信息
      final userData = await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      print('[AuthRepo] 用户数据: $userData');

      // 统计服务器数量
      try {
        final serverCountResult = await _supabase
            .from('media_servers')
            .select('id')
            .eq('user_id', userId)
            .eq('is_active', true);
        
        final serverCount = (serverCountResult as List).length;
        print('[AuthRepo] 服务器数量: $serverCount');

        // 将服务器数量添加到用户数据中
        final enrichedData = {
          ...userData,
          'server_count': serverCount,
        };

        return UserModel.fromJson(enrichedData).toEntity();
      } catch (e) {
        print('[AuthRepo] 统计服务器数量失败: $e');
        // 如果统计失败，使用 0
        final enrichedData = {
          ...userData,
          'server_count': 0,
        };
        return UserModel.fromJson(enrichedData).toEntity();
      }
    } catch (e) {
      print('[AuthRepo] 获取用户信息失败: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> redeemCode(String code) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('未登录');

      print('[AuthRepo] 兑换码兑换: $code');
      final result = await _supabase.rpc('redeem_code', params: {
        'p_code': code.trim().toUpperCase(),
        'p_user_id': user.id,
      });

      print('[AuthRepo] 兑换结果: $result');
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      print('[AuthRepo] 兑换码兑换失败: $e');
      throw Exception('兑换失败：$e');
    }
  }

  @override
  Future<Map<String, dynamic>> generateCodes({
    required String type,
    required int count,
    int durationDays = 30,
    int expiresDays = 365,
    String? note,
  }) async {
    try {
      print('[AuthRepo] 生成兑换码: type=$type, count=$count');
      final result = await _supabase.rpc('generate_codes', params: {
        'p_type': type,
        'p_count': count,
        'p_duration_days': durationDays,
        'p_expires_days': expiresDays,
        'p_note': note,
      });

      print('[AuthRepo] 生成结果: $result');
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      print('[AuthRepo] 生成兑换码失败: $e');
      throw Exception('生成失败：$e');
    }
  }

  @override
  Future<Map<String, dynamic>> listCodes({String filter = 'all'}) async {
    try {
      print('[AuthRepo] 查询兑换码列表: filter=$filter');
      final result = await _supabase.rpc('list_codes', params: {
        'p_filter': filter,
      });

      print('[AuthRepo] 查询结果类型: ${result.runtimeType}');
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      print('[AuthRepo] 查询兑换码列表失败: $e');
      throw Exception('查询失败：$e');
    }
  }
}
