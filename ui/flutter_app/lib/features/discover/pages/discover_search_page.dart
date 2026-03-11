import 'package:flutter/material.dart';

import '../../../core/theme/design_system.dart';
import '../../../widgets/custom_app_bar.dart';
import '../controllers/discover_search_controller.dart';
import '../models/tmdb_media_item.dart';
import '../services/discover_library_resolver_service.dart';
import '../widgets/discover_bookmark_button.dart';
import '../widgets/discover_matched_source_strip.dart';
import '../widgets/discover_poster_card.dart';

class DiscoverSearchPage extends StatefulWidget {
  const DiscoverSearchPage({
    super.key,
    this.embedded = false,
    required this.onExploreItem,
    required this.resolveLibraryMatches,
    required this.onQuickPlayMatch,
    required this.onToggleBookmark,
    required this.isBookmarked,
    this.bookmarkListenable,
  });

  final bool embedded;
  final Future<void> Function(TmdbMediaItem item) onExploreItem;
  final Future<List<DiscoverLibraryMatch>> Function(TmdbMediaItem item)
      resolveLibraryMatches;
  final Future<void> Function(TmdbMediaItem item, DiscoverLibraryMatch match)
      onQuickPlayMatch;
  final Future<void> Function(TmdbMediaItem item) onToggleBookmark;
  final bool Function(TmdbMediaItem item) isBookmarked;
  final Listenable? bookmarkListenable;

  @override
  State<DiscoverSearchPage> createState() => _DiscoverSearchPageState();
}

class _DiscoverSearchPageState extends State<DiscoverSearchPage> {
  late final DiscoverSearchController _controller;
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _controller = DiscoverSearchController();
    _textController = TextEditingController()
      ..addListener(() {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    _textController.dispose();
    super.dispose();
  }

  List<Widget> _buildQuickPlayButtons(TmdbMediaItem item) {
    return [
      FutureBuilder<List<DiscoverLibraryMatch>>(
        future: widget.resolveLibraryMatches(item),
        builder: (context, snapshot) {
          final matches = snapshot.data ?? const <DiscoverLibraryMatch>[];
          if (matches.isEmpty) return const SizedBox.shrink();

          return DiscoverMatchedSourceStrip(
            matches: matches,
            chipMaxWidth: 208,
            onTap: (match) => widget.onQuickPlayMatch(item, match),
          );
        },
      ),
    ];
  }

  Widget _buildBody() {
    final animation = widget.bookmarkListenable == null
        ? _controller
        : Listenable.merge([_controller, widget.bookmarkListenable!]);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: DesignSystem.neutral200),
                        boxShadow: DesignSystem.shadowSm,
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 14),
                          const Icon(
                            Icons.search_rounded,
                            color: DesignSystem.neutral500,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              autofocus: true,
                              onChanged: _controller.updateQuery,
                              onSubmitted: (_) => _controller.searchNow(),
                              decoration: const InputDecoration(
                                hintText: 'Search movies and shows from TMDB',
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          if (_textController.text.isNotEmpty)
                            IconButton(
                              onPressed: () {
                                _textController.clear();
                                _controller.updateQuery('');
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                          const SizedBox(width: 6),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _controller.query.isEmpty
                          ? 'Type a title to search TMDB and jump straight into your libraries.'
                          : 'Results for “${_controller.query}”',
                      style: const TextStyle(
                        fontSize: DesignSystem.textBase,
                        color: DesignSystem.neutral500,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!_controller.isConfigured)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: DiscoverEmptyState(
                  title: 'TMDB not configured',
                  subtitle: 'Add your TMDB token first to use search.',
                ),
              )
            else if (_controller.query.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: DiscoverEmptyState(
                  title: 'Start searching',
                  subtitle:
                      'Find a movie or show, then Explore or quick-play it from your matched libraries.',
                ),
              )
            else if (_controller.isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFE11D48)),
                ),
              )
            else if (_controller.results.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: DiscoverEmptyState(
                  title: 'No results',
                  subtitle:
                      'Try another title, original name, or shorter keyword.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = _controller.results[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: DiscoverPosterCard(
                              item: item,
                              posterUrl: _controller.imageUrl(item.posterPath,
                                  size: 'w500'),
                              onTap: () => widget.onExploreItem(item),
                              overlayAction: DiscoverBookmarkButton(
                                isActive: widget.isBookmarked(item),
                                onTap: () async {
                                  await widget.onToggleBookmark(item);
                                  if (mounted) setState(() {});
                                },
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
                                onTap: () => widget.onExploreItem(item),
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
                    childCount: _controller.results.length,
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return ColoredBox(
        color: const Color(0xFFF9FAFB),
        child: _buildBody(),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: const CustomAppBar(title: 'Search'),
      body: _buildBody(),
    );
  }
}

class DiscoverSearchActionChip extends StatelessWidget {
  const DiscoverSearchActionChip({
    super.key,
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.onTap,
    this.maxWidth,
    this.trailing,
  });

  final String label;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;
  final double? maxWidth;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints:
            maxWidth == null ? null : BoxConstraints(maxWidth: maxWidth!),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: DesignSystem.neutral200),
        ),
        child: Row(
          mainAxisSize: maxWidth == null ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Icon(icon, size: 15, color: accentColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: DesignSystem.textSm,
                  fontWeight: DesignSystem.weightSemibold,
                  color: DesignSystem.neutral900,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class DiscoverEmptyState extends StatelessWidget {
  const DiscoverEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: DesignSystem.shadowSm,
              ),
              child: const Icon(
                Icons.search_rounded,
                color: Color(0xFFE11D48),
                size: 28,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: DesignSystem.weightSemibold,
                color: DesignSystem.neutral900,
                letterSpacing: -0.7,
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: DesignSystem.textBase,
                  color: DesignSystem.neutral500,
                  height: 1.55,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
