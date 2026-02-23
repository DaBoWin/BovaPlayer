import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class MediaKitPlayerPage extends StatefulWidget {
  final String url;
  final String title;
  final Map<String, String>? httpHeaders;
  final List<Map<String, String>>? subtitles;
  final String? itemId; // 用于保存播放位置
  final String? serverUrl; // Emby 服务器地址
  final String? accessToken; // API Token
  final String? userId; // 用户 ID
  
  const MediaKitPlayerPage({
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
  State<MediaKitPlayerPage> createState() => _MediaKitPlayerPageState();
}

class _MediaKitPlayerPageState extends State<MediaKitPlayerPage> {
  late final Player _player;
  VideoController? _videoController;
  static const _trafficLightsChannel = MethodChannel('com.bovaplayer/traffic_lights');
  
  bool _isInitializing = true;
  String? _errorMessage;
  bool _showControls = true;
  bool _isLocked = false;
  double _playbackSpeed = 1.0;
  String _aspectRatio = 'fit';
  Timer? _hideTimer;
  Timer? _clockTimer;
  Timer? _speedTimer;
  Timer? _savePositionTimer;
  Timer? _reportProgressTimer; // 上报播放进度到 Emby
  String _currentTime = '';
  String _networkSpeed = '-- KB/s';
  int _lastPosition = 0;
  DateTime _lastSpeedCheck = DateTime.now();
  
  // 手势控制相关
  double _brightness = 0.5;
  double _volume = 0.5;
  bool _showBrightnessIndicator = false;
  bool _showVolumeIndicator = false;
  bool _showSeekIndicator = false;
  String _seekIndicatorText = '';
  int _accumulatedSeekSeconds = 0; // 手势拖拉累计的秒数
  Timer? _indicatorTimer;
  bool _isDraggingProgress = false;
  double _dragProgressPosition = 0;
  
  // 性能面板
  bool _showStatsPanel = false;

  // 播放位置记忆
  Duration? _savedPosition;
  
  // 播放会话 ID
  String? _playSessionId;

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
      ),
    );
    
    // 加载保存的播放位置
    _loadSavedPosition();
    
    // 延迟初始化 VideoController，避免在 initState 中访问 context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeVideoController();
    });
  }
  
  void _initializeVideoController() async {
    if (!mounted) return;
    
    // 检测是否是模拟器 - 仅在 Android 平台检测
    bool isEmulator = false;
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;
    
    if (isAndroid) {
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
    }
    
    // 真机启用硬件加速，模拟器禁用
    final enableHwAccel = !isEmulator && isAndroid;
    
    // 初始化控制器
    _initVideoController(enableHwAccel);
    
    print('[MediaKitPlayer] 平台: ${Theme.of(context).platform}, 模拟器: $isEmulator, 硬件加速: $enableHwAccel');
    
    // 配置 mpv TLS 选项（修复 HTTPS 播放）
    await _configureMpvTls(isEmulator);
    
    // 监听播放器状态
    _setupPlayerListeners();
    
    _initializePlayer();
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
    _speedTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateNetworkSpeed());
  }

  void _initVideoController(bool enableHwAccel) {
    // 销毁旧的控制器
    _videoController = null;
    _videoController = VideoController(
      _player,
      configuration: VideoControllerConfiguration(
        enableHardwareAcceleration: enableHwAccel,
      ),
    );
  }

  void _setupPlayerListeners() {
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
  }

  /// 测试 URL 是否可访问
  Future<void> _testUrlAccess() async {
    try {
      print('[MediaKitPlayer] 测试 URL 访问性...');
      
      // 创建支持自签名证书的 HTTP 客户端
      final httpClient = HttpClient()
        ..badCertificateCallback = (X509Certificate cert, String host, int port) {
          print('[MediaKitPlayer] 接受证书: $host:$port');
          return true; // 接受所有证书
        }
        ..connectionTimeout = const Duration(seconds: 10);
      
      final uri = Uri.parse(widget.url);
      final request = await httpClient.headUrl(uri);
      
      // 添加 headers
      if (widget.httpHeaders != null) {
        widget.httpHeaders!.forEach((key, value) {
          request.headers.add(key, value);
        });
      }
      
      final response = await request.close();
      print('[MediaKitPlayer] URL 测试响应: ${response.statusCode}');
      print('[MediaKitPlayer] Content-Type: ${response.headers.contentType}');
      print('[MediaKitPlayer] Content-Length: ${response.headers.contentLength}');
      
      httpClient.close();
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('[MediaKitPlayer] ✓ URL 可访问');
      } else {
        print('[MediaKitPlayer] ✗ URL 返回错误状态码: ${response.statusCode}');
      }
    } catch (e) {
      print('[MediaKitPlayer] ✗ URL 测试失败: $e');
      // 不抛出异常，继续尝试播放
    }
  }

  /// 配置 mpv 底层选项以支持 HTTPS 自签名证书
  Future<void> _configureMpvTls(bool isEmulator) async {
    try {
      final nativePlayer = _player.platform;
      if (nativePlayer == null) return;
      
      final isAndroid = Theme.of(context).platform == TargetPlatform.android;
      
      // 1. 禁用 TLS 证书验证（支持自签名证书）
      await (nativePlayer as dynamic).setProperty('tls-verify', 'no');
      await (nativePlayer as dynamic).setProperty('tls-ca-file', '');
      
      // 2. HTTP/HTTPS 网络配置 - BovaPlayer 客户端标识
      await (nativePlayer as dynamic).setProperty('user-agent', 'BovaPlayer/1.0.0 (macOS; Flutter)');
      
      // 添加基本的 HTTP headers
      final headers = [
        'User-Agent: BovaPlayer/1.0.0 (macOS; Flutter)',
        'Accept: */*',
        'Accept-Encoding: identity',
        'Connection: keep-alive',
      ];
      
      await (nativePlayer as dynamic).setProperty('http-header-fields', headers.join('\r\n'));
      
      // 3. 优化网络配置 - 支持负载均衡节点和连接恢复
      await (nativePlayer as dynamic).setProperty('cache', 'yes');
      
      // 网络重连和超时配置（关键：负载均衡节点需要重试）
      await (nativePlayer as dynamic).setProperty('network-timeout', '120'); // 增加到120秒超时（大文件需要）
      await (nativePlayer as dynamic).setProperty('http-reconnect', 'yes'); // 启用自动重连
      await (nativePlayer as dynamic).setProperty('stream-open-timeout', '120'); // 流打开超时120秒
      
      // FFmpeg 重连配置 - 增强版 + 多线程优化
      // reconnect: 启用重连
      // reconnect_streamed: 对流媒体也启用重连
      // reconnect_at_eof: 在 EOF 时重连
      // reconnect_on_network_error: 网络错误时重连
      // reconnect_on_http_error: HTTP 错误时重连
      // reconnect_delay_max: 最大重连延迟（秒）
      // multiple_requests: 启用 HTTP 范围请求（多线程下载）
      // seekable: 启用可查找（支持范围请求）
      final lavfOptions = [
        'reconnect=1',
        'reconnect_streamed=1',
        'reconnect_at_eof=1',
        'reconnect_on_network_error=1',
        'reconnect_on_http_error=4xx,5xx',
        'reconnect_delay_max=15', // 增加到15秒
        'timeout=120000000', // 120秒超时（微秒）- 大文件需要更长时间
        'tcp_nodelay=1', // 禁用 Nagle 算法，减少延迟
        'listen_timeout=120000000', // 监听超时120秒
        'tls_verify=0', // 禁用 TLS 证书验证
        'user_agent=BovaPlayer/1.0.0 (macOS; Flutter)', // 设置 User-Agent
        'multiple_requests=1', // 启用多个并发请求（关键：多线程下载）
        'seekable=1', // 启用可查找
        'rw_timeout=120000000', // 读写超时120秒（微秒）
      ].join(',');
      
      await (nativePlayer as dynamic).setProperty('stream-lavf-o', lavfOptions);
      
      // TCP Keepalive 配置 - 防止连接被中断
      await (nativePlayer as dynamic).setProperty('stream-lavf-o-append', 'tcp_keepalive=1');
      
      // 多线程解码配置
      await (nativePlayer as dynamic).setProperty('vd-lavc-threads', '4'); // 视频解码线程数
      await (nativePlayer as dynamic).setProperty('ad-lavc-threads', '2'); // 音频解码线程数
      await (nativePlayer as dynamic).setProperty('demuxer-thread', 'yes'); // 启用解复用线程
      
      // 缓冲配置 - 优化快速启动 + 并行加载
      await (nativePlayer as dynamic).setProperty('demuxer-max-bytes', '50000000'); // 50MB
      await (nativePlayer as dynamic).setProperty('demuxer-max-back-bytes', '25000000'); // 25MB
      await (nativePlayer as dynamic).setProperty('demuxer-readahead-secs', '3'); // 预读3秒
      
      // 快速启动播放 - 关键优化
      await (nativePlayer as dynamic).setProperty('cache-pause-initial', 'yes'); // 等待初始缓存（大文件需要）
      await (nativePlayer as dynamic).setProperty('cache-pause-wait', '2'); // 等待2秒缓存
      await (nativePlayer as dynamic).setProperty('cache-secs', '10'); // 缓存10秒（增加稳定性）
      
      // 预读优化 - 启用快速预读
      await (nativePlayer as dynamic).setProperty('cache-on-disk', 'no'); // 内存缓存更快
      await (nativePlayer as dynamic).setProperty('demuxer-donate-buffer', 'yes'); // 捐赠缓冲区给解码器
      
      // HTTP 范围请求优化（支持多线程下载）
      await (nativePlayer as dynamic).setProperty('stream-buffer-size', '4096'); // 4KB 流缓冲（小缓冲快速响应）
      
      // 启用 seekable
      await (nativePlayer as dynamic).setProperty('force-seekable', 'yes');
      
      // 启用快速查找
      await (nativePlayer as dynamic).setProperty('hr-seek', 'yes');
      await (nativePlayer as dynamic).setProperty('hr-seek-framedrop', 'yes');
      
      // 错误恢复配置
      await (nativePlayer as dynamic).setProperty('load-unsafe-playlists', 'yes');
      // demuxer-lavf-analyzeduration 单位是秒 - 大幅减少分析时间以加快启动
      await (nativePlayer as dynamic).setProperty('demuxer-lavf-analyzeduration', '1'); // 1秒分析时间（减少）
      await (nativePlayer as dynamic).setProperty('demuxer-lavf-probesize', '1000000'); // 1MB 探测大小
      await (nativePlayer as dynamic).setProperty('demuxer-lavf-probe-info', 'nostreams'); // 减少探测
      
      // 启用 MPV 详细日志以查看多线程状态
      await (nativePlayer as dynamic).setProperty('msg-level', 'all=info,ffmpeg=debug');
      
      print('[MediaKitPlayer] 网络配置完成 - 多线程加载 + 快速启动');
      
      // 4. 硬件解码配置 - 根据设备类型和平台
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
        // macOS 端: 修复 HDR及画面发暗偏灰问题 
        // 之前尝试的高级 tone-mapping 和 hdr-compute-peak 严重吃 GPU 导致卡顿掉帧
        // 回退到性能最好的 auto-copy 配合简单的基础调亮，放弃昂贵的逐帧高光计算
        await (nativePlayer as dynamic).setProperty('hwdec', 'auto-copy'); 
        
        await (nativePlayer as dynamic).setProperty('target-colorspace-hint', 'yes');
        
        // 仅使用最轻量级的基础参数大幅提亮画面，不消耗过多算力
        await (nativePlayer as dynamic).setProperty('brightness', '8'); 
        await (nativePlayer as dynamic).setProperty('gamma', '8');      
        await (nativePlayer as dynamic).setProperty('contrast', '2');   
        
        print('[MediaKitPlayer] macOS 配置: hwdec=auto-copy, 移除重度渲染特效，轻量级基础提亮');
      }
      
      print('[MediaKitPlayer] mpv 配置完成 - 优化缓冲设置');
    } catch (e) {
      print('[MediaKitPlayer] 配置 mpv 失败: $e');
    }
  }

  Future<void> _initializePlayer() async {
    try {
      print('[MediaKitPlayer] 开始初始化播放器');
      print('[MediaKitPlayer] Stream URL: ${widget.url}');
      print('[MediaKitPlayer] HTTP Headers: ${widget.httpHeaders}');
      
      // 先测试 URL 是否可访问 - 注释掉以加快播放速度
      // await _testUrlAccess();
      
      // 方法1: 不使用 httpHeaders（URL 已包含 api_key）
      try {
        print('[MediaKitPlayer] 尝试方法1: 不使用 httpHeaders');
        final media = Media(widget.url);
        
        print('[MediaKitPlayer] 打开媒体...');
        await _player.open(media);
        
        print('[MediaKitPlayer] 开始播放...');
        await _player.play();
        
        // 恢复播放位置
        if (_savedPosition != null && _savedPosition!.inSeconds > 5) {
          await _showResumeDialog();
        }
        
        // 启动定时保存播放位置
        _startSavePositionTimer();
        
        // 上报播放开始
        _reportPlaybackStart();
        
        // 启动定时上报播放进度
        _startReportProgressTimer();
        
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
      
      // 方法2: 尝试使用 httpHeaders
      try {
        print('[MediaKitPlayer] 尝试方法2: 使用 httpHeaders');
        final media = Media(
          widget.url,
          httpHeaders: widget.httpHeaders ?? {},
        );
        
        print('[MediaKitPlayer] 打开媒体...');
        await _player.open(media);
        
        print('[MediaKitPlayer] 开始播放...');
        await _player.play();
        
        // 恢复播放位置
        if (_savedPosition != null && _savedPosition!.inSeconds > 5) {
          await _showResumeDialog();
        }
        
        // 启动定时保存播放位置
        _startSavePositionTimer();
        
        // 上报播放开始
        _reportPlaybackStart();
        
        // 启动定时上报播放进度
        _startReportProgressTimer();
        
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
      
      // 恢复播放位置
      if (_savedPosition != null && _savedPosition!.inSeconds > 5) {
        await _showResumeDialog();
      }
      
      // 启动定时保存播放位置
      _startSavePositionTimer();
      
      // 上报播放开始
      _reportPlaybackStart();
      
      // 启动定时上报播放进度
      _startReportProgressTimer();
      
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
          _errorMessage = '$e';
        });
      }
    }
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
        print('[MediaKitPlayer] 加载保存的播放位置: $_savedPosition');
      }
    } catch (e) {
      print('[MediaKitPlayer] 加载播放位置失败: $e');
    }
  }
  
  Future<void> _savePlayPosition() async {
    if (widget.itemId == null) return;
    
    try {
      final position = _player.state.position;
      final duration = _player.state.duration;
      
      // 如果播放进度超过95%，清除保存的位置
      if (duration.inSeconds > 0 && position.inSeconds / duration.inSeconds > 0.95) {
        final prefs = await SharedPreferences.getInstance();
        final key = 'play_position_${widget.itemId}';
        await prefs.remove(key);
        print('[MediaKitPlayer] 播放完成，清除保存的位置');
        return;
      }
      
      // 保存当前位置
      if (position.inSeconds > 5) {
        final prefs = await SharedPreferences.getInstance();
        final key = 'play_position_${widget.itemId}';
        await prefs.setInt(key, position.inSeconds);
        print('[MediaKitPlayer] 保存播放位置: ${position.inSeconds}秒');
      }
    } catch (e) {
      print('[MediaKitPlayer] 保存播放位置失败: $e');
    }
  }
  
  void _startSavePositionTimer() {
    _savePositionTimer?.cancel();
    _savePositionTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _savePlayPosition();
    });
  }
  
  Future<void> _showResumeDialog() async {
    if (!mounted) return;
    
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
      await _player.seek(_savedPosition!);
    }
  }

  // ============== 手势控制 ==============
  
  void _handleVerticalDragUpdate(DragUpdateDetails details, bool isLeft) {
    if (_isLocked) return;
    
    final delta = details.delta.dy;
    
    if (isLeft) {
      // 左侧控制亮度
      setState(() {
        _brightness = (_brightness - delta / 500).clamp(0.0, 1.0);
        _showBrightnessIndicator = true;
        _showVolumeIndicator = false;
        _showSeekIndicator = false;
      });
      
      // 设置屏幕亮度
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarBrightness: _brightness > 0.5 ? Brightness.light : Brightness.dark,
      ));
      
      _startIndicatorTimer();
    } else {
      // 右侧控制音量
      setState(() {
        _volume = (_volume - delta / 500).clamp(0.0, 1.0);
        _showVolumeIndicator = true;
        _showBrightnessIndicator = false;
        _showSeekIndicator = false;
      });
      
      _player.setVolume(_volume * 100);
      _startIndicatorTimer();
    }
  }
  
  // 手势拖拉相关
  Duration? _seekStartPosition; // 手势按下时的初始播放位置
  Duration? _seekTargetPosition; // 计算出的目标位置
  
  void _handleHorizontalDragStart(DragStartDetails details) {
    if (_isLocked) return;
    // 记录拖拽开始时的当前播放进度
    _seekStartPosition = _player.state.position;
    _seekTargetPosition = _seekStartPosition;
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    if (_isLocked || _seekStartPosition == null) return;
    
    // 获取屏幕宽度和当前的横向移动增量
    final screenWidth = MediaQuery.of(context).size.width;
    final delta = details.primaryDelta ?? 0.0;
    
    // 定义滑动灵敏度：滑满全屏大约跨度 180 秒（3 分钟），也可根据视频总时长动态调整
    // 这里采用：屏幕每滑动 1%，步进 1.5 秒
    final duration = _player.state.duration;
    if (duration.inSeconds > 0) {
      final percentageDelta = delta / screenWidth;
      // 我们设定滑过全屏等于移动 180 秒，如果是长视频也可以改大
      // 或者按视频总长度的 5%~10% 来映射
      final secondsDelta = (percentageDelta * 180).round(); 
      
      var newTargetSeconds = (_seekTargetPosition!.inSeconds + secondsDelta);
      // 保证不越界
      newTargetSeconds = newTargetSeconds.clamp(0, duration.inSeconds);
      
      _seekTargetPosition = Duration(seconds: newTargetSeconds);
      
      // 格式化显示时间
      final minutes = newTargetSeconds ~/ 60;
      final seconds = newTargetSeconds % 60;
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
    if (_isLocked || _seekTargetPosition == null) return;
    
    // 跳转到目标位置
    _player.seek(_seekTargetPosition!);
    
    // 重置
    _seekStartPosition = null;
    _seekTargetPosition = null;
    
    setState(() {
      _showSeekIndicator = false;
    });
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
      print('[MediaKitPlayer] 缺少上报参数，跳过播放开始上报');
      return;
    }
    
    try {
      // 生成播放会话 ID
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
      
      print('[MediaKitPlayer] 上报播放开始: $body');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'X-Emby-Token': widget.accessToken!,
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 204 || response.statusCode == 200) {
        print('[MediaKitPlayer] 播放开始上报成功');
      } else {
        print('[MediaKitPlayer] 播放开始上报失败: ${response.statusCode}');
      }
    } catch (e) {
      print('[MediaKitPlayer] 播放开始上报异常: $e');
    }
  }
  
  void _startReportProgressTimer() {
    _reportProgressTimer?.cancel();
    _reportProgressTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _reportPlaybackProgress();
    });
  }
  
  Future<void> _reportPlaybackProgress() async {
    if (widget.itemId == null || widget.serverUrl == null || widget.accessToken == null || _playSessionId == null) {
      return;
    }
    
    try {
      final position = _player.state.position;
      final isPaused = !_player.state.playing;
      
      // 转换为 Ticks (1 tick = 100 纳秒)
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
      
      print('[MediaKitPlayer] 上报播放进度: ${position.inSeconds}秒');
    } catch (e) {
      print('[MediaKitPlayer] 播放进度上报异常: $e');
    }
  }
  
  Future<void> _reportPlaybackStopped() async {
    if (widget.itemId == null || widget.serverUrl == null || widget.accessToken == null || _playSessionId == null) {
      return;
    }
    
    try {
      final position = _player.state.position;
      final positionTicks = position.inMicroseconds * 10;
      
      final url = '${widget.serverUrl}/Sessions/Playing/Stopped';
      final body = {
        'ItemId': widget.itemId,
        'PlaySessionId': _playSessionId,
        'PositionTicks': positionTicks,
      };
      
      print('[MediaKitPlayer] 上报播放停止: ${position.inSeconds}秒');
      
      await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'X-Emby-Token': widget.accessToken!,
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 5));
      
      print('[MediaKitPlayer] 播放停止上报成功');
    } catch (e) {
      print('[MediaKitPlayer] 播放停止上报异常: $e');
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
    
    // 保存播放位置
    _savePlayPosition();
    
    // 上报停止播放
    _reportPlaybackStopped();
    
    // 恢复 macOS 红绿灯
    if (Platform.isMacOS) {
      _trafficLightsChannel.invokeMethod('show');
    }
    
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
        if (mounted) {
          setState(() => _showControls = false);
          if (Platform.isMacOS) {
            _trafficLightsChannel.invokeMethod('hide');
          }
        }
      });
    }
  }

  void _toggleControls() {
    if (_isLocked) return;
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      if (Platform.isMacOS) {
        _trafficLightsChannel.invokeMethod('show');
      }
      _startHideTimer();
    } else {
      if (Platform.isMacOS) {
        _trafficLightsChannel.invokeMethod('hide');
      }
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

  void _retryPlay() {
    setState(() {
      _errorMessage = null;
      _isInitializing = true;
    });
    // 重启播放流程
    _initializePlayer();
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
        onHorizontalDragStart: _handleHorizontalDragStart,
        onHorizontalDragUpdate: _handleHorizontalDragUpdate,
        onHorizontalDragEnd: _handleHorizontalDragEnd,
        child: Stack(
          children: [
            // 视频播放器
            Positioned.fill(child: _buildVideoPlayer()),

            // 缓冲指示器
            if (!_isInitializing && _errorMessage == null && _player.state.buffering && _player.state.playing)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                ),
              ),

            // 手势指示器
            if (_showBrightnessIndicator) _buildBrightnessIndicator(),
            if (_showVolumeIndicator) _buildVolumeIndicator(),
            if (_showSeekIndicator) _buildSeekIndicator(),

            // 错误信息显示 (自动重试面板)
            if (_errorMessage != null)
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2937).withOpacity(0.95),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        '播放出错',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                        textAlign: TextAlign.center,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
                            ),
                            child: const Text('返回'),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: _retryPlay,
                            icon: const Icon(Icons.refresh, size: 20),
                            label: const Text('重试播放'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // 控制层 - 无边框悬浮重构
            if (_showControls && !_isLocked && !_isInitializing && _errorMessage == null)
              Positioned.fill(
                child: Stack(
                  children: [
                    // 给顶部和底部微微加一层极淡的渐变以防全白画面看不到字，但不使用之前的深黑底色
                    Positioned(
                      top: 0, left: 0, right: 0, height: 120,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black54, Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0, left: 0, right: 0, height: 160,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black54, Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                    
                    // 顶部栏
                    Positioned(
                      top: 0, left: 0, right: 0,
                      child: _buildTopBar(),
                    ),
                    
                    // 左侧悬浮工具栏
                    Positioned(
                      left: 20,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _buildLeftToolbar(),
                      ),
                    ),
                    
                    // 底部悬浮控制胶囊
                    Positioned(
                      bottom: 32,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: _buildBottomPill(),
                      ),
                    ),
                  ],
                ),
              ),

            // 锁屏按钮
            if (_showControls && _errorMessage == null)
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
              
            // 性能监控面板
            if (_showStatsPanel) _buildStatsPanel(),
          ],
        ),
      ),
    );
  }

  void _setVolume(double value) {
    setState(() {
      _volume = value;
    });
    _player.setVolume(value * 100);
    _startHideTimer();
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 8),
            // 万能解码引擎标签
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.deepPurpleAccent.withOpacity(0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'MPV',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            // 将标题居中
            Expanded(
              child: Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 面板开关
            IconButton(
              icon: Icon(
                _showStatsPanel ? Icons.info : Icons.info_outline,
                color: _showStatsPanel ? Colors.deepPurpleAccent : Colors.white70,
                size: 20,
              ),
              onPressed: () {
                setState(() => _showStatsPanel = !_showStatsPanel);
                if (_showStatsPanel) {
                  _hideTimer?.cancel();
                } else {
                  _startHideTimer();
                }
              },
            ),
            const SizedBox(width: 8),
            // 网速
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.speed, color: Colors.greenAccent, size: 14),
                const SizedBox(width: 4),
                Text(
                  _networkSpeed,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(width: 16),
            // 时间显示
            Text(
              _currentTime,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToolIconButton(Icons.subtitles_outlined, _showSubtitleMenu),
          const SizedBox(height: 16),
          _buildToolIconButton(Icons.crop_free, _showAspectRatioMenu),
        ],
      ),
    );
  }

  Widget _buildToolIconButton(IconData icon, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Icon(icon, color: Colors.white70, size: 22),
      ),
    );
  }

  Widget _buildBottomPill() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.75, // 使用安全一点的最大宽度组合
          constraints: const BoxConstraints(maxWidth: 800),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white12, width: 0.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 上排：时间与进度条
              _buildProgressBarPill(),
              const SizedBox(height: 4),
              // 下排：控制按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 左侧功能
                  Row(
                    children: [
                      _buildToolIconButton(Icons.monitor_outlined, () {}),
                      const SizedBox(width: 12),
                      Icon(
                        _volume > 0.5 ? Icons.volume_up : (_volume > 0 ? Icons.volume_down : Icons.volume_off),
                        color: Colors.white70,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: SliderTheme(
                          data: const SliderThemeData(
                            trackHeight: 2,
                            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5),
                            overlayShape: RoundSliderOverlayShape(overlayRadius: 10),
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: Colors.white24,
                            thumbColor: Colors.white,
                          ),
                          child: Slider(
                            value: _volume,
                            max: 1.0,
                            onChanged: _setVolume,
                            onChangeEnd: (_) => _startHideTimer(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  // 中间核心控制
                  Row(
                    children: [
                      _buildToolIconButton(Icons.fast_rewind_rounded, () => _seek(const Duration(seconds: -10))),
                      const SizedBox(width: 16),
                      InkWell(
                        onTap: _togglePlayPause,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _player.state.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      _buildToolIconButton(Icons.fast_forward_rounded, () => _seek(const Duration(seconds: 10))),
                    ],
                  ),
                  
                  // 右侧功能
                  Row(
                    children: [
                      InkWell(
                        onTap: _showSpeedMenu,
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                          child: Text(
                            '${_playbackSpeed}x',
                            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBarPill() {
    return StreamBuilder<Duration>(
      stream: _player.stream.position,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = _player.state.duration;
        
        return Row(
          children: [
            Text(
              _isDraggingProgress 
                  ? _formatDuration(Duration(milliseconds: _dragProgressPosition.toInt()))
                  : _formatDuration(position),
              style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final totalWidth = constraints.maxWidth;
                  final maxMs = duration.inMilliseconds.toDouble();
                  final currentMs = _isDraggingProgress
                      ? _dragProgressPosition
                      : position.inMilliseconds.toDouble();
                  final progress = maxMs > 0 ? (currentMs / maxMs).clamp(0.0, 1.0) : 0.0;

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (details) {
                      _hideTimer?.cancel();
                      setState(() {
                        _isDraggingProgress = true;
                        _dragProgressPosition = position.inMilliseconds.toDouble();
                      });
                    },
                    onHorizontalDragUpdate: (details) {
                      if (maxMs <= 0) return;
                      final delta = details.delta.dx;
                      final msDelta = (delta / totalWidth) * maxMs;
                      setState(() {
                        _dragProgressPosition = (_dragProgressPosition + msDelta).clamp(0.0, maxMs).toDouble();
                      });
                    },
                    onHorizontalDragEnd: (details) {
                      _player.seek(Duration(milliseconds: _dragProgressPosition.toInt()));
                      setState(() {
                        _isDraggingProgress = false;
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
            const SizedBox(width: 12),
            Text(
              _formatDuration(duration),
              style: const TextStyle(color: Colors.white54, fontSize: 12, fontFamily: 'monospace'),
            ),
          ],
        );
      },
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
    final tracks = _player.state.tracks.subtitle;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildBottomSheetContainer(
        context,
        '字幕选择',
        ListView(
          shrinkWrap: true,
          children: [
            _buildActionItem('关闭字幕', true, _player.state.track.subtitle == SubtitleTrack.no(), () {
              _player.setSubtitleTrack(SubtitleTrack.no());
              Navigator.pop(context);
            }),
            ...tracks.map((track) {
              final title = track.title ?? track.language ?? '字幕 ${track.id}';
              final isSelected = _player.state.track.subtitle.id == track.id;
              return _buildActionItem(title, true, isSelected, () {
                _player.setSubtitleTrack(track);
                Navigator.pop(context);
              });
            }),
          ],
        ),
      ),
    );
  }

  void _showSpeedMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildBottomSheetContainer(
        context,
        '播放速度',
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...[0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
              return _buildActionItem('${speed}x', true, _playbackSpeed == speed, () {
                _changeSpeed(speed);
                Navigator.pop(context);
              });
            }),
          ],
        ),
      ),
    );
  }

  void _showAspectRatioMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildBottomSheetContainer(
        context,
        '画面比例',
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...[
              {'value': 'fit', 'label': '适应屏幕'},
              {'value': 'fill', 'label': '填充屏幕'},
              {'value': 'stretch', 'label': '拉伸填充'},
            ].map((ratio) {
              return _buildActionItem(ratio['label']!, true, _aspectRatio == ratio['value'], () {
                _changeAspectRatio(ratio['value']!);
                Navigator.pop(context);
              });
            }),
          ],
        ),
      ),
    );
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

  // ============== 手势指示器 ==============
  
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
            Icon(
              _seekIndicatorText.startsWith('+') ? Icons.fast_forward : Icons.fast_rewind,
              color: Colors.white,
              size: 32,
            ),
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

  // ============== 性能监控面板 ==============

  Widget _buildStatsPanel() {
    final state = _player.state;
    final videoParams = state.videoParams;
    final audioParams = state.audioParams;
    
    // 尝试寻找真实的视频帧率 (track 经常显示为 auto)
    double? actualFps = state.track.video.fps;
    if (actualFps == null) {
      // 从所有视频轨道中找第一个带有 fps 数据的（通常实际解码轨道存在于其中）
      for (final track in state.tracks.video) {
        if (track.fps != null) {
          actualFps = track.fps;
          break;
        }
      }
    }
    
    // 汇总要显示的信息
    final stats = <String, String>{
      '视频分辨率': '${videoParams.w ?? '?'} x ${videoParams.h ?? '?'}',
      '视频帧率': actualFps?.toStringAsFixed(2) ?? '未知',
      // `track` 经常是 auto 并且不包含码率，我们显示 audioBitrate 
      '音频码率': state.audioBitrate != null ? '${(state.audioBitrate! / 1000).toStringAsFixed(0)} Kbps' : '未知',
      '音频声道数': audioParams.channelCount?.toString() ?? '未知',
      '音频采样率': audioParams.sampleRate?.toString() ?? '未知',
      '缓冲比例': '${state.bufferingPercentage.toStringAsFixed(1)}%',
      '总缓冲时长': _formatDuration(state.buffer),
      '网速估算': _networkSpeed,
    };

    return Positioned(
      top: 60,
      right: 16,
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              children: [
                Icon(Icons.analytics_outlined, color: Colors.white70, size: 16),
                SizedBox(width: 8),
                Text(
                  '播放统计信息',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white24, height: 16),
            ...stats.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        e.key,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        e.value,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
