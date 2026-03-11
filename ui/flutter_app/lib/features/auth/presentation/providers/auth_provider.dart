import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/user.dart';
import '../../domain/services/auth_service.dart';
import '../../../sync/domain/services/sync_service.dart';
import '../../../sync/data/repositories/sync_repository_impl.dart';
import '../../../sync/domain/services/device_service.dart';

/// 认证状态
enum AuthState {
  initial, // 初始状态
  loading, // 加载中
  authenticated, // 已认证
  unauthenticated, // 未认证
  error, // 错误
}

/// 认证 Provider
///
/// 管理认证状态和用户信息
class AuthProvider with ChangeNotifier {
  final AuthService _authService;
  SyncService? _syncService;
  DeviceService? _deviceService;

  AuthState _state = AuthState.initial;
  User? _user;
  String? _errorMessage;

  AuthProvider(this._authService) {
    _init();
  }

  // Getters
  AuthState get state => _state;
  User? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated =>
      _state == AuthState.authenticated && _user != null;
  bool get isLoading => _state == AuthState.loading;

  /// 初始化
  Future<void> _init() async {
    try {
      _setState(AuthState.loading);

      // 初始化同步服务
      await _initSyncService();

      // 获取当前用户
      final user = await _authService.getCurrentUser();

      if (user != null) {
        _user = user;
        _setState(AuthState.authenticated);

        // 检查是否需要设置密码以启用同步
        _checkSyncPasswordStatus();
      } else {
        _setState(AuthState.unauthenticated);
      }

      // 监听认证状态变化
      _authService.authStateChanges.listen((user) {
        _user = user;
        if (user != null) {
          _setState(AuthState.authenticated);
          _checkSyncPasswordStatus();
        } else {
          _setState(AuthState.unauthenticated);
        }
      });
    } catch (e) {
      _setError('初始化失败：$e');
    }
  }

  /// 检查同步密码状态
  void _checkSyncPasswordStatus() {
    if (_syncService == null) return;

    final syncRepo = _syncService!.repository as SyncRepositoryImpl;
    if (!syncRepo.hasUserPassword) {
      debugPrint('[Auth] ⚠️  用户已登录但密码未设置，同步功能不可用');
      debugPrint('[Auth] 提示：需要重新登录或手动输入密码以启用同步');
    } else {
      debugPrint('[Auth] ✅ 同步功能已启用');
    }
  }

  /// 初始化同步服务
  Future<void> _initSyncService() async {
    try {
      debugPrint('[Auth] 开始初始化同步服务...');
      final prefs = await SharedPreferences.getInstance();
      final syncRepo = SyncRepositoryImpl(prefs: prefs);
      _syncService = SyncService(syncRepo);
      _deviceService = DeviceService();
      debugPrint('[Auth] ✅ 同步服务初始化成功');
    } catch (e) {
      debugPrint('[Auth] ❌ 初始化同步服务失败：$e');
    }
  }

  /// 注册
  Future<bool> register({
    required String email,
    required String password,
    String? username,
  }) async {
    try {
      _setState(AuthState.loading);

      _user = await _authService.register(
        email: email,
        password: password,
        username: username,
      );

      _setState(AuthState.authenticated);
      _bootstrapSyncAfterPasswordAuth(password);

      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// 登录
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('[Auth] 🔐 开始登录...');
      _setState(AuthState.loading);

      _user = await _authService.login(
        email: email,
        password: password,
      );

      debugPrint('[Auth] ✅ 登录成功，用户: ${_user?.email}');
      _setState(AuthState.authenticated);
      _bootstrapSyncAfterPasswordAuth(password);

      return true;
    } catch (e) {
      debugPrint('[Auth] ❌ 登录失败：$e');
      _setError(e.toString());
      return false;
    }
  }

