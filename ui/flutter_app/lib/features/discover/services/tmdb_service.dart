import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/env_config.dart';
import '../models/discover_feed.dart';
import '../models/discover_section.dart';
import '../models/tmdb_media_item.dart';

class TmdbService {
  TmdbService({http.Client? client})
      : _client = client ?? http.Client(),
        _imageBaseUrl = EnvConfig.tmdbImageBaseUrl;

  final http.Client _client;
  String _imageBaseUrl;

  bool get isConfigured =>
      EnvConfig.tmdbReadAccessToken.isNotEmpty ||
      EnvConfig.tmdbApiKey.isNotEmpty;

  Future<DiscoverPayload> fetchPayload(DiscoverFeed feed) async {
    if (!isConfigured) {
      return const DiscoverPayload(
        featured: null,
        wallItems: [],
        sections: [],
      );
    }

    await _ensureConfiguration();

    switch (feed) {
      case DiscoverFeed.home:
        return _fetchHomePayload();
      case DiscoverFeed.movies:
        return _fetchMoviePayload();
      case DiscoverFeed.shows:
        return _fetchShowPayload();
    }
  }

  Future<List<TmdbMediaItem>> searchMulti(String query) async {
    if (!isConfigured || query.trim().isEmpty) {
      return const [];
    }

    await _ensureConfiguration();
    return _fetchList(
      '/search/multi',
      queryParameters: {'query': query.trim(), 'include_adult': 'false'},
    );
  }

  String imageUrl(
    String? path, {
    String size = 'w780',
  }) {
    if (path == null || path.isEmpty) return '';
    return '$_imageBaseUrl$size$path';
  }

  Future<void> _ensureConfiguration() async {
    if (EnvConfig.tmdbImageBaseUrl.isNotEmpty) {
      _imageBaseUrl = _normalizeImageBaseUrl(EnvConfig.tmdbImageBaseUrl);
    }

    try {
      final json = await _getJson('/configuration');
      final images = json['images'] as Map<String, dynamic>?;
      final secureBaseUrl = images?['secure_base_url']?.toString();
      if (secureBaseUrl != null && secureBaseUrl.isNotEmpty) {
        _imageBaseUrl = _normalizeImageBaseUrl(secureBaseUrl);
      }
    } catch (_) {
      _imageBaseUrl = _normalizeImageBaseUrl(EnvConfig.tmdbImageBaseUrl);
    }
  }

  String _normalizeImageBaseUrl(String value) {
    if (value.isEmpty) {
      return 'https://image.tmdb.org/t/p/';
    }

    final trimmed = value.trim();
    return trimmed.endsWith('/') ? trimmed : '$trimmed/';
  }

  Future<DiscoverPayload> _fetchHomePayload() async {
    final responses = await Future.wait([
      _fetchList('/trending/all/day'),
      _fetchList('/movie/popular', forceType: 'movie'),
      _fetchList('/tv/popular', forceType: 'tv'),
      _fetchList('/movie/now_playing', forceType: 'movie'),
    ]);

    final featured = _pickFeatured(responses[0], fallback: responses[1]);
    final wall = _mergeUnique([responses[1], responses[3], responses[2]])
        .take(18)
        .toList();

    return DiscoverPayload(
      featured: featured,
      wallItems: wall,
      sections: [
        DiscoverSection(
          titleKey: 'discoverTrendingNow',
          subtitleKey: 'discoverTrendingNowSub',
          items: responses[0].take(12).toList(),
        ),
        DiscoverSection(
          titleKey: 'discoverPopularMovies',
          subtitleKey: 'discoverPopularMoviesSub',
          items: responses[1].take(12).toList(),
        ),
        DiscoverSection(
          titleKey: 'discoverPopularTV',
          subtitleKey: 'discoverPopularTVSub',
          items: responses[2].take(12).toList(),
        ),
      ],
    );
  }

