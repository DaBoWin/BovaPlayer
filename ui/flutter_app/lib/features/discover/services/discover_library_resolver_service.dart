import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../media_library/models/media_source.dart';
import '../../media_library/services/media_library_source_service.dart';
import '../models/discover_latency_tier.dart';
import '../models/tmdb_media_item.dart';

class DiscoverLibraryMatch {
  const DiscoverLibraryMatch({
    required this.source,
    required this.itemId,
    required this.itemName,
    required this.itemType,
    required this.score,
    required this.matchedByTmdbId,
    this.productionYear,
    this.responseTimeMs,
  });

  final MediaSource source;
  final String itemId;
  final String itemName;
  final String itemType;
  final double score;
  final bool matchedByTmdbId;
  final int? productionYear;
  final int? responseTimeMs;
}

class DiscoverLibraryResolverService {
  DiscoverLibraryResolverService({
    MediaLibrarySourceService? sourceService,
    http.Client? client,
  })  : _sourceService = sourceService ?? MediaLibrarySourceService(),
        _client = client ?? http.Client();

  static const Duration _latencyCacheTtl = Duration(minutes: 2);

  final MediaLibrarySourceService _sourceService;
  final http.Client _client;
  final Map<String, _LatencyCacheEntry> _latencyCache = {};

  Future<List<DiscoverLibraryMatch>> resolveItem(TmdbMediaItem item) async {
    final sources = await _sourceService.loadSources();
    final embySources = sources.where(_supportsDiscoverResolve).toList();

    if (embySources.isEmpty) {
      return const [];
    }

    final results = await Future.wait(
      embySources.map((source) => _resolveInEmbySource(source, item)),
    );

    final matches = results.whereType<DiscoverLibraryMatch>().toList()
      ..sort((left, right) {
        final latencyRankCompare = DiscoverLatencyTierResolver.sortRank(
          left.responseTimeMs,
        ).compareTo(
          DiscoverLatencyTierResolver.sortRank(right.responseTimeMs),
        );
        if (latencyRankCompare != 0) return latencyRankCompare;

        final leftLatency = left.responseTimeMs ?? 1 << 30;
        final rightLatency = right.responseTimeMs ?? 1 << 30;
        final latencyCompare = leftLatency.compareTo(rightLatency);
        if (latencyCompare != 0) return latencyCompare;

        final scoreCompare = right.score.compareTo(left.score);
        if (scoreCompare != 0) return scoreCompare;
        if (left.matchedByTmdbId != right.matchedByTmdbId) {
          return right.matchedByTmdbId ? 1 : -1;
        }
        return left.source.name.toLowerCase().compareTo(
              right.source.name.toLowerCase(),
            );
      });

    return matches;
  }

  bool _supportsDiscoverResolve(MediaSource source) {
    return source.type == SourceType.emby &&
        source.url.isNotEmpty &&
        source.username.isNotEmpty &&
        source.password.isNotEmpty;
  }

  Future<int?> _measureSourceLatency(MediaSource source) async {
    final uri = Uri.tryParse(source.url);
    final host = uri?.host;
    if (host == null || host.isEmpty) return null;

    final port = uri!.hasPort
        ? uri.port
        : uri.scheme.toLowerCase() == 'https'
            ? 443
            : 80;
    final cacheKey = '${host.toLowerCase()}:$port';
    final cached = _latencyCache[cacheKey];
    final now = DateTime.now();
    if (cached != null &&
        now.difference(cached.measuredAt) < _latencyCacheTtl) {
      return cached.latencyMs;
    }

    try {
      final stopwatch = Stopwatch()..start();
      final socket =
          await Socket.connect(host, port).timeout(const Duration(seconds: 2));
      stopwatch.stop();
      socket.destroy();
      final latencyMs = stopwatch.elapsedMilliseconds;
      _latencyCache[cacheKey] = _LatencyCacheEntry(
        latencyMs: latencyMs,
        measuredAt: now,
      );
      return latencyMs;
    } catch (_) {
      _latencyCache[cacheKey] = _LatencyCacheEntry(
        latencyMs: null,
        measuredAt: now,
      );
      return null;
    }
  }

