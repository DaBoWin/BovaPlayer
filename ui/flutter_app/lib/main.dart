import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'native_bridge.dart';

// 条件导入
import 'player_screen.dart' if (dart.library.io) 'player_screen_desktop.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化原生库
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
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const PlayerScreen(),
    );
  }
}