  /// 执行首次同步（后台执行，不阻塞 UI）
  Future<void> _performInitialSync() async {
    debugPrint('[Auth] 🔄 _performInitialSync 被调用');

    if (_syncService == null) {
      debugPrint('[Auth] ❌ 同步服务未初始化');
      return;
    }

    if (_deviceService == null) {
      debugPrint('[Auth] ❌ 设备服务未初始化');
      return;
    }

    try {
      // 1. 注册当前设备
      debugPrint('[Auth] 📱 注册设备...');
      await _deviceService!.registerCurrentDevice();
      debugPrint('[Auth] ✅ 设备注册完成');

      // 2. 同步数据
      debugPrint('[Auth] 🔄 开始首次同步...');
      await _syncService!.performInitialSync();
      debugPrint('[Auth] ✅ 首次同步完成');

      // 3. 同步完成后刷新用户数据（更新使用量统计）
      debugPrint('[Auth] 🔄 刷新用户数据...');
      await refreshUser();
      debugPrint('[Auth] ✅ 用户数据刷新完成');
    } catch (e, stackTrace) {
      debugPrint('[Auth] ❌ 首次同步失败：$e');
      debugPrint('[Auth] 堆栈跟踪：$stackTrace');
      // 同步失败不影响登录流程
    }
  }

  void _bootstrapSyncAfterPasswordAuth(String password) {
    if (_syncService == null) {
      debugPrint('[Auth] ⚠️  同步服务未初始化，跳过自动同步');
      return;
    }

    final syncRepo = _syncService!.repository as SyncRepositoryImpl;
    syncRepo.setUserPassword(password);
    debugPrint('[Auth] ✅ 已设置同步密码，准备后台同步媒体源');

    Future<void>(() async {
      try {
        await _syncService!.repository.syncMediaServers();
        debugPrint('[Auth] ✅ 媒体源同步完成');
      } catch (e, stackTrace) {
        debugPrint('[Auth] ❌ 媒体源同步失败：$e');
        debugPrint('[Auth] 堆栈跟踪：$stackTrace');
      }
    });

    Future<void>(() async {
      await _performInitialSync();
    });
  }

