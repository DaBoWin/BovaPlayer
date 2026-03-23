import 'package:flutter/material.dart';

import '../../../core/theme/design_system.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../widgets/custom_app_bar.dart';
import '../models/tmdb_media_item.dart';
import '../services/discover_follow_series_service.dart';
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
    required this.followStatesListenable,
    required this.imageBuilder,
    required this.onExploreItem,
    required this.resolveLibraryMatches,
    required this.onQuickPlayMatch,
    required this.onToggleBookmark,
    required this.onToggleFollowSeries,
    required this.canFollowItem,
    required this.isBookmarked,
  });

  final bool embedded;
  final ValueNotifier<List<TmdbMediaItem>> bookmarksListenable;
  final ValueNotifier<Map<String, DiscoverFollowSeriesState>>
      followStatesListenable;
  final String Function(String? path, {String size}) imageBuilder;
  final Future<void> Function(TmdbMediaItem item) onExploreItem;
  final Future<List<DiscoverLibraryMatch>> Function(TmdbMediaItem item)
      resolveLibraryMatches;
  final Future<void> Function(TmdbMediaItem item, DiscoverLibraryMatch match)
      onQuickPlayMatch;
  final Future<void> Function(TmdbMediaItem item) onToggleBookmark;
  final Future<void> Function(TmdbMediaItem item) onToggleFollowSeries;
  final bool Function(TmdbMediaItem item, [List<DiscoverLibraryMatch>? matches])
      canFollowItem;
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

  String _itemKey(TmdbMediaItem item) => '${item.mediaType}-${item.id}';

  Widget _buildFollowBadge(
    BuildContext context,
    DiscoverFollowSeriesState? state,
  ) {
    if (state == null || !state.isFollowing) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final hasUpdates = state.hasNewEpisodes;
    final backgroundColor = hasUpdates
        ? scheme.primary.withValues(alpha: 0.14)
        : scheme.surfaceContainerHighest.withValues(alpha: 0.92);
    final foregroundColor =
        hasUpdates ? scheme.primary : scheme.onSurface.withValues(alpha: 0.74);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: foregroundColor.withValues(alpha: hasUpdates ? 0.28 : 0.16),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasUpdates ? Icons.new_releases_rounded : Icons.tv_rounded,
            size: 14,
            color: foregroundColor,
          ),
          const SizedBox(width: 6),
          Text(
            hasUpdates
                ? S.of(context).followSeriesUpdated
                : S.of(context).followSeriesActive,
            style: TextStyle(
              fontSize: DesignSystem.textXs,
              fontWeight: DesignSystem.weightSemibold,
              color: foregroundColor,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActionChips(
    BuildContext context,
    TmdbMediaItem item,
  ) {
    final l = S.of(context);
    final scheme = Theme.of(context).colorScheme;

    return [
      DiscoverSearchActionChip(
        label: l.discoverExplore,
        icon: Icons.arrow_forward_rounded,
        accentColor: scheme.onSurface,
        onTap: () => onExploreItem(item),
      ),
    ];
  }

  Widget _buildFollowOverlay(
    BuildContext context,
    TmdbMediaItem item,
    DiscoverFollowSeriesState? state,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<List<DiscoverLibraryMatch>>(
      future: resolveLibraryMatches(item),
      builder: (context, snapshot) {
        final matches = snapshot.data ?? const <DiscoverLibraryMatch>[];
        final canFollow = canFollowItem(item, matches);
        if (item.mediaType != 'tv' ||
            (!canFollow && !(state?.isFollowing ?? false))) {
          return const SizedBox.shrink();
        }

        if (state?.isFollowing == true) {
          return _buildFollowBadge(context, state);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onToggleFollowSeries(item),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: scheme.outline.withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_alert_rounded,
                  size: 14,
                  color: scheme.onSurface,
                ),
                const SizedBox(width: 6),
                Text(
                  S.of(context).followSeriesStart,
                  style: TextStyle(
                    fontSize: DesignSystem.textXs,
                    fontWeight: DesignSystem.weightSemibold,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    List<TmdbMediaItem> bookmarks,
    Map<String, DiscoverFollowSeriesState> followStates,
  ) {
    final l = S.of(context);
    final scheme = Theme.of(context).colorScheme;

    if (bookmarks.isEmpty) {
      return DiscoverEmptyState(
        title: l.discoverNoBookmarks,
        subtitle: l.discoverNoBookmarksHint,
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
                  l.discoverBookmarkCount(bookmarks.length),
                  style: TextStyle(
                    fontSize: DesignSystem.textBase,
                    color: scheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                if (followStates.values
                    .any((state) => state.hasNewEpisodes)) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.new_releases_rounded,
                          size: 16,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            l.discoverBookmarksSortedByUpdates,
                            style: TextStyle(
                              fontSize: DesignSystem.textSm,
                              fontWeight: DesignSystem.weightMedium,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                final followState = followStates[_itemKey(item)];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DiscoverPosterCard(
                        item: item,
                        posterUrl: imageBuilder(item.posterPath, size: 'w500'),
                        overlayAction: DiscoverBookmarkButton(
                          isActive: isBookmarked(item),
                          onTap: () => onToggleBookmark(item),
                        ),
                        overlayBadge:
                            _buildFollowOverlay(context, item, followState),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ..._buildActionChips(context, item),
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
              mainAxisExtent: 444,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;

    return ValueListenableBuilder<List<TmdbMediaItem>>(
      valueListenable: bookmarksListenable,
      builder: (context, bookmarks, _) {
        return ValueListenableBuilder<Map<String, DiscoverFollowSeriesState>>(
          valueListenable: followStatesListenable,
          builder: (context, followStates, __) {
            if (embedded) {
              return ColoredBox(
                color: bg,
                child: _buildBody(context, bookmarks, followStates),
              );
            }

            return Scaffold(
              backgroundColor: bg,
              appBar: const CustomAppBar(title: 'Bookmarks'),
              body: _buildBody(context, bookmarks, followStates),
            );
          },
        );
      },
    );
  }
}
