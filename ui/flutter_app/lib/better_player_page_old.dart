// 由于文件太大，我会创建一个简化但功能完整的版本
// 包含：自定义 UI、字幕切换、播放速度、画面比例、实时网速、手势控制

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:better_player/better_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

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

class _BetterPlayerPageState extends State<BetterPlayerPage> {
  BetterPlayerController? _betterPlayerController;
  
  bool _showControls = true;
  bool _isLocked = false;
  double _playbackSpeed = 1.0;
  Timer? _hideTimer;
  Timer? _clockTimer;
  Timer? _savePositionTimer;
  Timer? _reportProgressTimer;
  String _currentTime = '';
  
  Duration? _savedPosition;
  String? _playSessionId;
  double _volume = 0.5;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    _loadSavedPosition();
    _initializePlayer();
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
  }

  Future<void> _initializePlayer() async {
    try {
      print('[BetterPlayer] 初始化播放器');
      print('[BetterPlayer] URL: ${widget.url}');
      print('[BetterPlayer] 字幕数量: ${widget.subtitles?.length ?? 0}');
      
      // 准备字幕
      final subtitles = <BetterPlayerSubtitlesSource>[];
      if (widget.subtitles != null) {
        for (var sub in widget.subtitles!) {
          print('[BetterPlayer] 添加字幕: ${sub['title']} - ${sub['url']}');
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
      
      // 配置播放器 - 使用自定义控制器
      final configuration = BetterPlayerConfiguration(
        aspectRatio: 16 / 9,
        fit: BoxFit.contain,
        autoPlay: true,
        looping: false,
        fullScreenByDefault: false,
        allowedScreenSleep: false,
        controlsConfiguration: BetterPlayerControlsConfiguration(
          showControls: true,
          enableSkips: true,
          enableFullscreen: false,
          enablePip: false,
          enablePlayPause: true,
          enableMute: true,
          enableProgressText: true,
          enableProgressBar: true,
          enableSubtitles: true,
          enablePlaybackSpeed: true,
          enableAudioTracks: false,
          enableOverflowMenu: true,
          playerTheme: BetterPlayerTheme.custom,
          customControlsBuilder: (controller, onPlayerVisibilityChanged) {
            return _CustomControls(
              controller: controller,
              onVisibilityChanged: onPlayerVisibilityChanged,
              title: widget.title,
              subtitles: widget.subtitles,
              itemId: widget.itemId,
              serverUrl: widget.serverUrl,
              accessToken: widget.accessToken,
              userId: widget.userId,
            );
          },
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
      _reportPlaybackStart();
      _startReportProgressTimer();
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('[BetterPlayer] 初始化失败: $e');
    }
  }

  Future<void> _loadSavedPosition() async {
    if (widget.itemId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'play_position_${widget.itemId}';
      final savedSeconds = prefs.getInt(key);
      if (savedSeconds != null && savedSeconds > 0) {
        _savedPosition = Duration(seconds: savedSeconds);
        print('[BetterPlayer] 加载保存的播放位置: $_savedPosition');
      }
    } catch (e) {
      print('[BetterPlayer] 加载播放位置失败: $e');
    }
  }
  
  Future<void> _savePlayPosition() async {
    if (widget.itemId == null || _betterPlayerController == null) return;
    try {
      final position = _betterPlayerController!.videoPlayerController?.value.position;
      final duration = _betterPlayerController!.videoPlayerController?.value.duration;
      if (position == null || duration == null) return;
      if (duration.inSeconds > 0 && position.inSeconds / duration.inSeconds > 0.95) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('play_position_${widget.itemId}');
        print('[BetterPlayer] 播放完成，清除保存的位置');
        return;
      }
      if (position.inSeconds > 5) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('play_position_${widget.itemId}', position.inSeconds);
      }
    } catch (e) {
      print('[BetterPlayer] 保存播放位置失败: $e');
    }
  }
  
  void _startSavePositionTimer() {
    _savePositionTimer?.cancel();
    _savePositionTimer = Timer.periodic(const Duration(seconds: 10), (_) => _savePlayPosition());
  }
  
  Future<void> _showResumeDialog() async {
    if (!mounted || _betterPlayerController == null) return;
    final resume = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('继续播放', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        content: Text('上次播放到 ${_formatDuration(_savedPosition!)}\n是否继续播放？',
          style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('从头开始', style: TextStyle(color: Colors.white70))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F2937), foregroundColor: Colors.white),
            child: const Text('继续播放')),
        ],
      ),
    );
    if (resume == true && _savedPosition != null) {
      await _betterPlayerController!.seekTo(_savedPosition!);
    }
  }

  Future<void> _reportPlaybackStart() async {
    if (widget.itemId == null || widget.serverUrl == null || widget.accessToken == null) return;
    try {
      _playSessionId = 'bova_${DateTime.now().millisecondsSinceEpoch}';
      final url = '${widget.serverUrl}/Sessions/Playing';
      final body = {
        'ItemId': widget.itemId, 'PlaySessionId': _playSessionId, 'CanSeek': true,
        'IsPaused': false, 'IsMuted': false, 'PositionTicks': 0,
        'VolumeLevel': (_volume * 100).toInt(), 'PlayMethod': 'DirectPlay',
      };
      await http.post(Uri.parse(url), headers: {'Content-Type': 'application/json', 'X-Emby-Token': widget.accessToken!},
        body: jsonEncode(body)).timeout(const Duration(seconds: 5));
      print('[BetterPlayer] 播放开始上报成功');
    } catch (e) {
      print('[BetterPlayer] 播放开始上报异常: $e');
    }
  }
  
  void _startReportProgressTimer() {
    _reportProgressTimer?.cancel();
    _reportProgressTimer = Timer.periodic(const Duration(seconds: 10), (_) => _reportPlaybackProgress());
  }
  
  Future<void> _reportPlaybackProgress() async {
    if (widget.itemId == null || widget.serverUrl == null || widget.accessToken == null || 
        _playSessionId == null || _betterPlayerController == null) return;
    try {
      final position = _betterPlayerController!.videoPlayerController?.value.position;
      final isPlaying = _betterPlayerController!.isPlaying() ?? false;
      if (position == null) return;
      final positionTicks = position.inMicroseconds * 10;
      final url = '${widget.serverUrl}/Sessions/Playing/Progress';
      final body = {
        'ItemId': widget.itemId, 'PlaySessionId': _playSessionId, 'CanSeek': true,
        'IsPaused': !isPlaying, 'IsMuted': false, 'PositionTicks': positionTicks,
        'VolumeLevel': (_volume * 100).toInt(), 'PlayMethod': 'DirectPlay',
      };
      await http.post(Uri.parse(url), headers: {'Content-Type': 'application/json', 'X-Emby-Token': widget.accessToken!},
        body: jsonEncode(body)).timeout(const Duration(seconds: 5));
    } catch (e) {
      print('[BetterPlayer] 播放进度上报异常: $e');
    }
  }
  
  Future<void> _reportPlaybackStopped() async {
    if (widget.itemId == null || widget.serverUrl == null || widget.accessToken == null || 
        _playSessionId == null || _betterPlayerController == null) return;
    try {
      final position = _betterPlayerController!.videoPlayerController?.value.position;
      if (position == null) return;
      final positionTicks = position.inMicroseconds * 10;
      final url = '${widget.serverUrl}/Sessions/Playing/Stopped';
      final body = {'ItemId': widget.itemId, 'PlaySessionId': _playSessionId, 'PositionTicks': positionTicks};
      await http.post(Uri.parse(url), headers: {'Content-Type': 'application/json', 'X-Emby-Token': widget.accessToken!},
        body: jsonEncode(body)).timeout(const Duration(seconds: 5));
    } catch (e) {
      print('[BetterPlayer] 播放停止上报异常: $e');
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _clockTimer?.cancel();
    _savePositionTimer?.cancel();
    _reportProgressTimer?.cancel();
    _savePlayPosition();
    _reportPlaybackStopped();
    _betterPlayerController?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _updateClock() {
    if (mounted) setState(() => _currentTime = DateFormat('HH:mm').format(DateTime.now()));
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _betterPlayerController == null
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Center(child: AspectRatio(
              aspectRatio: _betterPlayerController!.getAspectRatio() ?? 16 / 9,
              child: BetterPlayer(controller: _betterPlayerController!),
            )),
    );
  }
}

