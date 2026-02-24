import 'dart:io';
import 'package:flutter/material.dart';
import 'media_kit_player_page.dart';
import 'better_player_page.dart'; // ExoPlayer (Android) / AVPlayer (iOS/Mac)
import 'mpv_android_player_page.dart'; // MPV Android (完整 FFmpeg 支持)
import 'mdk_player_page.dart'; // MDK Player (fvp)

/// 统一播放器入口
/// 混合多核架构：
/// - Android：智能选择
///   1. 简单格式（MP4/H.264/AAC）→ ExoPlayer（省电）
///   2. 复杂格式（MKV/HEVC/TrueHD/PGS）→ mpv-android（兼容性）
///   3. 最后备选 → Media Kit MPV（软件解码）
/// - macOS/Windows：默认 MDK/MPV 以获取最佳 4K HDR 效果
/// - iOS：普通格式 AVPlayer，高难度格式 MDK
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
  
  /// 判断是否是简单格式（ExoPlayer 可以高效处理）
  bool _isSimpleFormat(String videoUrl) {
    final lowerCaseUrl = videoUrl.toLowerCase();
    final pathWithoutQuery = lowerCaseUrl.split('?').first;
    
    // 简单容器格式
    if (pathWithoutQuery.endsWith('.mp4') || 
        pathWithoutQuery.endsWith('.mov') || 
        pathWithoutQuery.endsWith('.m4v')) {
      return true;
    }
    
    // 或者从 URL 参数判断
    if (lowerCaseUrl.contains('container=mp4') || 
        lowerCaseUrl.contains('container=mov')) {
      return true;
    }
    
    return false;
  }
  
  /// 判断是否包含复杂音频格式（需要 mpv-android）
  bool _hasComplexAudio() {
    // 从 URL 或其他元数据判断
    // 这里可以通过 MediaSource 信息来判断
    // 暂时返回 false，实际使用时需要从 Emby API 获取
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Android 智能选择策略
    if (Platform.isAndroid) {
      // 1. 简单格式优先使用 ExoPlayer（省电、性能好）
      if (_isSimpleFormat(url)) {
        print('[UnifiedPlayer] Android 使用 ExoPlayer 播放简单格式');
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
      
      // 2. 复杂格式使用 mpv-android（完整 FFmpeg 支持）
      print('[UnifiedPlayer] Android 使用 mpv-android 播放复杂格式');
      return MpvAndroidPlayerPage(
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
    if (Platform.isIOS && _isSimpleFormat(url)) {
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

    // 后备方案：Media Kit
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

