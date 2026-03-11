class TmdbMediaItem {
  final int id;
  final String mediaType;
  final String title;
  final String originalTitle;
  final String overview;
  final String? posterPath;
  final String? backdropPath;
  final String? releaseDate;
  final double voteAverage;
  final int voteCount;
  final List<int> genreIds;
  final double popularity;

  const TmdbMediaItem({
    required this.id,
    required this.mediaType,
    required this.title,
    required this.originalTitle,
    required this.overview,
    required this.posterPath,
    required this.backdropPath,
    required this.releaseDate,
    required this.voteAverage,
    required this.voteCount,
    required this.genreIds,
    required this.popularity,
  });

  factory TmdbMediaItem.fromJson(Map<String, dynamic> json,
      {String? forceType}) {
    final mediaType = (forceType ?? json['media_type'] ?? '').toString();
    final title = (json['title'] ??
            json['name'] ??
            json['original_title'] ??
            json['original_name'] ??
            'Untitled')
        .toString();
    final originalTitle =
        (json['original_title'] ?? json['original_name'] ?? title).toString();

    return TmdbMediaItem(
      id: json['id'] as int? ?? 0,
      mediaType: mediaType.isEmpty ? 'movie' : mediaType,
      title: title,
      originalTitle: originalTitle,
      overview: (json['overview'] ?? '').toString(),
      posterPath: json['poster_path']?.toString(),
      backdropPath: json['backdrop_path']?.toString(),
      releaseDate: (json['release_date'] ?? json['first_air_date'])?.toString(),
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0,
      voteCount: json['vote_count'] as int? ?? 0,
      genreIds: (json['genre_ids'] as List?)
              ?.whereType<num>()
              .map((value) => value.toInt())
              .toList() ??
          const [],
      popularity: (json['popularity'] as num?)?.toDouble() ?? 0,
    );
  }

  String get year {
    final value = releaseDate;
    if (value == null || value.length < 4) return '';
    return value.substring(0, 4);
  }

  String get mediaLabel {
    switch (mediaType) {
      case 'tv':
        return 'Series';
      case 'movie':
        return 'Movie';
      default:
        return mediaType.toUpperCase();
    }
  }
}
