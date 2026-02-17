import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:better_player/better_player.dart';
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
        if (mounted) setState(() => _showControls = false);
      });
    }
  }

  void _toggleControls() {
    if (_isLocked) return;
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
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

                  // 控制层
                  if (_showControls && !_isLocked) _buildControls(),

                  // 锁屏按钮
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

  Widget _buildControls() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.transparent,
              Colors.transparent,
              Colors.black.withOpacity(0.7),
            ],
            stops: const [0.0, 0.2, 0.8, 1.0],
          ),
        ),
        child: Column(
          children: [
            _buildTopBar(),
            const Spacer(),
            _buildCenterControls(),
            const Spacer(),
            _buildProgressBar(),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 网速显示
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.speed,
                    color: Colors.greenAccent,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _networkSpeed,
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 时间显示
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _currentTime,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildCircleButton(
          icon: Icons.replay_10,
          onPressed: () {
            final position = _betterPlayerController!.videoPlayerController!.value.position;
            _betterPlayerController!.seekTo(position - const Duration(seconds: 10));
          },
        ),
        const SizedBox(width: 48),
        _buildCircleButton(
          icon: (_betterPlayerController?.isPlaying() ?? false) ? Icons.pause : Icons.play_arrow,
          size: 64,
          onPressed: () {
            if (_betterPlayerController!.isPlaying() ?? false) {
              _betterPlayerController!.pause();
            } else {
              _betterPlayerController!.play();
            }
            _startHideTimer();
          },
        ),
        const SizedBox(width: 48),
        _buildCircleButton(
          icon: Icons.forward_10,
          onPressed: () {
            final position = _betterPlayerController!.videoPlayerController!.value.position;
            _betterPlayerController!.seekTo(position + const Duration(seconds: 10));
          },
        ),
      ],
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onPressed,
    double size = 48,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: size * 0.5),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildProgressBar() {
    if (_betterPlayerController == null) return const SizedBox.shrink();
    
    final position = _betterPlayerController!.videoPlayerController?.value.position ?? Duration.zero;
    final duration = _betterPlayerController!.videoPlayerController?.value.duration ?? Duration.zero;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            PlayerUtils.formatDuration(position),
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white.withOpacity(0.3),
                thumbColor: Colors.white,
                overlayColor: Colors.white.withOpacity(0.3),
              ),
              child: Slider(
                value: position.inMilliseconds.toDouble().clamp(
                  0,
                  duration.inMilliseconds.toDouble(),
                ),
                max: duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1,
                onChanged: (value) {
                  _betterPlayerController!.seekTo(Duration(milliseconds: value.toInt()));
                },
                onChangeEnd: (_) => _startHideTimer(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            PlayerUtils.formatDuration(duration),
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildBottomButton(
            icon: Icons.subtitles,
            label: '字幕',
            onPressed: _showSubtitleMenu,
          ),
          _buildBottomButton(
            icon: Icons.speed,
            label: '速度',
            onPressed: _showSpeedMenu,
          ),
          _buildBottomButton(
            icon: Icons.aspect_ratio,
            label: '比例',
            onPressed: () {
              // Better Player 0.0.84 不支持动态切换画面比例
              // 显示提示信息
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('画面比例功能暂不可用'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ],
        ),
      ),
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
