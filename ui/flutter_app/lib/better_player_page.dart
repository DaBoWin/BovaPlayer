import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'player/player_utils.dart';
import 'player/emby_reporter.dart';
import 'player/player_gestures.dart';

class BetterPlayerPage extends StatefulWidget {
  final String url;
  final String title;
  final Map<String, String>? httpHeaders;
  final List<Map<String, String>>? subtitles;
  final String? itemId;
  final String? serverUrl;
  final String? accessToken;
  final String? userId;
  
  const BetterPlayerPage({
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
  State<BetterPlayerPage> createState() => _BetterPlayerPageState();
}

class _BetterPlayerPageState extends State<BetterPlayerPage> with PlayerGesturesMixin {
  BetterPlayerController? _betterPlayerController;
  late EmbyReporter _embyReporter;
  static const _trafficLightsChannel = MethodChannel('com.bovaplayer/traffic_lights');
  
  bool _showControls = true;
  bool _isLocked = false;
  Timer? _hideTimer;
  Timer? _clockTimer;
  Timer? _savePositionTimer;
  Timer? _speedTimer;
  String _currentTime = '';
  String _networkSpeed = '-- KB/s';
  int _lastBufferPosition = 0;
  DateTime _lastSpeedCheck = DateTime.now();
  int _selectedSubtitleIndex = -1; // -1 表示关闭字幕
  bool _isDraggingProgress = false;
  double _dragProgressPosition = 0;
  
  Duration? _savedPosition;

  @override
  bool get isLocked => _isLocked;

  @override
  void setVolume(double volume) {
    _betterPlayerController?.setVolume(volume);
  }

  @override
  Duration? getCurrentDuration() {
    return _betterPlayerController?.videoPlayerController?.value.duration;
  }

  @override
  void seekTo(Duration position) {
    _betterPlayerController?.seekTo(position);
  }

  @override
  Duration? getCurrentPosition() {
    return _betterPlayerController?.videoPlayerController?.value.position;
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
    
    _loadAndInitialize();
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
    _speedTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateNetworkSpeed());
  }

  Future<void> _loadAndInitialize() async {
    _savedPosition = await PlayerUtils.loadSavedPosition(widget.itemId);
    await _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      print('[BetterPlayer] 初始化播放器');
      
      // 准备字幕
      final subtitles = <BetterPlayerSubtitlesSource>[];
      if (widget.subtitles != null) {
        for (var sub in widget.subtitles!) {
          subtitles.add(
            BetterPlayerSubtitlesSource(
              type: BetterPlayerSubtitlesSourceType.network,
              name: sub['title'],
              urls: [sub['url']!],
            ),
          );
        }
      }
      
      // 配置数据源
      final dataSource = BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        widget.url,
        headers: widget.httpHeaders,
        subtitles: subtitles,
        cacheConfiguration: const BetterPlayerCacheConfiguration(
          useCache: true,
          preCacheSize: 10 * 1024 * 1024,
          maxCacheSize: 100 * 1024 * 1024,
          maxCacheFileSize: 50 * 1024 * 1024,
        ),
        videoFormat: BetterPlayerVideoFormat.other,
      );
      
      // 配置播放器 - 完全禁用默认控制器
      final configuration = BetterPlayerConfiguration(
        aspectRatio: 16 / 9,
        fit: BoxFit.contain,
        autoPlay: true,
        looping: false,
        fullScreenByDefault: false,
        allowedScreenSleep: false,
        controlsConfiguration: const BetterPlayerControlsConfiguration(
          enableSkips: false,
          enableFullscreen: false,
          enablePip: false,
          enablePlayPause: false,
          enableMute: false,
          enableProgressText: false,
          enableProgressBar: false,
          enableSubtitles: false,
          enablePlaybackSpeed: false,
          enableAudioTracks: false,
          enableOverflowMenu: false,
          showControls: false,
        ),
        eventListener: (event) {
          if (event.betterPlayerEventType == BetterPlayerEventType.initialized) {
            print('[BetterPlayer] 初始化完成');
            if (_savedPosition != null && _savedPosition!.inSeconds > 5) {
              _showResumeDialog();
            }
          }
        },
      );
      
      _betterPlayerController = BetterPlayerController(configuration);
      await _betterPlayerController!.setupDataSource(dataSource);
      
      _startSavePositionTimer();
      await _embyReporter.reportPlaybackStart(0.5);
      _embyReporter.startReportProgressTimer(() => _reportProgress());
      
      if (mounted) {
        setState(() {});
        _startHideTimer();
      }
    } catch (e) {
      print('[BetterPlayer] 初始化失败: $e');
    }
  }

  void _reportProgress() {
    final position = _betterPlayerController?.videoPlayerController?.value.position;
    final isPlaying = _betterPlayerController?.isPlaying() ?? false;
    if (position != null) {
      _embyReporter.reportPlaybackProgress(position, !isPlaying, 0.5);
    }
  }

  void _startSavePositionTimer() {
    _savePositionTimer?.cancel();
    _savePositionTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      final position = _betterPlayerController?.videoPlayerController?.value.position;
      final duration = _betterPlayerController?.videoPlayerController?.value.duration;
      PlayerUtils.savePlayPosition(widget.itemId, position, duration);
    });
  }

  Future<void> _showResumeDialog() async {
    if (!mounted || _savedPosition == null) return;
    final resume = await PlayerUtils.showResumeDialog(context, _savedPosition!);
    if (resume == true && _savedPosition != null) {
      await _betterPlayerController!.seekTo(_savedPosition!);
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _clockTimer?.cancel();
    _savePositionTimer?.cancel();
    _speedTimer?.cancel();
    disposeGestures();
    
    final position = _betterPlayerController?.videoPlayerController?.value.position;
    final duration = _betterPlayerController?.videoPlayerController?.value.duration;
    PlayerUtils.savePlayPosition(widget.itemId, position, duration);
    
    if (position != null) {
      _embyReporter.reportPlaybackStopped(position);
    }
    _embyReporter.dispose();
    
    // 恢复 macOS 红绿灯
    if (Platform.isMacOS) {
      _trafficLightsChannel.invokeMethod('show');
    }
    
    _betterPlayerController?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _updateClock() {
    if (mounted) setState(() => _currentTime = DateFormat('HH:mm').format(DateTime.now()));
  }

  void _updateNetworkSpeed() {
    if (!mounted || _betterPlayerController == null) return;
    
    try {
      final videoPlayerController = _betterPlayerController!.videoPlayerController;
      if (videoPlayerController == null) return;
      
      final position = videoPlayerController.value.position;
      final buffered = videoPlayerController.value.buffered;
      
      // 计算缓冲区末尾位置
      int currentBufferMs = 0;
      if (buffered.isNotEmpty) {
        final lastBuffer = buffered.last;
        currentBufferMs = lastBuffer.end.inMilliseconds;
      }
      
      // 计算时间差
      final now = DateTime.now();
      final timeDiff = now.difference(_lastSpeedCheck).inSeconds.toDouble();
      
      if (timeDiff >= 1.0) {
        final bufferDiff = currentBufferMs - _lastBufferPosition;
        
        // 如果缓冲区在增长，说明正在下载
        if (bufferDiff > 0) {
          // 估算码率（基于视频分辨率）
          final width = videoPlayerController.value.size?.width ?? 1920;
          final height = videoPlayerController.value.size?.height ?? 1080;
          
          double estimatedBitrate; // Kbps
          if (width >= 1920 || height >= 1080) {
            estimatedBitrate = 8000; // 1080p: 8 Mbps
          } else if (width >= 1280 || height >= 720) {
            estimatedBitrate = 4000; // 720p: 4 Mbps
          } else {
            estimatedBitrate = 2000; // 480p: 2 Mbps
          }
          
          // 缓冲增量（秒）* 码率（Kbps）/ 8 = 下载的字节数
          final bufferIncreaseSec = bufferDiff / 1000.0;
          final downloadedBytes = (bufferIncreaseSec * estimatedBitrate * 1000) / 8;
          
          // 下载速度 = 下载的字节数 / 时间差
          final bytesPerSecond = downloadedBytes / timeDiff;
          
          if (bytesPerSecond > 0) {
            setState(() {
              _networkSpeed = _formatSpeed(bytesPerSecond);
            });
          }
        } else if (bufferDiff < 0) {
          // 缓冲区在减少，说明在播放但没有下载
          setState(() {
            _networkSpeed = '0 KB/s';
          });
        }
        
        _lastBufferPosition = currentBufferMs;
        _lastSpeedCheck = now;
      }
      
      // 显示缓冲状态
      if (videoPlayerController.value.isBuffering) {
        setState(() {
          _networkSpeed = '缓冲中...';
        });
      }
    } catch (e) {
      print('[BetterPlayer] 更新网速失败: $e');
    }
  }

  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 0) return '0 B/s';
    
    if (bytesPerSecond < 1024) {
      return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    } else if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(2)} MB/s';
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (!_isLocked && (_betterPlayerController?.isPlaying() ?? false)) {
      _hideTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() => _showControls = false);
          if (Platform.isMacOS) {
            _trafficLightsChannel.invokeMethod('hide');
          }
        }
      });
    }
  }

  void _toggleControls() {
    if (_isLocked) return;
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      if (Platform.isMacOS) {
        _trafficLightsChannel.invokeMethod('show');
      }
      _startHideTimer();
    } else {
      if (Platform.isMacOS) {
        _trafficLightsChannel.invokeMethod('hide');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _betterPlayerController == null
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : GestureDetector(
              onTap: _toggleControls,
              onVerticalDragUpdate: (details) {
                final screenWidth = MediaQuery.of(context).size.width;
                final isLeft = details.globalPosition.dx < screenWidth / 2;
                handleVerticalDragUpdate(details, isLeft);
              },
              onHorizontalDragStart: handleHorizontalDragStart,
              onHorizontalDragUpdate: (details) => handleHorizontalDragUpdate(details, context),
              onHorizontalDragEnd: handleHorizontalDragEnd,
              child: Stack(
                children: [
                  // 视频播放器
                  Center(
                    child: AspectRatio(
                      aspectRatio: _betterPlayerController!.getAspectRatio() ?? 16 / 9,
                      child: BetterPlayer(controller: _betterPlayerController!),
                    ),
                  ),

                  // 手势指示器
                  buildBrightnessIndicator(),
                  buildVolumeIndicator(),
                  buildSeekIndicator(),

                  // 锁屏按钮
                  if (_showControls && !_isLocked) 
                    Positioned.fill(
                      child: Stack(
                        children: [
                          // 顶部状态栏阴影 (微弱)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: 100,
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.black54, Colors.transparent],
                                ),
                              ),
                            ),
                          ),
                          // 顶部工具栏
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: _buildTopBar(),
                          ),
                          // 左侧悬浮工具栏 (字幕/比例)
                          Positioned(
                            left: 24,
                            top: 0,
                            bottom: 0,
                            child: Center(child: _buildLeftToolbar()),
                          ),
                          // 底部悬浮控制台 (高斯模糊胶囊)
                          Positioned(
                            bottom: 40,
                            left: 0,
                            right: 0,
                            child: Center(child: _buildBottomPill()),
                          ),
                        ],
                      ),
                    ),

                  // 总是可点击的锁屏按钮
                  if (_showControls)
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
            ),
    );
  }

  // --- 现代 UI 组件 ---

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
            // 原生引擎标签
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'NATIVE',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            // 将标题居中
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
            // 右侧网速与时间
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
                  _currentTime,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                ),
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
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToolIconButton(Icons.subtitles_outlined, _showSubtitleMenu),
          const SizedBox(height: 16),
          _buildToolIconButton(Icons.crop_free, () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('画面比例功能在此核心暂不适用')),
            );
          }),
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
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
              // 时间与进度条
              _buildProgressBarPill(),
              const SizedBox(height: 4),
              // 控制按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 左侧：音量 (这里通过手势控制，可以留空或加个喇叭图标)
                  Row(
                    children: [
                      Icon(Icons.volume_up_rounded, color: Colors.white70, size: 20),
                    ],
                  ),
                  // 中间：播放控制
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.replay_10_rounded),
                        color: Colors.white,
                        iconSize: 28,
                        onPressed: () {
                          final position = _betterPlayerController!.videoPlayerController!.value.position;
                          _betterPlayerController!.seekTo(position - const Duration(seconds: 10));
                          _startHideTimer();
                        },
                      ),
                      const SizedBox(width: 16),
                      Container(
                        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: IconButton(
                          icon: Icon((_betterPlayerController?.isPlaying() ?? false) ? Icons.pause_rounded : Icons.play_arrow_rounded),
                          color: Colors.black,
                          iconSize: 32,
                          onPressed: () {
                            if (_betterPlayerController!.isPlaying() ?? false) {
                              _betterPlayerController!.pause();
                            } else {
                              _betterPlayerController!.play();
                            }
                            _startHideTimer();
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.forward_10_rounded),
                        color: Colors.white,
                        iconSize: 28,
                        onPressed: () {
                          final position = _betterPlayerController!.videoPlayerController!.value.position;
                          _betterPlayerController!.seekTo(position + const Duration(seconds: 10));
                          _startHideTimer();
                        },
                      ),
                    ],
                  ),
                  // 右侧：倍速
                  InkWell(
                    onTap: _showSpeedMenu,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                      child: Text('倍速', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
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

  Widget _buildProgressBarPill() {
    if (_betterPlayerController == null) return const SizedBox.shrink();
    
    final position = _betterPlayerController!.videoPlayerController?.value.position ?? Duration.zero;
    final duration = _betterPlayerController!.videoPlayerController?.value.duration ?? Duration.zero;
    
    return Row(
      children: [
        Text(
          _isDraggingProgress
              ? PlayerUtils.formatDuration(Duration(milliseconds: _dragProgressPosition.toInt()))
              : PlayerUtils.formatDuration(position),
          style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              final maxMs = duration.inMilliseconds.toDouble();
              final currentMs = _isDraggingProgress
                  ? _dragProgressPosition
                  : position.inMilliseconds.toDouble();
              final progress = maxMs > 0 ? (currentMs / maxMs).clamp(0.0, 1.0) : 0.0;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (details) {
                  _hideTimer?.cancel();
                  setState(() {
                    _isDraggingProgress = true;
                    _dragProgressPosition = position.inMilliseconds.toDouble();
                  });
                },
                onHorizontalDragUpdate: (details) {
                  if (maxMs <= 0) return;
                  final delta = details.delta.dx;
                  final msDelta = (delta / totalWidth) * maxMs;
                  setState(() {
                    _dragProgressPosition = (_dragProgressPosition + msDelta).clamp(0.0, maxMs);
                  });
                },
                onHorizontalDragEnd: (details) {
                  _betterPlayerController!.seekTo(Duration(milliseconds: _dragProgressPosition.toInt()));
                  setState(() {
                    _isDraggingProgress = false;
                  });
                  _startHideTimer();
                },
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    clipBehavior: Clip.none,
                    children: [
                      // 背景轨道
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // 已播放轨道
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
                      // 滑块圆点
                      Positioned(
                        left: (progress * totalWidth) - 6,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Text(
          PlayerUtils.formatDuration(duration),
          style: const TextStyle(color: Colors.white54, fontSize: 12, fontFamily: 'monospace'),
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
                          _betterPlayerController?.setSpeed(speed);
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
                      // 关闭字幕选项
                      _buildSubtitleOption(
                        title: '关闭',
                        subtitle: null,
                        isSelected: _selectedSubtitleIndex == -1,
                        onTap: () async {
                          setState(() {
                            _selectedSubtitleIndex = -1;
                          });
                          
                          try {
                            // 使用 setupSubtitleSource 清除字幕
                            await _betterPlayerController?.setupSubtitleSource(
                              BetterPlayerSubtitlesSource(
                                type: BetterPlayerSubtitlesSourceType.none,
                              ),
                            );
                            print('[BetterPlayer] 字幕已关闭');
                          } catch (e) {
                            print('[BetterPlayer] 关闭字幕失败: $e');
                          }
                          
                          if (mounted) Navigator.pop(context);
                        },
                      ),
                      // 显示可用的字幕
                      if (widget.subtitles == null || widget.subtitles!.isEmpty)
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
                        for (int i = 0; i < widget.subtitles!.length; i++)
                          _buildSubtitleOption(
                            title: widget.subtitles![i]['title'] ?? '字幕 ${i + 1}',
                            subtitle: widget.subtitles![i]['language'],
                            isSelected: _selectedSubtitleIndex == i,
                            onTap: () async {
                              final subtitleTitle = widget.subtitles![i]['title'] ?? '字幕 ${i + 1}';
                              final subtitleUrl = widget.subtitles![i]['url']!;
                              
                              setState(() {
                                _selectedSubtitleIndex = i;
                              });
                              
                              try {
                                // 使用 setupSubtitleSource 动态切换字幕
                                final subtitleSource = BetterPlayerSubtitlesSource(
                                  type: BetterPlayerSubtitlesSourceType.network,
                                  name: subtitleTitle,
                                  urls: [subtitleUrl],
                                );
                                
                                print('[BetterPlayer] 开始切换字幕: $subtitleTitle');
                                print('[BetterPlayer] 字幕URL: $subtitleUrl');
                                
                                await _betterPlayerController?.setupSubtitleSource(subtitleSource);
                                
                                print('[BetterPlayer] 字幕切换成功');
                                
                                if (mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('已切换到: $subtitleTitle'),
                                      duration: const Duration(seconds: 2),
                                      backgroundColor: const Color(0xFF1F2937),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                print('[BetterPlayer] 切换字幕失败: $e');
                                if (mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('字幕加载失败: $e'),
                                      duration: const Duration(seconds: 3),
                                      backgroundColor: Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
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
