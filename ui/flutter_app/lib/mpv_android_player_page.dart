import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';

/// MPV Android 播放器页面
/// 使用原生 mpv-android 库，支持所有格式（包括 TrueHD、PGS 字幕等）
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
    super.key,
    required this.url,
    required this.title,
    this.httpHeaders,
    this.subtitles,
    this.itemId,
    this.serverUrl,
    this.accessToken,
    this.userId,
  });
  
  @override
  State<MpvAndroidPlayerPage> createState() => _MpvAndroidPlayerPageState();
}

class _MpvAndroidPlayerPageState extends State<MpvAndroidPlayerPage> {
  static const platform = MethodChannel('com.bovaplayer/mpv');
  
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _hasError = false;
  String? _errorMessage;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _showControls = true;
  Timer? _hideTimer;
  Timer? _positionTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      print('[MpvAndroid] 初始化播放器');
      print('[MpvAndroid] URL: ${widget.url}');
      
      // 准备播放参数
      final Map<String, dynamic> params = {
        'url': widget.url,
        'title': widget.title,
        'httpHeaders': widget.httpHeaders ?? {},
      };
      
      // 添加字幕
      if (widget.subtitles != null && widget.subtitles!.isNotEmpty) {
        params['subtitles'] = widget.subtitles;
      }
      
      // 调用原生方法初始化播放器
      await platform.invokeMethod('initialize', params);
      
      // 开始播放
      await platform.invokeMethod('play');
      
      setState(() {
        _isInitialized = true;
        _isPlaying = true;
      });
      
      // 启动位置更新定时器
      _startPositionTimer();
      _startHideTimer();
      
      print('[MpvAndroid] 初始化成功');
    } catch (e) {
      print('[MpvAndroid] 初始化失败: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'MPV 初始化失败: $e';
      });
    }
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      if (!_isInitialized) return;
      try {
        final position = await platform.invokeMethod('getPosition');
        final duration = await platform.invokeMethod('getDuration');
        if (mounted) {
          setState(() {
            _position = Duration(milliseconds: position ?? 0);
            _duration = Duration(milliseconds: duration ?? 0);
          });
        }
      } catch (e) {
        // 忽略错误
      }
    });
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (_isPlaying) {
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _startHideTimer();
    }
  }

  Future<void> _togglePlayPause() async {
    try {
      if (_isPlaying) {
        await platform.invokeMethod('pause');
      } else {
        await platform.invokeMethod('play');
      }
      setState(() => _isPlaying = !_isPlaying);
      _startHideTimer();
    } catch (e) {
      print('[MpvAndroid] 播放/暂停失败: $e');
    }
  }

  Future<void> _seek(Duration position) async {
    try {
      await platform.invokeMethod('seek', {'position': position.inMilliseconds});
    } catch (e) {
      print('[MpvAndroid] 跳转失败: $e');
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _positionTimer?.cancel();
    
    // 停止播放器
    try {
      platform.invokeMethod('dispose');
    } catch (e) {
      print('[MpvAndroid] 释放失败: $e');
    }
    
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // MPV 渲染视图（通过 Platform View）
          if (_isInitialized && !_hasError)
            Center(
              child: AndroidView(
                viewType: 'com.bovaplayer/mpv_view',
                creationParamsCodec: StandardMessageCodec(),
              ),
            ),

          // 加载中
          if (!_isInitialized && !_hasError)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // 错误提示
          if (_hasError)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 64),
                  const SizedBox(height: 24),
                  Text(
                    _errorMessage ?? 'MPV 播放失败',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('返回'),
                  ),
                ],
              ),
            ),

          // 控制器
          if (_showControls && _isInitialized && !_hasError)
            GestureDetector(
              onTap: _toggleControls,
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: Column(
                  children: [
                    // 顶部栏
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.title,
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'MPV-Android',
                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    // 中间播放按钮
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.replay_10, color: Colors.white, size: 32),
                          onPressed: () => _seek(_position - const Duration(seconds: 10)),
                        ),
                        const SizedBox(width: 32),
                        IconButton(
                          icon: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 48,
                          ),
                          onPressed: _togglePlayPause,
                        ),
                        const SizedBox(width: 32),
                        IconButton(
                          icon: const Icon(Icons.forward_10, color: Colors.white, size: 32),
                          onPressed: () => _seek(_position + const Duration(seconds: 10)),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // 底部进度条
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Text(
                                _formatDuration(_position),
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                              Expanded(
                                child: Slider(
                                  value: _duration.inMilliseconds > 0
                                      ? _position.inMilliseconds / _duration.inMilliseconds
                                      : 0,
                                  onChanged: (value) {
                                    final newPosition = Duration(
                                      milliseconds: (value * _duration.inMilliseconds).toInt(),
                                    );
                                    _seek(newPosition);
                                  },
                                ),
                              ),
                              Text(
                                _formatDuration(_duration),
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
