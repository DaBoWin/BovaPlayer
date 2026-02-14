import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'native_bridge.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with WidgetsBindingObserver {
  bool _isPlaying = false;
  bool _hwAccelEnabled = true;
  String _currentFile = '';
  double _currentPosition = 0;
  double _totalDuration = 0;
  VideoPlayerController? _videoController;
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasVideo = false;
  String _loadingMessage = '';

  // 全屏
  bool _isFullscreen = false;

  // 控制条显示/隐藏
  bool _showControls = true;
  Timer? _hideControlsTimer;

  // 进度条拖拽
  bool _isSeeking = false;
  double _seekPosition = 0;

  // 手势
  double _dragStartX = 0;
  double _dragStartPosition = 0;
  bool _isDraggingHorizontal = false;
  String _gestureInfo = '';
  bool _showGestureInfo = false;

  // 后台恢复
  double _savedPosition = 0;
  String? _savedFilePath;
  bool _wasPlaying = false;

  // 锁屏
  bool _isLocked = false;

  // 播放速度
  double _playbackSpeed = 1.0;
  final List<double> _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0];

  // 网速监控
  int _networkSpeed = 0; // bytes per second
  Timer? _speedTimer;
  int _lastBytes = 0;

  // 系统时间
  Timer? _clockTimer;
  String _currentTime = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeNativeBridge();
    _startHideControlsTimer();
    // 时钟定时器
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) => _updateClock());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideControlsTimer?.cancel();
    _speedTimer?.cancel();
    _clockTimer?.cancel();
    _videoController?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _updateClock() {
    final now = DateTime.now();
    setState(() {
      _currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    });
  }

  // 后台恢复
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (_videoController != null && _videoController!.value.isInitialized) {
        _savedPosition = _videoController!.value.position.inMilliseconds.toDouble();
        _wasPlaying = _videoController!.value.isPlaying;
        if (_wasPlaying) _videoController!.pause();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_videoController != null && _videoController!.value.isInitialized && _savedPosition > 0) {
        _videoController!.seekTo(Duration(milliseconds: _savedPosition.toInt()));
        if (_wasPlaying) _videoController!.play();
      }
    }
  }

  Future<void> _initializeNativeBridge() async {
    try {
      await NativeBridge.initialize();
    } catch (_) {}
  }

  void _videoPlayerListener() {
    if (_videoController != null && _videoController!.value.isInitialized && !_isSeeking) {
      setState(() {
        _currentPosition = _videoController!.value.position.inMilliseconds.toDouble();
        _isPlaying = _videoController!.value.isPlaying;
        _totalDuration = _videoController!.value.duration.inMilliseconds.toDouble();
      });
    }
  }

  // ============== 控制条 ==============

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 5), () {
      if (_isPlaying && mounted) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    if (_isLocked) {
      // 锁屏时只显示/隐藏锁按钮
      setState(() => _showControls = !_showControls);
      if (_showControls) _startHideControlsTimer();
      return;
    }
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideControlsTimer();
  }

  // ============== 全屏 ==============

  void _enterFullscreen() {
    setState(() => _isFullscreen = true);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _startHideControlsTimer();
  }

  void _exitFullscreen() {
    setState(() {
      _isFullscreen = false;
      _isLocked = false;
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  // ============== 文件操作 ==============

  Future<void> _openFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        final file = result.files.single;
        final filePath = file.path!;
        final fileSizeInMB = file.size / (1024 * 1024);

        setState(() {
          _isLoading = true;
          _hasVideo = false;
          _errorMessage = null;
          _loadingMessage = fileSizeInMB > 1000
            ? '正在加载 ${(fileSizeInMB/1024).toStringAsFixed(1)} GB 视频...'
            : '正在加载 ${fileSizeInMB.toStringAsFixed(1)} MB 视频...';
        });

        try {
          _videoController?.dispose();
          _videoController = VideoPlayerController.file(
            File(filePath),
            videoPlayerOptions: VideoPlayerOptions(
              mixWithOthers: true,
              allowBackgroundPlayback: true,
            ),
          );
          await _videoController!.initialize();
          _videoController!.addListener(_videoPlayerListener);

          setState(() {
            _isLoading = false;
            _hasVideo = true;
            _currentFile = file.name;
            _savedFilePath = filePath;
            _totalDuration = _videoController!.value.duration.inMilliseconds.toDouble();
            _currentPosition = 0;
          });

          await _videoController!.play();
          // 自动进入全屏
          _enterFullscreen();
        } catch (e) {
          setState(() {
            _isLoading = false;
            _errorMessage = '视频加载失败: $e';
          });
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '文件选择失败: $e';
      });
    }
  }

  Future<void> _togglePlay() async {
    if (_videoController != null && _videoController!.value.isInitialized) {
      if (_videoController!.value.isPlaying) {
        await _videoController!.pause();
      } else {
        await _videoController!.play();
        _startHideControlsTimer();
      }
    }
  }

  Future<void> _stop() async {
    if (_videoController != null && _videoController!.value.isInitialized) {
      await _videoController!.pause();
      await _videoController!.seekTo(Duration.zero);
      setState(() { _currentPosition = 0; _isPlaying = false; });
    }
  }

  Future<void> _seekTo(double positionMs) async {
    if (_videoController != null && _videoController!.value.isInitialized) {
      final clamped = positionMs.clamp(0.0, _totalDuration);
      await _videoController!.seekTo(Duration(milliseconds: clamped.toInt()));
      setState(() => _currentPosition = clamped);
    }
  }

  void _changeSpeed() {
    final idx = _speeds.indexOf(_playbackSpeed);
    final next = (idx + 1) % _speeds.length;
    setState(() => _playbackSpeed = _speeds[next]);
    _videoController?.setPlaybackSpeed(_playbackSpeed);
  }

  // ============== 手势 ==============

  void _onDoubleTapAt(double x, double screenWidth) {
    if (x < screenWidth * 0.35) {
      final newPos = (_currentPosition - 10000).clamp(0.0, _totalDuration);
      _seekTo(newPos);
      _showGestureInfoBriefly('⏪ -10s');
    } else if (x > screenWidth * 0.65) {
      final newPos = (_currentPosition + 10000).clamp(0.0, _totalDuration);
      _seekTo(newPos);
      _showGestureInfoBriefly('⏩ +10s');
    } else {
      // 双击中间：暂停/播放
      _togglePlay();
    }
  }

  void _showGestureInfoBriefly(String info) {
    setState(() { _gestureInfo = info; _showGestureInfo = true; });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showGestureInfo = false);
    });
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    if (!_hasVideo || _videoController == null || _isLocked) return;
    _dragStartX = details.localPosition.dx;
    _dragStartPosition = _currentPosition;
    _isDraggingHorizontal = true;
    _isSeeking = true;
    _seekPosition = _currentPosition;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details, double screenWidth) {
    if (!_isDraggingHorizontal || !_hasVideo) return;
    final dx = details.localPosition.dx - _dragStartX;
    final seekDelta = (dx / screenWidth) * _totalDuration * 0.33;
    _seekPosition = (_dragStartPosition + seekDelta).clamp(0.0, _totalDuration);
    setState(() {
      _gestureInfo = '${_formatTime(_seekPosition)} / ${_formatTime(_totalDuration)}';
      _showGestureInfo = true;
    });
  }

  void _onHorizontalDragEnd() {
    if (!_isDraggingHorizontal) return;
    _seekTo(_seekPosition);
    _isDraggingHorizontal = false;
    _isSeeking = false;
    setState(() => _showGestureInfo = false);
  }

  // ============== 格式化 ==============

  String _formatTime(double ms) {
    final totalSeconds = (ms / 1000).floor();
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatSpeed(int bytesPerSec) {
    if (bytesPerSec > 1024 * 1024) return '${(bytesPerSec / 1024 / 1024).toStringAsFixed(1)} MB/s';
    if (bytesPerSec > 1024) return '${(bytesPerSec / 1024).toStringAsFixed(0)} KB/s';
    return '$bytesPerSec B/s';
  }

  // ====================================================================
  //  全屏播放器 UI（参考 Infuse 风格）
  // ====================================================================

  Widget _buildFullscreenPlayer() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 视频
          Positioned.fill(
            child: Center(
              child: _videoController != null && _videoController!.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: VideoPlayer(_videoController!),
                    )
                  : const SizedBox.shrink(),
            ),
          ),

          // 手势层
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _toggleControls,
              onDoubleTapDown: _isLocked ? null : (details) {
                _onDoubleTapAt(details.localPosition.dx, MediaQuery.of(context).size.width);
              },
              onDoubleTap: () {},
              onHorizontalDragStart: _isLocked ? null : _onHorizontalDragStart,
              onHorizontalDragUpdate: _isLocked ? null : (d) => _onHorizontalDragUpdate(d, MediaQuery.of(context).size.width),
              onHorizontalDragEnd: _isLocked ? null : (_) => _onHorizontalDragEnd(),
              child: Container(color: Colors.transparent),
            ),
          ),

          // 手势信息
          if (_showGestureInfo)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _gestureInfo,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
            ),

          // 锁屏模式：只显示锁按钮
          if (_isLocked && _showControls)
            Positioned(
              left: 16,
              top: 0, bottom: 0,
              child: Center(
                child: _buildCircleIcon(Icons.lock, () {
                  setState(() => _isLocked = false);
                }, size: 40),
              ),
            ),

          // 完整控制层
          if (!_isLocked && _showControls)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.35),
                child: SafeArea(
                  child: Column(
                    children: [
                      _buildTopBar(),
                      const Spacer(),
                      _buildCenterControls(),
                      const Spacer(),
                      _buildProgressBar(),
                      _buildBottomBar(),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---- 顶部栏：时间 | 标题 | 网速 ----
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          // 当前时间
          Text(
            _currentTime,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(width: 16),
          // 标题
          Expanded(
            child: Text(
              _currentFile,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 16),
          // 网速
          if (_networkSpeed > 0)
            Text(
              _formatSpeed(_networkSpeed),
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          // 关闭按钮
          const SizedBox(width: 8),
          _buildCircleIcon(Icons.close, _exitFullscreen, size: 28),
        ],
      ),
    );
  }

  // ---- 中间：播放/暂停大按钮 + 快退快进 ----
  Widget _buildCenterControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 快退 10s
        IconButton(
          icon: const Icon(Icons.replay_10, color: Colors.white, size: 36),
          onPressed: () {
            final p = (_currentPosition - 10000).clamp(0.0, _totalDuration);
            _seekTo(p);
          },
        ),
        const SizedBox(width: 40),
        // 播放/暂停
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.15),
            ),
            child: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),
        const SizedBox(width: 40),
        // 快进 10s
        IconButton(
          icon: const Icon(Icons.forward_10, color: Colors.white, size: 36),
          onPressed: () {
            final p = (_currentPosition + 10000).clamp(0.0, _totalDuration);
            _seekTo(p);
          },
        ),
      ],
    );
  }

  // ---- 进度条 ----
  Widget _buildProgressBar() {
    final max = _totalDuration > 0 ? _totalDuration : 1.0;
    final current = (_isSeeking ? _seekPosition : _currentPosition).clamp(0.0, max);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            _formatTime(current),
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                overlayColor: Colors.white.withValues(alpha: 0.1),
                valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
                valueIndicatorColor: Colors.deepPurple,
                valueIndicatorTextStyle: const TextStyle(color: Colors.white, fontSize: 12),
                showValueIndicator: ShowValueIndicator.onlyForContinuous,
              ),
              child: Slider(
                value: current,
                min: 0,
                max: max,
                label: _formatTime(current),
                onChangeStart: (v) {
                  _isSeeking = true;
                  _seekPosition = v;
                },
                onChanged: (v) => setState(() => _seekPosition = v),
                onChangeEnd: (v) {
                  _seekTo(v);
                  _isSeeking = false;
                  _startHideControlsTimer();
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatTime(max),
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // ---- 底部栏：锁 | 速度 | 全屏退出等 ----
  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          // 锁屏按钮
          _buildSmallButton(Icons.lock_open, '锁屏', () {
            setState(() => _isLocked = true);
            _startHideControlsTimer();
          }),
          const SizedBox(width: 16),
          // 倍速
          _buildSmallButton(null, '${_playbackSpeed}x', _changeSpeed),
          const Spacer(),
          // 画面比例 (预留)
          _buildSmallButton(Icons.aspect_ratio, null, () {
            // 预留功能
            _showGestureInfoBriefly('画面比例：开发中');
          }),
          const SizedBox(width: 16),
          // 退出全屏
          _buildSmallButton(Icons.fullscreen_exit, null, _exitFullscreen),
        ],
      ),
    );
  }

  Widget _buildSmallButton(IconData? icon, String? label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) Icon(icon, color: Colors.white70, size: 18),
            if (icon != null && label != null) const SizedBox(width: 4),
            if (label != null) Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleIcon(IconData icon, VoidCallback onTap, {double size = 32}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.12),
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.55),
      ),
    );
  }

  // ====================================================================
  //  普通模式 UI
  // ====================================================================

  Widget _buildNormalVideoArea() {
    if (!_hasVideo && !_isLoading && _errorMessage == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.video_library, size: 64, color: Colors.white24),
              SizedBox(height: 16),
              Text('点击下方按钮选择视频', style: TextStyle(fontSize: 16, color: Colors.white38)),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(_loadingMessage, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.white54, fontSize: 12), textAlign: TextAlign.center),
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _openFile, child: const Text('重新选择')),
            ],
          ),
        ),
      );
    }

    // 视频 + 手势
    return GestureDetector(
      onTap: () {
        if (_hasVideo) _enterFullscreen();
      },
      child: Container(
        color: Colors.black,
        child: Center(
          child: AspectRatio(
            aspectRatio: _videoController!.value.aspectRatio,
            child: VideoPlayer(_videoController!),
          ),
        ),
      ),
    );
  }

  Widget _buildNormalSeekBar() {
    final max = _totalDuration > 0 ? _totalDuration : 1.0;
    final current = (_isSeeking ? _seekPosition : _currentPosition).clamp(0.0, max);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Text(_formatTime(current), style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                activeTrackColor: Colors.deepPurple,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.deepPurple,
                valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
                valueIndicatorColor: Colors.deepPurple,
                valueIndicatorTextStyle: const TextStyle(color: Colors.white, fontSize: 12),
                showValueIndicator: ShowValueIndicator.onlyForContinuous,
              ),
              child: Slider(
                value: current, min: 0, max: max,
                label: _formatTime(current),
                onChangeStart: (v) { _isSeeking = true; _seekPosition = v; },
                onChanged: (v) => setState(() => _seekPosition = v),
                onChangeEnd: (v) { _seekTo(v); _isSeeking = false; },
              ),
            ),
          ),
          Text(_formatTime(max), style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 全屏模式
    if (_isFullscreen && _hasVideo) {
      return _buildFullscreenPlayer();
    }

    // 普通模式
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('BovaPlayer', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('硬件加速', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Switch(
                value: _hwAccelEnabled,
                activeColor: Colors.deepPurple,
                onChanged: (v) async {
                  setState(() => _hwAccelEnabled = v);
                  await NativeBridge.setHardwareAccel(v);
                },
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 视频区域 - 用 Expanded 避免溢出
          Expanded(
            child: Container(
              color: Colors.black,
              child: Center(
                child: AspectRatio(
                  aspectRatio: _hasVideo && _videoController != null && _videoController!.value.isInitialized
                      ? _videoController!.value.aspectRatio
                      : 16 / 9,
                  child: _buildNormalVideoArea(),
                ),
              ),
            ),
          ),

          // 进度条
          if (_hasVideo) _buildNormalSeekBar(),

          // 底部按钮
          Padding(
            padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16, top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildActionButton(Icons.folder_open, '打开文件', _openFile),
                const SizedBox(width: 24),
                _buildPlayButton(),
                const SizedBox(width: 24),
                _buildActionButton(Icons.stop, '停止', _stop),
                if (_hasVideo) ...[
                  const SizedBox(width: 24),
                  _buildActionButton(Icons.fullscreen, '全屏', _enterFullscreen),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onPressed) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(icon: Icon(icon, color: Colors.white), onPressed: onPressed, iconSize: 28),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }

  Widget _buildPlayButton() {
    return GestureDetector(
      onTap: _togglePlay,
      child: Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(colors: [Colors.deepPurple, Colors.purple]),
          boxShadow: [BoxShadow(color: Colors.deepPurple.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 2)],
        ),
        child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 28),
      ),
    );
  }
}