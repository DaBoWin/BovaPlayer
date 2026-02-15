import 'dart:async';
import 'dart:io';
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
  VideoController? _videoController;
  
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
    
    // 延迟初始化 VideoController，避免在 initState 中访问 context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeVideoController();
    });
  }
  
  void _initializeVideoController() async {
    if (!mounted) return;
    
    // 检测是否是模拟器 - 使用多种方法
    bool isEmulator = false;
    try {
      // 方法1: 检查 ro.kernel.qemu
      final result1 = await Process.run('getprop', ['ro.kernel.qemu']);
      final qemu = result1.stdout.toString().trim();
      print('[MediaKitPlayer] ro.kernel.qemu = $qemu');
      
      // 方法2: 检查 ro.product.model
      final result2 = await Process.run('getprop', ['ro.product.model']);
      final model = result2.stdout.toString().trim();
      print('[MediaKitPlayer] ro.product.model = $model');
      
      // 方法3: 检查 ro.hardware
      final result3 = await Process.run('getprop', ['ro.hardware']);
      final hardware = result3.stdout.toString().trim();
      print('[MediaKitPlayer] ro.hardware = $hardware');
      
      // 判断是否是模拟器
      isEmulator = qemu == '1' || 
                   model.toLowerCase().contains('sdk') || 
                   model.toLowerCase().contains('emulator') ||
                   hardware.toLowerCase().contains('ranchu') ||
                   hardware.toLowerCase().contains('goldfish');
      
      print('[MediaKitPlayer] 模拟器检测结果: $isEmulator');
    } catch (e) {
      print('[MediaKitPlayer] 模拟器检测失败: $e，默认假设是真机');
      isEmulator = false;
    }
    
    // 真机启用硬件加速，模拟器禁用
    final enableHwAccel = !isEmulator && Theme.of(context).platform == TargetPlatform.android;
    
    _videoController = VideoController(
      _player,
      configuration: VideoControllerConfiguration(
        enableHardwareAcceleration: enableHwAccel,
      ),
    );
    
    print('[MediaKitPlayer] 平台: ${Theme.of(context).platform}, 模拟器: $isEmulator, 硬件加速: $enableHwAccel');
    
    // 配置 mpv TLS 选项（修复 HTTPS 播放）
    await _configureMpvTls(isEmulator);
    
    // 监听播放器状态
    _player.stream.playing.listen((playing) {
      print('[MediaKitPlayer] 播放状态变化: $playing');
      if (mounted) setState(() {});
    });
    
    _player.stream.buffering.listen((buffering) {
      print('[MediaKitPlayer] 缓冲状态: $buffering');
      if (mounted) setState(() {});
    });
    
    _player.stream.error.listen((error) {
      print('[MediaKitPlayer] 播放器错误: $error');
      if (mounted) {
        setState(() {
          _errorMessage = '播放错误: $error';
        });
      }
    });
    
    _player.stream.width.listen((width) {
      print('[MediaKitPlayer] 视频宽度: $width');
      if (mounted) setState(() {});
    });
    
    _player.stream.height.listen((height) {
      print('[MediaKitPlayer] 视频高度: $height');
      if (mounted) setState(() {});
    });
    
    _player.stream.duration.listen((duration) {
      print('[MediaKitPlayer] 视频时长: $duration');
      if (mounted) setState(() {});
    });
    
    _initializePlayer();
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
    _speedTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateNetworkSpeed());
  }

  /// 配置 mpv 底层选项以支持 HTTPS 自签名证书
  Future<void> _configureMpvTls(bool isEmulator) async {
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
      
      // 3. 硬件解码配置 - 根据设备类型和平台
      if (isAndroid) {
        if (isEmulator) {
          // 模拟器使用纯软件解码
          await (nativePlayer as dynamic).setProperty('hwdec', 'no');
          print('[MediaKitPlayer] Android 模拟器配置: hwdec=no (纯软件解码)');
        } else {
          // 真机使用硬件解码
          await (nativePlayer as dynamic).setProperty('hwdec', 'mediacodec-copy');
          print('[MediaKitPlayer] Android 真机配置: hwdec=mediacodec-copy (硬件解码)');
        }
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
  /// 使用播放位置和缓冲区来估算下载速度
  void _updateNetworkSpeed() async {
    if (!mounted) return;
    
    try {
      final buffer = _player.state.buffer;
      final position = _player.state.position;
      final duration = _player.state.duration;
      final buffering = _player.state.buffering;
      
      // 计算时间差
      final now = DateTime.now();
      final timeDiff = now.difference(_lastSpeedCheck).inSeconds.toDouble();
      
      if (timeDiff >= 1.0) {
        final currentBufferMs = buffer.inMilliseconds;
        final currentPosMs = position.inMilliseconds;
        final bufferDiff = currentBufferMs - _lastPosition;
        
        // 如果缓冲区在增长，说明正在下载
        if (bufferDiff > 0 && duration.inMilliseconds > 0) {
          // 计算视频的平均码率（基于已播放的部分）
          // 假设视频文件大小可以从时长估算
          // 一般视频：1080p 约 5-10 Mbps，720p 约 2-5 Mbps，480p 约 1-2 Mbps
          
          // 使用视频分辨率来估算码率
          final width = _player.state.width ?? 1920;
          final height = _player.state.height ?? 1080;
          
          double estimatedBitrate; // Kbps
          if (width >= 1920 || height >= 1080) {
            estimatedBitrate = 8000; // 1080p: 8 Mbps
          } else if (width >= 1280 || height >= 720) {
            estimatedBitrate = 4000; // 720p: 4 Mbps
          } else {
            estimatedBitrate = 2000; // 480p: 2 Mbps
          }
          
          // 缓冲增量（秒）* 码率（Kbps）/ 8 = 下载的字节数
          final bufferIncreaseSec = bufferDiff / 1000.0;
          final downloadedBytes = (bufferIncreaseSec * estimatedBitrate * 1000) / 8;
          
          // 下载速度 = 下载的字节数 / 时间差
          final bytesPerSecond = downloadedBytes / timeDiff;
          
          if (bytesPerSecond > 0) {
            final speed = _formatSpeed(bytesPerSecond);
            if (mounted) {
              setState(() {
                _networkSpeed = speed;
              });
            }
          }
        } else if (bufferDiff < 0) {
          // 缓冲区在减少，说明在播放但没有下载
          if (mounted) {
            setState(() {
              _networkSpeed = '0 KB/s';
            });
          }
        }
        
        _lastPosition = currentBufferMs;
        _lastSpeedCheck = now;
      }
      
      // 显示缓冲状态
      if (buffering) {
        if (mounted) {
          setState(() {
            _networkSpeed = '缓冲中...';
          });
        }
      }
    } catch (e) {
      print('[NetworkSpeed] 更新失败: $e');
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

    if (_errorMessage != null) {
      return Center(
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
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('返回'),
              ),
            ],
          ),
        ),
      );
    }

    // 使用 Container 包裹确保有背景色
    return Container(
      color: Colors.black,
      child: _videoController != null
          ? Video(
              controller: _videoController!,
              controls: NoVideoControls,
              fit: BoxFit.contain,
              // 添加 wakelock 保持屏幕常亮
              wakelock: true,
            )
          : const Center(
              child: CircularProgressIndicator(color: Colors.white),
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

            // 调试信息（开发时显示）
            if (_isInitializing || _errorMessage != null)
              Positioned(
                top: 100,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '播放器状态:',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '初始化中: $_isInitializing',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        '播放中: ${_player.state.playing}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        '缓冲中: ${_player.state.buffering}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        '视频尺寸: ${_player.state.width}x${_player.state.height}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        '时长: ${_player.state.duration}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '错误: $_errorMessage',
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            // 控制层
            if (_showControls && !_isLocked && !_isInitializing)
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
