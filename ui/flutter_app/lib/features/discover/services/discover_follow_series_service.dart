import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../media_library/models/media_source.dart';
import '../../media_library/services/media_library_source_service.dart';
import '../services/discover_library_resolver_service.dart';

class DiscoverFollowSeriesState {
  const DiscoverFollowSeriesState({
    required this.isFollowing,
    this.followedAt,
    this.sourceId,
    this.embyItemId,
    this.matchedByTmdbId = false,
    this.hasNewEpisodes = false,
    this.lastCheckedAt,
  });

  final bool isFollowing;
  final DateTime? followedAt;
  final String? sourceId;
  final String? embyItemId;
  final bool matchedByTmdbId;
  final bool hasNewEpisodes;
  final DateTime? lastCheckedAt;

  DiscoverFollowSeriesState copyWith({
    bool? isFollowing,
    DateTime? followedAt,
    String? sourceId,
    String? embyItemId,
    bool? matchedByTmdbId,
    bool? hasNewEpisodes,
    DateTime? lastCheckedAt,
    bool clearSourceId = false,
    bool clearEmbyItemId = false,
    bool clearLastCheckedAt = false,
  }) {
    return DiscoverFollowSeriesState(
      isFollowing: isFollowing ?? this.isFollowing,
      followedAt: followedAt ?? this.followedAt,
      sourceId: clearSourceId ? null : (sourceId ?? this.sourceId),
      embyItemId: clearEmbyItemId ? null : (embyItemId ?? this.embyItemId),
      matchedByTmdbId: matchedByTmdbId ?? this.matchedByTmdbId,
      hasNewEpisodes: hasNewEpisodes ?? this.hasNewEpisodes,
      lastCheckedAt:
          clearLastCheckedAt ? null : (lastCheckedAt ?? this.lastCheckedAt),
    );
  }

  Map<String, dynamic> toJson() => {
        'is_following': isFollowing,
        'followed_at': followedAt?.toIso8601String(),
        'source_id': sourceId,
        'emby_item_id': embyItemId,
        'matched_by_tmdb_id': matchedByTmdbId,
        'has_new_episodes': hasNewEpisodes,
        'last_checked_at': lastCheckedAt?.toIso8601String(),
      };

  factory DiscoverFollowSeriesState.fromJson(Map<String, dynamic> json) {
    return DiscoverFollowSeriesState(
      isFollowing: json['is_following'] == true,
      followedAt: _tryParseDateTime(json['followed_at']?.toString()),
      sourceId: json['source_id']?.toString(),
      embyItemId: json['emby_item_id']?.toString(),
      matchedByTmdbId: json['matched_by_tmdb_id'] == true,
      hasNewEpisodes: json['has_new_episodes'] == true,
      lastCheckedAt: _tryParseDateTime(json['last_checked_at']?.toString()),
    );
  }

  static DateTime? _tryParseDateTime(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}

class DiscoverFollowRefreshResult {
  const DiscoverFollowRefreshResult({
    required this.hasNewEpisodes,
    this.sourceId,
    this.embyItemId,
  });

  final bool hasNewEpisodes;
  final String? sourceId;
  final String? embyItemId;
}

class DiscoverFollowSeriesService {
  DiscoverFollowSeriesService({
    MediaLibrarySourceService? sourceService,
    http.Client? client,
  })  : _sourceService = sourceService ?? MediaLibrarySourceService(),
        _client = client ?? http.Client();

  static const String _storageKey = 'discover_follow_series';

  final MediaLibrarySourceService _sourceService;
  final http.Client _client;

  Future<Map<String, DiscoverFollowSeriesState>> loadStates() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return <String, DiscoverFollowSeriesState>{};
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return <String, DiscoverFollowSeriesState>{};
    }