  /// GitHub 登录
  Future<bool> loginWithGitHub() async {
    try {
      _setState(AuthState.loading);

      _user = await _authService.loginWithGitHub();

      _setState(AuthState.authenticated);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// 登出
  Future<void> logout() async {
    try {
      _setState(AuthState.loading);

      await _authService.logout();

      // 清除用户密码
      if (_syncService != null) {
        final syncRepo = _syncService!.repository as SyncRepositoryImpl;
        syncRepo.clearUserPassword();
        debugPrint('[Auth] 已清除用户密码');
      }

      _user = null;
      _setState(AuthState.unauthenticated);
    } catch (e) {
      _setError(e.toString());
    }
  }

  /// 发送密码重置邮件
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      _setState(AuthState.loading);

      await _authService.sendPasswordResetEmail(email);

      _setState(
          _user != null ? AuthState.authenticated : AuthState.unauthenticated);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// 更新用户信息
  Future<bool> updateUser({
    String? username,
    String? avatarUrl,
  }) async {
    try {
      _setState(AuthState.loading);

      _user = await _authService.updateUser(
        username: username,
        avatarUrl: avatarUrl,
      );

      _setState(AuthState.authenticated);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// 上传头像
  Future<bool> uploadAvatar(String filePath) async {
    try {
      _setState(AuthState.loading);
      _user = await _authService.uploadAvatar(filePath);
      _setState(AuthState.authenticated);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// 刷新用户信息
  Future<void> refreshUser() async {
    try {
      if (_user == null) {
        debugPrint('[Auth] 刷新失败：用户未登录');
        return;
      }

      debugPrint('[Auth] 开始刷新用户信息...');
      _user = await _authService.refreshUser();
      debugPrint('[Auth] 刷新成功');
      notifyListeners();
    } catch (e) {
      debugPrint('[Auth] 刷新用户信息失败：$e');
      // 不抛出异常，避免影响 UI
    }
  }

  /// 清除错误
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// 手动触发同步（供其他页面调用）
  Future<void> triggerSync() async {
    if (_syncService == null) {
      debugPrint('[Auth] 同步服务未初始化');
      return;
    }

    // 检查用户是否为 Pro 用户
    if (_user != null && !_user!.isPro) {
      debugPrint('[Auth] ⚠️  云同步功能仅限 Pro 用户使用');
      return;
    }

    // 检查是否有用户密码（即同步是否已启用）
    final syncRepo = _syncService!.repository as SyncRepositoryImpl;
    if (!syncRepo.hasUserPassword) {
      debugPrint('[Auth] ⚠️  云同步未启用');
      debugPrint('[Auth] 提示：请在账户页面启用云同步功能');
      return;
    }

    try {
      debugPrint('[Auth] 手动触发同步...');
      await _syncService!.performIncrementalSync();
      debugPrint('[Auth] 同步完成');
    } catch (e) {
      debugPrint('[Auth] 同步失败: $e');
      // 不抛出异常，避免影响 UI
    }
  }

  /// 设置密码以启用同步（用于已登录但密码不在内存的情况）
  Future<bool> enableSyncWithPassword(String password) async {
    if (_syncService == null) {
      debugPrint('[Auth] 同步服务未初始化');
      return false;
    }

    if (_user == null) {
      debugPrint('[Auth] 用户未登录');
      return false;
    }

    try {
      // 验证密码是否正确（通过尝试重新登录）
      debugPrint('[Auth] 验证密码...');
      await _authService.login(
        email: _user!.email,
        password: password,
      );

      // 密码正确，设置到同步服务
      final syncRepo = _syncService!.repository as SyncRepositoryImpl;
      syncRepo.setUserPassword(password);
      debugPrint('[Auth] ✅ 密码已设置，同步功能已启用');

      // 通知监听者状态已改变
      notifyListeners();

      // 执行一次同步
      await triggerSync();

      return true;
    } catch (e) {
      debugPrint('[Auth] ❌ 密码验证失败: $e');
      return false;
    }
  }

  /// 兑换码兑换
  Future<Map<String, dynamic>> redeemCode(String code) async {
    try {
      debugPrint('[Auth] 🎫 兑换码兑换: $code');
      final result = await _authService.redeemCode(code);

      if (result['success'] == true) {
        // 兑换成功，刷新用户信息
        await refreshUser();
        debugPrint('[Auth] ✅ 兑换成功: ${result['message']}');
      }

      return result;
    } catch (e) {
      debugPrint('[Auth] ❌ 兑换失败: $e');
      return {'success': false, 'message': '兑换失败：$e'};
    }
  }

  /// 生成兑换码（管理员）
  Future<Map<String, dynamic>> generateCodes({
    required String type,
    required int count,
    int durationDays = 30,
    int expiresDays = 365,
    String? note,
  }) async {
    try {
      debugPrint('[Auth] 🔑 生成兑换码: type=$type, count=$count');
      return await _authService.generateCodes(
        type: type,
        count: count,
        durationDays: durationDays,
        expiresDays: expiresDays,
        note: note,
      );
    } catch (e) {
      debugPrint('[Auth] ❌ 生成兑换码失败: $e');
      return {'success': false, 'message': '生成失败：$e'};
    }
  }

  /// 查询兑换码列表（管理员）
  Future<Map<String, dynamic>> listCodes({String filter = 'all'}) async {
    try {
      return await _authService.listCodes(filter: filter);
    } catch (e) {
      debugPrint('[Auth] ❌ 查询兑换码列表失败: $e');
      return {'success': false, 'message': '查询失败：$e'};
    }
  }

  /// 检查同步是否可用
  bool get isSyncEnabled {
    if (_syncService == null) return false;
    final syncRepo = _syncService!.repository as SyncRepositoryImpl;
    return syncRepo.hasUserPassword;
  }

  /// 设置状态
  void _setState(AuthState state) {
    _state = state;
    if (state != AuthState.error) {
      _errorMessage = null;
    }
    notifyListeners();
  }

  /// 设置错误
  void _setError(String message) {
    _state = AuthState.error;
    _errorMessage = message;
    notifyListeners();
  }
}
