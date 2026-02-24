import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:fvp/fvp.dart'; // MDK plugin
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:io' show Platform;
import 'package:window_manager/window_manager.dart';
import 'package:flutter/foundation.dart' show kIsWeb;


class MdkPlayerPage extends StatefulWidget {
  final String url;
  final String title;
  final Map<String, String>? httpHeaders;
  final List<Map<String, String>>? subtitles;
  final String? itemId;
  final String? serverUrl;
  final String? accessToken;
  final String? userId;
  final bool isSubWindow;
  
  const MdkPlayerPage({
    super.key,
    required this.url,
    required this.title,
    this.httpHeaders,
    this.subtitles,
    this.itemId,
    this.serverUrl,
    this.accessToken,
    this.userId,
    this.isSubWindow = false,
  });
  
  @override
  State<MdkPlayerPage> createState() => _MdkPlayerPageState();
}

class _MdkPlayerPageState extends State<MdkPlayerPage> {
  VideoPlayerController? _controller;
  static const _trafficLightsChannel = MethodChannel('com.bovaplayer/traffic_lights');
  
  bool _isInitializing = true;
  String? _errorMessage;
  bool _showControls = true;
  bool _isLocked = false;
  double _playbackSpeed = 1.0;
  Timer? _hideTimer;
  Timer? _clockTimer;
  Timer? _savePositionTimer;
  Timer? _reportProgressTimer;
  Timer? _speedTimer;
  String _currentTime = '';
  String _networkSpeed = '-- KB/s';
  String _aspectRatio = 'fit';
  int _lastBufferedPosition = 0;
  DateTime _lastSpeedCheck = DateTime.now();
  bool _isDragging = false;
  double _dragPosition = 0;
  int _selectedTextTrack = -1; 
  List<Map<String, dynamic>> _textTracks = [];
  
  // 手势控制相关
  double _brightness = 0.5;
  double _volume = 0.5;
  bool _showBrightnessIndicator = false;
  bool _showVolumeIndicator = false;
  bool _showSeekIndicator = false;
  String _seekIndicatorText = '';
  Timer? _indicatorTimer;
  
  Duration? _savedPosition;
  String? _playSessionId;
  Duration? _seekTargetPosition;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    // Config FVP/MDK options globally before first initialization
    registerWith(options: {
      // 硬件解码优先
      'video.decoders': 'MediaCodec:copy=0,FFmpeg',  // Android 硬件解码
      // 缓冲配置 - 针对高码率优化
      'buffer': '50000+1000000',  // 最小50MB，最大1GB缓冲
      'buffer.ranges': '8',  // 缓冲范围数量
      // 网络配置
      'demux.buffer.ranges': '8',
      'demux.buffer.protocols': 'http,https,rtmp,rtsp',
      // 线程配置
      'threads': '4',  // 解码线程数
      // 日志级别
      'logLevel': 'Info',
    });

