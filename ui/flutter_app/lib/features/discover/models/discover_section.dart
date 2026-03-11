import 'tmdb_media_item.dart';

class DiscoverSection {
  final String title;
  final String subtitle;
  final List<TmdbMediaItem> items;

  const DiscoverSection({
    required this.title,
    required this.subtitle,
    required this.items,
  });
}

class DiscoverPayload {
  final TmdbMediaItem? featured;
  final List<TmdbMediaItem> wallItems;
  final List<DiscoverSection> sections;

  const DiscoverPayload({
    required this.featured,
    required this.wallItems,
    required this.sections,
  });
}
