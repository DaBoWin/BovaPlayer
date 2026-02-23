import 'dart:io';
import 'package:flutter/material.dart';
import 'media_kit_player_page.dart';
import 'better_player_page.dart'; // ExoPlayer (Android) / AVPlayer (iOS/Mac)
import 'mdk_player_page.dart'; // MDK Player (fvp)

/// 统一播放器入口
/// 混合多核架构：
/// - macOS/Windows：默认 MDK/MPV 以获取最佳 4K HDR 效果。
/// - Android：根据格式决定；传统 MP4 走原生 ExoPlayer 极致省电，复杂 MKV 或多音轨原盘（TrueHD）走 MDK/MPV。
/// - iOS：普通格式 AVPlayer，高难度格式 MDK。
class UnifiedPlayerPage extends StatelessWidget {
  final String url;
  final String title;
  final Map<String, String>? httpHeaders;
  final List<Map<String, String>>? subtitles;
  final String? itemId;
  final String? serverUrl;
  final String? accessToken;
  final String? userId;
  
  const UnifiedPlayerPage({
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
  
  bool _isNativeSupportedFormat(String videoUrl) {
    final lowerCaseUrl = videoUrl.toLowerCase();
    // 剔除 URL 参数便于判断后缀
    final pathWithoutQuery = lowerCaseUrl.split('?').first;
    
    // 苹果平台能直接硬解且支持原生 HDR 映射的理想容器格式
    if (pathWithoutQuery.endsWith('.mp4') || 
        pathWithoutQuery.endsWith('.mov') || 
        pathWithoutQuery.endsWith('.m4v')) {
      return true;
    }
    
    // 或者直接看是否从 Emby 传来的直链并且标明了 Container=mp4
    if (lowerCaseUrl.contains('container=mp4') || 
        lowerCaseUrl.contains('container=mov')) {
      return true;
    }
    
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if ((Platform.isIOS || Platform.isAndroid) && _isNativeSupportedFormat(url)) {
      print('[UnifiedPlayer] 检测到原生兼容格式，分配给 BetterPlayer (${Platform.operatingSystem})');
      return BetterPlayerPage(
        url: url,
        title: title,
        httpHeaders: httpHeaders,
        subtitles: subtitles,
        itemId: itemId,
        serverUrl: serverUrl,
        accessToken: accessToken,
        userId: userId,
      );
    }
    
    // 对于复杂格式（或桌面端），优先尝试 MDK (fvp)，它对性能和格式支持达到最优平衡
    // 您也可以根据特定条件回退至 media_kit，比如某类流媒体 HLS 测试下来 media_kit 比较好时。这里默认以 MDK 为主。
    if (Platform.isMacOS || Platform.isWindows || Platform.isAndroid || Platform.isIOS || Platform.isLinux) {
      print('[UnifiedPlayer] 分配给 MDK 引擎解码复杂/高画质格式 (${Platform.operatingSystem})');
      return MdkPlayerPage(
        url: url,
        title: title,
        httpHeaders: httpHeaders,
        subtitles: subtitles,
        itemId: itemId,
        serverUrl: serverUrl,
        accessToken: accessToken,
        userId: userId,
      );
    }

    // 后备：强大的跨平台桌面内核方案 mpv (media_kit)
    print('[UnifiedPlayer] 使用 fallback media_kit 解码万能格式 (${Platform.operatingSystem})');
    return MediaKitPlayerPage(
      url: url,
      title: title,
      httpHeaders: httpHeaders,
      subtitles: subtitles,
      itemId: itemId,
      serverUrl: serverUrl,
      accessToken: accessToken,
      userId: userId,
    );
  }
}

