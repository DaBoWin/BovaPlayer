import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'player/player_utils.dart';
import 'player/emby_reporter.dart';
import 'player/player_gestures.dart';

/// MPV Android 播放器页面
/// 使用原生 mpv-android 库，支持所有格式（包括 TrueHD、DTS-HD MA、PGS 字幕等）
/// UI 与 BetterPlayerPage 完全一致
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

class _MpvAndroidPlayerPageState extends State<MpvAndroidPlayerPage> with PlayerGesturesMixin {
  static const platform = MethodChannel('com.bovaplayer/mpv');
  late EmbyReporter _embyReporter;
  
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _showControls = true;
  bool _isLocked = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration? _savedPosition;
  int _selectedSubtitleIndex = -1;
  bool _isDraggingProgress = false;
  double _dragProgressPosition = 0;
  
  Timer? _hideTimer;
  Timer? _positionTimer;
  Timer? _clockTimer;
  Timer? _savePositionTimer;
  String _currentTime = '';
  String _networkSpeed = '-- KB/s';

  // --- PlayerGesturesMixin 必须实现的方法 ---
  @override
  bool get isLocked => _isLocked;

  @override
  void setVolume(double volume) {
    if (_isInitialized) {
      platform.invokeMethod('setVolume', {'volume': (volume * 100).toInt()}).catchError((_) {});
    }
  }

  @override
  Duration? getCurrentDuration() => _duration;

  @override
  Duration? getCurrentPosition() => _position;

