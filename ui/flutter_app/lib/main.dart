import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'dart:io' show File, Platform;
import 'dart:ui';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:window_manager/window_manager.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'native_bridge.dart';

// 条件导入：Web 使用 player_screen.dart，移动端/桌面端使用 player_screen_mobile.dart
import 'player_screen.dart' if (dart.library.io) 'player_screen_mobile.dart';
import 'media_library_page.dart';
import 'widgets/custom_app_bar.dart';

// 云同步功能
import 'core/config/env_config.dart';
import 'features/auth/domain/services/auth_service.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/presentation/providers/auth_provider.dart' as auth_provider;
import 'features/auth/domain/entities/user.dart' as auth_entities show AccountType, User;
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/register_page.dart';
import 'features/auth/presentation/pages/forgot_password_page.dart';
import 'features/auth/presentation/pages/account_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 加载环境变量
  try {
    await dotenv.load(fileName: '.env');
    print('[Main] 环境变量加载成功');
  } catch (e) {
    print('[Main] 环境变量加载失败: $e');
  }
  
  // 初始化 Supabase
  try {
    await Supabase.initialize(
      url: EnvConfig.supabaseUrl,
      anonKey: EnvConfig.supabaseAnonKey,
      debug: EnvConfig.supabaseDebug,
    );
    print('[Main] Supabase 初始化成功');
    print('[Main] Supabase URL: ${EnvConfig.supabaseUrl}');
  } catch (e) {
    print('[Main] Supabase 初始化失败: $e');
  }
  
  // 初始化 media_kit（必须在使用任何 media_kit API 之前调用）
  MediaKit.ensureInitialized();
  print('[Main] media_kit 已初始化');

  try {
    final result = await NativeBridge.initialize();
    print('[Main] Native bridge initialized: $result');
  } catch (error) {
    print('[Main] Failed to initialize native library: $error');
  }
  
  // 初始化桌面端窗口设置 (无边框体验)
  if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 800),
      minimumSize: Size(800, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      title: 'BovaPlayer',
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const BovaPlayerApp());
}

class BovaPlayerApp extends StatelessWidget {
  const BovaPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 创建认证依赖
    final authRepository = AuthRepositoryImpl();
    final authService = AuthService(authRepository);
    
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => auth_provider.AuthProvider(authService),
        ),
      ],
      child: MaterialApp(
        title: 'BovaPlayer',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.deepPurple,
          scaffoldBackgroundColor: const Color(0xFF1A1A2E),
          useMaterial3: true,
          colorScheme: ColorScheme.dark(
            primary: Colors.deepPurple,
            secondary: Colors.purple.shade300,
            surface: const Color(0xFF16213E),
          ),
        ),
        home: const AuthWrapper(),
        routes: {
          '/login': (context) => const LoginPage(),
          '/register': (context) => const RegisterPage(),
          '/forgot-password': (context) => const ForgotPasswordPage(),
          '/account': (context) => const AccountPage(),
          '/main': (context) => const MainNavigation(),
        },
      ),
    );
  }
}

