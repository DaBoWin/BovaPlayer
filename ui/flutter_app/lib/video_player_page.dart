import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:subtitle_wrapper_package/subtitle_wrapper_package.dart';
import 'package:http/http.dart' as http;

/// 使用 Flutter 官方 video_player 的播放器页面
class VideoPlayerPage extends StatefulWidget {
  final String url;
  final String title;
  final Map<String, String>? httpHeaders;
  final List<Map<String, String>>? subtitles;

  const VideoPlayerPage({
    super.key,
    required this.url,
    required this.title,
    this.httpHeaders,
    this.subtitles,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _showControls = true;
  Timer? _hideControlsTimer;
  double _playbackSpeed = 1.0;
  
  // 字幕相关
  late SubtitleController _subtitleController;
  int _selectedSubtitleIndex = -1; // -1 表示无字幕
  
  // 网速监控
  Timer? _networkSpeedTimer;
  double _currentSpeed = 0; // KB/s
  int _lastBytesLoaded = 0;
  DateTime _lastSpeedCheck = DateTime.now();

  @override
  void initState() {
    super.initState();
    _subtitleController = SubtitleController(
      subtitleType: SubtitleType.srt,
      showSubtitles: true,
    );
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      print('[VideoPlayer] 开始初始化播放器');
      print('[VideoPlayer] URL: ${widget.url}');
      print('[VideoPlayer] Headers: ${widget.httpHeaders}');
      
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
        httpHeaders: widget.httpHeaders ?? {},
      );

      print('[VideoPlayer] 开始加载视频...');
      await _controller.initialize().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('视频加载超时（30秒）');
        },
      );
      
      print('[VideoPlayer] 视频加载成功，开始播放');
      await _controller.play();

      setState(() {
        _isInitialized = true;
      });

      _controller.addListener(() {
        if (mounted) {
          setState(() {});
        }
      });

      _startHideControlsTimer();
      _startNetworkSpeedMonitor();
      
