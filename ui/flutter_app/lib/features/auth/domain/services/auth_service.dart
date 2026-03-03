import '../entities/user.dart';
import '../repositories/auth_repository.dart';

/// 认证服务
/// 
/// 处理认证相关的业务逻辑
class AuthService {
  final AuthRepository _repository;

  AuthService(this._repository);

  /// 注册新用户
  Future<User> register({
    required String email,
    required String password,
    String? username,
  }) async {
    // 验证邮箱格式
    if (!_isValidEmail(email)) {
      throw Exception('邮箱格式不正确');
    }

    // 验证密码强度
    if (!_isStrongPassword(password)) {
      throw Exception('密码强度不足：至少 8 位，包含字母和数字');
    }

    return await _repository.register(
      email: email,
      password: password,
      username: username,
    );
  }

  /// 登录
  Future<User> login({
    required String email,
    required String password,
  }) async {
    if (email.isEmpty || password.isEmpty) {
      throw Exception('邮箱和密码不能为空');
    }

    return await _repository.login(
      email: email,
      password: password,
    );
  }

  /// GitHub OAuth 登录
  Future<User> loginWithGitHub() async {
    return await _repository.loginWithGitHub();
  }

  /// 登出
  Future<void> logout() async {
    await _repository.logout();
  }

  /// 获取当前用户
  Future<User?> getCurrentUser() async {
    return await _repository.getCurrentUser();
  }

  /// 发送密码重置邮件
  Future<void> sendPasswordResetEmail(String email) async {
    if (!_isValidEmail(email)) {
      throw Exception('邮箱格式不正确');
    }

    await _repository.sendPasswordResetEmail(email);
  }

  /// 重置密码
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    if (!_isStrongPassword(newPassword)) {
      throw Exception('密码强度不足：至少 8 位，包含字母和数字');
    }

    await _repository.resetPassword(
      token: token,
      newPassword: newPassword,
    );
  }

  /// 更新用户信息
  Future<User> updateUser({
    String? username,
    String? avatarUrl,
  }) async {
    if (username != null && username.isEmpty) {
      throw Exception('用户名不能为空');
    }

    return await _repository.updateUser(
      username: username,
      avatarUrl: avatarUrl,
    );
  }

  /// 上传头像
  Future<User> uploadAvatar(String filePath) async {
    if (filePath.isEmpty) {
      throw Exception('请选择一张图片');
    }
    return await _repository.uploadAvatar(filePath);
  }

  /// 监听认证状态变化
  Stream<User?> get authStateChanges => _repository.authStateChanges;

  /// 刷新用户信息
  Future<User> refreshUser() async {
    return await _repository.refreshUser();
  }

  /// 验证邮箱格式
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  /// 验证密码强度
  bool _isStrongPassword(String password) {
    // 至少 8 位
    if (password.length < 8) return false;

    // 包含字母
    if (!password.contains(RegExp(r'[a-zA-Z]'))) return false;

    // 包含数字
    if (!password.contains(RegExp(r'[0-9]'))) return false;

    return true;
  }

  /// 兑换码兑换
  Future<Map<String, dynamic>> redeemCode(String code) async {
    if (code.trim().isEmpty) {
      throw Exception('请输入兑换码');
    }
    return await _repository.redeemCode(code);
  }

  /// 生成兑换码（管理员）
  Future<Map<String, dynamic>> generateCodes({
    required String type,
    required int count,
    int durationDays = 30,
    int expiresDays = 365,
    String? note,
  }) async {
    return await _repository.generateCodes(
      type: type,
      count: count,
      durationDays: durationDays,
      expiresDays: expiresDays,
      note: note,
    );
  }

  /// 查询兑换码列表（管理员）
  Future<Map<String, dynamic>> listCodes({String filter = 'all'}) async {
    return await _repository.listCodes(filter: filter);
  }
}
