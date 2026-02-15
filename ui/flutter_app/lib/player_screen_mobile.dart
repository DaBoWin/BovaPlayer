import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  Player? _player;
  VideoController? _videoController;
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasVideo = false;
  String _currentFile = '';
  String _videoInfo = '';
  
  // 字幕相关
  List<SubtitleTrack> _subtitleTracks = [];
  SubtitleTrack _currentSubtitle = SubtitleTrack.no();
  
  // 网速监控
  Timer? _speedTimer;
  double _currentSpeed = 0.0; // KB/s
  int _lastBufferPosition = 0;
  DateTime _lastSpeedCheck = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }
  
  void _initializePlayer() {
    try {
      print('[PlayerScreen] 初始化播放器');
      _player = Player();
      _videoController = VideoController(_player!);
      
      // 监听播放器状态变化
      _player!.stream.duration.listen((duration) {
        if (mounted) {
          setState(() {
            _updateVideoInfo();
          });
        }
      });
      
      _player!.stream.width.listen((width) {
        if (mounted) {
          setState(() {
            _updateVideoInfo();
          });
        }
      });
      
      _player!.stream.height.listen((height) {
        if (mounted) {
          setState(() {
            _updateVideoInfo();
          });
        }
      });
      
      // 监听字幕轨道变化
      _player!.stream.tracks.listen((tracks) {
        if (mounted) {
          setState(() {
            _subtitleTracks = tracks.subtitle;
          });
        }
      });
      
      _player!.stream.track.listen((track) {
        if (mounted) {
          setState(() {
            _currentSubtitle = track.subtitle;
          });
        }
      });
      
      // 监听缓冲状态来计算网速
      _player!.stream.buffer.listen((buffer) {
        _updateNetworkSpeed(buffer.inMilliseconds);
      });
      
      // 启动网速监控定时器
      _startSpeedMonitoring();
      
      print('[PlayerScreen] Media Kit 播放器已初始化');
    } catch (e) {
      print('[PlayerScreen] 播放器初始化失败: $e');
      setState(() {
        _errorMessage = '播放器初始化失败: $e';
      });
    }
  }

  @override
  void dispose() {
    _speedTimer?.cancel();
    _player?.dispose();
    super.dispose();
  }
  
  void _startSpeedMonitoring() {
    _speedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _player != null && _player!.state.playing) {
        // 网速会在 buffer 监听中更新
        setState(() {});
      }
    });
  }
  
  void _updateNetworkSpeed(int currentBufferMs) {
    final now = DateTime.now();
    final timeDiff = now.difference(_lastSpeedCheck).inMilliseconds;
    
    if (timeDiff > 0) {
      final bufferDiff = currentBufferMs - _lastBufferPosition;
      // 估算网速：缓冲增量 / 时间差
      // 假设视频码率约为 5 Mbps (625 KB/s)
      if (bufferDiff > 0) {
        _currentSpeed = (bufferDiff / timeDiff) * 625; // KB/s
      }
    }
    
    _lastBufferPosition = currentBufferMs;
    _lastSpeedCheck = now;
  }
  
  void _updateVideoInfo() {
    if (_player == null) return;
    
    final duration = _player!.state.duration;
    final width = _player!.state.width;
    final height = _player!.state.height;
    
    final durationStr = duration.inSeconds > 0 
        ? '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}'
        : '未知';
    
    final resolutionStr = (width != null && height != null) 
        ? '${width}x${height}'
        : '未知';
    
    _videoInfo = '时长: $durationStr | 分辨率: $resolutionStr';
  }
  
  String _formatSpeed(double speedKBps) {
    if (speedKBps < 1024) {
      return '${speedKBps.toStringAsFixed(0)} KB/s';
    } else {
      return '${(speedKBps / 1024).toStringAsFixed(2)} MB/s';
    }
  }
  
  Future<void> _showSubtitleSelector() async {
    if (_player == null) return;
    
    if (_subtitleTracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('当前视频没有字幕轨道'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.subtitles, color: Colors.white),
                    const SizedBox(width: 12),
                    const Text(
                      '选择字幕',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              // 无字幕选项
              ListTile(
                leading: Radio<String>(
                  value: 'no',
                  groupValue: _currentSubtitle.id,
                  onChanged: (value) async {
                    await _player?.setSubtitleTrack(SubtitleTrack.no());
                    Navigator.pop(context);
                  },
                  activeColor: Colors.deepPurple.shade200,
                ),
                title: const Text(
                  '无字幕',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  await _player?.setSubtitleTrack(SubtitleTrack.no());
                  Navigator.pop(context);
                },
              ),
              // 字幕轨道列表
              ..._subtitleTracks.map((track) {
                return ListTile(
                  leading: Radio<String>(
                    value: track.id,
                    groupValue: _currentSubtitle.id,
                    onChanged: (value) async {
                      await _player?.setSubtitleTrack(track);
                      Navigator.pop(context);
                    },
                    activeColor: Colors.deepPurple.shade200,
                  ),
                  title: Text(
                    track.title ?? track.language ?? '字幕 ${track.id}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: track.language != null
                      ? Text(
                          track.language!,
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        )
                      : null,
                  onTap: () async {
                    await _player?.setSubtitleTrack(track);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
  
  Future<void> _loadExternalSubtitle() async {
    if (_player == null) return;
    
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['srt', 'ass', 'ssa', 'vtt'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final filePath = result.files.first.path;
        if (filePath != null) {
          await _player?.setSubtitleTrack(
            SubtitleTrack.uri(filePath),
          );
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('已加载字幕: ${result.files.first.name}'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (e) {
      print('[PlayerScreen] 加载外部字幕失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载字幕失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickAndPlayFile() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final filePath = result.files.first.path;
        if (filePath != null) {
          await _playFile(filePath);
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('[PlayerScreen] 文件选择错误: $e');
      setState(() {
        _errorMessage = '文件选择失败: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _playFile(String filePath) async {
    if (_player == null) {
      print('[PlayerScreen] 播放器未初始化');
      setState(() {
        _errorMessage = '播放器未初始化';
        _isLoading = false;
        _hasVideo = false;
      });
      return;
    }
    
    try {
      print('[PlayerScreen] 准备播放文件: $filePath');

      await _player!.open(Media(filePath));
      await _player!.play();

      setState(() {
        _hasVideo = true;
        _currentFile = filePath.split('/').last;
        _isLoading = false;
        _errorMessage = null;
      });

      print('[PlayerScreen] 播放成功');
    } catch (e) {
      print('[PlayerScreen] 播放失败: $e');
      setState(() {
        _errorMessage = '播放失败: $e';
        _isLoading = false;
        _hasVideo = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('本地播放', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // 字幕按钮
          if (_hasVideo)
            IconButton(
              icon: const Icon(Icons.subtitles_outlined),
              onPressed: _showSubtitleSelector,
              tooltip: '字幕选择',
            ),
          // 加载外部字幕
          if (_hasVideo)
            IconButton(
              icon: const Icon(Icons.closed_caption_outlined),
              onPressed: _loadExternalSubtitle,
              tooltip: '加载外部字幕',
            ),
          // 打开文件
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _isLoading ? null : _pickAndPlayFile,
            tooltip: '选择视频文件',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.deepPurple),
            SizedBox(height: 16),
            Text(
              '加载中...',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 64),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              onPressed: _pickAndPlayFile,
            ),
          ],
        ),
      );
    }

    if (!_hasVideo) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.deepPurple.withOpacity(0.15),
              ),
              child: Icon(
                Icons.video_library_outlined,
                size: 60,
                color: Colors.deepPurple.shade200,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '还没有选择视频',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '点击右上角文件夹图标选择视频',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.folder_open),
              label: const Text('选择视频文件'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: _pickAndPlayFile,
            ),
          ],
        ),
      );
    }

    // 显示视频播放器
    return Column(
      children: [
        // 文件名和视频信息
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: const Color(0xFF16213E),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _currentFile,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // 实时网速显示
                  if (_player != null && _player!.state.playing && _currentSpeed > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.green.withOpacity(0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.speed,
                            size: 14,
                            color: Colors.green.shade300,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatSpeed(_currentSpeed),
                            style: TextStyle(
                              color: Colors.green.shade300,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              if (_videoInfo.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _videoInfo,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    // 当前字幕显示
                    if (_currentSubtitle.id != 'no' && _currentSubtitle.id != 'auto')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.subtitles,
                              size: 12,
                              color: Colors.deepPurple.shade200,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _currentSubtitle.title ?? 
                              _currentSubtitle.language ?? 
                              '字幕',
                              style: TextStyle(
                                color: Colors.deepPurple.shade200,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        // 视频播放器
        Expanded(
          child: Container(
            color: Colors.black,
            child: Stack(
              children: [
                if (_videoController != null)
                  Center(
                    child: Video(
                      controller: _videoController!,
                      controls: MaterialVideoControls,
                    ),
                  )
                else
                  const Center(
                    child: CircularProgressIndicator(color: Colors.deepPurple),
                  ),
                // 缓冲时显示网速
                if (_player != null)
                  StreamBuilder<bool>(
                    stream: _player!.stream.buffering,
                    builder: (context, snapshot) {
                    final isBuffering = snapshot.data ?? false;
                    if (!isBuffering) return const SizedBox.shrink();
                    
                    return Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '缓冲中...',
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                            if (_currentSpeed > 0) ...[
                              const SizedBox(height: 4),
                              Text(
                                _formatSpeed(_currentSpeed),
                                style: TextStyle(
                                  color: Colors.green.shade300,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        // 底部控制栏
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF16213E),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 快退 10 秒
              IconButton(
                icon: const Icon(Icons.replay_10),
                color: Colors.white,
                iconSize: 32,
                onPressed: _player == null ? null : () async {
                  final currentPos = _player!.state.position;
                  final newPos = currentPos - const Duration(seconds: 10);
                  await _player!.seek(newPos.isNegative ? Duration.zero : newPos);
                },
                tooltip: '后退 10 秒',
              ),
              // 播放/暂停
              if (_player != null)
                StreamBuilder<bool>(
                  stream: _player!.stream.playing,
                  builder: (context, snapshot) {
                    final isPlaying = snapshot.data ?? false;
                    return IconButton(
                      icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                      color: Colors.deepPurple.shade200,
                      iconSize: 56,
                      onPressed: () async {
                        await _player!.playOrPause();
                      },
                      tooltip: isPlaying ? '暂停' : '播放',
                    );
                  },
                )
              else
                IconButton(
                  icon: const Icon(Icons.play_circle_filled),
                  color: Colors.grey,
                  iconSize: 56,
                  onPressed: null,
                ),
              // 快进 10 秒
              IconButton(
                icon: const Icon(Icons.forward_10),
                color: Colors.white,
                iconSize: 32,
                onPressed: _player == null ? null : () async {
                  final currentPos = _player!.state.position;
                  final duration = _player!.state.duration;
                  final newPos = currentPos + const Duration(seconds: 10);
                  await _player!.seek(newPos > duration ? duration : newPos);
                },
                tooltip: '前进 10 秒',
              ),
              // 停止
              IconButton(
                icon: const Icon(Icons.stop_circle_outlined),
                color: Colors.white,
                iconSize: 32,
                onPressed: _player == null ? null : () async {
                  await _player!.stop();
                },
                tooltip: '停止',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