    return decoded.map<String, DiscoverFollowSeriesState>((key, value) {
      final json = value is Map<String, dynamic>
          ? value
          : value is Map
              ? value.cast<String, dynamic>()
              : <String, dynamic>{};
      return MapEntry(key.toString(), DiscoverFollowSeriesState.fromJson(json));
    });
  }

  Future<void> saveStates(Map<String, DiscoverFollowSeriesState> states) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(
        states.map((key, value) => MapEntry(key, value.toJson())),
      ),
    );
  }

  Future<void> upsertState(String key, DiscoverFollowSeriesState state) async {
    final states = await loadStates();
    states[key] = state;
    await saveStates(states);
  }

  Future<void> removeState(String key) async {
    final states = await loadStates();
    states.remove(key);
    await saveStates(states);
  }

  List<DiscoverLibraryMatch> exactSeriesMatches(
    List<DiscoverLibraryMatch> matches,
  ) {
    return matches.where((match) {
      return match.matchedByTmdbId &&
          match.itemType == 'Series' &&
          match.itemId.isNotEmpty &&
          match.source.type == SourceType.emby;
    }).toList(growable: false);
  }

  Future<DiscoverFollowRefreshResult> refreshState({
    required DiscoverFollowSeriesState state,
    required List<DiscoverLibraryMatch> matches,
  }) async {
    final exactMatches = exactSeriesMatches(matches);
    if (exactMatches.isEmpty) {
      return const DiscoverFollowRefreshResult(hasNewEpisodes: false);
    }

    final prioritizedMatches = _prioritizeMatches(exactMatches, state);
    DiscoverLibraryMatch? fallbackMatch;

    for (final match in prioritizedMatches) {
      fallbackMatch ??= match;
      final hasNewEpisodes = await _hasNewEpisodes(match);
      if (hasNewEpisodes) {
        return DiscoverFollowRefreshResult(
          hasNewEpisodes: true,
          sourceId: match.source.id,
          embyItemId: match.itemId,
        );
      }
    }

    return DiscoverFollowRefreshResult(
      hasNewEpisodes: false,
      sourceId: fallbackMatch?.source.id,
      embyItemId: fallbackMatch?.itemId,
    );
  }

  List<DiscoverLibraryMatch> _prioritizeMatches(
    List<DiscoverLibraryMatch> matches,
    DiscoverFollowSeriesState state,
  ) {
    final prioritized = List<DiscoverLibraryMatch>.from(matches);
    prioritized.sort((left, right) {
      final leftPriority =
          left.source.id == state.sourceId && left.itemId == state.embyItemId;
      final rightPriority =
          right.source.id == state.sourceId && right.itemId == state.embyItemId;
      if (leftPriority == rightPriority) return 0;
      return leftPriority ? -1 : 1;
    });
    return prioritized;
  }

  Future<bool> _hasNewEpisodes(DiscoverLibraryMatch match) async {
    final source = await _ensureAuthorizedSource(match.source);
    if (source == null || source.accessToken == null || source.userId == null) {
      return false;
    }

    final uri = Uri.parse(
      '${source.url}/emby/Shows/${match.itemId}/Episodes',
    ).replace(
      queryParameters: {
        'UserId': source.userId,
        'Fields': 'PremiereDate,DateCreated,UserData',
        'IsMissing': 'false',
        'api_key': source.accessToken,
      },
    );

    try {
      final response = await _client
          .get(uri, headers: _headers(source.accessToken!))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return false;
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final items = decoded is Map<String, dynamic> ? decoded['Items'] : null;
      if (items is! List) {
        return false;
      }

      final now = DateTime.now().toUtc();
      for (final rawItem in items) {
        if (rawItem is! Map) continue;
        final item = rawItem.cast<String, dynamic>();
        final userData = item['UserData'];
        final played = userData is Map && userData['Played'] == true;
        if (played) continue;
        if (_isReleased(item, now)) {
          return true;
        }
      }
    } catch (_) {
      return false;
    }

    return false;
  }

  bool _isReleased(Map<String, dynamic> item, DateTime nowUtc) {
    final premiereDate =
        DateTime.tryParse(item['PremiereDate']?.toString() ?? '');
    if (premiereDate != null) {
      return !premiereDate.toUtc().isAfter(nowUtc);
    }

    final createdAt = DateTime.tryParse(item['DateCreated']?.toString() ?? '');
    if (createdAt != null) {
      return !createdAt.toUtc().isAfter(nowUtc);
    }

    return true;
  }

  Future<MediaSource?> _ensureAuthorizedSource(MediaSource source) async {
    if ((source.accessToken?.isNotEmpty ?? false) &&
        (source.userId?.isNotEmpty ?? false)) {
      return source;
    }

    try {
      return await _sourceService.refreshEmbySession(source);
    } catch (_) {
      return null;
    }
  }

  Map<String, String> _headers(String token) => {
        'X-Emby-Authorization':
            'MediaBrowser Client="BovaPlayer", Device="Flutter", DeviceId="bova-flutter", Version="1.0.0", Token="$token"',
        'Content-Type': 'application/json',
      };

  void dispose() {
    _client.close();
  }
}
