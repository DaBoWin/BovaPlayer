import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:fvp/fvp.dart'; // MDK plugin
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:io' show Platform;
import 'package:window_manager/window_manager.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// 弹幕功能
import 'features/danmaku/controllers/danmaku_controller.dart';
import 'features/danmaku/widgets/danmaku_view.dart';
import 'features/danmaku/widgets/danmaku_settings_panel.dart';


class MdkPlayerPage extends StatefulWidget {
  final String url;
  final String title;
  final Map<String, String>? httpHeaders;
  final List<Map<String, String>>? subtitles;
  final String? itemId;
  final String? serverUrl;
  final String? accessToken;
  final String? userId;
  final bool isSubWindow;
  final Duration? startPosition;  // 起始播放位置（用于显示，不用于 seek）
  final int? startTimeTicks;  // URL 中的 StartTimeTicks 值（用于时间轴校正）
  
  const MdkPlayerPage({
    super.key,
    required this.url,
    required this.title,
    this.httpHeaders,
    this.subtitles,
    this.itemId,
    this.serverUrl,
    this.accessToken,
    this.userId,
    this.isSubWindow = false,
    this.startPosition,
    this.startTimeTicks,
  });
  
  @override
  State<MdkPlayerPage> createState() => _MdkPlayerPageState();
}

class _MdkPlayerPageState extends State<MdkPlayerPage> {
  VideoPlayerController? _controller;
  static const _trafficLightsChannel = MethodChannel('com.bovaplayer/traffic_lights');
  static const _networkSpeedChannel = MethodChannel('com.bovaplayer/network_speed');
  static bool _mdkInitialized = false;  // 全局标记，避免重复初始化
  
  // 弹幕控制器
  late DanmakuController _danmakuController;
  
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
  bool _isDragging = false;
  double _dragPosition = 0;
  int _selectedTextTrack = -1; 
  List<Map<String, dynamic>> _textTracks = [];
  
  // 手势控制相关
  double _brightness = 0.5;
  double _volume = 0.5;
  bool _showBrightnessIndicator = false;
  bool _showVolumeIndicator = false;
  bool _showSeekIndicator = false;
  String _seekIndicatorText = '';
  Timer? _indicatorTimer;
  
  // 缓冲指示器相关
  bool _forceShowBuffering = false;  // 强制显示缓冲指示器（确保用户能看到）
  Timer? _bufferingTimer;
  
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
    
    // 初始化弹幕控制器
    _danmakuController = DanmakuController();
    
    // 只初始化一次 MDK 配置（全局生效）
    if (!_mdkInitialized) {
      registerWith(options: {
        // macOS 硬件解码优先（VideoToolbox for HEVC/H264/Dolby Vision）
        'video.decoders': ['VT', 'FFmpeg'],  // VideoToolbox 优先，FFmpeg 备用
        
        // 缓冲配置 - 针对杜比视界等超高码率视频优化
        'buffer': '150000+4000000',  // 最小150MB，最大4GB（更激进的缓冲）
        'buffer.ranges': 64,  // 增加到64个缓冲范围（支持更多并发分段）
        'buffer.drop': 0,  // 不丢弃缓冲数据
        
        // 网络配置 - 多线程下载优化
        'demux.buffer.ranges': 64,  // 增加解复用缓冲范围到64
        'demux.buffer.protocols': 'http,https,rtmp,rtsp',
        'avio.protocol_whitelist': 'file,http,https,tcp,tls',
        'avio.reconnect': 1,
        'avio.reconnect_streamed': 1,
        'avio.reconnect_delay_max': 1,  // 1秒重连延迟（更快恢复）
        'avio.http_persistent': 1,  // 持久连接
        'avio.multiple_requests': 1,  // 允许多个请求
        'avio.seekable': 1,
        
        // HTTP 多线程下载配置 - 关键优化
        'avformat.http_multiple': 4,  // 4个并发连接下载（多线程）
        'avformat.http_seekable': 1,  // 支持 HTTP Range 请求
        
        // HTTP Range 请求配置 - 优化高码率流
        'avformat.fflags': '+fastseek+discardcorrupt+genpts',
        'avformat.seek2any': 1,
        'avformat.skip_initial_bytes': 0,
        
        // TCP 优化 - 提升网络吞吐量
        'avio.tcp_nodelay': 0,  // 允许 TCP 缓冲（Nagle算法），提高吞吐量
        'avio.listen_timeout': 5000000,  // 5秒超时
        'avio.rw_timeout': 10000000,  // 10秒读写超时
        
        // 线程配置 - 充分利用多核处理器
        'threads': 16,  // 增加到16线程（解码+网络）
        
        // 预加载配置 - 激进预读
        'avformat.fpsprobesize': 0,
        'avformat.analyzeduration': 5000000,  // 5秒分析
        'avformat.probesize': 100000000,  // 100MB探测（更大的探测窗口）
        'avformat.max_interleave_delta': 0,
        
        // 禁用低延迟模式 - 高码率需要更多缓冲
        'lowLatency': 0,
        
        // 预读策略 - 激进缓冲
        'avformat.max_delay': 5000000,  // 5秒最大延迟
        
        // 日志级别 - 完全关闭所有日志
        'logLevel': 'Off',
        'MDK_LOG': '0',  // 环境变量方式关闭日志
      });
      _mdkInitialized = true;
      print('[播放器] ✅ MDK 初始化完成（日志已关闭）');
    }

