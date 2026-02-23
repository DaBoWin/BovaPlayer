import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'dart:ui';
import 'package:window_manager/window_manager.dart';
import 'dart:io' show Platform;
import 'native_bridge.dart';

// 条件导入：Web 使用 player_screen.dart，移动端/桌面端使用 player_screen_mobile.dart
import 'player_screen.dart' if (dart.library.io) 'player_screen_mobile.dart';
import 'emby_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
    return MaterialApp(
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
      home: const MainNavigation(),
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

  @override
  Widget build(BuildContext context) {
    print('[MainNavigation] build 被调用，当前索引: $_currentIndex');
    
    // 只渲染当前选中的页面，避免 IndexedStack 同时初始化所有页面
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
      // EmbyPage 自己处理返回逻辑，不需要额外包装
      currentPage = const EmbyPage();
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      extendBody: true,
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
                    icon: Icons.cloud_outlined,
                    activeIcon: Icons.cloud_rounded,
                    label: 'Emby',
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