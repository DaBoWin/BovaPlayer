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
    // Android 优先使用 BetterPlayer (ExoPlayer) - 省电且性能好
    // 如果播放失败，会在 BetterPlayerPage 内部处理错误并提示用户切换
    if (Platform.isAndroid) {
      print('[UnifiedPlayer] Android 优先使用 BetterPlayer (ExoPlayer)');
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
    
    // iOS 对于简单格式使用原生 AVPlayer
    if (Platform.isIOS && _isNativeSupportedFormat(url)) {
      print('[UnifiedPlayer] iOS 使用 BetterPlayer (AVPlayer) 播放简单格式');
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
    
    // 桌面端和复杂格式使用 MDK
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      print('[UnifiedPlayer] 桌面端使用 MDK 引擎 (${Platform.operatingSystem})');
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

    // iOS 复杂格式使用 Media Kit (MPV)
    if (Platform.isIOS) {
      print('[UnifiedPlayer] iOS 使用 media_kit (MPV) 播放复杂格式');
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

    // 后备方案
    print('[UnifiedPlayer] 使用 fallback media_kit (${Platform.operatingSystem})');
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

