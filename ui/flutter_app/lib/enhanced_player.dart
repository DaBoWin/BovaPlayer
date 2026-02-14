import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:intl/intl.dart';

class EnhancedPlayerPage extends StatefulWidget {
  final VideoPlayerController controller;
  final String title;
  const EnhancedPlayerPage({super.key, required this.controller, required this.title});
  
  @override
  State<EnhancedPlayerPage> createState() => _EnhancedPlayerPageState();
}

class _EnhancedPlayerPageState extends State<EnhancedPlayerPage> {
  bool _showControls = true;
  bool _isLocked = false;
  double _playbackSpeed = 1.0;
  String _aspectRatio = 'fit'; // fit, fill, stretch
  Timer? _hideTimer;
  Timer? _clockTimer;
  Timer? _speedTimer;
  String _currentTime = '';
  String _networkSpeed = '0 KB/s';
  int _lastPosition = 0;
  int _lastCheckTime = 0;
  
  // 字幕相关
  List<String> _subtitleTracks = [];
  int _selectedSubtitleIndex = -1; // -1 表示关闭字幕

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    widget.controller.addListener(_listener);
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
    _speedTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateNetworkSpeed());
    _loadSubtitles();
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _clockTimer?.cancel();
    _speedTimer?.cancel();
    widget.controller.removeListener(_listener);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _listener() {
    if (mounted) setState(() {});
  }

  void _updateClock() {
    if (mounted) {
      setState(() {
        _currentTime = DateFormat('HH:mm').format(DateTime.now());
      });
    }
  }

  void _updateNetworkSpeed() {
    if (mounted && widget.controller.value.isInitialized) {
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final currentPosition = widget.controller.value.position.inMilliseconds;
      
      if (_lastCheckTime > 0) {
        final timeDiff = (currentTime - _lastCheckTime) / 1000.0; // 秒
        final posDiff = currentPosition - _lastPosition; // 毫秒
        
        if (timeDiff > 0 && posDiff > 0) {
          // 假设视频码率，根据播放进度估算网速
          // 这是一个简化的估算，实际网速需要从网络层获取
          final bytesPerMs = 1500; // 假设平均码率 1.5 KB/ms
          final bytesDownloaded = posDiff * bytesPerMs;
          final speedBps = bytesDownloaded / timeDiff;
          
          setState(() {
            if (speedBps > 1024 * 1024) {
              _networkSpeed = '${(speedBps / (1024 * 1024)).toStringAsFixed(1)} MB/s';
            } else if (speedBps > 1024) {
              _networkSpeed = '${(speedBps / 1024).toStringAsFixed(0)} KB/s';
            } else {
              _networkSpeed = '${speedBps.toStringAsFixed(0)} B/s';
            }
          });
        }
      }
      
      _lastCheckTime = currentTime;
      _lastPosition = currentPosition;
    }
  }

  void _loadSubtitles() {
    // 模拟加载字幕轨道
    // 实际应该从视频源获取
    setState(() {
      _subtitleTracks = [
        '关闭',
        '中文',
        '英文',
        '中英双语',
      ];
    });
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (!_isLocked && widget.controller.value.isPlaying) {
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
    final newPos = widget.controller.value.position + offset;
    widget.controller.seekTo(newPos);
    _startHideTimer();
  }

  void _togglePlayPause() {
    if (widget.controller.value.isPlaying) {
      widget.controller.pause();
    } else {
      widget.controller.play();
    }
    _startHideTimer();
  }

  void _changeSpeed(double speed) {
    setState(() => _playbackSpeed = speed);
    widget.controller.setPlaybackSpeed(speed);
    Navigator.pop(context);
  }

  void _changeAspectRatio(String ratio) {
    setState(() => _aspectRatio = ratio);
    Navigator.pop(context);
  }

  Widget _buildVideoPlayer() {
    final v = widget.controller.value;
    if (!v.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    Widget videoWidget = VideoPlayer(widget.controller);

    switch (_aspectRatio) {
      case 'fill':
        return SizedBox.expand(
          child: FittedBox(fit: BoxFit.cover, child: SizedBox(
            width: v.size.width,
            height: v.size.height,
            child: videoWidget,
          )),
        );
      case 'stretch':
        return SizedBox.expand(child: videoWidget);
      case 'fit':
      default:
        return Center(
          child: AspectRatio(
            aspectRatio: v.aspectRatio,
            child: videoWidget,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.controller.value;

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
            
            const SizedBox(width: 16),
            
            // 网速（实时更新）
            Text(
              _networkSpeed,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
            
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterControls() {
    final v = widget.controller.value;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 快退 10s
        _buildCircleButton(
          icon: Icons.replay_10,
          onPressed: () => _seek(const Duration(seconds: -10)),
        ),
        
        const SizedBox(width: 48),
        
        // 播放/暂停
        _buildCircleButton(
          icon: v.isPlaying ? Icons.pause : Icons.play_arrow,
          size: 64,
          onPressed: _togglePlayPause,
        ),
        
        const SizedBox(width: 48),
        
        // 快进 10s
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
    final v = widget.controller.value;
    final position = v.position;
    final duration = v.duration;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // 当前时间
          Text(
            _formatDuration(position),
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
                inactiveTrackColor: Colors.white.withOpacity(0.3),
                thumbColor: Colors.white,
                overlayColor: Colors.white.withOpacity(0.3),
              ),
              child: Slider(
                value: position.inMilliseconds.toDouble().clamp(
                  0,
                  duration.inMilliseconds.toDouble(),
                ),
                max: duration.inMilliseconds > 0
                    ? duration.inMilliseconds.toDouble()
                    : 1,
                onChanged: (value) {
                  widget.controller.seekTo(
                    Duration(milliseconds: value.toInt()),
                  );
                },
                onChangeEnd: (_) => _startHideTimer(),
              ),
            ),
          ),
          
          const SizedBox(width: 8),
          
          // 总时长
          Text(
            _formatDuration(duration),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
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
          // 字幕
          _buildBottomButton(
            icon: Icons.subtitles,
            label: _selectedSubtitleIndex >= 0 
                ? _subtitleTracks[_selectedSubtitleIndex] 
                : '字幕',
            onPressed: _showSubtitleMenu,
          ),
          
          // 倍速
          _buildBottomButton(
            icon: Icons.speed,
            label: '${_playbackSpeed}x',
            onPressed: _showSpeedMenu,
          ),
          
          // 画面比例
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
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
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

  void _showSubtitleMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '字幕',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            for (int i = 0; i < _subtitleTracks.length; i++)
              ListTile(
                title: Text(
                  _subtitleTracks[i],
                  style: TextStyle(
                    color: _selectedSubtitleIndex == i
                        ? Colors.deepPurple.shade200
                        : Colors.white,
                  ),
                ),
                trailing: _selectedSubtitleIndex == i
                    ? const Icon(Icons.check, color: Colors.deepPurple)
                    : null,
                onTap: () {
                  setState(() => _selectedSubtitleIndex = i);
                  // TODO: 实际切换字幕轨道
                  Navigator.pop(context);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showSpeedMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '播放速度',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            for (final speed in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
              ListTile(
                title: Text(
                  '${speed}x',
                  style: TextStyle(
                    color: _playbackSpeed == speed
                        ? Colors.deepPurple.shade200
                        : Colors.white,
                  ),
                ),
                trailing: _playbackSpeed == speed
                    ? const Icon(Icons.check, color: Colors.deepPurple)
                    : null,
                onTap: () => _changeSpeed(speed),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showAspectRatioMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '画面比例',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            for (final ratio in [
              {'value': 'fit', 'label': '适应屏幕'},
              {'value': 'fill', 'label': '填充屏幕'},
              {'value': 'stretch', 'label': '拉伸填充'},
            ])
              ListTile(
                title: Text(
                  ratio['label']!,
                  style: TextStyle(
                    color: _aspectRatio == ratio['value']
                        ? Colors.deepPurple.shade200
                        : Colors.white,
                  ),
                ),
                trailing: _aspectRatio == ratio['value']
                    ? const Icon(Icons.check, color: Colors.deepPurple)
                    : null,
                onTap: () => _changeAspectRatio(ratio['value']!),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
