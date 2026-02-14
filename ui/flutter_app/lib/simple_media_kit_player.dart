import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// 简化版 media_kit 播放器，用于测试
class SimpleMediaKitPlayer extends StatefulWidget {
  final String url;
  final String title;
  final Map<String, String>? httpHeaders;
  
  const SimpleMediaKitPlayer({
    super.key,
    required this.url,
    required this.title,
    this.httpHeaders,
  });
  
  @override
  State<SimpleMediaKitPlayer> createState() => _SimpleMediaKitPlayerState();
}

class _SimpleMediaKitPlayerState extends State<SimpleMediaKitPlayer> {
  late final Player player;
  late final VideoController controller;
  
  @override
  void initState() {
    super.initState();
    
    // 创建播放器，配置 MPV 参数支持 HTTPS
    player = Player(
      configuration: PlayerConfiguration(
        title: 'BovaPlayer',
        // 允许所有协议
        protocolWhitelist: const ['http', 'https', 'file', 'tcp', 'tls'],
        // 启用调试日志，方便排查 HTTPS / TLS 问题
        logLevel: MPVLogLevel.warn,
      ),
    );
    // 使用软件渲染以确保兼容性（避免黑屏）
    controller = VideoController(
      player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: false, // 禁用以避免黑屏
      ),
    );
    
    // 配置 mpv TLS 选项（修复 HTTPS 播放）
    _configureMpvOptions();
    
    // 监听状态
    player.stream.error.listen((error) {
      print('[SimplePlayer] 错误: $error');
    });
    
    player.stream.width.listen((width) {
      print('[SimplePlayer] 宽度: $width');
    });
    
    player.stream.height.listen((height) {
      print('[SimplePlayer] 高度: $height');
    });
    
    player.stream.duration.listen((duration) {
      print('[SimplePlayer] 时长: $duration');
    });
    
    player.stream.playing.listen((playing) {
      print('[SimplePlayer] 播放中: $playing');
    });
    
    player.stream.buffering.listen((buffering) {
      print('[SimplePlayer] 缓冲中: $buffering');
    });
    
    _init();
  }
  
  /// 配置 mpv 底层选项以支持 HTTPS 自签名证书
  Future<void> _configureMpvOptions() async {
    try {
      final nativePlayer = player.platform;
      if (nativePlayer != null) {
        // 1. 禁用 TLS 证书验证
        await (nativePlayer as dynamic).setProperty('tls-verify', 'no');
        await (nativePlayer as dynamic).setProperty('tls-ca-file', '');
        
        // 2. 优化网络和缓冲配置
        await (nativePlayer as dynamic).setProperty('user-agent', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
        await (nativePlayer as dynamic).setProperty('cache', 'yes');
        await (nativePlayer as dynamic).setProperty('demuxer-max-bytes', '50000000');
        await (nativePlayer as dynamic).setProperty('demuxer-max-back-bytes', '20000000');
        await (nativePlayer as dynamic).setProperty('demuxer-readahead-secs', '1');
        await (nativePlayer as dynamic).setProperty('cache-pause-initial', 'no');
        await (nativePlayer as dynamic).setProperty('cache-pause-wait', '0');
        await (nativePlayer as dynamic).setProperty('force-seekable', 'yes'); 
        await (nativePlayer as dynamic).setProperty('msg-level', 'all=v');
        await (nativePlayer as dynamic).setProperty('network-timeout', '60'); 
        
        // 3. 音频解码配置 - 强制使用 FFmpeg 解码器
        await (nativePlayer as dynamic).setProperty('ad', 'lavc:truehd'); // 指定使用 libavcodec 的 truehd 解码器
        await (nativePlayer as dynamic).setProperty('ad-lavc-downmix', 'no');
        await (nativePlayer as dynamic).setProperty('audio-channels', 'auto');
        await (nativePlayer as dynamic).setProperty('audio-samplerate', '0');
        
        // 4. 硬件解码配置
        await (nativePlayer as dynamic).setProperty('hwdec', 'auto-copy');
        await (nativePlayer as dynamic).setProperty('vo', 'libmpv');
        
        print('[SimplePlayer] 已配置 mpv: TLS=no, Cache=yes, Audio=lavc:truehd, hwdec=auto-copy');
        
        if (widget.httpHeaders != null && widget.httpHeaders!.isNotEmpty) {
           print('[SimplePlayer] HTTP headers 将使用 Media 构造函数传递');
        }
      }
    } catch (e) {
      print('[SimplePlayer] 配置 mpv 选项失败: $e');
      print('[SimplePlayer] 这可能意味着 media_kit 打包的 MPV 不支持 TrueHD');
      print('[SimplePlayer] 建议：使用音频转码或选择其他音轨');
    }
  }
  
  Future<void> _init() async {
    try {
      print('[SimplePlayer] 打开: ${widget.url}');
      // 使用 Media 构造函数传递 HTTP headers (官方用法)
      await player.open(
        Media(
          widget.url,
          httpHeaders: widget.httpHeaders,
        ),
      );
      await player.play();
      print('[SimplePlayer] 播放开始');
    } catch (e, stack) {
      print('[SimplePlayer] 初始化失败: $e');
      print('[SimplePlayer] 堆栈: $stack');
    }
  }
  
  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black,
      ),
      body: Center(
        child: Video(
          controller: controller,
          controls: MaterialDesktopVideoControls, // 使用默认控制器
        ),
      ),
    );
  }
}