  @override
  void seekTo(Duration position) {
    platform.invokeMethod('seek', {'position': position.inMilliseconds}).catchError((_) {});
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    _embyReporter = EmbyReporter(
      itemId: widget.itemId,
      serverUrl: widget.serverUrl,
      accessToken: widget.accessToken,
      userId: widget.userId,
    );

    // 监听来自 Kotlin 的回调
    platform.setMethodCallHandler(_handleNativeCall);
    
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
    
    // 延迟到 PlatformView 创建后再渲染
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _loadAndInitialize();
        }
      });
    });
  }

  Future<void> _loadAndInitialize() async {
    _savedPosition = await PlayerUtils.loadSavedPosition(widget.itemId);
    await _initializePlayer();
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onMpvReady':
        print('[MpvAndroid] 收到 onMpvReady 回调');
        if (mounted) {
          setState(() {
            _isInitialized = true;
            _isPlaying = true;
          });
          _startPositionTimer();
          _startHideTimer();
          _startSavePositionTimer();
          
          // Emby 报告
          await _embyReporter.reportPlaybackStart(0.5);
          _embyReporter.startReportProgressTimer(() => _reportProgress());
          
          // 恢复播放对话框
          if (_savedPosition != null && _savedPosition!.inSeconds > 5) {
            _showResumeDialog();
          }
        }
        break;
      case 'onError':
        final msg = call.arguments as String? ?? 'Unknown error';
        print('[MpvAndroid] 收到 onError 回调: $msg');
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = msg;
          });
        }
        break;
    }
  }

  Future<void> _initializePlayer() async {
    try {
      print('[MpvAndroid] 初始化播放器');
      print('[MpvAndroid] URL: ${widget.url}');
      
      final Map<String, dynamic> params = {
        'url': widget.url,
        'title': widget.title,
        'httpHeaders': widget.httpHeaders ?? {},
      };
      
      if (widget.subtitles != null && widget.subtitles!.isNotEmpty) {
        params['subtitles'] = widget.subtitles;
      }
      
      await platform.invokeMethod('initialize', params);
      print('[MpvAndroid] initialize 调用成功，等待 MPV 就绪回调...');
    } catch (e) {
      print('[MpvAndroid] 初始化失败: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'MPV 初始化失败: $e';
        });
      }
    }
  }

  void _reportProgress() {
    if (_isInitialized) {
      _embyReporter.reportPlaybackProgress(_position, !_isPlaying, 0.5);
    }
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      if (!_isInitialized || !mounted) return;
      try {
        final position = await platform.invokeMethod('getPosition');
        final duration = await platform.invokeMethod('getDuration');
        if (mounted) {
          setState(() {
            _position = Duration(milliseconds: position ?? 0);
            _duration = Duration(milliseconds: duration ?? 0);
          });
        }
      } catch (_) {}
    });
  }

  void _startSavePositionTimer() {
    _savePositionTimer?.cancel();
    _savePositionTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      PlayerUtils.savePlayPosition(widget.itemId, _position, _duration);
    });
  }

  Future<void> _showResumeDialog() async {
    if (!mounted || _savedPosition == null) return;
    final resume = await PlayerUtils.showResumeDialog(context, _savedPosition!);
    if (resume == true && _savedPosition != null) {
      seekTo(_savedPosition!);
    }
  }

  void _updateClock() {
    if (mounted) setState(() => _currentTime = DateFormat('HH:mm').format(DateTime.now()));
  }

  // --- 控制方法 ---
  void _startHideTimer() {
    _hideTimer?.cancel();
    if (!_isLocked && _isPlaying) {
      _hideTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _showControls = false);
      });
    }
  }

  void _toggleControls() {
    if (_isLocked) return;
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

  @override
  void dispose() {
    _hideTimer?.cancel();
    _clockTimer?.cancel();
    _savePositionTimer?.cancel();
    _positionTimer?.cancel();
    disposeGestures();
    
    PlayerUtils.savePlayPosition(widget.itemId, _position, _duration);
    _embyReporter.reportPlaybackStopped(_position);
    _embyReporter.dispose();
    
    try {
      platform.invokeMethod('dispose');
    } catch (_) {}
    
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 1024) return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    if (bytesPerSecond < 1024 * 1024) return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(2)} MB/s';
  }

  // ============= BUILD =============

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // MPV 渲染视图
          if (!_hasError)
            Positioned.fill(
              child: AndroidView(
                viewType: 'com.bovaplayer/mpv_view',
                creationParamsCodec: const StandardMessageCodec(),
              ),
            ),

          // 触摸拦截层（AndroidView 会吞掉触摸事件）
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _toggleControls,
              onVerticalDragUpdate: (details) {
                final screenWidth = MediaQuery.of(context).size.width;
                final isLeft = details.globalPosition.dx < screenWidth / 2;
                handleVerticalDragUpdate(details, isLeft);
              },
              onHorizontalDragStart: handleHorizontalDragStart,
              onHorizontalDragUpdate: (details) => handleHorizontalDragUpdate(details, context),
              onHorizontalDragEnd: handleHorizontalDragEnd,
              child: Container(color: Colors.transparent),
            ),
          ),

          // 手势指示器
          buildBrightnessIndicator(),
          buildVolumeIndicator(),
          buildSeekIndicator(),

          // 加载中 — 炫酷动画
          if (!_isInitialized && !_hasError)
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
                            // 外圈 — 旋转渐变环
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
                            // 内圈 — 反向旋转
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

          // 控制器 UI
          if (_showControls && !_isLocked && _isInitialized && !_hasError)
            Positioned.fill(
              child: Stack(
                children: [
                  // 顶部阴影
                  Positioned(top: 0, left: 0, right: 0, height: 100,
                    child: Container(
                      decoration: const BoxDecoration(gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.black54, Colors.transparent],
                      )),
                    ),
                  ),
                  // 顶部工具栏
                  Positioned(top: 0, left: 0, right: 0, child: _buildTopBar()),
                  // 左侧工具栏
                  Positioned(left: 24, top: 0, bottom: 0, child: Center(child: _buildLeftToolbar())),
                  // 底部胶囊
                  Positioned(bottom: 40, left: 0, right: 0, child: Center(child: _buildBottomPill())),
                ],
              ),
            ),

          // 锁屏按钮（始终显示）
          if (_showControls && _isInitialized)
            Positioned(
              left: 16,
              top: MediaQuery.of(context).size.height / 2 - 24,
              child: IconButton(
                icon: Icon(_isLocked ? Icons.lock : Icons.lock_open, color: Colors.white, size: 28),
                onPressed: () {
                  setState(() => _isLocked = !_isLocked);
                  if (_isLocked) _hideTimer?.cancel(); else _startHideTimer();
                },
              ),
            ),
        ],
      ),
    );
  }

  // --- 现代 UI 组件（与 BetterPlayerPage 一致） ---

  Widget _buildTopBar() {
    return SafeArea(
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
                color: Colors.deepPurple.withOpacity(0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('MPV', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(widget.title, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w400, letterSpacing: 0.5),
                overflow: TextOverflow.ellipsis),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.speed, color: Colors.greenAccent, size: 14),
                const SizedBox(width: 4),
                Text(_networkSpeed, style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(width: 12),
                Text(_currentTime, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToolIconButton(Icons.subtitles_outlined, _showSubtitleMenu),
          const SizedBox(height: 16),
          _buildToolIconButton(Icons.audiotrack_outlined, _showAudioTrackMenu),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(Icons.volume_up_rounded, color: Colors.white70, size: 20),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.replay_10_rounded), color: Colors.white, iconSize: 28,
                        onPressed: () { seekTo(_position - const Duration(seconds: 10)); _startHideTimer(); },
                      ),
                      const SizedBox(width: 16),
                      Container(
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: IconButton(
                          icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                          color: Colors.black, iconSize: 32,
                          onPressed: () { _togglePlayPause(); },
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.forward_10_rounded), color: Colors.white, iconSize: 28,
                        onPressed: () { seekTo(_position + const Duration(seconds: 10)); _startHideTimer(); },
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Row(
      children: [
        Text(
          _isDraggingProgress
              ? PlayerUtils.formatDuration(Duration(milliseconds: _dragProgressPosition.toInt()))
              : PlayerUtils.formatDuration(_position),
          style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            final totalWidth = constraints.maxWidth;
            final maxMs = _duration.inMilliseconds.toDouble();
            final currentMs = _isDraggingProgress ? _dragProgressPosition : _position.inMilliseconds.toDouble();
            final progress = maxMs > 0 ? (currentMs / maxMs).clamp(0.0, 1.0) : 0.0;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (_) {
                _hideTimer?.cancel();
                setState(() { _isDraggingProgress = true; _dragProgressPosition = _position.inMilliseconds.toDouble(); });
              },
              onHorizontalDragUpdate: (details) {
                if (maxMs <= 0) return;
                final msDelta = (details.delta.dx / totalWidth) * maxMs;
                setState(() => _dragProgressPosition = (_dragProgressPosition + msDelta).clamp(0.0, maxMs));
              },
              onHorizontalDragEnd: (_) {
                seekTo(Duration(milliseconds: _dragProgressPosition.toInt()));
                setState(() => _isDraggingProgress = false);
                _startHideTimer();
              },
              child: Container(
                height: 48, alignment: Alignment.center,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  clipBehavior: Clip.none,
                  children: [
                    Container(height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(2))),
                    FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(2))),
                    ),
                    Positioned(
                      left: (progress * totalWidth) - 6,
                      child: Container(
                        width: 12, height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 1))],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
        const SizedBox(width: 12),
        Text(PlayerUtils.formatDuration(_duration),
          style: const TextStyle(color: Colors.white54, fontSize: 12, fontFamily: 'monospace')),
      ],
    );
  }

  // --- 菜单 ---

  void _showSpeedMenu() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(color: Color(0xFF1F2937), borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text('播放速度', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
                for (final speed in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
                  InkWell(
                    onTap: () {
                      platform.invokeMethod('setSpeed', {'speed': speed}).catchError((_) {});
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5)),
                      child: Text('${speed}x', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }

  void _showSubtitleMenu() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        decoration: const BoxDecoration(color: Color(0xFF1F2937), borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text('字幕', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(children: [
                  _buildOptionTile(title: '关闭', isSelected: _selectedSubtitleIndex == -1, icon: Icons.subtitles_off_outlined,
                    onTap: () {
                      setState(() => _selectedSubtitleIndex = -1);
                      platform.invokeMethod('setSubtitle', {'index': -1}).catchError((_) {});
                      Navigator.pop(context);
                    }),
                  if (widget.subtitles == null || widget.subtitles!.isEmpty)
                    Padding(padding: const EdgeInsets.all(24),
                      child: Column(children: [
                        Icon(Icons.subtitles_off_outlined, color: Colors.white.withOpacity(0.3), size: 48),
                        const SizedBox(height: 12),
                        Text('暂无可用字幕', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
                      ]))
                  else
                    for (int i = 0; i < widget.subtitles!.length; i++)
                      _buildOptionTile(
                        title: widget.subtitles![i]['title'] ?? '字幕 ${i + 1}',
                        subtitle: widget.subtitles![i]['language'],
                        isSelected: _selectedSubtitleIndex == i,
                        icon: Icons.subtitles_outlined,
                        onTap: () {
                          setState(() => _selectedSubtitleIndex = i);
                          final subUrl = widget.subtitles![i]['url']!;
                          platform.invokeMethod('loadSubtitle', {'url': subUrl}).catchError((_) {});
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('已切换到: ${widget.subtitles![i]['title']}'),
                            duration: const Duration(seconds: 2),
                            backgroundColor: const Color(0xFF1F2937),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ));
                        },
                      ),
                ]),
              ),
            ),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }

  void _showAudioTrackMenu() {
    // MPV 可以通过内嵌音轨切换
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('MPV 会自动使用最佳音轨（TrueHD/DTS 原生解码）'),
      duration: Duration(seconds: 2),
      backgroundColor: Color(0xFF1F2937),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Widget _buildOptionTile({required String title, String? subtitle, required bool isSelected, required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(isSelected ? Icons.check_circle : icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
            if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13))],
          ])),
          if (isSelected) const Icon(Icons.check, color: Colors.white, size: 24),
        ]),
      ),
    );
  }
}