/// 认证包装器
/// 
/// 根据认证状态决定显示登录页还是主页
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<auth_provider.AuthProvider>(
      builder: (context, authProvider, _) {
        // 初始状态或加载中，显示加载指示器
        if (authProvider.state == auth_provider.AuthState.initial ||
            authProvider.state == auth_provider.AuthState.loading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // 已认证，显示主页
        if (authProvider.isAuthenticated) {
          return const MainNavigation();
        }

        // 未认证，显示登录页
        return const LoginPage();
      },
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final GlobalKey<MediaLibraryPageState> _mediaLibraryKey = GlobalKey<MediaLibraryPageState>();
  String? _localAvatarPath;

  @override
  void initState() {
    super.initState();
    _loadLocalAvatar();
    // 监听认证状态变化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<auth_provider.AuthProvider>(context, listen: false);
      authProvider.addListener(_onAuthStateChanged);
    });
  }

  Future<void> _loadLocalAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('local_avatar_path');
    if (path != null && File(path).existsSync()) {
      setState(() => _localAvatarPath = path);
    }
  }

  @override
  void dispose() {
    final authProvider = Provider.of<auth_provider.AuthProvider>(context, listen: false);
    authProvider.removeListener(_onAuthStateChanged);
    super.dispose();
  }

  void _onAuthStateChanged() {
    final authProvider = Provider.of<auth_provider.AuthProvider>(context, listen: false);
    // 如果用户已登出，不需要手动导航，AuthWrapper 会自动处理
    if (!authProvider.isAuthenticated) {
      print('[MainNavigation] 检测到登出，AuthWrapper 将显示登录页');
    }
  }

  void _navigateToAccount() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AccountPage(),
      ),
    );
    // 返回时重新加载头像
    _loadLocalAvatar();
  }

  Widget _buildMiniAvatar(auth_entities.User? user, Color bgColor) {
    final initial = user?.username?.substring(0, 1).toUpperCase() ??
        user?.email.substring(0, 1).toUpperCase() ??
        '?';
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.add, color: Color(0xFF1F2937), size: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      offset: const Offset(0, 40),
      onSelected: (type) {
        if (type == 'emby') {
          _mediaLibraryKey.currentState?.showAddSourceDialog(SourceType.emby);
        } else if (type == 'smb') {
          _mediaLibraryKey.currentState?.showAddSourceDialog(SourceType.smb);
        } else if (type == 'ftp') {
          _mediaLibraryKey.currentState?.showAddSourceDialog(SourceType.ftp);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'emby',
          child: Row(
            children: [
              Icon(Icons.cloud_outlined, size: 18),
              SizedBox(width: 12),
              Text('Emby 服务器', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'smb',
          child: Row(
            children: [
              Icon(Icons.folder_shared_outlined, size: 18),
              SizedBox(width: 12),
              Text('SMB 共享', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'ftp',
          child: Row(
            children: [
              Icon(Icons.storage_outlined, size: 18),
              SizedBox(width: 12),
              Text('FTP 服务器', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    print('[MainNavigation] build 被调用，当前索引: $_currentIndex');
    
    // 获取用户信息用于显示标记
    final authProvider = Provider.of<auth_provider.AuthProvider>(context);
    final user = authProvider.user;
    
    // 根据账户类型确定用户图标颜色和徽章
    Color iconColor = const Color(0xFF1F2937); // 默认深灰色
    String badge = '';
    auth_entities.AccountType? accountType = user?.accountType;
    if (user != null) {
      switch (user.accountType) {
        case auth_entities.AccountType.pro:
          iconColor = const Color(0xFF3B82F6); // 钻石蓝色
          badge = '💎';
          break;
        case auth_entities.AccountType.lifetime:
          iconColor = const Color(0xFFF59E0B); // 黄金色
          badge = '👑';
          break;
        case auth_entities.AccountType.free:
        default:
          iconColor = const Color(0xFF1F2937);
          badge = '';
      }
    }
    
    // 构建标题 Widget
    Widget? titleWidget;
    if (accountType == auth_entities.AccountType.pro || 
        accountType == auth_entities.AccountType.lifetime) {
      titleWidget = _AnimatedTitle(
        isPro: accountType == auth_entities.AccountType.pro,
      );
    }
    
    // 只渲染当前选中的页面
    Widget currentPage;
    if (_currentIndex == 0) {
      currentPage = WillPopScope(
        onWillPop: () async {
          print('[MainNavigation] 本地播放页面返回');
          final shouldExit = await _showExitConfirmDialog();
          return shouldExit;
        },
        child: const PlayerScreen(),
      );
    } else {
      currentPage = MediaLibraryPage(key: _mediaLibraryKey);
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      extendBody: true,
      appBar: CustomAppBar(
        title: 'BovaPlayer',
        titleWidget: titleWidget,
        actions: [
          // 媒体库页面显示同步和添加按钮
          if (_currentIndex == 1) ...[
            IconButton(
              icon: const Icon(Icons.sync, color: Color(0xFF1F2937), size: 20),
              onPressed: () {
                _mediaLibraryKey.currentState?.refreshAndSync();
              },
              tooltip: '刷新并同步',
            ),
            _buildAddButton(),
          ],
          // 账号按钮 - 显示用户头像
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _navigateToAccount,
              child: _AnimatedAvatarRing(
                iconColor: iconColor,
                isPaid: badge.isNotEmpty,
                isPro: user?.accountType == auth_entities.AccountType.pro,
                child: _localAvatarPath != null
                    ? ClipOval(
                        child: Image.file(
                          File(_localAvatarPath!),
                          width: 30,
                          height: 30,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildMiniAvatar(user, iconColor),
                        ),
                      )
                    : _buildMiniAvatar(user, iconColor),
              ),
            ),
          ),
        ],
      ),
      body: currentPage,
      // 始终显示底部导航栏，方便用户在横屏时也能切换页面
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7), // 增加透明度
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), // 增强模糊效果
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(
                    icon: Icons.play_circle_outline_rounded,
                    activeIcon: Icons.play_circle_rounded,
                    label: '本地播放',
                    isActive: _currentIndex == 0,
                    onTap: () {
                      print('[MainNavigation] 切换到索引: 0');
                      setState(() => _currentIndex = 0);
                    },
                  ),
                  _buildNavItem(
                    icon: Icons.video_library_outlined,
                    activeIcon: Icons.video_library,
                    label: '媒体库',
                    isActive: _currentIndex == 1,
                    onTap: () {
                      print('[MainNavigation] 切换到索引: 1');
                      setState(() => _currentIndex = 1);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Future<bool> _showExitConfirmDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          '退出应用',
          style: TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.w600),
        ),
        content: const Text(
          '确定要退出应用吗？',
          style: TextStyle(color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1F2937),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 70,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                color: isActive ? const Color(0xFF1F2937) : const Color(0xFF9CA3AF),
                size: 28,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? const Color(0xFF1F2937) : const Color(0xFF9CA3AF),
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 动态标题组件 - 渐变文字 + 旋转图标
class _AnimatedTitle extends StatefulWidget {
  final bool isPro;
  const _AnimatedTitle({required this.isPro});

  @override
  State<_AnimatedTitle> createState() => _AnimatedTitleState();
}

class _AnimatedTitleState extends State<_AnimatedTitle>
    with TickerProviderStateMixin {
  late AnimationController _colorController;
  late AnimationController _iconController;

  @override
  void initState() {
    super.initState();
    // 颜色渐变循环
    _colorController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    // 图标旋转 + 呼吸
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _colorController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_colorController, _iconController]),
      builder: (context, child) {
        final List<Color> gradientColors = widget.isPro
            ? [
                Color.lerp(const Color(0xFF3B82F6), const Color(0xFF8B5CF6), _colorController.value)!,
                Color.lerp(const Color(0xFF8B5CF6), const Color(0xFF06B6D4), _colorController.value)!,
              ]
            : [
                Color.lerp(const Color(0xFFF59E0B), const Color(0xFFEF4444), _colorController.value)!,
                Color.lerp(const Color(0xFFEF4444), const Color(0xFFF97316), _colorController.value)!,
              ];

        // 图标呼吸缩放 0.85 ~ 1.15
        final breathValue = ((_iconController.value * 2 * 3.14159).remainder(6.28318)).abs();
        final scale = 0.85 + 0.3 * ((breathValue < 3.14159) ? breathValue / 3.14159 : (6.28318 - breathValue) / 3.14159);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 渐变文字
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: const Text(
                'BovaPlayer',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 6),
            // 旋转 + 呼吸图标
            Transform.scale(
              scale: scale,
              child: Transform.rotate(
                angle: _iconController.value * 2 * 3.14159,
                child: ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: Icon(
                    widget.isPro ? Icons.diamond : Icons.auto_awesome,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AnimatedAvatarRing extends StatefulWidget {
  final Color iconColor;
  final bool isPaid; // 是否付费用户（Pro或永久）
  final bool isPro; // true=Pro, false=Lifetime
  final Widget child;

  const _AnimatedAvatarRing({
    required this.iconColor,
    required this.isPaid,
    required this.isPro,
    required this.child,
  });

  @override
  State<_AnimatedAvatarRing> createState() => _AnimatedAvatarRingState();
}

class _AnimatedAvatarRingState extends State<_AnimatedAvatarRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (widget.isPaid) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedAvatarRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPaid && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isPaid && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isPaid) {
      // 免费用户 - 静态灰色圆环
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.iconColor,
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: Padding(
              padding: const EdgeInsets.all(1),
              child: widget.child,
            ),
          ),
        ),
      );
    }

    // Pro/Lifetime 用户 - 动态旋转变色圆环
    final List<Color> gradientColors = widget.isPro
        ? [
            const Color(0xFF3B82F6), // 蓝
            const Color(0xFF8B5CF6), // 紫
            const Color(0xFF06B6D4), // 青
            const Color(0xFF3B82F6), // 蓝（闭合）
          ]
        : [
            const Color(0xFFF59E0B), // 金
            const Color(0xFFEF4444), // 红
            const Color(0xFFF97316), // 橙
            const Color(0xFFF59E0B), // 金（闭合）
          ];

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: gradientColors[0].withOpacity(0.3 + 0.2 * _controller.value),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: CustomPaint(
            painter: _GradientRingPainter(
              colors: gradientColors,
              progress: _controller.value,
              strokeWidth: 2.5,
            ),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(1),
                  child: widget.child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 渐变旋转圆环画笔
class _GradientRingPainter extends CustomPainter {
  final List<Color> colors;
  final double progress;
  final double strokeWidth;

  _GradientRingPainter({
    required this.colors,
    required this.progress,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // 旋转渐变
    final sweepGradient = SweepGradient(
      startAngle: progress * 2 * 3.14159,
      endAngle: progress * 2 * 3.14159 + 2 * 3.14159,
      colors: colors,
      tileMode: TileMode.clamp,
    );

    final paint = Paint()
      ..shader = sweepGradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _GradientRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}