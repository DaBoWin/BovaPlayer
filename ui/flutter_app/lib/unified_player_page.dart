import 'dart:io';
import 'package:flutter/material.dart';
import 'media_kit_player_page.dart';

/// 统一播放器入口
/// 所有平台统一使用 media_kit (基于 libmpv)
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
    // 所有平台统一使用 media_kit
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
