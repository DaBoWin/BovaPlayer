import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/tmdb_media_item.dart';

class DiscoverBookmarkService {
  static const String _storageKey = 'discover_bookmarks';

  Future<List<TmdbMediaItem>> loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return <TmdbMediaItem>[];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .whereType<Map>()
        .map((item) => _fromStoredJson(item.cast<String, dynamic>()))
        .toList();
  }

  Future<List<TmdbMediaItem>> toggleBookmark(TmdbMediaItem item) async {
    final bookmarks = await loadBookmarks();
    final key = _itemKey(item);
    final existingIndex =
        bookmarks.indexWhere((entry) => _itemKey(entry) == key);

    if (existingIndex >= 0) {
      bookmarks.removeAt(existingIndex);
    } else {
      bookmarks.insert(0, item);
    }

    await _persistBookmarks(bookmarks);
    return bookmarks;
  }

  Future<void> _persistBookmarks(List<TmdbMediaItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(items.map(_toStoredJson).toList(growable: false)),
    );
  }

  String _itemKey(TmdbMediaItem item) => '${item.mediaType}-${item.id}';

  Map<String, dynamic> _toStoredJson(TmdbMediaItem item) => {
        'id': item.id,
        'media_type': item.mediaType,
        'title': item.title,
        'original_title': item.originalTitle,
        'overview': item.overview,
        'poster_path': item.posterPath,
        'backdrop_path': item.backdropPath,
        'release_date': item.releaseDate,
        'vote_average': item.voteAverage,
        'vote_count': item.voteCount,
        'genre_ids': item.genreIds,
        'popularity': item.popularity,
      };

  TmdbMediaItem _fromStoredJson(Map<String, dynamic> json) {
    return TmdbMediaItem.fromJson(json,
        forceType: json['media_type']?.toString());
  }
}
