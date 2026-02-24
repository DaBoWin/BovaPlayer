import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'player/player_utils.dart';
import 'player/emby_reporter.dart';

/// MPV 播放器 - 完全复制 BetterPlayer 的 UI
class MpvPlayerWithControls extends StatefulWidget {
  final String url;
  final String title;
  final Map<String, String>? httpHeaders;
  final List<Map<String, String>>? subtitles;
  final String? itemId;
  final String? serverUrl;
  final String? accessToken;
  final String? userId;

  const MpvPlayerWithControls({
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
  State<MpvPlayerWithControls> createState() => _MpvPlayerWithControlsState();
}

class _MpvPlayerWithControlsState extends State<MpvPlayerWithControls> {
  static const platform = MethodChannel('com.bovaplayer/mpv');
  
  bool _showControls = true;
  bool _isPlaying = false;
  bool _hasError = false;
  String? _errorMessage;
  Timer? _hideTimer;
  Timer? _updateTimer;
  
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String _networkSpeed = '-- KB/s';
  int _selectedSubtitleIndex = -1;
  List<Map<String, dynamic>> _availableSubtitles = [];
  double _currentSpeed = 1.0;
  
  late EmbyReporter _embyReporter;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    _embyReporter = EmbyReporter(
      serverUrl: widget.serverUrl ?? '',
      accessToken: widget.accessToken ?? '',
      userId: widget.userId ?? '',
      itemId: widget.itemId ?? '',
    );
    
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      await _embyReporter.reportPlaybackStart(0.5);
      
      // 设置方法调用处理器
      platform.setMethodCallHandler(_handleMethodCall);
      
      final params = {
        'url': widget.url,
        'title': widget.title,
        'httpHeaders': widget.httpHeaders ?? {},
        'subtitles': widget.subtitles?.map((sub) => {
          'title': sub['title'] ?? '',
          'url': sub['url'] ?? '',
          'language': sub['language'] ?? '',
        }).toList(),
      };
      
      await platform.invokeMethod('initializeWithControls', params);
      
      setState(() {
        _isPlaying = true;
      });
      
      // 启动更新定时器
      _startUpdateTimer();
      _startHideTimer();
      
      // 延迟获取字幕列表
      Future.delayed(const Duration(seconds: 2), _loadSubtitleList);
      
      print('[MpvPlayer] 初始化成功');
    } catch (e) {
      print('[MpvPlayer] 初始化失败: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'MPV 初始化失败: $e';
      });
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onPositionUpdate':
        final position = call.arguments['position'] as int?;
        final duration = call.arguments['duration'] as int?;
        final speed = call.arguments['speed'] as String?;
        
        if (mounted) {
          setState(() {
            if (position != null) _position = Duration(milliseconds: position);
            if (duration != null) _duration = Duration(milliseconds: duration);
            if (speed != null) _networkSpeed = speed;
          });
        }
        break;
        
      case 'onPlaybackStateChanged':
        final isPlaying = call.arguments as bool?;
        if (mounted && isPlaying != null) {
          setState(() {
            _isPlaying = isPlaying;
          });
        }
        break;
        
      case 'onError':
        final error = call.arguments as String?;
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = error ?? '播放错误';
          });
        }
        break;
    }
  }

  void _startUpdateTimer() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      if (!mounted) return;
      
      try {
        final result = await platform.invokeMethod('getPlaybackState');
        if (result != null && mounted) {
          setState(() {
            _position = Duration(milliseconds: result['position'] ?? 0);
            _duration = Duration(milliseconds: result['duration'] ?? 0);
            _isPlaying = result['isPlaying'] ?? false;
            _networkSpeed = result['speed'] ?? '-- KB/s';
          });
        }
      } catch (e) {
        // Ignore errors during update
      }
    });
  }

  Future<void> _loadSubtitleList() async {
    try {
      final result = await platform.invokeMethod('getSubtitleTracks');
      if (result != null && mounted) {
        setState(() {
          _availableSubtitles = List<Map<String, dynamic>>.from(result);
        });
        print('[MpvPlayer] 加载了 ${_availableSubtitles.length} 个字幕轨道');
      }
    } catch (e) {
      print('[MpvPlayer] 获取字幕列表失败: $e');
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (_isPlaying) {
      _hideTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
  }

  Future<void> _togglePlayPause() async {
    try {
      await platform.invokeMethod('togglePlayPause');
      setState(() => _isPlaying = !_isPlaying);
      _startHideTimer();
    } catch (e) {
      print('[MpvPlayer] 切换播放状态失败: $e');
    }
  }

  Future<void> _seekTo(Duration position) async {
    try {
      await platform.invokeMethod('seekTo', {'position': position.inMilliseconds});
    } catch (e) {
      print('[MpvPlayer] 跳转失败: $e');
    }
  }

  Future<void> _skip(int seconds) async {
    final newPosition = _position + Duration(seconds: seconds);
    await _seekTo(newPosition);
    _startHideTimer();
  }

  Future<void> _setSpeed(double speed) async {
    try {
      await platform.invokeMethod('setSpeed', {'speed': speed});
      setState(() => _currentSpeed = speed);
    } catch (e) {
      print('[MpvPlayer] 设置倍速失败: $e');
    }
  }

  Future<void> _setSubtitle(int index) async {
    try {
      await platform.invokeMethod('setSubtitle', {'index': index});
      setState(() => _selectedSubtitleIndex = index);
    } catch (e) {
      print('[MpvPlayer] 切换字幕失败: $e');
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _updateTimer?.cancel();
    _embyReporter.dispose();
    
    platform.invokeMethod('dispose');
    
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // MPV 视频视图（AndroidView）
            Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: AndroidView(
                  viewType: 'com.bovaplayer/mpv_view',
                  creationParams: {
                    'url': widget.url,
                  },
                  creationParamsCodec: const StandardMessageCodec(),
                ),
              ),
            ),

            // 错误提示
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

            // 控制器UI（完全复制BetterPlayer）
            if (_showControls && !_hasError)
              _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Positioned.fill(
      child: Stack(
        children: [
          // 顶部栏
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopBar(),
          ),
          
          // 左侧工具栏
          Positioned(
            left: 24,
            top: 0,
            bottom: 0,
            child: Center(child: _buildLeftToolbar()),
          ),
          
          // 底部控制栏
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(child: _buildBottomPill()),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black54, Colors.transparent],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'MPV',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.speed, color: Colors.greenAccent, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    _networkSpeed,
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    TimeOfDay.now().format(context),
                    style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeftToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToolIconButton(Icons.subtitles_outlined, _showSubtitleMenu),
        ],
      ),
    );
  }

  Widget _buildToolIconButton(IconData icon, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildBottomPill() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.75,
          constraints: const BoxConstraints(maxWidth: 800),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white12, width: 0.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildProgressBar(),
              const SizedBox(height: 4),
              _buildControlButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    
    return Row(
      children: [
        Text(
          PlayerUtils.formatDuration(_position),
          style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onHorizontalDragUpdate: (details) {
              final RenderBox box = context.findRenderObject() as RenderBox;
              final localPosition = box.globalToLocal(details.globalPosition);
              final width = box.size.width;
              final newProgress = (localPosition.dx / width).clamp(0.0, 1.0);
              final newPosition = Duration(milliseconds: (_duration.inMilliseconds * newProgress).toInt());
              _seekTo(newPosition);
            },
            child: Container(
              height: 48,
              alignment: Alignment.center,
              child: Stack(
                alignment: Alignment.centerLeft,
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          PlayerUtils.formatDuration(_duration),
          style: const TextStyle(color: Colors.white54, fontSize: 12, fontFamily: 'monospace'),
        ),
      ],
    );
  }

  Widget _buildControlButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Icon(Icons.volume_up_rounded, color: Colors.white70, size: 20),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.replay_10_rounded),
              color: Colors.white,
              iconSize: 28,
              onPressed: () => _skip(-10),
            ),
            const SizedBox(width: 16),
            Container(
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: IconButton(
                icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                color: Colors.black,
                iconSize: 32,
                onPressed: _togglePlayPause,
              ),
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.forward_10_rounded),
              color: Colors.white,
              iconSize: 28,
              onPressed: () => _skip(10),
            ),
          ],
        ),
        InkWell(
          onTap: _showSpeedMenu,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: const Text('倍速', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  void _showSpeedMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1F2937),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '播放速度',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final speed in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
                      InkWell(
                        onTap: () {
                          _setSpeed(speed);
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            '${speed}x',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showSubtitleMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF1F2937),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '字幕',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildSubtitleOption(
                        title: '关闭',
                        isSelected: _selectedSubtitleIndex == -1,
                        onTap: () {
                          _setSubtitle(-1);
                          Navigator.pop(context);
                        },
                      ),
                      if (_availableSubtitles.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.subtitles_off_outlined,
                                color: Colors.white.withOpacity(0.3),
                                size: 48,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '暂无可用字幕',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        for (int i = 0; i < _availableSubtitles.length; i++)
                          _buildSubtitleOption(
                            title: _availableSubtitles[i]['title'] ?? '字幕 ${i + 1}',
                            subtitle: _availableSubtitles[i]['language'],
                            isSelected: _selectedSubtitleIndex == i,
                            onTap: () {
                              _setSubtitle(i);
                              Navigator.pop(context);
                            },
                          ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitleOption({
    required String title,
    String? subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isSelected ? Icons.check_circle : Icons.subtitles_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check,
                color: Colors.white,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
