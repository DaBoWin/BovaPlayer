import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'mpv_player.dart';

class MpvPlayerPage extends StatefulWidget {
  final String streamUrl;
  final String title;
  
  const MpvPlayerPage({
    super.key,
    required this.streamUrl,
    required this.title,
  });
  
  @override
  State<MpvPlayerPage> createState() => _MpvPlayerPageState();
}

class _MpvPlayerPageState extends State<MpvPlayerPage> {
  late MpvPlayer _player;
  bool _isInitializing = true;
  String? _errorMessage;
  bool _showControls = true;
  bool _isLocked = false;
  Timer? _hideTimer;
  Timer? _clockTimer;
  Timer? _frameTimer;
  Timer? _positionTimer;
  String _currentTime = '';
  
  ui.Image? _currentFrame;
  double _currentPosition = 0.0;
  double _duration = 0.0;
  bool _isPlaying = false;
  int _videoWidth = 0;
  int _videoHeight = 0;
  int _lastFrameTime = 0;
  
  double _playbackSpeed = 1.0;
  String _aspectRatio = 'fit';
  
  // 字幕相关（暂时为空，等待MPV FFI支持）
  List<Map<String, dynamic>> _subtitleTracks = [
    {'DisplayTitle': '关闭', 'Index': -1},
  ];
  int _selectedSubtitleIndex = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    _player = MpvPlayer();
    _initializePlayer();
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
  }

  Future<void> _initializePlayer() async {
    try {
      if (!_player.create()) {
        throw Exception('Failed to create player');
      }
      
      if (!_player.openMedia(widget.streamUrl, hwaccel: true)) {
        throw Exception('Failed to open media');
      }
      
      // 等待视频初始化
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (!_player.play()) {
        throw Exception('Failed to start playback');
      }
      
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _isPlaying = true;
        });
        
        // 启动帧更新定时器（15fps以减少CPU占用）
        _frameTimer = Timer.periodic(const Duration(milliseconds: 66), (_) => _updateFrame());
        
        // 启动位置更新定时器
        _positionTimer = Timer.periodic(const Duration(milliseconds: 200), (_) => _updatePosition());
        
        _startHideTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = '播放失败: $e';
        });
      }
    }
  }

  void _updateFrame() {
    if (!mounted) return;
    
    final frameData = _player.getLatestFrame();
    if (frameData == null) return;
    
    final width = _player.getVideoWidth();
    final height = _player.getVideoHeight();
    
    if (width == 0 || height == 0) return;
    
    // 降低帧率，减少CPU占用（从30fps降到15fps）
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_lastFrameTime > 0 && now - _lastFrameTime < 66) {
      return; // 跳过这一帧
    }
    _lastFrameTime = now;
    
    // 将RGBA数据转换为Image
    ui.decodeImageFromPixels(
      frameData,
      width,
      height,
      ui.PixelFormat.rgba8888,
      (image) {
        if (mounted) {
          setState(() {
            _currentFrame?.dispose(); // 释放旧帧
            _currentFrame = image;
            _videoWidth = width;
            _videoHeight = height;
          });
        }
      },
    );
  }

  void _updatePosition() {
    if (!mounted) return;
    
    final position = _player.getPosition();
    final duration = _player.getDuration();
    final playing = _player.isPlaying();
    
    setState(() {
      _currentPosition = position;
      if (duration > 0) {
        _duration = duration;
      }
      _isPlaying = playing;
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _clockTimer?.cancel();
    _frameTimer?.cancel();
    _positionTimer?.cancel();
    _player.dispose();
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
    if (_showControls) _startHideTimer();
  }

  String _formatDuration(double seconds) {
    final d = Duration(seconds: seconds.toInt());
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _seek(double offset) {
    final newPos = (_currentPosition + offset).clamp(0.0, _duration);
    _player.seek(newPos);
    _startHideTimer();
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _player.pause();
    } else {
      _player.play();
    }
    _startHideTimer();
  }

  Widget _buildVideoPlayer() {
    if (_currentFrame == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            if (_errorMessage != null) ...[
              const SizedBox(height: 20),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      );
    }

    return Center(
      child: CustomPaint(
        painter: _VideoPainter(_currentFrame!),
        size: Size.infinite,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // 视频播放器
            Positioned.fill(child: _buildVideoPlayer()),

            // 控制层
            if (_showControls && !_isLocked)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.7),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                      stops: const [0.0, 0.2, 0.8, 1.0],
                    ),
                  ),
                  child: Column(
                    children: [
                      // 顶部栏
                      _buildTopBar(),
                      
                      const Spacer(),
                      
                      // 中间控制
                      _buildCenterControls(),
                      
                      const Spacer(),
                      
                      // 进度条
                      _buildProgressBar(),
                      
                      // 底部栏
                      _buildBottomBar(),
                    ],
                  ),
                ),
              ),

            // 锁屏按钮（始终显示）
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

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            // 返回按钮
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            
            // 标题
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
            
            // 系统时间
            Text(
              _currentTime,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
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
        // 快退 10s
        _buildCircleButton(
          icon: Icons.replay_10,
          onPressed: () => _seek(-10),
        ),
        
        const SizedBox(width: 48),
        
        // 播放/暂停
        _buildCircleButton(
          icon: _isPlaying ? Icons.pause : Icons.play_arrow,
          size: 64,
          onPressed: _togglePlayPause,
        ),
        
        const SizedBox(width: 48),
        
        // 快进 10s
        _buildCircleButton(
          icon: Icons.forward_10,
          onPressed: () => _seek(10),
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
        color: Colors.white.withValues(alpha: 0.3),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // 当前时间
          Text(
            _formatDuration(_currentPosition),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
          
          const SizedBox(width: 8),
          
          // 进度条
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                thumbColor: Colors.white,
                overlayColor: Colors.white.withValues(alpha: 0.3),
              ),
              child: Slider(
                value: _duration > 0 ? _currentPosition.clamp(0.0, _duration) : 0.0,
                max: _duration > 0 ? _duration : 1.0,
                onChanged: (value) {
                  _player.seek(value);
                },
                onChangeEnd: (_) => _startHideTimer(),
              ),
            ),
          ),
          
          const SizedBox(width: 8),
          
          // 总时长
          Text(
            _formatDuration(_duration),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoPainter extends CustomPainter {
  final ui.Image image;
  
  _VideoPainter(this.image);
  
  @override
  void paint(Canvas canvas, Size size) {
    final srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    
    // 计算适应屏幕的目标矩形（保持宽高比）
    final imageAspect = image.width / image.height;
    final screenAspect = size.width / size.height;
    
    Rect dstRect;
    if (imageAspect > screenAspect) {
      // 图片更宽，以宽度为准
      final height = size.width / imageAspect;
      final top = (size.height - height) / 2;
      dstRect = Rect.fromLTWH(0, top, size.width, height);
    } else {
      // 图片更高，以高度为准
      final width = size.height * imageAspect;
      final left = (size.width - width) / 2;
      dstRect = Rect.fromLTWH(left, 0, width, size.height);
    }
    
    canvas.drawImageRect(image, srcRect, dstRect, Paint());
  }
  
  @override
  bool shouldRepaint(_VideoPainter oldDelegate) {
    return oldDelegate.image != image;
  }
}
