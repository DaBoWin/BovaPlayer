import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../features/media_library/models/media_source.dart';
import '../player_window/desktop_player_window.dart';

class EmbyQuickPlayException implements Exception {
  const EmbyQuickPlayException(this.message);

  final String message;

  @override
  String toString() => message;
}

class EmbyQuickPlayService {
  EmbyQuickPlayService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  Future<PlayerLaunchMode> play({
    required BuildContext context,
    required MediaSource source,
    required String itemId,
    required String fallbackTitle,
  }) async {
    final session = await _resolveSession(source);
    final item = await _fetchItemDetails(session, itemId);
    final playableItem = await _resolvePlayableItem(session, item);
    final playableItemId = playableItem['Id']?.toString() ?? itemId;
    final title = _buildFullTitle(playableItem, fallbackTitle);
    final startData = await _loadSavedPosition(playableItemId);
    Map<String, dynamic> playbackInfo = const {};
    try {
      playbackInfo = await _fetchPlaybackInfo(
        session,
        playableItemId,
        startTimeTicks: startData.startTimeTicks,
      );
    } on EmbyQuickPlayException catch (error) {
      // Some Emby servers reject PlaybackInfo for quick-play requests.
      // Fall back to a basic stream URL instead of blocking playback entirely.
      print('[EmbyQuickPlayService] $error, fallback to basic stream URL');
    }
    final playbackUrl = _resolvePlaybackUrl(
      playbackInfo,
      session,
      playableItemId,
      startTimeTicks: startData.startTimeTicks,
    );

    if (playbackUrl == null || playbackUrl.isEmpty) {
      throw const EmbyQuickPlayException('无法获取播放地址');
    }

    if (!context.mounted) {
      throw const EmbyQuickPlayException('页面已关闭，无法继续播放');
    }

    return DesktopPlayerLauncher.openPlayer(
      context: context,
      url: playbackUrl,
      title: title,
      httpHeaders: _buildPlaybackHeaders(session.accessToken),
      subtitles: _extractSubtitles(playableItem, session),
      itemId: playableItemId,
      serverUrl: session.serverUrl,
      accessToken: session.accessToken,
      userId: session.userId,
      startPosition: startData.position,
      startTimeTicks: startData.startTimeTicks,
    );
  }