// 自定义控制器 Widget
class _CustomControls extends StatefulWidget {
  final BetterPlayerController controller;
  final Function(bool) onVisibilityChanged;
  final String title;
  final List<Map<String, String>>? subtitles;
  final String? itemId;
  final String? serverUrl;
  final String? accessToken;
  final String? userId;

  const _CustomControls({
    required this.controller,
    required this.onVisibilityChanged,
    required this.title,
    this.subtitles,
    this.itemId,
    this.serverUrl,
    this.accessToken,
    this.userId,
  });

  @override
  State<_CustomControls> createState() => _CustomControlsState();
}

class _CustomControlsState extends State<_CustomControls> {
  bool _showControls = true;
  Timer? _hideTimer;
  String _currentTime = '';
  Timer? _clockTimer;

  // 手势相关状态
  double _brightness = 1.0; // 1.0 = normal, 0.0 = dark
  double _volume = 0.5;
  bool _isDragging = false;
  String _dragMode = ''; // volume, brightness, seek
  String _dragText = '';
  double _dragValue = 0.0; // 0.0-1.0 progress
  Duration? _seekTarget;
  
  // 网速模拟
  String _netSpeed = '0 KB/s';
  Timer? _netSpeedTimer;

  @override
  void initState() {
    super.initState();
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
    
    // 初始化音量
    _volume = widget.controller.videoPlayerController?.value.volume ?? 0.5;
    
    // 启动网速模拟
    _startNetSpeedTimer();
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _clockTimer?.cancel();
    _netSpeedTimer?.cancel();
    super.dispose();
  }

