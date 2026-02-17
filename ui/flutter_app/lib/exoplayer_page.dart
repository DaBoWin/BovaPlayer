import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class ExoPlayerPage extends StatefulWidget {
  final String url;
  final String title;
  final Map<String, String>? httpHeaders;
  final List<Map<String, String>>? subtitles;
  final String? itemId;
  final String? serverUrl;
  final String? accessToken;
  final String? userId;
  
  const ExoPlayerPage({
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
  State<ExoPlayerPage> createState() => _ExoPlayerPageState();
}

class _ExoPlayerPageState extends State<ExoPlayerPage> {
  VideoPlayerController? _controller;
  
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
  int _selectedTextTrack = -1; // -1 表示关闭字幕
  List<Map<String, dynamic>> _textTracks = []; // 字幕轨道列表
  
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
    
    _loadSavedPosition();
    _initializePlayer();
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
    _speedTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateNetworkSpeed());
  }

  Future<void> _initializePlayer() async {
    try {
      print('[ExoPlayer] 初始化播放器');
      print('[ExoPlayer] URL: ${widget.url}');
      
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
        httpHeaders: widget.httpHeaders ?? {},
      );
      
      await _controller!.initialize();
      
      _controller!.addListener(() {
        if (mounted) setState(() {});
      });
      
      // 尝试获取字幕轨道信息（如果视频有内嵌字幕）
      _loadTextTracks();
      
      await _controller!.play();
      
      // 恢复播放位置
      if (_savedPosition != null && _savedPosition!.inSeconds > 5) {
        await _showResumeDialog();
      }
      
      _startSavePositionTimer();
      _reportPlaybackStart();
      _startReportProgressTimer();
      
      print('[ExoPlayer] 初始化成功');
      
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
        _startHideTimer();
      }
    } catch (e) {
      print('[ExoPlayer] 初始化失败: $e');
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = '播放失败: $e';
        });
      }
    }
  }

  void _loadTextTracks() {
    // 添加外挂字幕（如果有）
    if (widget.subtitles != null && widget.subtitles!.isNotEmpty) {
      for (int i = 0; i < widget.subtitles!.length; i++) {
        final subtitle = widget.subtitles![i];
        _textTracks.add({
          'index': i,
          'title': subtitle['title'] ?? '字幕 ${i + 1}',
          'language': subtitle['language'] ?? 'und',
          'url': subtitle['url'],
        });
      }
      print('[ExoPlayer] 加载了 ${_textTracks.length} 个外挂字幕');
    }
    
    // 注意：video_player 插件默认不支持获取内嵌字幕轨道
    // 如果需要完整的字幕支持，需要使用 better_player 或自定义 ExoPlayer 插件
    // 这里我们先支持外挂字幕
  }

  // ============== 播放位置记忆 ==============
  
  Future<void> _loadSavedPosition() async {
    if (widget.itemId == null) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'play_position_${widget.itemId}';
      final savedSeconds = prefs.getInt(key);
      
      if (savedSeconds != null && savedSeconds > 0) {
        _savedPosition = Duration(seconds: savedSeconds);
        print('[ExoPlayer] 加载保存的播放位置: $_savedPosition');
      }
    } catch (e) {
      print('[ExoPlayer] 加载播放位置失败: $e');
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
        print('[ExoPlayer] 播放完成，清除保存的位置');
        return;
      }
      
      if (position.inSeconds > 5) {
        final prefs = await SharedPreferences.getInstance();
        final key = 'play_position_${widget.itemId}';
        await prefs.setInt(key, position.inSeconds);
      }
    } catch (e) {
      print('[ExoPlayer] 保存播放位置失败: $e');
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
        title: const Text(
          '继续播放',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: Text(
          '上次播放到 ${_formatDuration(_savedPosition!)}\n是否继续播放？',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('从头开始', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1F2937),
              foregroundColor: Colors.white,
            ),
            child: const Text('继续播放'),
          ),
        ],
      ),
    );
    
    if (resume == true && _savedPosition != null) {
      await _controller!.seekTo(_savedPosition!);
    }
  }

  // ============== 手势控制 ==============
  
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
    final dragPosition = details.globalPosition.dx;
    
    final duration = _controller!.value.duration;
    if (duration.inSeconds > 0) {
      final percentage = (dragPosition / screenWidth).clamp(0.0, 1.0);
      final targetSeconds = (duration.inSeconds * percentage).round();
      _seekTargetPosition = Duration(seconds: targetSeconds);
      
      final minutes = targetSeconds ~/ 60;
      final seconds = targetSeconds % 60;
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
  }
  
  void _startIndicatorTimer() {
    _indicatorTimer?.cancel();
    _indicatorTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showBrightnessIndicator = false;
          _showVolumeIndicator = false;
          _showSeekIndicator = false;
        });
      }
    });
  }

  // ============== Emby 播放进度上报 ==============
  
  Future<void> _reportPlaybackStart() async {
    if (widget.itemId == null || widget.serverUrl == null || widget.accessToken == null) {
      return;
    }
    
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
      
      print('[ExoPlayer] 播放开始上报成功');
    } catch (e) {
      print('[ExoPlayer] 播放开始上报异常: $e');
    }
  }
  
  void _startReportProgressTimer() {
    _reportProgressTimer?.cancel();
    _reportProgressTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _reportPlaybackProgress();
    });
  }
  
  Future<void> _reportPlaybackProgress() async {
    if (widget.itemId == null || widget.serverUrl == null || 
        widget.accessToken == null || _playSessionId == null || _controller == null) {
      return;
    }
    
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
        'IsMuted': false,
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
      print('[ExoPlayer] 播放进度上报异常: $e');
    }
  }
  
  Future<void> _reportPlaybackStopped() async {
    if (widget.itemId == null || widget.serverUrl == null || 
        widget.accessToken == null || _playSessionId == null || _controller == null) {
      return;
    }
    
    try {
      final position = _controller!.value.position;
      final positionTicks = position.inMicroseconds * 10;
      
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
      print('[ExoPlayer] 播放停止上报异常: $e');
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
          // 估算码率（基于分辨率）
          double estimatedBitrate = 4000; // 默认 4 Mbps
          
          // 缓冲增量（秒）* 码率（Kbps）/ 8 = 下载的字节数
          final bufferIncreaseSec = bufferDiff / 1000.0;
          final downloadedBytes = (bufferIncreaseSec * estimatedBitrate * 1000) / 8;
          final bytesPerSecond = downloadedBytes / timeDiff;
          
          if (bytesPerSecond > 0) {
            final speed = _formatSpeed(bytesPerSecond);
            if (mounted) {
              setState(() {
                _networkSpeed = speed;
              });
            }
          }
        }
        
        _lastBufferedPosition = currentBuffered;
        _lastSpeedCheck = now;
      }
      
      if (_controller!.value.isBuffering) {
        if (mounted) {
          setState(() {
            _networkSpeed = '缓冲中...';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _networkSpeed = '-- KB/s';
        });
      }
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
    if (!_isLocked && _controller?.value.isPlaying == true) {
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
      case 'fill':
        return '填充';
      case 'stretch':
        return '拉伸';
      case 'fit':
      default:
        return '适应';
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
            // 视频播放器
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
                        ? SizedBox.expand(
                            child: VideoPlayer(_controller!),
                          )
                        : AspectRatio(
                            aspectRatio: _controller!.value.aspectRatio,
                            child: VideoPlayer(_controller!),
                          ),
              )
            else if (_isInitializing)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
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

            // 手势指示器
            if (_showBrightnessIndicator) _buildBrightnessIndicator(),
            if (_showVolumeIndicator) _buildVolumeIndicator(),
            if (_showSeekIndicator) _buildSeekIndicator(),

            // 控制层
            if (_showControls && !_isLocked && !_isInitializing && _controller != null)
              _buildControls(),

            // 锁屏按钮
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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
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
          onPressed: () => _seek(const Duration(seconds: -10)),
        ),
        const SizedBox(width: 48),
        _buildCircleButton(
          icon: _controller?.value.isPlaying == true ? Icons.pause : Icons.play_arrow,
          size: 64,
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
    if (_controller == null) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            _formatDuration(_controller!.value.position),
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
                value: _controller!.value.position.inMilliseconds.toDouble().clamp(
                  0,
                  _controller!.value.duration.inMilliseconds.toDouble(),
                ),
                max: _controller!.value.duration.inMilliseconds > 0
                    ? _controller!.value.duration.inMilliseconds.toDouble()
                    : 1,
                onChanged: (value) {
                  _controller!.seekTo(Duration(milliseconds: value.toInt()));
                },
                onChangeEnd: (_) => _startHideTimer(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatDuration(_controller!.value.duration),
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
            label: '${_playbackSpeed}x',
            onPressed: _showSpeedMenu,
          ),
          _buildBottomButton(
            icon: Icons.aspect_ratio,
            label: _getAspectRatioLabel(),
            onPressed: _showAspectRatioMenu,
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
                      _buildSpeedChip(speed),
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

  Widget _buildSpeedChip(double speed) {
    final isSelected = _playbackSpeed == speed;
    return InkWell(
      onTap: () => _changeSpeed(speed),
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.check_circle, color: Colors.white, size: 18),
              ),
            Text(
              '${speed}x',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
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
                        isSelected: _selectedTextTrack == -1,
                        onTap: () {
                          setState(() {
                            _selectedTextTrack = -1;
                          });
                          Navigator.pop(context);
                          print('[ExoPlayer] 字幕已关闭');
                        },
                      ),
                      // 显示可用的字幕轨道
                      if (_textTracks.isEmpty)
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
                        for (int i = 0; i < _textTracks.length; i++)
                          _buildSubtitleOption(
                            title: _textTracks[i]['title'] ?? '字幕 ${i + 1}',
                            subtitle: _textTracks[i]['language'],
                            isSelected: _selectedTextTrack == i,
                            onTap: () {
                              setState(() {
                                _selectedTextTrack = i;
                              });
                              Navigator.pop(context);
                              print('[ExoPlayer] 选择字幕: ${_textTracks[i]['title']}');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('字幕切换功能需要重新加载视频'),
                                  duration: const Duration(seconds: 2),
                                  backgroundColor: const Color(0xFF1F2937),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
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

  void _showAspectRatioMenu() {
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
                '画面比例',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              for (final ratio in [
                {'value': 'fit', 'label': '适应屏幕', 'icon': Icons.fit_screen},
                {'value': 'fill', 'label': '填充屏幕', 'icon': Icons.fullscreen},
                {'value': 'stretch', 'label': '拉伸填充', 'icon': Icons.open_in_full},
              ])
                _buildAspectRatioOption(
                  value: ratio['value'] as String,
                  label: ratio['label'] as String,
                  icon: ratio['icon'] as IconData,
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAspectRatioOption({
    required String value,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _aspectRatio == value;
    return InkWell(
      onTap: () => _changeAspectRatio(value),
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
                icon,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrightnessIndicator() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.brightness_6, color: Colors.white, size: 32),
            const SizedBox(height: 8),
            Text(
              '${(_brightness * 100).toInt()}%',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                value: _brightness,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildVolumeIndicator() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _volume > 0.5 ? Icons.volume_up : (_volume > 0 ? Icons.volume_down : Icons.volume_off),
              color: Colors.white,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              '${(_volume * 100).toInt()}%',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                value: _volume,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSeekIndicator() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fast_forward, color: Colors.white, size: 32),
            const SizedBox(height: 8),
            Text(
              _seekIndicatorText,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
