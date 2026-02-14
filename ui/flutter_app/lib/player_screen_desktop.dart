import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
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
  double _dragStartY = 0;
  double _dragStartPosition = 0;
  bool _isDraggingHorizontal = false;
  bool _isDraggingVertical = false;
  String _gestureInfo = '';
  bool _showGestureInfo = false;

  // 后台恢复
  double _savedPosition = 0;
  String? _savedFilePath;
  bool _wasPlaying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeNativeBridge();
    _startHideControlsTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideControlsTimer?.cancel();
    _videoController?.dispose();
    // 退出全屏时恢复状态栏
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  // 后台恢复：记录和恢复播放状态
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // 进入后台：保存播放进度
      if (_videoController != null && _videoController!.value.isInitialized) {
        _savedPosition = _videoController!.value.position.inMilliseconds.toDouble();
        _wasPlaying = _videoController!.value.isPlaying;
        if (_wasPlaying) {
          _videoController!.pause();
        }
        print('进入后台，保存进度: ${_savedPosition}ms, 正在播放: $_wasPlaying');
      }
    } else if (state == AppLifecycleState.resumed) {
      // 回到前台：恢复播放
      if (_videoController != null && _videoController!.value.isInitialized && _savedPosition > 0) {
        _videoController!.seekTo(Duration(milliseconds: _savedPosition.toInt()));
        if (_wasPlaying) {
          _videoController!.play();
        }
        print('回到前台，恢复进度: ${_savedPosition}ms');
      }
    }
  }

  Future<void> _initializeNativeBridge() async {
    try {
      final result = await NativeBridge.initialize();
      print('Native bridge初始化结果: $result');
    } catch (e) {
      print('Native bridge初始化失败: $e');
    }
  }

  void _videoPlayerListener() {
    if (_videoController != null && _videoController!.value.isInitialized) {
      if (!_isSeeking) {
        setState(() {
          _currentPosition = _videoController!.value.position.inMilliseconds.toDouble();
          _isPlaying = _videoController!.value.isPlaying;
          _totalDuration = _videoController!.value.duration.inMilliseconds.toDouble();
        });
      }
    }
  }

  // ============== 控制条 ==============

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (_isPlaying && mounted) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideControlsTimer();
    }
  }

  // ============== 全屏 ==============

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
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
        final fileSizeInMB = (file.size / (1024 * 1024));

        print('选择的文件: ${file.name}, 路径: $filePath');

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

          // 自动开始播放
          await _videoController!.play();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('已加载: ${file.name}'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          print('视频初始化失败: $e');
          setState(() {
            _isLoading = false;
            _errorMessage = '视频初始化失败: $e';
          });
        }
      }
    } catch (e) {
      print('文件选择错误: $e');
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
      setState(() {
        _currentPosition = 0;
        _isPlaying = false;
      });
    }
  }

  Future<void> _seekTo(double positionMs) async {
    if (_videoController != null && _videoController!.value.isInitialized) {
      final clamped = positionMs.clamp(0.0, _totalDuration);
      await _videoController!.seekTo(Duration(milliseconds: clamped.toInt()));
      setState(() {
        _currentPosition = clamped;
      });
    }
  }

  // ============== 手势处理 ==============

  void _onDoubleTapLeft() {
    // 双击左侧：快退 10 秒
    final newPos = (_currentPosition - 10000).clamp(0.0, _totalDuration);
    _seekTo(newPos);
    _showGestureInfoBriefly('⏪ 快退 10 秒');
  }

  void _onDoubleTapRight() {
    // 双击右侧：快进 10 秒
    final newPos = (_currentPosition + 10000).clamp(0.0, _totalDuration);
    _seekTo(newPos);
    _showGestureInfoBriefly('⏩ 快进 10 秒');
  }

  void _showGestureInfoBriefly(String info) {
    setState(() {
      _gestureInfo = info;
      _showGestureInfo = true;
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() => _showGestureInfo = false);
      }
    });
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    if (!_hasVideo || _videoController == null) return;
    _dragStartX = details.localPosition.dx;
    _dragStartPosition = _currentPosition;
    _isDraggingHorizontal = true;
    _isSeeking = true;
    _seekPosition = _currentPosition;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details, double screenWidth) {
    if (!_isDraggingHorizontal || !_hasVideo) return;
    final dx = details.localPosition.dx - _dragStartX;
    // 滑动屏幕宽度 = 总时长的 1/3
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

  // ============== 时间格式化 ==============

  String _formatTime(double ms) {
    final totalSeconds = (ms / 1000).floor();
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // ============== UI 构建 ==============

  Widget _buildVideoArea() {
    if (!_hasVideo && !_isLoading && _errorMessage == null) {
      // 空状态
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
              Text('加载失败', style: TextStyle(color: Colors.red[300], fontSize: 16)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _openFile,
                child: const Text('重新选择'),
              ),
            ],
          ),
        ),
      );
    }

    // 视频播放器
    return LayoutBuilder(
      builder: (context, constraints) {
        final videoAspect = _videoController!.value.aspectRatio;
        return Container(
          color: Colors.black,
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 视频画面 - 自适应比例
              Center(
                child: AspectRatio(
                  aspectRatio: videoAspect,
                  child: VideoPlayer(_videoController!),
                ),
              ),

              // 手势层
              _buildGestureLayer(constraints.maxWidth),

              // 手势信息提示
              if (_showGestureInfo)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _gestureInfo,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

              // 控制条
              if (_showControls) _buildControlsOverlay(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGestureLayer(double screenWidth) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _toggleControls,
      // 双击左半边快退，右半边快进
      onDoubleTapDown: (details) {
        final x = details.localPosition.dx;
        if (x < screenWidth / 2) {
          _onDoubleTapLeft();
        } else {
          _onDoubleTapRight();
        }
      },
      onDoubleTap: () {}, // 需要这个才能触发 onDoubleTapDown
      // 水平滑动拖进度
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragUpdate: (d) => _onHorizontalDragUpdate(d, screenWidth),
      onHorizontalDragEnd: (_) => _onHorizontalDragEnd(),
      child: Container(color: Colors.transparent),
    );
  }

  Widget _buildControlsOverlay() {
    return Positioned.fill(
      child: Column(
        children: [
          // 顶部栏
          Container(
            padding: EdgeInsets.only(
              top: _isFullscreen ? 8 : MediaQuery.of(context).padding.top,
              left: 8, right: 8,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black54, Colors.transparent],
              ),
            ),
            child: Row(
              children: [
                if (_isFullscreen)
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: _toggleFullscreen,
                  ),
                Expanded(
                  child: Text(
                    _currentFile,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // 中间播放/暂停大按钮
          IconButton(
            iconSize: 64,
            icon: Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
              color: Colors.white.withOpacity(0.9),
            ),
            onPressed: _togglePlay,
          ),

          const Spacer(),

          // 底部进度条和控制
          Container(
            padding: const EdgeInsets.only(bottom: 8, left: 12, right: 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black54, Colors.transparent],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 进度条
                _buildSeekBar(),
                // 时间 + 按钮行
                Row(
                  children: [
                    Text(
                      _formatTime(_isSeeking ? _seekPosition : _currentPosition),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const Text(' / ', style: TextStyle(color: Colors.white38, fontSize: 12)),
                    Text(
                      _formatTime(_totalDuration),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                        color: Colors.white,
                      ),
                      onPressed: _toggleFullscreen,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeekBar() {
    final max = _totalDuration > 0 ? _totalDuration : 1.0;
    final current = (_isSeeking ? _seekPosition : _currentPosition).clamp(0.0, max);

    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        activeTrackColor: Colors.deepPurple,
        inactiveTrackColor: Colors.white24,
        thumbColor: Colors.deepPurple,
        overlayColor: Colors.deepPurple.withOpacity(0.2),
        // 拖拽时显示时间气泡
        valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
        valueIndicatorColor: Colors.deepPurple,
        valueIndicatorTextStyle: const TextStyle(color: Colors.white, fontSize: 12),
        showValueIndicator: ShowValueIndicator.always,
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
        onChanged: (v) {
          setState(() {
            _seekPosition = v;
          });
        },
        onChangeEnd: (v) {
          _seekTo(v);
          _isSeeking = false;
          _startHideControlsTimer();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 全屏模式
    if (_isFullscreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: _buildVideoArea(),
      );
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
              Text(
                '硬件加速',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Switch(
                value: _hwAccelEnabled,
                activeColor: Colors.deepPurple,
                onChanged: (value) async {
                  setState(() => _hwAccelEnabled = value);
                  await NativeBridge.setHardwareAccel(value);
                },
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 视频区域 - 自适应比例，不固定高度
          AspectRatio(
            aspectRatio: _hasVideo && _videoController != null && _videoController!.value.isInitialized
                ? _videoController!.value.aspectRatio
                : 16 / 9,
            child: _buildVideoArea(),
          ),

          // 非全屏时的底部控制
          if (_hasVideo) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    _formatTime(_isSeeking ? _seekPosition : _currentPosition),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Expanded(child: _buildSeekBar()),
                  Text(
                    _formatTime(_totalDuration),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],

          const Spacer(),

          // 底部操作按钮
          Padding(
            padding: const EdgeInsets.only(bottom: 32, left: 16, right: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildActionButton(Icons.folder_open, '打开文件', _openFile),
                const SizedBox(width: 24),
                _buildCircleButton(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  _togglePlay,
                  size: 56,
                ),
                const SizedBox(width: 24),
                _buildActionButton(Icons.stop, '停止', _stop),
                if (_hasVideo) ...[
                  const SizedBox(width: 24),
                  _buildActionButton(
                    Icons.fullscreen, '全屏', _toggleFullscreen,
                  ),
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
        IconButton(
          icon: Icon(icon, color: Colors.white),
          onPressed: onPressed,
          iconSize: 28,
        ),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }

  Widget _buildCircleButton(IconData icon, VoidCallback onPressed, {double size = 48}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Colors.deepPurple, Colors.purple],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.4),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: size * 0.5),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }
}