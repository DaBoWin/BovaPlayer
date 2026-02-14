import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class MediaKitPlayerPage extends StatefulWidget {
  final String url;
  final String title;
  final Map<String, String>? httpHeaders;
  final List<Map<String, String>>? subtitles;
  
  const MediaKitPlayerPage({
    super.key,
    required this.url,
    required this.title,
    this.httpHeaders,
    this.subtitles,
  });
  
  @override
  State<MediaKitPlayerPage> createState() => _MediaKitPlayerPageState();
}

class _MediaKitPlayerPageState extends State<MediaKitPlayerPage> {
  late final Player _player;
  late final VideoController _videoController;
  
  bool _isInitializing = true;
  String? _errorMessage;
  bool _showControls = true;
  bool _isLocked = false;
  double _playbackSpeed = 1.0;
  String _aspectRatio = 'fit';
  Timer? _hideTimer;
  Timer? _clockTimer;
  Timer? _speedTimer;
  String _currentTime = '';
  String _networkSpeed = '-- KB/s';
  int _lastPosition = 0;
  DateTime _lastSpeedCheck = DateTime.now();

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    _player = Player(
      configuration: const PlayerConfiguration(
        title: 'BovaPlayer',
        protocolWhitelist: ['http', 'https', 'file', 'tcp', 'tls'],
        logLevel: MPVLogLevel.warn,
      ),
    );
    
    // Android 需要启用硬件加速，macOS 需要禁用
    final bool enableHwAccel = Theme.of(context).platform == TargetPlatform.android;
    
    _videoController = VideoController(
      _player,
      configuration: VideoControllerConfiguration(
        enableHardwareAcceleration: enableHwAccel,
        // Android 特定配置
        androidAttachSurfaceAfterVideoParameters: enableHwAccel,
      ),
    );
    
    print('[MediaKitPlayer] 平台: ${Theme.of(context).platform}, 硬件加速: $enableHwAccel');
    
    // 配置 mpv TLS 选项（修复 HTTPS 播放）
    _configureMpvTls();
    
    // 监听播放器状态
    _player.stream.playing.listen((playing) {
      print('[MediaKitPlayer] 播放状态变化: $playing');
    });
    
    _player.stream.buffering.listen((buffering) {
      print('[MediaKitPlayer] 缓冲状态: $buffering');
    });
    
    _player.stream.error.listen((error) {
      print('[MediaKitPlayer] 播放器错误: $error');
    });
    
    _player.stream.width.listen((width) {
      print('[MediaKitPlayer] 视频宽度: $width');
    });
    
    _player.stream.height.listen((height) {
      print('[MediaKitPlayer] 视频高度: $height');
    });
    