  Future<DiscoverPayload> _fetchMoviePayload() async {
    final responses = await Future.wait([
      _fetchList('/trending/movie/day', forceType: 'movie'),
      _fetchList('/movie/popular', forceType: 'movie'),
      _fetchList('/movie/now_playing', forceType: 'movie'),
      _fetchList('/discover/movie', forceType: 'movie', queryParameters: {
        'sort_by': 'popularity.desc',
        'vote_count.gte': '120',
      }),
    ]);

    final featured = _pickFeatured(responses[0], fallback: responses[1]);
    final wall = _mergeUnique([responses[1], responses[2], responses[3]])
        .take(20)
        .toList();

    return DiscoverPayload(
      featured: featured,
      wallItems: wall,
      sections: [
        DiscoverSection(
          titleKey: 'discoverTrendingMovies',
          subtitleKey: 'discoverTrendingMoviesSub',
          items: responses[0].take(12).toList(),
        ),
        DiscoverSection(
          titleKey: 'discoverNowPlaying',
          subtitleKey: 'discoverNowPlayingSub',
          items: responses[2].take(12).toList(),
        ),
        DiscoverSection(
          titleKey: 'discoverMovies',
          subtitleKey: 'discoverMoviesSub',
          items: responses[3].take(12).toList(),
        ),
      ],
    );
  }

  Future<DiscoverPayload> _fetchShowPayload() async {
    final responses = await Future.wait([
      _fetchList('/trending/tv/day', forceType: 'tv'),
      _fetchList('/tv/popular', forceType: 'tv'),
      _fetchList('/discover/tv', forceType: 'tv', queryParameters: {
        'sort_by': 'popularity.desc',
        'vote_count.gte': '80',
      }),
    ]);

    final featured = _pickFeatured(responses[0], fallback: responses[1]);
    final wall = _mergeUnique([responses[1], responses[2], responses[0]])
        .take(20)
        .toList();

    return DiscoverPayload(
      featured: featured,
      wallItems: wall,
      sections: [
        DiscoverSection(
          titleKey: 'discoverTrendingShows',
          subtitleKey: 'discoverTrendingShowsSub',
          items: responses[0].take(12).toList(),
        ),
        DiscoverSection(
          titleKey: 'discoverPopularTVShows',
          subtitleKey: 'discoverPopularTVShowsSub',
          items: responses[1].take(12).toList(),
        ),
        DiscoverSection(
          titleKey: 'discoverTV',
          subtitleKey: 'discoverTVSub',
          items: responses[2].take(12).toList(),
        ),
      ],
    );
  }

  TmdbMediaItem? _pickFeatured(
    List<TmdbMediaItem> primary, {
    List<TmdbMediaItem> fallback = const [],
  }) {
    for (final item in [...primary, ...fallback]) {
      if ((item.backdropPath ?? '').isNotEmpty) return item;
    }
    return (primary.isNotEmpty
        ? primary.first
        : (fallback.isNotEmpty ? fallback.first : null));
  }

  List<TmdbMediaItem> _mergeUnique(List<List<TmdbMediaItem>> lists) {
    final seen = <String>{};
    final merged = <TmdbMediaItem>[];
    for (final list in lists) {
      for (final item in list) {
        final key = '${item.mediaType}-${item.id}';
        if (seen.add(key)) {
          merged.add(item);
        }
      }
    }
    return merged;
  }

  Future<List<TmdbMediaItem>> _fetchList(
    String path, {
    String? forceType,
    Map<String, String>? queryParameters,
  }) async {
    final json = await _getJson(path, queryParameters: queryParameters);
    final results = (json['results'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        const [];
    return results
        .map((item) => TmdbMediaItem.fromJson(item, forceType: forceType))
        .where((item) => item.posterPath != null || item.backdropPath != null)
        .toList();
  }

  Future<Map<String, dynamic>> _getJson(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final mergedQuery = <String, String>{
      'language': EnvConfig.tmdbLanguage,
      ...?queryParameters,
    };

    if (EnvConfig.tmdbReadAccessToken.isEmpty &&
        EnvConfig.tmdbApiKey.isNotEmpty) {
      mergedQuery['api_key'] = EnvConfig.tmdbApiKey;
    }

    final baseUrl = EnvConfig.tmdbBaseUrl.replaceFirst(RegExp(r'/$'), '');
    final uri =
        Uri.parse('$baseUrl$path').replace(queryParameters: mergedQuery);
    final response = await _client.get(
      uri,
      headers: {
        'accept': 'application/json',
        if (EnvConfig.tmdbReadAccessToken.isNotEmpty)
          'Authorization': 'Bearer ${EnvConfig.tmdbReadAccessToken}',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('TMDB request failed (${response.statusCode})');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