  Future<_EmbySession> _resolveSession(MediaSource source) async {
    if ((source.accessToken?.isNotEmpty ?? false) &&
        (source.userId?.isNotEmpty ?? false)) {
      return _EmbySession(
        serverUrl: _normalizeServerUrl(source.url),
        username: source.username,
        password: source.password,
        accessToken: source.accessToken!,
        userId: source.userId!,
      );
    }

    final response = await _client
        .post(
          Uri.parse('${source.url}/emby/Users/AuthenticateByName'),
          headers: const {
            'X-Emby-Authorization':
                'MediaBrowser Client="BovaPlayer", Device="Flutter", DeviceId="bova-flutter", Version="1.0.0"',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'Username': source.username,
            'Pw': source.password,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw EmbyQuickPlayException('Emby 认证失败: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final accessToken = data['AccessToken']?.toString();
    final userId = (data['User'] as Map<String, dynamic>?)?['Id']?.toString();
    if (accessToken == null ||
        accessToken.isEmpty ||
        userId == null ||
        userId.isEmpty) {
      throw const EmbyQuickPlayException('Emby 认证结果缺少访问凭据');
    }

    return _EmbySession(
      serverUrl: _normalizeServerUrl(source.url),
      username: source.username,
      password: source.password,
      accessToken: accessToken,
      userId: userId,
    );
  }

  Future<Map<String, dynamic>> _fetchItemDetails(
    _EmbySession session,
    String itemId,
  ) async {
    final response = await _client
        .get(
          Uri.parse(
            '${session.serverUrl}/emby/Users/${session.userId}/Items/$itemId'
            '?Fields=ProductionYear,MediaStreams,ParentIndexNumber,IndexNumber,SeriesName',
          ),
          headers: _headers(session.accessToken),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      throw EmbyQuickPlayException(
        '获取 Emby 条目详情失败: ${response.statusCode}',
      );
    }

    return Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<Map<String, dynamic>> _resolvePlayableItem(
    _EmbySession session,
    Map<String, dynamic> item,
  ) async {
    final type = item['Type']?.toString();
    if (type != 'Series') {
      return item;
    }

    final seriesId = item['Id']?.toString();
    if (seriesId == null || seriesId.isEmpty) {
      return item;
    }

    final episode = await _fetchFirstPlayableEpisode(session, seriesId);
    return episode ?? item;
  }

  Future<Map<String, dynamic>?> _fetchFirstPlayableEpisode(
    _EmbySession session,
    String seriesId,
  ) async {
    final uri = Uri.parse(
      '${session.serverUrl}/emby/Shows/$seriesId/Episodes'
      '?UserId=${session.userId}'
      '&Fields=ProductionYear,MediaStreams,ParentIndexNumber,IndexNumber,SeriesName'
      '&IsMissing=false'
      '&Limit=1',
    );
    final response = await _client
        .get(uri, headers: _headers(session.accessToken))
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      return null;
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    final items = (data is Map<String, dynamic> ? data['Items'] : null);
    if (items is List && items.isNotEmpty) {
      final first = items.first;
      if (first is Map<String, dynamic>) {
        return first;
      }
      if (first is Map) {
        return first.cast<String, dynamic>();
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> _fetchPlaybackInfo(
    _EmbySession session,
    String itemId, {
    int? startTimeTicks,
  }) async {
    final playbackInfoUri = Uri.parse(
      '${session.serverUrl}/emby/Items/$itemId/PlaybackInfo'
      '?UserId=${session.userId}&api_key=${session.accessToken}',
    );
    final headers = {
      'Content-Type': 'application/json',
      ..._headers(session.accessToken),
    };
    final requestBody = {
      'DeviceProfile': {
        'MaxStreamingBitrate': 120000000,
        'MaxStaticBitrate': 100000000,
        'MusicStreamingTranscodingBitrate': 384000,
        'DirectPlayProfiles': [
          {
            'Container': 'mp4,m4v,mkv,avi,mov,wmv,asf,webm,flv,ts',
            'Type': 'Video',
            'VideoCodec': 'h264,hevc,vp8,vp9,av1,mpeg4,mpeg2video',
            'AudioCodec': 'aac,mp3,ac3,flac,opus,vorbis,pcm',
          },
        ],
        'TranscodingProfiles': [
          {
            'Container': 'ts',
            'Type': 'Audio',
            'AudioCodec': 'aac',
            'Protocol': 'hls',
            'Context': 'Streaming',
          },
          {
            'Container': 'ts',
            'Type': 'Video',
            'AudioCodec': 'aac',
            'VideoCodec': 'h264,hevc',
            'Protocol': 'hls',
            'Context': 'Streaming',
          },
        ],
        'ContainerProfiles': const [],
        'CodecProfiles': const [],
        'SubtitleProfiles': const [
          {'Format': 'srt', 'Method': 'External'},
          {'Format': 'ass', 'Method': 'External'},
          {'Format': 'vtt', 'Method': 'External'},
        ],
      },
      if (startTimeTicks != null) 'StartTimeTicks': startTimeTicks,
    };

    http.Response response = await _client
        .post(
          playbackInfoUri,
          headers: headers,
          body: jsonEncode(requestBody),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode >= 500) {
      response = await _client
          .post(
            playbackInfoUri,
            headers: headers,
            body: jsonEncode({
              if (startTimeTicks != null) 'StartTimeTicks': startTimeTicks,
            }),
          )
          .timeout(const Duration(seconds: 10));
    }

    if (response.statusCode != 200) {
      throw EmbyQuickPlayException(
        '获取 Emby 播放信息失败: ${response.statusCode}',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  String? _resolvePlaybackUrl(
    Map<String, dynamic> playbackInfo,
    _EmbySession session,
    String itemId, {
    int? startTimeTicks,
  }) {
    final mediaSources = playbackInfo['MediaSources'];
    if (mediaSources is List && mediaSources.isNotEmpty) {
      final mediaSource = Map<String, dynamic>.from(
        mediaSources.first as Map,
      );
      final mediaSourceId = mediaSource['Id']?.toString();
      final extStartTime =
          startTimeTicks == null ? '' : '&StartTimeTicks=$startTimeTicks';

      final directStreamUrl = mediaSource['DirectStreamUrl']?.toString();
      if (directStreamUrl != null && directStreamUrl.isNotEmpty) {
        var url = directStreamUrl.startsWith('http')
            ? directStreamUrl
            : '${session.serverUrl}$directStreamUrl';
        if (url.contains('Static=true')) {
          url = url.replaceAll('Static=true', 'Static=false');
        }
        if (startTimeTicks != null && !url.contains('StartTimeTicks=')) {
          url += extStartTime;
        }
        return url;
      }

      final transcodingUrl = mediaSource['TranscodingUrl']?.toString();
      if (mediaSource['SupportsTranscoding'] == true &&
          transcodingUrl != null &&
          transcodingUrl.isNotEmpty) {
        return transcodingUrl.startsWith('http')
            ? transcodingUrl
            : '${session.serverUrl}$transcodingUrl';
      }

      final path = mediaSource['Path']?.toString();
      if (path != null && path.startsWith('http')) {
        return path;
      }

      if (mediaSource['SupportsDirectPlay'] == true &&
          mediaSourceId != null &&
          mediaSourceId.isNotEmpty) {
        return '${session.serverUrl}/emby/Videos/$itemId/stream'
            '?MediaSourceId=$mediaSourceId&Static=false'
            '&api_key=${session.accessToken}$extStartTime';
      }

      if (mediaSource['SupportsDirectStream'] == true &&
          mediaSourceId != null &&
          mediaSourceId.isNotEmpty) {
        final container = mediaSource['Container']?.toString() ?? 'mkv';
        return '${session.serverUrl}/emby/Videos/$itemId/stream.$container'
            '?MediaSourceId=$mediaSourceId'
            '&api_key=${session.accessToken}$extStartTime';
      }
    }

    return '${session.serverUrl}/emby/Videos/$itemId/stream'
        '?api_key=${session.accessToken}';
  }

  List<Map<String, String>> _extractSubtitles(
    Map<String, dynamic> item,
    _EmbySession session,
  ) {
    final mediaStreams = item['MediaStreams'];
    if (mediaStreams is! List) {
      return const [];
    }

    final itemId = item['Id']?.toString();
    if (itemId == null || itemId.isEmpty) {
      return const [];
    }

    final subtitles = <Map<String, String>>[];
    for (final stream in mediaStreams) {
      if (stream is! Map || stream['Type'] != 'Subtitle') {
        continue;
      }

      final index = stream['Index'];
      if (index == null) {
        continue;
      }

      final language = stream['Language']?.toString() ??
          stream['DisplayLanguage']?.toString() ??
          'Unknown';
      final title = stream['DisplayTitle']?.toString() ?? language;
      final isExternal = stream['IsExternal'] as bool? ?? false;
      String? subtitleUrl;

      if (isExternal && stream['DeliveryUrl'] != null) {
        subtitleUrl = stream['DeliveryUrl'].toString();
        if (!subtitleUrl.startsWith('http')) {
          subtitleUrl = '${session.serverUrl}$subtitleUrl';
        }
      } else {
        subtitleUrl =
            '${session.serverUrl}/Videos/$itemId/$itemId/Subtitles/$index/Stream.srt'
            '?api_key=${session.accessToken}';
      }

      subtitles.add({
        'title': title,
        'url': subtitleUrl,
        'language': language,
      });
    }

    return subtitles;
  }

  String _buildFullTitle(Map<String, dynamic> item, String fallbackTitle) {
    final name = item['Name']?.toString() ?? fallbackTitle;
    final type = item['Type']?.toString();

    if (type == 'Episode') {
      final seriesName = item['SeriesName']?.toString() ?? name;
      final season = item['ParentIndexNumber'];
      final episode = item['IndexNumber'];
      if (season != null && episode != null) {
        final seasonStr = season.toString().padLeft(2, '0');
        final episodeStr = episode.toString().padLeft(2, '0');
        return '$seriesName S${seasonStr}E$episodeStr';
      }
      return seriesName;
    }

    if (type == 'Movie' && item['ProductionYear'] != null) {
      return '$name (${item['ProductionYear']})';
    }

    return name;
  }

  Future<_SavedStartData> _loadSavedPosition(String itemId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedSeconds = prefs.getInt('play_position_$itemId');
      if (savedSeconds != null && savedSeconds > 5) {
        return _SavedStartData(
          position: Duration(seconds: savedSeconds),
          startTimeTicks: savedSeconds * 10000000,
        );
      }
    } catch (_) {}

    return const _SavedStartData();
  }

  Map<String, String> _headers(String accessToken) => {
        'X-Emby-Authorization':
            'MediaBrowser Client="BovaPlayer", Device="Flutter", DeviceId="bova-flutter", Version="1.0.0", Token="$accessToken"',
        'Content-Type': 'application/json',
      };

  Map<String, String> _buildPlaybackHeaders(String accessToken) => {
        'X-Emby-Authorization':
            'MediaBrowser Client="BovaPlayer", Device="Flutter", DeviceId="bova-flutter", Version="1.0.0", Token="$accessToken"',
      };

  String _normalizeServerUrl(String url) {
    var normalized = url.trim();
    if (url.contains(':443')) {
      normalized = url.replaceAll(':443', '');
    }
    return normalized.endsWith('/')
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
  }
}

class _EmbySession {
  const _EmbySession({
    required this.serverUrl,
    required this.username,
    required this.password,
    required this.accessToken,
    required this.userId,
  });

  final String serverUrl;
  final String username;
  final String password;
  final String accessToken;
  final String userId;
}

class _SavedStartData {
  const _SavedStartData({
    this.position,
    this.startTimeTicks,
  });

  final Duration? position;
  final int? startTimeTicks;
}