    _loadSavedPosition();
    _initializePlayer();
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
    _speedTimer = Timer.periodic(const Duration(seconds: 2), (_) => _updateNetworkSpeed());  // 改为2秒更新一次
  }

  Future<void> _initializePlayer() async {
    try {
      print('[播放器] 🎬 初始化播放器');
      print('[播放器] 📺 URL: ${widget.url}');
      
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
        httpHeaders: widget.httpHeaders ?? {},
        videoPlayerOptions: VideoPlayerOptions(
          allowBackgroundPlayback: false,
          mixWithOthers: false,
        ),
      );
      
      // Use FVP to inject MDK backend to video_player
      await _controller!.initialize();
      
      _controller!.addListener(() {
        if (mounted) {
          // 不再打印缓冲日志
          setState(() {});
        }
      });
      
      print('[播放器] ✅ 初始化成功');
      
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
      
      // 检查 URL 是否包含 StartTimeTicks
      if (widget.url.contains('StartTimeTicks=') && widget.startTimeTicks != null) {
        print('[播放器] 📍 URL 包含 StartTimeTicks，服务器将从 ${widget.startPosition != null ? _formatDuration(widget.startPosition!) : "指定位置"} 开始发送数据');
        
        // 显示缓冲指示器
        setState(() => _forceShowBuffering = true);
        
        // 开始播放
        await _controller!.play();
        
        // 等待初始缓冲（2-3秒）
        await Future.delayed(const Duration(milliseconds: 2000));
        
        // 检查是否真的在播放
        final startPos = _controller!.value.position.inSeconds;
        await Future.delayed(const Duration(milliseconds: 500));
        final endPos = _controller!.value.position.inSeconds;
        
        if ((endPos - startPos).abs() > 0) {
          print('[播放器] ✅ 初始缓冲完成，开始播放');
          setState(() => _forceShowBuffering = false);
        } else {
          // 还在缓冲，继续监控
          _startPlaybackMonitor();
        }
      } else {
        // 显示缓冲指示器
        setState(() => _forceShowBuffering = true);
        
        // 开始播放
        await _controller!.play();
        
        // 等待初始缓冲（2-3秒）
        await Future.delayed(const Duration(milliseconds: 2000));
        
        // 检查是否真的在播放
        final startPos = _controller!.value.position.inSeconds;
        await Future.delayed(const Duration(milliseconds: 500));
        final endPos = _controller!.value.position.inSeconds;
        
        if ((endPos - startPos).abs() > 0) {
          print('[播放器] ✅ 初始缓冲完成，开始播放');
          setState(() => _forceShowBuffering = false);
        } else {
          // 还在缓冲，继续监控
          _startPlaybackMonitor();
        }
        
        // 检查是否需要恢复播放位置（通过 seek）
        if (_savedPosition != null && _savedPosition!.inSeconds > 5) {
          // 显示对话框让用户选择
          await _showResumeDialog();
        }
      }
      
      // 异步加载字幕和启动定时器（不阻塞播放）
      Future.microtask(() {
        _loadTextTracks();
        _loadDanmaku(); // 加载弹幕
        _startHideTimer();
        _startSavePositionTimer();
        _reportPlaybackStart();
        _startReportProgressTimer();
      });
    } catch (e) {
      print('[播放器] ❌ 初始化失败: $e');
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = '播放失败: $e';
        });
      }
    }
  }

  void _loadTextTracks() {
    _textTracks.clear();
    
    // 确保已初始化再调用 ext API
    if (_controller == null || !_controller!.value.isInitialized) return;
    
    // 1. 获取内嵌字幕
    try {
      final mediaInfo = _controller?.getMediaInfo();
      if (mediaInfo?.subtitle != null) {
        for (int i = 0; i < mediaInfo!.subtitle!.length; i++) {
          final stream = mediaInfo.subtitle![i];
          _textTracks.add({
            'index': _textTracks.length,
            'title': stream.metadata['title'] ?? stream.metadata['language'] ?? '内置字幕 ${i + 1}',
            'language': stream.metadata['language'] ?? 'und',
            'is_internal': true,
            'mdk_id': i,
          });
        }
      }
    } catch (e) {
      // 静默失败
    }

    // 2. 获取外挂字幕
    if (widget.subtitles != null && widget.subtitles!.isNotEmpty) {
      for (int i = 0; i < widget.subtitles!.length; i++) {
        final subtitle = widget.subtitles![i];
        
        // 查重：防止重复加载
        bool exists = _textTracks.any((t) => t['url'] == subtitle['url']);
        if (!exists) {
          _textTracks.add({
            'index': _textTracks.length,
            'title': subtitle['title'] ?? '外挂字幕 ${i + 1}',
            'language': subtitle['language'] ?? 'und',
            'url': subtitle['url'],
            'is_internal': false,
          });
        }
      }
    }
  }
  
  /// 加载弹幕
  Future<void> _loadDanmaku() async {
    try {
      // 检查用户是否为 Pro 用户
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user');
      bool isPro = false;
      
      if (userJson != null) {
        try {
          final userData = jsonDecode(userJson);
          final accountType = userData['account_type'] as String?;
          isPro = accountType == 'pro' || accountType == 'lifetime';
        } catch (e) {
          print('[播放器] 解析用户信息失败: $e');
        }
      }
      
      if (!isPro) {
        print('[播放器] 弹幕功能仅限 Pro 用户使用');
        // 禁用弹幕
        _danmakuController.updateConfig(_danmakuController.config.copyWith(enabled: false));
        return;
      }
      
      final success = await _danmakuController.loadDanmakuByFileName(widget.title);
      if (!success && mounted) {
        // 如果加载失败，可以选择显示提示（可选）
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text('未找到弹幕')),
        // );
      }
    } catch (e) {
      print('[播放器] 加载弹幕异常: $e');
    }
  }

  Future<void> _loadSavedPosition() async {
    // 如果构造函数已经提供了起始位置，优先使用它
    if (widget.startPosition != null) {
      _savedPosition = widget.startPosition;
      return;
    }
    
    if (widget.itemId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'play_position_${widget.itemId}';
      final savedSeconds = prefs.getInt(key);
      if (savedSeconds != null && savedSeconds > 0) {
        _savedPosition = Duration(seconds: savedSeconds);
      }
    } catch (e) {
      print('[播放器] ⚠️  加载播放位置失败: $e');
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
        return;
      }
      
      if (position.inSeconds > 5) {
        final prefs = await SharedPreferences.getInstance();
        final key = 'play_position_${widget.itemId}';
        await prefs.setInt(key, position.inSeconds);
      }
    } catch (e) {
      // 静默失败
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
        title: const Text('继续播放', style: TextStyle(color: Colors.white)),
        content: Text(
          '上次播放到 ${_formatDuration(_savedPosition!)}\n\n'
          '继续播放需要缓冲，可能需要等待一段时间。\n'
          '建议选择"从头开始"以获得更流畅的体验。',
          style: const TextStyle(color: Colors.white70)
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context, false),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
            ),
            child: const Text('从头开始（推荐）', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('继续播放', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
    
    if (resume == true && _savedPosition != null) {
      // 显示加载提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('正在跳转，请稍候...'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      
      // 执行 seek
      await _controller!.seekTo(_savedPosition!);
    }
  }

  void _startPlaybackMonitor() {
    // 监控播放是否卡顿
    var lastPosition = -1;
    var stuckCount = 0;
    
    _bufferingTimer?.cancel();
    _bufferingTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted || _controller == null) {
        timer.cancel();
        _bufferingTimer = null;
        return;
      }
      
      final currentPos = _controller!.value.position.inSeconds;
      
      if (lastPosition == -1) {
        // 第一次检查
        lastPosition = currentPos;
        return;
      }
      
      // 检查位置是否在变化
      if ((currentPos - lastPosition).abs() > 0) {
        // 正在播放
        if (_forceShowBuffering) {
          setState(() => _forceShowBuffering = false);
        }
        timer.cancel();
        _bufferingTimer = null;
      } else {
        // 卡住了
        stuckCount++;
        if (stuckCount >= 2 && !_forceShowBuffering) {
          // 卡住超过 1 秒
          setState(() => _forceShowBuffering = true);
        }
      }
      
      lastPosition = currentPos;
      // 不设置超时，一直等待直到开始播放
    });
  }

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
    final duration = _controller!.value.duration;
    
    if (duration.inSeconds > 0) {
      // 第一次拖拽时，以当前播放位置为起点
      _seekTargetPosition ??= _controller!.value.position;
      
      // 根据手指滑动距离计算时间偏移（全屏宽度 = 视频总时长）
      final deltaSec = (details.delta.dx / screenWidth) * duration.inSeconds;
      final newSeconds = (_seekTargetPosition!.inSeconds + deltaSec).round().clamp(0, duration.inSeconds);
      _seekTargetPosition = Duration(seconds: newSeconds);
      
      final minutes = newSeconds ~/ 60;
      final seconds = newSeconds % 60;
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
    
    final targetPosition = _seekTargetPosition!;
    _controller!.seekTo(targetPosition);
    _seekTargetPosition = null;
    
    setState(() {
      _showSeekIndicator = false;
    });
    
    // Seek 完成后，监控是否真正开始播放
    _bufferingTimer?.cancel();
    var lastPosition = -1;
    var stuckCount = 0;
    
    _bufferingTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (!mounted || _controller == null) {
        timer.cancel();
        _bufferingTimer = null;
        return;
      }
      
      final currentPos = _controller!.value.position.inSeconds;
      
      if (lastPosition == -1) {
        // 第一次检查，记录初始位置
        lastPosition = currentPos;
        return;
      }
      
      // 检查位置是否在变化（视频是否在播放）
      if ((currentPos - lastPosition).abs() > 0) {
        // 位置在变化，说明正在播放
        if (_forceShowBuffering) {
          setState(() => _forceShowBuffering = false);
        }
        timer.cancel();
        _bufferingTimer = null;
      } else {
        // 位置没变化，说明卡住了
        stuckCount++;
        if (stuckCount >= 2 && !_forceShowBuffering) {
          // 卡住超过 600ms，显示加载动画
          setState(() => _forceShowBuffering = true);
        }
      }
      
      lastPosition = currentPos;
      // 不设置超时，一直等待直到开始播放
    });
  }

  void _startIndicatorTimer() {
    _indicatorTimer?.cancel();
    _indicatorTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() {
        _showBrightnessIndicator = false;
        _showVolumeIndicator = false;
        _showSeekIndicator = false;
      });
    });
  }

  Future<void> _reportPlaybackStart() async {
    if (widget.itemId == null || widget.serverUrl == null || widget.accessToken == null) return;
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
    } catch (e) {
      // 静默失败
    }
  }

  void _startReportProgressTimer() {
    _reportProgressTimer?.cancel();
    _reportProgressTimer = Timer.periodic(const Duration(seconds: 10), (_) => _reportPlaybackProgress());
  }

  Future<void> _reportPlaybackProgress() async {
    if (widget.itemId == null || widget.serverUrl == null || widget.accessToken == null || _playSessionId == null || _controller == null) return;
    try {
      final position = _controller!.value.position;
      final duration = _controller!.value.duration;
      final isPaused = !_controller!.value.isPlaying;
      final positionTicks = position.inMicroseconds * 10;
      
      final url = '${widget.serverUrl}/Sessions/Playing/Progress';
      final body = {
        'ItemId': widget.itemId,
        'PlaySessionId': _playSessionId,
        'CanSeek': true,
        'IsPaused': isPaused,
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
      // 静默失败
    }
  }

  Future<void> _reportPlaybackStopped() async {
    if (widget.itemId == null || widget.serverUrl == null || widget.accessToken == null || _playSessionId == null || _controller == null) return;
    try {
      final position = _controller!.value.position;
      final duration = _controller!.value.duration;
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
      // 静默失败
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
    _bufferingTimer?.cancel();  // 清理缓冲计时器

    _savePlayPosition();
    _reportPlaybackStopped();
    
    // 清理弹幕控制器
    _danmakuController.dispose();

    if (!kIsWeb && Platform.isMacOS) {
      _trafficLightsChannel.invokeMethod('show');
    }

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

  void _updateNetworkSpeed() async {
    if (!mounted || _controller == null || !_controller!.value.isInitialized) return;
    
    try {
      // 在 macOS 上使用系统 API 获取真实网速
      if (Platform.isMacOS) {
        final bytesPerSecond = await _networkSpeedChannel.invokeMethod<double>('getNetworkSpeed');
        if (bytesPerSecond != null && bytesPerSecond > 0 && mounted) {
          setState(() => _networkSpeed = _formatSpeed(bytesPerSecond));
        } else if (mounted && _controller!.value.isBuffering) {
          setState(() => _networkSpeed = '缓冲中...');
        }
        return;
      }
      
      // 其他平台使用原来的估算方法
      final now = DateTime.now();
      final timeDiff = now.difference(_lastSpeedCheck).inSeconds.toDouble();
      if (timeDiff >= 1.0) {
        final currentBuffered = _controller!.value.buffered.isNotEmpty
            ? _controller!.value.buffered.last.end.inMilliseconds
            : 0;
        final bufferDiff = currentBuffered - _lastBufferedPosition;
        if (bufferDiff > 0) {
          // 根据视频分辨率动态估算码率
          final videoSize = _controller!.value.size;
          double estimatedBitrate;
          
          if (videoSize.width >= 3840) {
            // 4K: 15-50 Mbps，取中间值 25 Mbps
            estimatedBitrate = 25000;
          } else if (videoSize.width >= 1920) {
            // 1080p: 5-15 Mbps，取 8 Mbps
            estimatedBitrate = 8000;
          } else if (videoSize.width >= 1280) {
            // 720p: 3-8 Mbps，取 5 Mbps
            estimatedBitrate = 5000;
          } else {
            // SD: 1-3 Mbps，取 2 Mbps
            estimatedBitrate = 2000;
          }
          
          final bufferIncreaseSec = bufferDiff / 1000.0;
          final downloadedBytes = (bufferIncreaseSec * estimatedBitrate * 1000) / 8;
          final bytesPerSecond = downloadedBytes / timeDiff;
          if (bytesPerSecond > 0 && mounted) {
            setState(() => _networkSpeed = _formatSpeed(bytesPerSecond));
          }
        }
        _lastBufferedPosition = currentBuffered;
        _lastSpeedCheck = now;
      }
      if (_controller!.value.isBuffering && mounted) {
        setState(() => _networkSpeed = '缓冲中...');
      }
    } catch (e) {
      if (mounted) setState(() => _networkSpeed = '-- KB/s');
    }
  }

  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 0) return '0 B/s';
    if (bytesPerSecond < 1024) return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    if (bytesPerSecond < 1024 * 1024) return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(2)} MB/s';
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controller?.value.isPlaying == true) {
        setState(() => _showControls = false);
        if (Platform.isAndroid || Platform.isIOS) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        }
        if (Platform.isMacOS) {
          _trafficLightsChannel.invokeMethod('hide');
        }
      }
    });
  }

  void _toggleControls() {
    if (_isLocked) return;
    setState(() => _showControls = !_showControls);

    if (_showControls) {
      if (Platform.isAndroid || Platform.isIOS) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
      if (Platform.isMacOS) {
        _trafficLightsChannel.invokeMethod('show');
      }
      _startHideTimer();
    } else {
      if (Platform.isAndroid || Platform.isIOS) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
      if (Platform.isMacOS) {
        _trafficLightsChannel.invokeMethod('hide');
      }
      _hideTimer?.cancel();
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
    if (_controller == null) return;
    final currentPos = _controller!.value.position;
    final newPos = currentPos + offset;
    final duration = _controller!.value.duration;
    final clampedPos = Duration(
      milliseconds: newPos.inMilliseconds.clamp(0, duration.inMilliseconds)
    );
    
    _controller!.seekTo(clampedPos);
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
      case 'fill': return '填充';
      case 'stretch': return '拉伸';
      case 'fit': default: return '适应';
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
                        ? SizedBox.expand(child: VideoPlayer(_controller!))
                        : AspectRatio(
                            aspectRatio: _controller!.value.aspectRatio,
                            child: VideoPlayer(_controller!),
                          ),
              )
            else if (_isInitializing)
              const Center(child: CircularProgressIndicator(color: Colors.white))
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

            if (_showBrightnessIndicator) _buildBrightnessIndicator(),
            if (_showVolumeIndicator) _buildVolumeIndicator(),
            if (_showSeekIndicator) _buildSeekIndicator(),
            
            // 弹幕层
            if (_controller != null && _controller!.value.isInitialized)
              ListenableBuilder(
                listenable: _danmakuController,
                builder: (context, _) {
                  return DanmakuView(
                    danmakuList: _danmakuController.danmakuList,
                    currentPosition: _controller!.value.position,
                    isPlaying: _controller!.value.isPlaying,
                    config: _danmakuController.config,
                  );
                },
              ),

            if (_showControls && !_isLocked && !_isInitializing && _controller != null)
              _buildControls(),

            // 缓冲加载动画（放在最上层，确保不被遮挡）
            if (_forceShowBuffering || 
                (_controller != null && 
                 _controller!.value.isInitialized && 
                 _controller!.value.isBuffering))
              _buildBufferingIndicator(),

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
    final bool isMacOS = !kIsWeb && Platform.isMacOS;
    return SafeArea(
      child: DragToMoveArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: isMacOS ? 80.0 : 8.0, 
            right: 8.0, 
            top: isMacOS ? 4.0 : 0.0, 
            bottom: 0.0
          ),
          child: SizedBox(
            height: 42.0,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.speed, color: Colors.greenAccent, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        _networkSpeed,
                        style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _currentTime,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
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
          iconSize: 48,
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
    double iconSize = 32,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: iconSize),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildProgressBar() {
    final position = _controller?.value.position ?? Duration.zero;
    final duration = _controller?.value.duration ?? Duration.zero;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Text(
            _isDragging 
                ? _formatDuration(Duration(milliseconds: _dragPosition.toInt()))
                : _formatDuration(position),
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final totalWidth = constraints.maxWidth;
                final maxMs = duration.inMilliseconds.toDouble();
                final currentMs = _isDragging
                    ? _dragPosition
                    : position.inMilliseconds.toDouble();
                final progress = maxMs > 0 ? (currentMs / maxMs).clamp(0.0, 1.0) : 0.0;

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (details) {
                    _hideTimer?.cancel();
                    setState(() {
                      _isDragging = true;
                      // 从当前播放位置开始拖，而不是鼠标点击的位置
                      _dragPosition = position.inMilliseconds.toDouble();
                    });
                  },
                  onHorizontalDragUpdate: (details) {
                    if (maxMs <= 0) return;
                    final delta = details.delta.dx;
                    final msDelta = (delta / totalWidth) * maxMs;
                    setState(() {
                      _dragPosition = (_dragPosition + msDelta).clamp(0.0, maxMs).toDouble();
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    final targetPosition = Duration(milliseconds: _dragPosition.toInt());
                    
                    setState(() {
                      _isDragging = false;
                    });
                    
                    _controller?.seekTo(targetPosition);
                    
                    // Seek 完成后，监控是否真正开始播放
                    _bufferingTimer?.cancel();
                    var lastPosition = -1;
                    var stuckCount = 0;
                    
                    _bufferingTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
                      if (!mounted || _controller == null) {
                        timer.cancel();
                        _bufferingTimer = null;
                        return;
                      }
                      
                      final currentPos = _controller!.value.position.inSeconds;
                      
                      if (lastPosition == -1) {
                        // 第一次检查，记录初始位置
                        lastPosition = currentPos;
                        return;
                      }
                      
                      // 检查位置是否在变化（视频是否在播放）
                      if ((currentPos - lastPosition).abs() > 0) {
                        // 位置在变化，说明正在播放
                        if (_forceShowBuffering) {
                          setState(() => _forceShowBuffering = false);
                        }
                        timer.cancel();
                        _bufferingTimer = null;
                      } else {
                        // 位置没变化，说明卡住了
                        stuckCount++;
                        if (stuckCount >= 2 && !_forceShowBuffering) {
                          // 卡住超过 600ms，显示加载动画
                          setState(() => _forceShowBuffering = true);
                        }
                      }
                      
                      lastPosition = currentPos;
                      // 不设置超时，一直等待直到开始播放
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
          const SizedBox(width: 16),
          Text(
            _formatDuration(duration),
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(
          children: [
            const Spacer(),
            if (_textTracks.isNotEmpty)
              TextButton(
                onPressed: _showSubtitleMenu,
                child: const Text('字幕', style: TextStyle(color: Colors.white, fontSize: 14)),
              ),
            // 弹幕按钮
            ListenableBuilder(
              listenable: _danmakuController,
              builder: (context, _) {
                return TextButton.icon(
                  onPressed: () {
                    _danmakuController.toggleEnabled();
                  },
                  icon: Icon(
                    _danmakuController.config.enabled 
                        ? Icons.chat_bubble 
                        : Icons.chat_bubble_outline,
                    color: _danmakuController.config.enabled 
                        ? Colors.blue 
                        : Colors.white,
                    size: 18,
                  ),
                  label: Text(
                    '弹幕',
                    style: TextStyle(
                      color: _danmakuController.config.enabled 
                          ? Colors.blue 
                          : Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  onLongPress: () {
                    // 长按打开弹幕设置
                    showDialog(
                      context: context,
                      barrierColor: Colors.black54,
                      builder: (context) => GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Material(
                          color: Colors.transparent,
                          child: Center(
                            child: GestureDetector(
                              onTap: () {}, // 阻止点击穿透到背景
                              child: Container(
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width - 80,
                                  maxHeight: MediaQuery.of(context).size.height - 160,
                                ),
                                child: DanmakuSettingsPanel(
                                  controller: _danmakuController,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            TextButton(
              onPressed: _showAspectRatioMenu,
              child: Text(_getAspectRatioLabel(), style: const TextStyle(color: Colors.white, fontSize: 14)),
            ),
            TextButton(
              onPressed: _showSpeedMenu,
              child: Text('${_playbackSpeed}x', style: const TextStyle(color: Colors.white, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
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
    _hideTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // 使用透明背景，依靠 _buildBottomSheetContainer 展示高斯模糊
      isScrollControlled: true,
      builder: (context) {
        return _buildBottomSheetContainer(
          context,
          '字幕选择',
          ListView(
            shrinkWrap: true,
            children: [
              _buildActionItem('关闭字幕', -1, _selectedTextTrack, () {
                setState(() => _selectedTextTrack = -1);
                _controller?.setSubtitleTracks([]); // 禁用所有字幕
                Navigator.pop(context);
              }),
              ..._textTracks.map((track) {
                final index = track['index'];
                final isInternal = track['is_internal'] == true;
                final title = track['title'] ?? '未知语言';
                final displayTitle = isInternal ? '$title (内置)' : '$title (外挂)';
                return _buildActionItem(displayTitle, index, _selectedTextTrack, () {
                  setState(() => _selectedTextTrack = index);
                  if (isInternal) {
                    _controller?.setSubtitleTracks([track['mdk_id']]);
                  } else {
                    final url = track['url'];
                    if (url != null) {
                      _controller?.setExternalSubtitle(url);
                      Future.delayed(const Duration(milliseconds: 200), () {
                        if (mounted) _controller?.setSubtitleTracks([0]);
                      });
                    }
                  }
                  Navigator.pop(context);
                });
              }),
            ],
          ),
        );
      },
    ).then((_) => _startHideTimer());
  }

  void _showAspectRatioMenu() {
    _hideTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _buildBottomSheetContainer(
          context,
          '画面比例',
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildActionItem('适应 (Fit)', 'fit', _aspectRatio, () => _changeAspectRatio('fit')),
              _buildActionItem('拉伸 (Stretch)', 'stretch', _aspectRatio, () => _changeAspectRatio('stretch')),
              _buildActionItem('填充 (Fill)', 'fill', _aspectRatio, () => _changeAspectRatio('fill')),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    ).then((_) => _startHideTimer());
  }

  void _showSpeedMenu() {
    _hideTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _buildBottomSheetContainer(
          context,
          '播放速度',
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildActionItem('0.5x', 0.5, _playbackSpeed, () => _changeSpeed(0.5)),
              _buildActionItem('0.75x', 0.75, _playbackSpeed, () => _changeSpeed(0.75)),
              _buildActionItem('1.0x (正常)', 1.0, _playbackSpeed, () => _changeSpeed(1.0)),
              _buildActionItem('1.25x', 1.25, _playbackSpeed, () => _changeSpeed(1.25)),
              _buildActionItem('1.5x', 1.5, _playbackSpeed, () => _changeSpeed(1.5)),
              _buildActionItem('2.0x', 2.0, _playbackSpeed, () => _changeSpeed(2.0)),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    ).then((_) => _startHideTimer());
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

  Widget _buildBrightnessIndicator() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.brightness_6, color: Colors.white, size: 48),
            const SizedBox(height: 8),
            SizedBox(
              width: 100,
              child: LinearProgressIndicator(
                value: _brightness,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(height: 4),
            Text('${(_brightness * 100).toInt()}%', style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildVolumeIndicator() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _volume == 0 ? Icons.volume_off : (_volume < 0.5 ? Icons.volume_down : Icons.volume_up),
              color: Colors.white,
              size: 48,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 100,
              child: LinearProgressIndicator(
                value: _volume,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(height: 4),
            Text('${(_volume * 100).toInt()}%', style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildSeekIndicator() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fast_forward, color: Colors.white, size: 48),
            const SizedBox(height: 12),
            Text(_seekIndicatorText, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildBufferingIndicator() {
    return const Center(
      child: SizedBox(
        width: 48,
        height: 48,
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 3,
        ),
      ),
    );
  }
}
