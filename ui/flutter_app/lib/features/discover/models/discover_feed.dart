enum DiscoverFeed {
  home,
  movies,
  shows,
}

extension DiscoverFeedX on DiscoverFeed {
  String get title {
    switch (this) {
      case DiscoverFeed.home:
        return 'Featured';
      case DiscoverFeed.movies:
        return 'Movies';
      case DiscoverFeed.shows:
        return 'TV Shows';
    }
  }

  String get subtitle {
    switch (this) {
      case DiscoverFeed.home:
        return 'Trending picks and popular titles from TMDB';
      case DiscoverFeed.movies:
        return 'Popular films and in-the-moment movie picks';
      case DiscoverFeed.shows:
        return 'Series trends, binge-worthy picks and TV highlights';
    }
  }
}
