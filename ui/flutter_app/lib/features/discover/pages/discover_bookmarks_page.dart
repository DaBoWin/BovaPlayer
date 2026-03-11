import 'package:flutter/material.dart';

import '../../../core/theme/design_system.dart';
import '../../../widgets/custom_app_bar.dart';
import '../models/tmdb_media_item.dart';
import '../services/discover_library_resolver_service.dart';
import '../widgets/discover_bookmark_button.dart';
import '../widgets/discover_matched_source_strip.dart';
import '../widgets/discover_poster_card.dart';
import 'discover_search_page.dart';

class DiscoverBookmarksPage extends StatelessWidget {
  const DiscoverBookmarksPage({
    super.key,
    this.embedded = false,
    required this.bookmarksListenable,
    required this.imageBuilder,
    required this.onExploreItem,
    required this.resolveLibraryMatches,
    required this.onQuickPlayMatch,
    required this.onToggleBookmark,
    required this.isBookmarked,
  });

  final bool embedded;
  final ValueNotifier<List<TmdbMediaItem>> bookmarksListenable;
  final String Function(String? path, {String size}) imageBuilder;
  final Future<void> Function(TmdbMediaItem item) onExploreItem;
  final Future<List<DiscoverLibraryMatch>> Function(TmdbMediaItem item)
      resolveLibraryMatches;
  final Future<void> Function(TmdbMediaItem item, DiscoverLibraryMatch match)
      onQuickPlayMatch;
  final Future<void> Function(TmdbMediaItem item) onToggleBookmark;
  final bool Function(TmdbMediaItem item) isBookmarked;

  List<Widget> _buildQuickPlayButtons(TmdbMediaItem item) {
    return [
      FutureBuilder<List<DiscoverLibraryMatch>>(
        future: resolveLibraryMatches(item),
        builder: (context, snapshot) {
          final matches = snapshot.data ?? const <DiscoverLibraryMatch>[];
          if (matches.isEmpty) return const SizedBox.shrink();

          return DiscoverMatchedSourceStrip(
            matches: matches,
            chipMaxWidth: 208,
            onTap: (match) => onQuickPlayMatch(item, match),
          );
        },
      ),
    ];
  }

  Widget _buildBody(BuildContext context, List<TmdbMediaItem> bookmarks) {
    if (bookmarks.isEmpty) {
      return const DiscoverEmptyState(
        title: 'No bookmarks yet',
        subtitle:
            'Save titles from the featured hero or search results and they will show up here.',
      );
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${bookmarks.length} saved titles ready for Explore or quick play.',
                  style: const TextStyle(
                    fontSize: DesignSystem.textBase,
                    color: DesignSystem.neutral500,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = bookmarks[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DiscoverPosterCard(
                        item: item,
                        posterUrl: imageBuilder(item.posterPath, size: 'w500'),
                        onTap: () => onExploreItem(item),
                        overlayAction: DiscoverBookmarkButton(
                          isActive: isBookmarked(item),
                          onTap: () => onToggleBookmark(item),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DiscoverSearchActionChip(
                          label: 'Explore',
                          icon: Icons.arrow_forward_rounded,
                          accentColor: const Color(0xFF111827),
                          onTap: () => onExploreItem(item),
                        ),
                        ..._buildQuickPlayButtons(item).expand(
                          (widget) => [
                            const SizedBox(height: 8),
                            widget,
                          ],
                        ),
                      ],
                    ),
                  ],
                );
              },
              childCount: bookmarks.length,
            ),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 240,
              crossAxisSpacing: 18,
              mainAxisSpacing: 24,
              mainAxisExtent: 454,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<TmdbMediaItem>>(
      valueListenable: bookmarksListenable,
      builder: (context, bookmarks, _) {
        if (embedded) {
          return ColoredBox(
            color: const Color(0xFFF9FAFB),
            child: _buildBody(context, bookmarks),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF9FAFB),
          appBar: const CustomAppBar(title: 'Bookmarks'),
          body: _buildBody(context, bookmarks),
        );
      },
    );
  }
}