      // 加载第一个字幕（如果有）
      if (widget.subtitles != null && widget.subtitles!.isNotEmpty) {
        _loadSubtitle(0);
      }
    } on TimeoutException catch (e) {
      print('[VideoPlayer] 超时错误: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('视频加载超时，请检查网络连接'),
            action: SnackBarAction(
              label: '重试',
              onPressed: () {
                _initializePlayer();
              },
            ),
          ),
        );
      }
    } catch (e) {
      print('[VideoPlayer] 初始化失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('播放器初始化失败: $e'),
            action: SnackBarAction(
              label: '重试',
              onPressed: () {
                _initializePlayer();
              },
            ),
          ),
        );
      }
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controller.value.isPlaying) {
        setState(() {
          _showControls = false;
        });
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

  void _togglePlayPause() {
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
      _startHideControlsTimer();
    }
    setState(() {});
  }

  void _changePlaybackSpeed(double speed) {
    _controller.setPlaybackSpeed(speed);
    setState(() {
      _playbackSpeed = speed;
    });
  }

  Future<void> _loadSubtitle(int index) async {
    if (widget.subtitles == null || index < 0 || index >= widget.subtitles!.length) {
      return;
    }

    try {
      final subtitle = widget.subtitles![index];
      final url = subtitle['url']!;
      
      print('[VideoPlayer] 加载字幕: ${subtitle['title']} from $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: widget.httpHeaders ?? {},
      );
      
      if (response.statusCode == 200) {
        final subtitleContent = response.body;
        
        // 使用 SubtitleController 加载字幕
        _subtitleController.updateSubtitleContent(
          content: subtitleContent,
        );
        
        setState(() {
          _selectedSubtitleIndex = index;
        });
        
        print('[VideoPlayer] 字幕加载成功');
      }
    } catch (e) {
      print('[VideoPlayer] 字幕加载失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('字幕加载失败: $e')),
        );
      }
    }
  }

  void _disableSubtitle() {
    _subtitleController.updateSubtitleContent(content: '');
    setState(() {
      _selectedSubtitleIndex = -1;
    });
  }

  void _startNetworkSpeedMonitor() {
    _networkSpeedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_controller.value.isInitialized) return;
      
      // 估算网速：基于视频缓冲进度
      final now = DateTime.now();
      final duration = _controller.value.duration;
      final buffered = _controller.value.buffered;
      
      if (buffered.isNotEmpty && duration.inMilliseconds > 0) {
        final bufferedEnd = buffered.last.end;
        final bufferedBytes = (bufferedEnd.inMilliseconds / duration.inMilliseconds) * 
                              (_controller.value.size.width * _controller.value.size.height * 0.5); // 估算
        
        final timeDiff = now.difference(_lastSpeedCheck).inMilliseconds / 1000.0;
        if (timeDiff > 0) {
          final bytesDiff = bufferedBytes - _lastBytesLoaded;
          _currentSpeed = (bytesDiff / timeDiff) / 1024; // KB/s
          
          _lastBytesLoaded = bufferedBytes.toInt();
          _lastSpeedCheck = now;
          
          if (mounted) {
            setState(() {});
          }
        }
      }
    });
  }

  String _formatSpeed(double speedKBps) {
    if (speedKBps < 1024) {
      return '${speedKBps.toStringAsFixed(0)} KB/s';
    } else {
      return '${(speedKBps / 1024).toStringAsFixed(1)} MB/s';
    }
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _networkSpeedTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // 视频播放器 + 字幕
            Center(
              child: _isInitialized
                  ? SubtitleWrapper(
                      subtitleController: _subtitleController,
                      videoPlayerController: _controller,
                      subtitleStyle: const SubtitleStyle(
                        fontSize: 20,
                        textColor: Colors.white,
                        hasBorder: true,
                      ),
                      videoChild: AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: VideoPlayer(_controller),
                      ),
                    )
                  : const CircularProgressIndicator(color: Colors.white),
            ),

            // 点击区域（显示/隐藏控制栏）
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleControls,
                behavior: HitTestBehavior.translucent,
              ),
            ),

            // 控制栏
            if (_showControls) ...[
              // 顶部栏
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // 字幕选择
                      if (widget.subtitles != null && widget.subtitles!.isNotEmpty)
                        PopupMenuButton<int>(
                          icon: const Icon(Icons.subtitles, color: Colors.white),
                          onSelected: (index) {
                            if (index == -1) {
                              _disableSubtitle();
                            } else {
                              _loadSubtitle(index);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: -1,
                              child: Text('关闭字幕'),
                            ),
                            const PopupMenuDivider(),
                            ...List.generate(
                              widget.subtitles!.length,
                              (index) => PopupMenuItem(
                                value: index,
                                child: Row(
                                  children: [
                                    if (_selectedSubtitleIndex == index)
                                      const Icon(Icons.check, size: 16),
                                    if (_selectedSubtitleIndex == index)
                                      const SizedBox(width: 8),
                                    Text(widget.subtitles![index]['title'] ?? '字幕 ${index + 1}'),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      // 倍速选择
                      PopupMenuButton<double>(
                        icon: const Icon(Icons.speed, color: Colors.white),
                        onSelected: _changePlaybackSpeed,
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 0.5, child: Text('0.5x')),
                          const PopupMenuItem(value: 0.75, child: Text('0.75x')),
                          const PopupMenuItem(value: 1.0, child: Text('1.0x')),
                          const PopupMenuItem(value: 1.25, child: Text('1.25x')),
                          const PopupMenuItem(value: 1.5, child: Text('1.5x')),
                          const PopupMenuItem(value: 2.0, child: Text('2.0x')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 网速和时间显示（右上角）
              Positioned(
                top: 60,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // 实时时间
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            _getCurrentTime(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // 网速
                      if (_currentSpeed > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.speed, color: Colors.green, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              _formatSpeed(_currentSpeed),
                              style: const TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),

              // 底部控制栏
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 进度条
                      if (_isInitialized)
                        VideoProgressIndicator(
                          _controller,
                          allowScrubbing: true,
                          colors: const VideoProgressColors(
                            playedColor: Colors.deepPurple,
                            bufferedColor: Colors.white24,
                            backgroundColor: Colors.white12,
                          ),
                        ),
                      const SizedBox(height: 8),
                      // 控制按钮
                      Row(
                        children: [
                          // 播放/暂停
                          IconButton(
                            icon: Icon(
                              _controller.value.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              color: Colors.white,
                              size: 32,
                            ),
                            onPressed: _togglePlayPause,
                          ),
                          const SizedBox(width: 8),
                          // 时间显示
                          if (_isInitialized)
                            Text(
                              '${_formatDuration(_controller.value.position)} / ${_formatDuration(_controller.value.duration)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          const Spacer(),
                          // 倍速显示
                          Text(
                            '${_playbackSpeed}x',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 中央播放/暂停按钮
              if (!_controller.value.isPlaying)
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 48,
                      ),
                      onPressed: _togglePlayPause,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
