import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
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
    
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          PlayerScreen(),
          EmbyPage(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
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
            onTap: (index) {
              print('[MainNavigation] 切换到索引: $index');
              setState(() => _currentIndex = index);
            },
            backgroundColor: Colors.transparent,
            selectedItemColor: Colors.deepPurple.shade200,
            unselectedItemColor: Colors.white38,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
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
      ),
    );
  }
}