import 'dart:io';
import 'package:flutter/material.dart';
import 'exoplayer_page.dart';
import 'media_kit_player_page.dart';

/// 统一播放器入口
/// Android 使用 ExoPlayer，其他平台使用 media_kit
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
  
  @override
  Widget build(BuildContext context) {
    // Android 使用 ExoPlayer，其他平台使用 media_kit
    if (Platform.isAndroid) {
      print('[UnifiedPlayer] 使用 ExoPlayer (Android)');
      return ExoPlayerPage(
        url: url,
        title: title,
        httpHeaders: httpHeaders,
        subtitles: subtitles,
        itemId: itemId,
        serverUrl: serverUrl,
        accessToken: accessToken,
        userId: userId,
      );
    } else {
      print('[UnifiedPlayer] 使用 media_kit (${Platform.operatingSystem})');
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
}
