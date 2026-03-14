import 'tmdb_media_item.dart';

class DiscoverSection {
  final String titleKey;
  final String subtitleKey;
  final List<TmdbMediaItem> items;

  const DiscoverSection({
    required this.titleKey,
    required this.subtitleKey,
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