    _loadSavedPosition();
    _initializePlayer();
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
    _speedTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateNetworkSpeed());
  }

  Future<void> _initializePlayer() async {
    try {
      print('[MdkPlayer] 初始化播放器');
      print('[MdkPlayer] URL: ${widget.url}');
      
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
        httpHeaders: widget.httpHeaders ?? {},
        videoPlayerOptions: VideoPlayerOptions(
          // 允许后台播放
          allowBackgroundPlayback: false,
          // 混音模式
          mixWithOthers: false,
        ),
      );
      
      // Use FVP to inject MDK backend to video_player
      await _controller!.initialize();
      
      _controller!.addListener(() {
        if (mounted) setState(() {});
      });
      
      // 注意：只有在 initialize 完成后，底层才知道有多少个轨道
      _loadTextTracks();
      
      await _controller!.play();
      
      if (_savedPosition != null && _savedPosition!.inSeconds > 5) {
        await _showResumeDialog();
      }
      
      _startSavePositionTimer();
      _reportPlaybackStart();
      _startReportProgressTimer();
      
      print('[MdkPlayer] 初始化成功');
      
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
        _startHideTimer();
      }
    } catch (e) {
      print('[MdkPlayer] 初始化失败: $e');
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = '播放失败: $e';
        });
      }
    }
  }

  void _loadTextTracks() {
    _textTracks.clear();
    
    // 确保已初始化再调用 ext API
    if (_controller == null || !_controller!.value.isInitialized) return;
    
    // 1. 获取内嵌字幕
    try {
      final mediaInfo = _controller?.getMediaInfo();
      if (mediaInfo?.subtitle != null) {
        for (int i = 0; i < mediaInfo!.subtitle!.length; i++) {
          final stream = mediaInfo.subtitle![i];
          _textTracks.add({
            'index': _textTracks.length,
            'title': stream.metadata['title'] ?? stream.metadata['language'] ?? '内置字幕 ${i + 1}',
            'language': stream.metadata['language'] ?? 'und',
            'is_internal': true,
            'mdk_id': i,
          });
        }
        print('[MdkPlayer] 加载了 ${mediaInfo.subtitle!.length} 个内置字幕');
      }
    } catch (e) {
      print('[MdkPlayer] 获取内置字幕失败: $e');
    }

    // 2. 获取外挂字幕
    if (widget.subtitles != null && widget.subtitles!.isNotEmpty) {
      for (int i = 0; i < widget.subtitles!.length; i++) {
        final subtitle = widget.subtitles![i];
        
        // 查重：防止重复加载
        bool exists = _textTracks.any((t) => t['url'] == subtitle['url']);
        if (!exists) {
          _textTracks.add({
            'index': _textTracks.length,
            'title': subtitle['title'] ?? '外挂字幕 ${i + 1}',
            'language': subtitle['language'] ?? 'und',
            'url': subtitle['url'],
            'is_internal': false,
          });
        }
      }
      print('[MdkPlayer] 加载了 ${widget.subtitles!.length} 个外挂字幕');
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
      }
    } catch (e) {
      print('[MdkPlayer] 加载播放位置失败: $e');
    }
  }
  
  Future<void> _savePlayPosition() async {
    if (widget.itemId == null || _controller == null) return;
    try {
      final position = _controller!.value.position;
      final duration = _controller!.value.duration;
      
      if (duration.inSeconds > 0 && position.inSeconds / duration.inSeconds > 0.95) {
        final prefs = await SharedPreferences.getInstance();
        final key = 'play_position_${widget.itemId}';
        await prefs.remove(key);
        return;
      }
      
      if (position.inSeconds > 5) {
        final prefs = await SharedPreferences.getInstance();
        final key = 'play_position_${widget.itemId}';
        await prefs.setInt(key, position.inSeconds);
      }
    } catch (e) {
      print('[MdkPlayer] 保存播放位置失败: $e');
    }
  }
  
  void _startSavePositionTimer() {
    _savePositionTimer?.cancel();
    _savePositionTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _savePlayPosition();
    });
  }

  Future<void> _showResumeDialog() async {
    if (!mounted || _controller == null) return;
    final resume = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('继续播放', style: TextStyle(color: Colors.white)),
        content: Text('上次播放到 ${_formatDuration(_savedPosition!)}\n是否继续播放？', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('从头开始', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1F2937),
            ),
            child: const Text('继续播放', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (resume == true && _savedPosition != null) {
      await _controller!.seekTo(_savedPosition!);
    }
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details, bool isLeft) {
    if (_isLocked) return;
    final delta = details.delta.dy;
    if (isLeft) {
      setState(() {
        _brightness = (_brightness - delta / 500).clamp(0.0, 1.0);
        _showBrightnessIndicator = true;
        _showVolumeIndicator = false;
        _showSeekIndicator = false;
      });
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarBrightness: _brightness > 0.5 ? Brightness.light : Brightness.dark,
      ));
      _startIndicatorTimer();
    } else {
      setState(() {
        _volume = (_volume - delta / 500).clamp(0.0, 1.0);
        _showVolumeIndicator = true;
        _showBrightnessIndicator = false;
        _showSeekIndicator = false;
      });
      _controller?.setVolume(_volume);
      _startIndicatorTimer();
    }
  }
  
  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    if (_isLocked || _controller == null) return;
    final screenWidth = MediaQuery.of(context).size.width;
    final duration = _controller!.value.duration;
    
    if (duration.inSeconds > 0) {
      // 第一次拖拽时，以当前播放位置为起点
      _seekTargetPosition ??= _controller!.value.position;
      
      // 根据手指滑动距离计算时间偏移（全屏宽度 = 视频总时长）
      final deltaSec = (details.delta.dx / screenWidth) * duration.inSeconds;
      final newSeconds = (_seekTargetPosition!.inSeconds + deltaSec).round().clamp(0, duration.inSeconds);
      _seekTargetPosition = Duration(seconds: newSeconds);
      
      final minutes = newSeconds ~/ 60;
      final seconds = newSeconds % 60;
      final timeStr = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      
      setState(() {
        _showSeekIndicator = true;
        _showBrightnessIndicator = false;
        _showVolumeIndicator = false;
        _seekIndicatorText = timeStr;
      });
      
      _startIndicatorTimer();
    }
  }
  
  void _handleHorizontalDragEnd(DragEndDetails details) {
    if (_isLocked || _seekTargetPosition == null || _controller == null) return;
    _controller!.seekTo(_seekTargetPosition!);
    _seekTargetPosition = null;
    setState(() { _showSeekIndicator = false; });
  }

  void _startIndicatorTimer() {
    _indicatorTimer?.cancel();
    _indicatorTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() {
        _showBrightnessIndicator = false;
        _showVolumeIndicator = false;
        _showSeekIndicator = false;
      });
    });
  }

  Future<void> _reportPlaybackStart() async {
    if (widget.itemId == null || widget.serverUrl == null || widget.accessToken == null) return;
    try {
      _playSessionId = 'bova_${DateTime.now().millisecondsSinceEpoch}';
      final url = '${widget.serverUrl}/Sessions/Playing';
      final body = {
        'ItemId': widget.itemId,
        'PlaySessionId': _playSessionId,
        'CanSeek': true,
        'IsPaused': false,
        'IsMuted': false,
        'PositionTicks': 0,
        'VolumeLevel': (_volume * 100).toInt(),
        'PlayMethod': 'DirectPlay',
      };
      await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'X-Emby-Token': widget.accessToken!,
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      print('[MdkPlayer] 上报播放开始失败: $e');
    }
  }

  void _startReportProgressTimer() {
    _reportProgressTimer?.cancel();
    _reportProgressTimer = Timer.periodic(const Duration(seconds: 10), (_) => _reportPlaybackProgress());
  }

  Future<void> _reportPlaybackProgress() async {
    if (widget.itemId == null || widget.serverUrl == null || widget.accessToken == null || _playSessionId == null || _controller == null) return;
    try {
      final position = _controller!.value.position;
      final isPaused = !_controller!.value.isPlaying;
      final positionTicks = position.inMicroseconds * 10;
      final url = '${widget.serverUrl}/Sessions/Playing/Progress';
      final body = {
        'ItemId': widget.itemId,
        'PlaySessionId': _playSessionId,
        'CanSeek': true,
        'IsPaused': isPaused,
        'PositionTicks': positionTicks,
        'VolumeLevel': (_volume * 100).toInt(),
        'PlayMethod': 'DirectPlay',
      };
      await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'X-Emby-Token': widget.accessToken!,
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      print('[MdkPlayer] 上报进度失败: $e');
    }
  }

  Future<void> _reportPlaybackStopped() async {
    if (widget.itemId == null || widget.serverUrl == null || widget.accessToken == null || _playSessionId == null || _controller == null) return;
    try {
      final positionTicks = _controller!.value.position.inMicroseconds * 10;
      final url = '${widget.serverUrl}/Sessions/Playing/Stopped';
      final body = {
        'ItemId': widget.itemId,
        'PlaySessionId': _playSessionId,
        'PositionTicks': positionTicks,
      };
      await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'X-Emby-Token': widget.accessToken!,
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      print('[MdkPlayer] 上报停止失败: $e');
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _clockTimer?.cancel();
    _speedTimer?.cancel();
    _savePositionTimer?.cancel();
    _reportProgressTimer?.cancel();
    _indicatorTimer?.cancel();

    _savePlayPosition();
    _reportPlaybackStopped();

    if (!kIsWeb && Platform.isMacOS) {
      _trafficLightsChannel.invokeMethod('show');
    }

    _controller?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _updateClock() {
    if (mounted) {
      setState(() {
        _currentTime = DateFormat('HH:mm').format(DateTime.now());
      });
    }
  }

  void _updateNetworkSpeed() {
    if (!mounted || _controller == null || !_controller!.value.isInitialized) return;
    try {
      final now = DateTime.now();
      final timeDiff = now.difference(_lastSpeedCheck).inSeconds.toDouble();
      if (timeDiff >= 1.0) {
        final currentBuffered = _controller!.value.buffered.isNotEmpty
            ? _controller!.value.buffered.last.end.inMilliseconds
            : 0;
        final bufferDiff = currentBuffered - _lastBufferedPosition;
        if (bufferDiff > 0) {
          double estimatedBitrate = 4000;
          final bufferIncreaseSec = bufferDiff / 1000.0;
          final downloadedBytes = (bufferIncreaseSec * estimatedBitrate * 1000) / 8;
          final bytesPerSecond = downloadedBytes / timeDiff;
          if (bytesPerSecond > 0 && mounted) {
            setState(() => _networkSpeed = _formatSpeed(bytesPerSecond));
          }
        }
        _lastBufferedPosition = currentBuffered;
        _lastSpeedCheck = now;
      }
      if (_controller!.value.isBuffering && mounted) {
        setState(() => _networkSpeed = '缓冲中...');
      }
    } catch (_) {
      if (mounted) setState(() => _networkSpeed = '-- KB/s');
    }
  }

  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 0) return '0 B/s';
    if (bytesPerSecond < 1024) return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    if (bytesPerSecond < 1024 * 1024) return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(2)} MB/s';
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controller?.value.isPlaying == true) {
        setState(() => _showControls = false);
        if (Platform.isAndroid || Platform.isIOS) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        }
        if (Platform.isMacOS) {
          _trafficLightsChannel.invokeMethod('hide');
        }
      }
    });
  }

  void _toggleControls() {
    if (_isLocked) return;
    setState(() => _showControls = !_showControls);

    if (_showControls) {
      if (Platform.isAndroid || Platform.isIOS) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
      if (Platform.isMacOS) {
        _trafficLightsChannel.invokeMethod('show');
      }
      _startHideTimer();
    } else {
      if (Platform.isAndroid || Platform.isIOS) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
      if (Platform.isMacOS) {
        _trafficLightsChannel.invokeMethod('hide');
      }
      _hideTimer?.cancel();
    }
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

  void _seek(Duration offset) {
    if (_controller == null) return;
    final newPos = _controller!.value.position + offset;
    _controller!.seekTo(newPos);
    _startHideTimer();
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
    _startHideTimer();
  }

  void _changeSpeed(double speed) {
    setState(() => _playbackSpeed = speed);
    _controller?.setPlaybackSpeed(speed);
    Navigator.pop(context);
  }

  void _changeAspectRatio(String ratio) {
    setState(() => _aspectRatio = ratio);
    Navigator.pop(context);
  }

  String _getAspectRatioLabel() {
    switch (_aspectRatio) {
      case 'fill': return '填充';
      case 'stretch': return '拉伸';
      case 'fit': default: return '适应';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        onVerticalDragUpdate: (details) {
          final screenWidth = MediaQuery.of(context).size.width;
          final isLeft = details.globalPosition.dx < screenWidth / 2;
          _handleVerticalDragUpdate(details, isLeft);
        },
        onHorizontalDragUpdate: _handleHorizontalDragUpdate,
        onHorizontalDragEnd: _handleHorizontalDragEnd,
        child: Stack(
          children: [
            if (_controller != null && _controller!.value.isInitialized)
              Center(
                child: _aspectRatio == 'fill'
                    ? SizedBox.expand(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _controller!.value.size.width,
                            height: _controller!.value.size.height,
                            child: VideoPlayer(_controller!),
                          ),
                        ),
                      )
                    : _aspectRatio == 'stretch'
                        ? SizedBox.expand(child: VideoPlayer(_controller!))
                        : AspectRatio(
                            aspectRatio: _controller!.value.aspectRatio,
                            child: VideoPlayer(_controller!),
                          ),
              )
            else if (_isInitializing)
              const Center(child: CircularProgressIndicator(color: Colors.white))
            else if (_errorMessage != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

            if (_showBrightnessIndicator) _buildBrightnessIndicator(),
            if (_showVolumeIndicator) _buildVolumeIndicator(),
            if (_showSeekIndicator) _buildSeekIndicator(),

            if (_showControls && !_isLocked && !_isInitializing && _controller != null)
              _buildControls(),

            if (_showControls)
              Positioned(
                left: 16,
                top: MediaQuery.of(context).size.height / 2 - 24,
                child: IconButton(
                  icon: Icon(
                    _isLocked ? Icons.lock : Icons.lock_open,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: () {
                    setState(() => _isLocked = !_isLocked);
                    if (_isLocked) {
                      _hideTimer?.cancel();
                    } else {
                      _startHideTimer();
                    }
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
    final bool isMacOS = !kIsWeb && Platform.isMacOS;
    return SafeArea(
      child: DragToMoveArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: isMacOS ? 80.0 : 8.0, 
            right: 8.0, 
            top: isMacOS ? 4.0 : 0.0, 
            bottom: 0.0
          ),
          child: SizedBox(
            height: 42.0,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.speed, color: Colors.greenAccent, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        _networkSpeed,
                        style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
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
      ),
    );
  }

  Widget _buildCenterControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildCircleButton(
          icon: Icons.replay_10,
          onPressed: () => _seek(const Duration(seconds: -10)),
        ),
        const SizedBox(width: 48),
        _buildCircleButton(
          icon: _controller?.value.isPlaying == true ? Icons.pause : Icons.play_arrow,
          size: 64,
          iconSize: 48,
          onPressed: _togglePlayPause,
        ),
        const SizedBox(width: 48),
        _buildCircleButton(
          icon: Icons.forward_10,
          onPressed: () => _seek(const Duration(seconds: 10)),
        ),
      ],
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onPressed,
    double size = 48,
    double iconSize = 32,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: iconSize),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildProgressBar() {
    final position = _controller?.value.position ?? Duration.zero;
    final duration = _controller?.value.duration ?? Duration.zero;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Text(
            _isDragging 
                ? _formatDuration(Duration(milliseconds: _dragPosition.toInt()))
                : _formatDuration(position),
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final totalWidth = constraints.maxWidth;
                final maxMs = duration.inMilliseconds.toDouble();
                final currentMs = _isDragging
                    ? _dragPosition
                    : position.inMilliseconds.toDouble();
                final progress = maxMs > 0 ? (currentMs / maxMs).clamp(0.0, 1.0) : 0.0;

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (details) {
                    _hideTimer?.cancel();
                    setState(() {
                      _isDragging = true;
                      // 从当前播放位置开始拖，而不是鼠标点击的位置
                      _dragPosition = position.inMilliseconds.toDouble();
                    });
                  },
                  onHorizontalDragUpdate: (details) {
                    if (maxMs <= 0) return;
                    final delta = details.delta.dx;
                    final msDelta = (delta / totalWidth) * maxMs;
                    setState(() {
                      _dragPosition = (_dragPosition + msDelta).clamp(0.0, maxMs).toDouble();
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    _controller?.seekTo(Duration(milliseconds: _dragPosition.toInt()));
                    setState(() {
                      _isDragging = false;
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
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        // 已播放轨道
                        FractionallySizedBox(
                          widthFactor: progress,
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                        // 滑块圆点
                        Positioned(
                          left: (progress * totalWidth) - 8,
                          child: Container(
                            width: 16,
                            height: 16,
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
          const SizedBox(width: 16),
          Text(
            _formatDuration(duration),
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(
          children: [
            const Spacer(),
            if (_textTracks.isNotEmpty)
              TextButton(
                onPressed: _showSubtitleMenu,
                child: const Text('字幕', style: TextStyle(color: Colors.white, fontSize: 14)),
              ),
            TextButton(
              onPressed: _showAspectRatioMenu,
              child: Text(_getAspectRatioLabel(), style: const TextStyle(color: Colors.white, fontSize: 14)),
            ),
            TextButton(
              onPressed: _showSpeedMenu,
              child: Text('${_playbackSpeed}x', style: const TextStyle(color: Colors.white, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSheetContainer(BuildContext context, String title, Widget menuContent) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black.withOpacity(0.7) : Colors.white.withOpacity(0.85);
    final grabberColor = isDark ? Colors.white38 : Colors.black26;
    final titleColor = isDark ? Colors.white : Colors.black87;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          color: bgColor,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: grabberColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(title, style: TextStyle(color: titleColor, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Flexible(child: menuContent),
            ],
          ),
        ),
      ),
    );
  }

  void _showSubtitleMenu() {
    _hideTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // 使用透明背景，依靠 _buildBottomSheetContainer 展示高斯模糊
      isScrollControlled: true,
      builder: (context) {
        return _buildBottomSheetContainer(
          context,
          '字幕选择',
          ListView(
            shrinkWrap: true,
            children: [
              _buildActionItem('关闭字幕', -1, _selectedTextTrack, () {
                setState(() => _selectedTextTrack = -1);
                _controller?.setSubtitleTracks([]); // 禁用所有字幕
                Navigator.pop(context);
              }),
              ..._textTracks.map((track) {
                final index = track['index'];
                final isInternal = track['is_internal'] == true;
                final title = track['title'] ?? '未知语言';
                final displayTitle = isInternal ? '$title (内置)' : '$title (外挂)';
                return _buildActionItem(displayTitle, index, _selectedTextTrack, () {
                  setState(() => _selectedTextTrack = index);
                  if (isInternal) {
                    _controller?.setSubtitleTracks([track['mdk_id']]);
                  } else {
                    final url = track['url'];
                    if (url != null) {
                      _controller?.setExternalSubtitle(url);
                      Future.delayed(const Duration(milliseconds: 200), () {
                        if (mounted) _controller?.setSubtitleTracks([0]);
                      });
                    }
                  }
                  Navigator.pop(context);
                });
              }),
            ],
          ),
        );
      },
    ).then((_) => _startHideTimer());
  }

  void _showAspectRatioMenu() {
    _hideTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _buildBottomSheetContainer(
          context,
          '画面比例',
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildActionItem('适应 (Fit)', 'fit', _aspectRatio, () => _changeAspectRatio('fit')),
              _buildActionItem('拉伸 (Stretch)', 'stretch', _aspectRatio, () => _changeAspectRatio('stretch')),
              _buildActionItem('填充 (Fill)', 'fill', _aspectRatio, () => _changeAspectRatio('fill')),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    ).then((_) => _startHideTimer());
  }

  void _showSpeedMenu() {
    _hideTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _buildBottomSheetContainer(
          context,
          '播放速度',
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildActionItem('0.5x', 0.5, _playbackSpeed, () => _changeSpeed(0.5)),
              _buildActionItem('0.75x', 0.75, _playbackSpeed, () => _changeSpeed(0.75)),
              _buildActionItem('1.0x (正常)', 1.0, _playbackSpeed, () => _changeSpeed(1.0)),
              _buildActionItem('1.25x', 1.25, _playbackSpeed, () => _changeSpeed(1.25)),
              _buildActionItem('1.5x', 1.5, _playbackSpeed, () => _changeSpeed(1.5)),
              _buildActionItem('2.0x', 2.0, _playbackSpeed, () => _changeSpeed(2.0)),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    ).then((_) => _startHideTimer());
  }

  Widget _buildActionItem<T>(String title, T value, T groupValue, VoidCallback onTap) {
    bool isSelected = value == groupValue;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isSelected 
        ? Theme.of(context).primaryColor 
        : (isDark ? Colors.white : Colors.black87);
    final inactiveIconColor = isDark ? Colors.white38 : Colors.black26;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.transparent,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title, 
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500
                )
              ),
            ),
            if (isSelected) 
              Icon(Icons.check_circle, color: Theme.of(context).primaryColor, size: 24)
            else
              Icon(Icons.circle_outlined, color: inactiveIconColor, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildBrightnessIndicator() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.brightness_6, color: Colors.white, size: 48),
            const SizedBox(height: 8),
            SizedBox(
              width: 100,
              child: LinearProgressIndicator(
                value: _brightness,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(height: 4),
            Text('${(_brightness * 100).toInt()}%', style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildVolumeIndicator() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _volume == 0 ? Icons.volume_off : (_volume < 0.5 ? Icons.volume_down : Icons.volume_up),
              color: Colors.white,
              size: 48,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 100,
              child: LinearProgressIndicator(
                value: _volume,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(height: 4),
            Text('${(_volume * 100).toInt()}%', style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildSeekIndicator() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fast_forward, color: Colors.white, size: 48),
            const SizedBox(height: 12),
            Text(_seekIndicatorText, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