  Future<DiscoverLibraryMatch?> _resolveInEmbySource(
    MediaSource source,
    TmdbMediaItem item,
  ) async {
    final authorizedSource = await _ensureAuthorizedSource(source);
    if (authorizedSource == null) {
      return null;
    }

    final latencyFuture = _measureSourceLatency(authorizedSource);

    final searchTerms = <String>{
      item.title.trim(),
      item.originalTitle.trim(),
    }..removeWhere((term) => term.isEmpty);

    final candidates = <String, Map<String, dynamic>>{};
    for (final term in searchTerms) {
      final results = await _searchEmby(authorizedSource, item, term);
      for (final entry in results) {
        final id = entry['Id']?.toString();
        if (id != null && id.isNotEmpty) {
          candidates[id] = entry;
        }
      }
    }

    if (candidates.isEmpty) {
      return null;
    }

    Map<String, dynamic>? bestItem;
    double bestScore = 0;
    bool bestMatchedByTmdbId = false;

    for (final candidate in candidates.values) {
      final scoreResult = _scoreCandidate(item, candidate);
      if (scoreResult.score > bestScore) {
        bestScore = scoreResult.score;
        bestItem = candidate;
        bestMatchedByTmdbId = scoreResult.matchedByTmdbId;
      }
    }

    if (bestItem == null || bestScore < 45) {
      return null;
    }

    final latencyMs = await latencyFuture;

    return DiscoverLibraryMatch(
      source: authorizedSource,
      itemId: bestItem['Id']?.toString() ?? '',
      itemName: bestItem['Name']?.toString() ?? item.title,
      itemType: bestItem['Type']?.toString() ?? '',
      score: bestScore,
      matchedByTmdbId: bestMatchedByTmdbId,
      productionYear: (bestItem['ProductionYear'] as num?)?.toInt(),
      responseTimeMs: latencyMs,
    );
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

  Future<List<Map<String, dynamic>>> _searchEmby(
    MediaSource source,
    TmdbMediaItem item,
    String searchTerm,
  ) async {
    final includeItemTypes = item.mediaType == 'tv' ? 'Series' : 'Movie';
    final uri =
        Uri.parse('${source.url}/emby/Users/${source.userId}/Items').replace(
      queryParameters: {
        'Recursive': 'true',
        'SearchTerm': searchTerm,
        'IncludeItemTypes': includeItemTypes,
        'Limit': '12',
        'Fields': 'ProviderIds,ProductionYear',
        'api_key': source.accessToken,
      },
    );

    try {
      final response = await _client
          .get(
            uri,
            headers: _headers(source.accessToken!),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        return const [];
      }

      final json = jsonDecode(utf8.decode(response.bodyBytes));
      return (json['Items'] as List?)
              ?.whereType<Map>()
              .map((item) => item.cast<String, dynamic>())
              .toList() ??
          const [];
    } catch (_) {
      return const [];
    }
  }

  _ScoreResult _scoreCandidate(
      TmdbMediaItem item, Map<String, dynamic> candidate) {
    double score = 0;
    var matchedByTmdbId = false;

    final providerIds = candidate['ProviderIds'];
    final tmdbProviderId =
        providerIds is Map ? providerIds['Tmdb']?.toString() : null;
    if (tmdbProviderId == item.id.toString()) {
      score += 120;
      matchedByTmdbId = true;
    }

    final candidateName = candidate['Name']?.toString() ?? '';
    final normalizedCandidate = _normalize(candidateName);
    final normalizedTitle = _normalize(item.title);
    final normalizedOriginalTitle = _normalize(item.originalTitle);

    if (normalizedCandidate == normalizedTitle) {
      score += 70;
    } else if (normalizedCandidate == normalizedOriginalTitle) {
      score += 64;
    } else if (normalizedCandidate.contains(normalizedTitle) ||
        normalizedTitle.contains(normalizedCandidate)) {
      score += 40;
    } else if (normalizedCandidate.contains(normalizedOriginalTitle) ||
        normalizedOriginalTitle.contains(normalizedCandidate)) {
      score += 34;
    }

    final year = int.tryParse(item.year);
    final candidateYear = (candidate['ProductionYear'] as num?)?.toInt();
    if (year != null && candidateYear != null) {
      if (candidateYear == year) {
        score += 18;
      } else if ((candidateYear - year).abs() == 1) {
        score += 8;
      }
    }

    final candidateType = candidate['Type']?.toString();
    if (item.mediaType == 'movie' && candidateType == 'Movie') {
      score += 10;
    } else if (item.mediaType == 'tv' && candidateType == 'Series') {
      score += 10;
    }

    return _ScoreResult(score: score, matchedByTmdbId: matchedByTmdbId);
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fff]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
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

class _ScoreResult {
  const _ScoreResult({required this.score, required this.matchedByTmdbId});

  final double score;
  final bool matchedByTmdbId;
}

class _LatencyCacheEntry {
  const _LatencyCacheEntry({
    required this.latencyMs,
    required this.measuredAt,
  });

  final int? latencyMs;
  final DateTime measuredAt;
}