    _initializePlayer();
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
    _speedTimer = Timer.periodic(const Duration(seconds: 2), (_) => _updateNetworkSpeed());
  }

  /// 配置 mpv 底层选项以支持 HTTPS 自签名证书
  Future<void> _configureMpvTls() async {
    try {
      final nativePlayer = _player.platform;
      if (nativePlayer == null) return;
      
      final isAndroid = Theme.of(context).platform == TargetPlatform.android;
      
      // 1. 禁用 TLS 证书验证
      await (nativePlayer as dynamic).setProperty('tls-verify', 'no');
      await (nativePlayer as dynamic).setProperty('tls-ca-file', '');
      
      // 2. 优化网络和缓冲配置
      await (nativePlayer as dynamic).setProperty('user-agent', 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36');
      await (nativePlayer as dynamic).setProperty('cache', 'yes');
      await (nativePlayer as dynamic).setProperty('demuxer-max-bytes', '50000000');
      await (nativePlayer as dynamic).setProperty('demuxer-max-back-bytes', '20000000');
      await (nativePlayer as dynamic).setProperty('demuxer-readahead-secs', '1');
      await (nativePlayer as dynamic).setProperty('cache-pause-initial', 'no');
      await (nativePlayer as dynamic).setProperty('cache-pause-wait', '0');
      await (nativePlayer as dynamic).setProperty('force-seekable', 'yes');
      await (nativePlayer as dynamic).setProperty('network-timeout', '60');
      
      // 3. 硬件解码配置 - Android 和 macOS 不同
      if (isAndroid) {
        // Android 使用 mediacodec 硬件解码
        await (nativePlayer as dynamic).setProperty('hwdec', 'mediacodec-copy');
        await (nativePlayer as dynamic).setProperty('vo', 'gpu');
        print('[MediaKitPlayer] Android 配置: hwdec=mediacodec-copy, vo=gpu');
      } else {
        // macOS 使用 auto-copy
        await (nativePlayer as dynamic).setProperty('hwdec', 'auto-copy');
        print('[MediaKitPlayer] macOS 配置: hwdec=auto-copy');
      }
      
      print('[MediaKitPlayer] mpv 配置完成');
    } catch (e) {
      print('[MediaKitPlayer] 配置 mpv 失败: $e');
    }
  }

  Future<void> _initializePlayer() async {
    try {
      print('[MediaKitPlayer] 开始初始化播放器');
      print('[MediaKitPlayer] Stream URL: ${widget.url}');
      print('[MediaKitPlayer] HTTP Headers: ${widget.httpHeaders}');
      
      // 方法1: 尝试使用 httpHeaders
      try {
        print('[MediaKitPlayer] 尝试方法1: 使用 httpHeaders');
        final media = Media(
          widget.url,
          httpHeaders: widget.httpHeaders ?? {},
        );
        
        print('[MediaKitPlayer] 打开媒体...');
        await _player.open(media);
        
        print('[MediaKitPlayer] 开始播放...');
        await _player.play();
        
        print('[MediaKitPlayer] 播放器初始化成功');
        
        if (mounted) {
          setState(() {
            _isInitializing = false;
          });
          _startHideTimer();
        }
        return;
      } catch (e) {
        print('[MediaKitPlayer] 方法1失败: $e');
      }
      
      // 方法2: 直接使用 URL（不带 headers）
      print('[MediaKitPlayer] 尝试方法2: 不使用 headers');
      final media = Media(widget.url);
      
      await _player.open(media);
      await _player.play();
      
      print('[MediaKitPlayer] 方法2成功');
      
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
        _startHideTimer();
      }
    } catch (e, stackTrace) {
      print('[MediaKitPlayer] 所有方法都失败: $e');
      print('[MediaKitPlayer] 堆栈: $stackTrace');
      
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = '播放失败: $e\n\n请尝试在浏览器中打开此URL测试:\n${widget.url}';
        });
      }
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _clockTimer?.cancel();
    _speedTimer?.cancel();
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

  /// 计算实时网速
  /// 通过监听播放位置变化来估算下载速度
  void _updateNetworkSpeed() async {
    if (!mounted) return;
    
    try {
      final nativePlayer = _player.platform;
      if (nativePlayer == null) {
        return;
      }
      
      try {
        // 方法1: 尝试从 MPV 获取 cache-speed
        // cache-speed 单位可能是 bytes/s，直接使用
        final cacheSpeed = await (nativePlayer as dynamic).getProperty('cache-speed');
        
        if (cacheSpeed != null) {
          double? speedValue;
          if (cacheSpeed is num) {
            speedValue = cacheSpeed.toDouble();
          } else if (cacheSpeed is String) {
            speedValue = double.tryParse(cacheSpeed);
          }
          
          if (speedValue != null && speedValue > 0) {
            // cache-speed 单位是 bytes/s，直接格式化
            final speed = _formatSpeed(speedValue);
            if (mounted) {
              setState(() {
                _networkSpeed = speed;
              });
            }
            return;
          }
        }
      } catch (e) {
        // cache-speed 不可用
      }
      
      try {
        // 方法2: 尝试获取 demuxer-cache-state，使用 raw-input-rate
        final cacheState = await (nativePlayer as dynamic).getProperty('demuxer-cache-state');
        
        if (cacheState != null && cacheState is Map) {
          // raw-input-rate 是实时输入速率（字节/秒）
          final rawInputRate = cacheState['raw-input-rate'];
          
          if (rawInputRate != null) {
            double? speedValue;
            if (rawInputRate is num) {
              speedValue = rawInputRate.toDouble();
            } else if (rawInputRate is String) {
              speedValue = double.tryParse(rawInputRate);
            }
            
            if (speedValue != null && speedValue > 0) {
              final speed = _formatSpeed(speedValue);
              if (mounted) {
                setState(() {
                  _networkSpeed = speed;
                });
              }
              return;
            }
          }
          
          // 备用：计算缓存增长速度
          final totalBytes = cacheState['total-bytes'];
          if (totalBytes != null) {
            int? bytesValue;
            if (totalBytes is num) {
              bytesValue = totalBytes.toInt();
            } else if (totalBytes is String) {
              bytesValue = int.tryParse(totalBytes);
            }
            
            if (bytesValue != null) {
              final now = DateTime.now();
              final timeDiff = now.difference(_lastSpeedCheck).inSeconds.toDouble();
              
              if (timeDiff > 0 && _lastPosition > 0 && bytesValue > _lastPosition) {
                final bytesDiff = bytesValue - _lastPosition;
                final bytesPerSecond = bytesDiff / timeDiff;
                
                if (bytesPerSecond > 0) {
                  final speed = _formatSpeed(bytesPerSecond);
                  if (mounted) {
                    setState(() {
                      _networkSpeed = speed;
                    });
                  }
                }
              }
              
              _lastPosition = bytesValue;
              _lastSpeedCheck = now;
              return;
            }
          }
        }
      } catch (e) {
        print('[NetworkSpeed] 方法2失败: $e');
      }
      
      try {
        // 方法3: 使用 video-bitrate 和 audio-bitrate 估算
        final videoBitrate = await (nativePlayer as dynamic).getProperty('video-bitrate');
        final audioBitrate = await (nativePlayer as dynamic).getProperty('audio-bitrate');
        
        double totalBitrate = 0;
        
        if (videoBitrate != null) {
          if (videoBitrate is num) {
            totalBitrate += videoBitrate.toDouble();
          } else if (videoBitrate is String) {
            totalBitrate += double.tryParse(videoBitrate) ?? 0;
          }
        }
        
        if (audioBitrate != null) {
          if (audioBitrate is num) {
            totalBitrate += audioBitrate.toDouble();
          } else if (audioBitrate is String) {
            totalBitrate += double.tryParse(audioBitrate) ?? 0;
          }
        }
        
        if (totalBitrate > 0) {
          // bitrate 单位是 bits/s，转换为 bytes/s
          final bytesPerSecond = totalBitrate / 8.0;
          final speed = _formatSpeed(bytesPerSecond);
          if (mounted) {
            setState(() {
              _networkSpeed = speed;
            });
          }
          return;
        }
      } catch (e) {
        print('[NetworkSpeed] 方法3失败: $e');
      }
      
      // 所有方法都失败，显示状态
      if (_player.state.buffering) {
        if (mounted) {
          setState(() {
            _networkSpeed = '缓冲中...';
          });
        }
      } else if (_player.state.playing) {
        if (mounted) {
          setState(() {
            _networkSpeed = '-- KB/s';
          });
        }
      }
    } catch (e) {
      print('[NetworkSpeed] 更新失败: $e');
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
    if (!_isLocked && _player.state.playing) {
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
    final newPos = _player.state.position + offset;
    _player.seek(newPos);
    _startHideTimer();
  }

  void _togglePlayPause() {
    _player.playOrPause();
    _startHideTimer();
  }

  void _changeSpeed(double speed) {
    setState(() => _playbackSpeed = speed);
    _player.setRate(speed);
    Navigator.pop(context);
  }

  void _changeAspectRatio(String ratio) {
    setState(() => _aspectRatio = ratio);
    Navigator.pop(context);
  }

  Widget _buildVideoPlayer() {
    if (_isInitializing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 16),
            const Text(
              '正在加载...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      );
    }

    // 使用 SizedBox.expand 确保视频填充整个屏幕
    return SizedBox.expand(
      child: Video(
        controller: _videoController,
        controls: NoVideoControls, // 使用自定义控制
        fit: BoxFit.contain, // 保持宽高比
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
          icon: _player.state.playing ? Icons.pause : Icons.play_arrow,
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
    return StreamBuilder<Duration>(
      stream: _player.stream.position,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = _player.state.duration;
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                _formatDuration(position),
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
                    max: duration.inMilliseconds > 0
                        ? duration.inMilliseconds.toDouble()
                        : 1,
                    onChanged: (value) {
                      _player.seek(Duration(milliseconds: value.toInt()));
                    },
                    onChangeEnd: (_) => _startHideTimer(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatDuration(duration),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        );
      },
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
    final tracks = _player.state.tracks.subtitle;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
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
              ListTile(
                title: const Text(
                  '关闭',
                  style: TextStyle(color: Colors.white),
                ),
                trailing: _player.state.track.subtitle == SubtitleTrack.no()
                    ? const Icon(Icons.check, color: Colors.deepPurple)
                    : null,
                onTap: () {
                  _player.setSubtitleTrack(SubtitleTrack.no());
                  Navigator.pop(context);
                },
              ),
              for (final track in tracks)
                ListTile(
                  title: Text(
                    track.title ?? track.language ?? '字幕 ${track.id}',
                    style: TextStyle(
                      color: _player.state.track.subtitle.id == track.id
                          ? Colors.deepPurple.shade200
                          : Colors.white,
                    ),
                  ),
                  trailing: _player.state.track.subtitle.id == track.id
                      ? const Icon(Icons.check, color: Colors.deepPurple)
                      : null,
                  onTap: () {
                    _player.setSubtitleTrack(track);
                    Navigator.pop(context);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
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
        child: SingleChildScrollView(
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
        child: SingleChildScrollView(
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
      ),
    );
  }
}
