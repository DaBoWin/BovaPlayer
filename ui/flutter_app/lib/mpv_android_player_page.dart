import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'player/player_utils.dart';
import 'player/emby_reporter.dart';

/// MPV Android 播放器页面
/// 通过启动原生 MpvPlayerActivity 来播放视频
/// Flutter 端只负责显示加载动画和启动/关闭逻辑
class MpvAndroidPlayerPage extends StatefulWidget {
  final String url;
  final String title;
  final Map<String, String>? httpHeaders;
  final List<Map<String, String>>? subtitles;
  final String? itemId;
  final String? serverUrl;
  final String? accessToken;
  final String? userId;

  const MpvAndroidPlayerPage({
    Key? key,
    required this.url,
    required this.title,
    this.httpHeaders,
    this.subtitles,
    this.itemId,
    this.serverUrl,
    this.accessToken,
    this.userId,
  }) : super(key: key);

  @override
  State<MpvAndroidPlayerPage> createState() => _MpvAndroidPlayerPageState();
}

class _MpvAndroidPlayerPageState extends State<MpvAndroidPlayerPage>
    with WidgetsBindingObserver {
  static const platform = MethodChannel('com.bovaplayer/mpv');
  
  bool _hasError = false;
  String? _errorMessage;
  bool _activityLaunched = false;
  late EmbyReporter _embyReporter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _embyReporter = EmbyReporter(
      serverUrl: widget.serverUrl ?? '',
      accessToken: widget.accessToken ?? '',
      userId: widget.userId ?? '',
      itemId: widget.itemId ?? '',
    );
    
    // 延迟启动原生 Activity
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _launchMpvActivity();
    });
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _embyReporter.dispose();
    super.dispose();
  }
  
  /// 监听 App 生命周期 — 当原生 Activity 关闭后，Flutter 页面会恢复前台
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _activityLaunched) {
      // 原生 Activity 关闭了，用户回到 Flutter
      // 给一点延迟确保 Activity 完全关闭
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          Navigator.pop(context);
        }
      });
    }
  }
  
  Future<void> _launchMpvActivity() async {
    try {
      // 报告 Emby 播放开始
      await _embyReporter.reportPlaybackStart(0.5);
      
      // 转换字幕格式为 ArrayList<HashMap<String, String>>
      final List<Map<String, dynamic>>? subtitlesList = widget.subtitles?.map((sub) {
        return {
          'title': sub['title'] ?? '',
          'url': sub['url'] ?? '',
          'language': sub['language'] ?? '',
        };
      }).toList();
      
      final Map<String, dynamic> params = {
        'url': widget.url,
        'title': widget.title,
        'httpHeaders': widget.httpHeaders ?? {},
        'subtitles': subtitlesList,
      };
      
      await platform.invokeMethod('initialize', params);
      
      setState(() {
        _activityLaunched = true;
      });
      
      print('[MpvAndroid] Native Activity launched');
    } catch (e) {
      print('[MpvAndroid] Failed to launch: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'MPV 启动失败: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 设置全屏横屏
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 错误页
          if (_hasError)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.8),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 64),
                      const SizedBox(height: 24),
                      const Text('MPV 播放失败',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(_errorMessage!, style: const TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
                        ),
                      const SizedBox(height: 32),
                      TextButton(onPressed: () => Navigator.pop(context),
                        child: const Text('返回', style: TextStyle(color: Colors.white70))),
                    ],
                  ),
                ),
              ),
            ),
            
          // 加载动画（在原生 Activity 启动前显示）
          if (!_hasError)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.9,
                    colors: [
                      const Color(0xFF1a1a2e),
                      Colors.black,
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 多层旋转光环
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // 外圈渐变环
                            SizedBox(
                              width: 100, height: 100,
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.0, end: 1.0),
                                duration: const Duration(seconds: 2),
                                builder: (context, value, child) {
                                  return CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    strokeCap: StrokeCap.round,
                                    value: null,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color.lerp(const Color(0xFF7C3AED), const Color(0xFF06B6D4), value)!,
                                    ),
                                  );
                                },
                              ),
                            ),
                            // 内圈
                            SizedBox(
                              width: 70, height: 70,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                strokeCap: StrokeCap.round,
                                value: null,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white.withOpacity(0.3),
                                ),
                              ),
                            ),
                            // 中心 LOGO
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF7C3AED).withOpacity(0.4),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // 引擎标签
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.12)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.memory, color: Color(0xFF7C3AED), size: 14),
                            SizedBox(width: 6),
                            Text('MPV Engine',
                              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('正在加载…',
                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13, letterSpacing: 0.5)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
