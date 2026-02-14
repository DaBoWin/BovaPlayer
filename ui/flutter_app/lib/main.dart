import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'native_bridge.dart';

// 条件导入：Web 使用 player_screen.dart，其他平台使用 player_screen_desktop.dart
import 'player_screen.dart' if (dart.library.io) 'player_screen_desktop.dart';
import 'emby_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化 media_kit（添加详细日志）
  MediaKit.ensureInitialized();
  
  print('[Main] media_kit 已初始化');

  NativeBridge.initialize().then((result) {
    print('Native bridge initialized: $result');
    runApp(const BovaPlayerApp());
  }).catchError((error) {
    print('Failed to initialize native library: $error');
    runApp(const BovaPlayerApp());
  });
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

  final List<Widget> _pages = [
    const PlayerScreen(),
    const EmbyPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: const Color(0xFF16213E),
          selectedItemColor: Colors.deepPurple.shade200,
          unselectedItemColor: Colors.white38,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.play_circle_outline),
              activeIcon: Icon(Icons.play_circle_filled),
              label: '本地播放',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.cloud_outlined),
              activeIcon: Icon(Icons.cloud),
              label: 'Emby',
            ),
          ],
        ),
      ),
    );
  }
}