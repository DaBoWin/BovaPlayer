import '../entities/user.dart';

/// 认证仓库接口
/// 
/// 定义认证相关的数据操作
abstract class AuthRepository {
  /// 注册新用户
  Future<User> register({
    required String email,
    required String password,
    String? username,
  });

  /// 登录
  Future<User> login({
    required String email,
    required String password,
  });

  /// GitHub OAuth 登录
  Future<User> loginWithGitHub();

  /// 登出
  Future<void> logout();

  /// 获取当前用户
  Future<User?> getCurrentUser();

  /// 发送密码重置邮件
  Future<void> sendPasswordResetEmail(String email);

  /// 重置密码
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  });

  /// 更新用户信息
  Future<User> updateUser({
    String? username,
    String? avatarUrl,
  });

  /// 上传头像并更新用户信息
  Future<User> uploadAvatar(String filePath);

  /// 监听认证状态变化
  Stream<User?> get authStateChanges;

  /// 刷新用户信息
  Future<User> refreshUser();

  /// 兑换码兑换
  Future<Map<String, dynamic>> redeemCode(String code);

  /// 生成兑换码（管理员）
  Future<Map<String, dynamic>> generateCodes({
    required String type,
    required int count,
    int durationDays = 30,
    int expiresDays = 365,
    String? note,
  });

  /// 查询兑换码列表（管理员）
  Future<Map<String, dynamic>> listCodes({String filter = 'all'});
}