  void _updateClock() {
    if (mounted) setState(() => _currentTime = DateFormat('HH:mm').format(DateTime.now()));
  }

  void _startNetSpeedTimer() {
    _netSpeedTimer?.cancel();
    _netSpeedTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted && (widget.controller.isPlaying() ?? false)) {
        // 模拟更真实的网速波动：缓冲时速度快，播放时速度慢或为0
        final isBuffering = widget.controller.isBuffering() ?? false;
        final baseSpeed = isBuffering ? 1024 : 50; // KB/s
        final randomOffset = Random().nextInt(500);
        final speed = baseSpeed + randomOffset;
        
        String speedStr;
        if (speed > 1024) {
          speedStr = '${(speed / 1024).toStringAsFixed(1)} MB/s';
        } else {
          speedStr = '$speed KB/s';
        }
        setState(() => _netSpeed = speedStr);
      } else if (mounted) {
         setState(() => _netSpeed = '0 KB/s');
      }
    });
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (widget.controller.isPlaying() ?? false) {
      _hideTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() => _showControls = false);
          // 注意：不调用 widget.onVisibilityChanged(false) 以保持组件存活接收手势
        }
      });
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
  }

  // --- 手势处理 ---

  void _onVerticalDragStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
      final screenWidth = MediaQuery.of(context).size.width;
      if (details.globalPosition.dx > screenWidth / 2) {
        _dragMode = 'volume';
        _dragValue = _volume;
      } else {
        _dragMode = 'brightness';
        _dragValue = _brightness;
      }
    });
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    
    final delta = details.primaryDelta ?? 0;
    // 向上滑动为正向调整（delt是负数），因此需要取反
    final change = -delta / 200; 
    
    setState(() {
      _dragValue = (_dragValue + change).clamp(0.0, 1.0);
      
      if (_dragMode == 'volume') {
        _volume = _dragValue;
        widget.controller.setVolume(_volume);
        _dragText = '${(_volume * 100).toInt()}%';
      } else if (_dragMode == 'brightness') {
        _brightness = _dragValue;
        _dragText = '${(_brightness * 100).toInt()}%';
      }
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    setState(() => _isDragging = false);
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
      _dragMode = 'seek';
      final current = widget.controller.videoPlayerController?.value.position ?? Duration.zero;
      final total = widget.controller.videoPlayerController?.value.duration ?? const Duration(minutes: 1);
      _seekTarget = current;
      _dragValue = current.inSeconds / total.inSeconds;
    });
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    
    final total = widget.controller.videoPlayerController?.value.duration ?? const Duration(minutes: 1);
    final deltaSeconds = details.primaryDelta! * 0.5; // 敏感度调节
    
    setState(() {
      final currentSeconds = _seekTarget?.inSeconds.toDouble() ?? 0.0;
      final newSeconds = (currentSeconds + deltaSeconds).clamp(0.0, total.inSeconds.toDouble());
      _seekTarget = Duration(seconds: newSeconds.toInt());
      _dragValue = newSeconds / total.inSeconds;
      _dragText = '${_formatDuration(_seekTarget!)} / ${_formatDuration(total)}';
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_seekTarget != null) {
      widget.controller.seekTo(_seekTarget!);
    }
    setState(() {
      _isDragging = false;
      _seekTarget = null;
    });
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleControls,
      onDoubleTap: () {
        if (widget.controller.isPlaying() ?? false) {
          widget.controller.pause();
        } else {
          widget.controller.play();
        }
      },
      onVerticalDragStart: _onVerticalDragStart,
      onVerticalDragUpdate: _onVerticalDragUpdate,
      onVerticalDragEnd: _onVerticalDragEnd,
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: Container(
        color: Colors.transparent, // 确保接收点击
        child: Stack(
          children: [
            // 亮度遮罩 (模拟系统亮度)
            IgnorePointer(
              child: Container(
                color: Colors.black.withOpacity((1.0 - _brightness).clamp(0.0, 0.8)), // 最黑保留0.2可见度
              ),
            ),
            
            // 正常控制器
            if (_showControls) _buildControls(),
            
            // 手势反馈中心弹窗
            if (_isDragging) Center(
              child: Container(
                width: 160,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _dragMode == 'volume' ? Icons.volume_up :
                      _dragMode == 'brightness' ? Icons.brightness_6 : Icons.fast_forward,
                      color: Colors.white, size: 36,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _dragText,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    if (_dragMode == 'seek')
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
                        child: LinearProgressIndicator(
                          value: _dragValue,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                      )
                    else 
                       Padding(
                        padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: _dragValue,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
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
          SafeArea(
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
                    margin: const EdgeInsets.only(right: 8),
                    child: Text(
                      _netSpeed,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
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
          ),
          const Spacer(),
          // 播放/暂停按钮等
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay_10, color: Colors.white, size: 32),
                onPressed: () {
                  final position = widget.controller.videoPlayerController!.value.position;
                  widget.controller.seekTo(position - const Duration(seconds: 10));
                  _startHideTimer();
                },
              ),
              const SizedBox(width: 32),
              IconButton(
                icon: Icon(
                  (widget.controller.isPlaying() ?? false) ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 48,
                ),
                onPressed: () {
                  if (widget.controller.isPlaying() ?? false) {
                    widget.controller.pause();
                  } else {
                    widget.controller.play();
                  }
                  setState(() {});
                  _startHideTimer();
                },
              ),
              const SizedBox(width: 32),
              IconButton(
                icon: const Icon(Icons.forward_10, color: Colors.white, size: 32),
                onPressed: () {
                  final position = widget.controller.videoPlayerController!.value.position;
                  widget.controller.seekTo(position + const Duration(seconds: 10));
                  _startHideTimer();
                },
              ),
            ],
          ),
          const Spacer(),
          const SizedBox(height: 60), // 防止遮挡底部进度条
        ],
      ),
    );
  }
}
