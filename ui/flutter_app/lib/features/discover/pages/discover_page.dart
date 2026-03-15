import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_system.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../controllers/discover_controller.dart';
import '../models/discover_feed.dart';
import '../models/discover_section.dart';
import '../models/tmdb_media_item.dart';
import '../widgets/discover_bookmark_button.dart';
import '../widgets/discover_featured_hero.dart';
import '../widgets/discover_latency_indicator.dart';
import '../widgets/discover_matched_source_strip.dart';
import '../widgets/discover_poster_card.dart';
import '../services/discover_library_resolver_service.dart';
import '../widgets/discover_section_row.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({
    super.key,
    required this.feed,
    this.onExploreItem,
    this.resolveLibraryMatches,
    this.onQuickPlayMatch,
    this.onSaveItem,
    this.isBookmarked,
    this.bookmarkListenable,
  });

  final DiscoverFeed feed;
  final Future<void> Function(TmdbMediaItem item)? onExploreItem;
  final Future<List<DiscoverLibraryMatch>> Function(TmdbMediaItem item)?
      resolveLibraryMatches;
  final Future<void> Function(
    TmdbMediaItem item,
    DiscoverLibraryMatch match,
  )? onQuickPlayMatch;
  final Future<void> Function(TmdbMediaItem item)? onSaveItem;
  final bool Function(TmdbMediaItem item)? isBookmarked;
  final Listenable? bookmarkListenable;

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  late final DiscoverController _controller;
  String? _lastLocaleCode;

  @override
  void initState() {
    super.initState();
    _controller = DiscoverController();
    _controller.load(widget.feed, force: true);
  }

  @override
  void didUpdateWidget(covariant DiscoverPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.feed != widget.feed) {
      _controller.load(widget.feed, force: true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final localeCode = Localizations.localeOf(context).languageCode;
    if (_lastLocaleCode != null && _lastLocaleCode != localeCode) {
      _controller.load(widget.feed, force: true);
    }
    _lastLocaleCode = localeCode;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _itemKey(TmdbMediaItem item) => '${item.mediaType}-${item.id}';

  List<Widget> _buildQuickPlayButtons(TmdbMediaItem item,
      {bool compact = false}) {
    final resolver = widget.resolveLibraryMatches;
    final onQuickPlayMatch = widget.onQuickPlayMatch;
    if (resolver == null || onQuickPlayMatch == null) {
      return const [];
    }

    return [
      FutureBuilder<List<DiscoverLibraryMatch>>(
        future: resolver(item),
        builder: (context, snapshot) {
          final matches = snapshot.data ?? const <DiscoverLibraryMatch>[];
          if (matches.isEmpty) {
            return const SizedBox.shrink();
          }

          if (compact) {
            return DiscoverMatchedSourceStrip(
              matches: matches,
              onTap: (match) => onQuickPlayMatch(item, match),
            );
          }

          final chips = [
            for (final match in matches)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _QuickPlayButton(
                  key: ValueKey('${_itemKey(item)}-${match.source.id}'),
                  label: match.source.name,
                  latencyMs: match.responseTimeMs,
                  onTap: () => onQuickPlayMatch(item, match),
                ),
              ),
          ];

          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips.map((chip) => chip.child!).toList(growable: false),
          );
        },
      ),
    ];
  }

  Widget? _buildBookmarkOverlay(TmdbMediaItem item) {
    final onSaveItem = widget.onSaveItem;
    final isBookmarked = widget.isBookmarked;
    if (onSaveItem == null || isBookmarked == null) {
      return null;
    }

    return DiscoverBookmarkButton(
      isActive: isBookmarked(item),
      onTap: () => onSaveItem(item),
    );
  }

  Future<void> _handleItemTap(TmdbMediaItem item) async {
    final handler = widget.onExploreItem;
    if (handler != null) {
      await handler(item);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Selected: ${item.title}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = DesignSystem.isMobile(context);
    final animation = widget.bookmarkListenable == null
        ? _controller
        : Listenable.merge([_controller, widget.bookmarkListenable!]);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        if (!_controller.isConfigured) {
          return _ConfigurationEmptyState(feed: widget.feed);
        }

        if (_controller.isLoading && _controller.payload == null) {
          return const _DiscoverLoadingState();
        }

        if (_controller.errorMessage != null && _controller.payload == null) {
          return _DiscoverErrorState(
            message: _controller.errorMessage!,
            onRetry: _controller.refresh,
          );
        }

        final payload = _controller.payload ??
            const DiscoverPayload(featured: null, wallItems: [], sections: []);

        return RefreshIndicator(
          color: Theme.of(context).colorScheme.primary,
          onRefresh: _controller.refresh,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth >= 1200
                  ? 36.0
                  : constraints.maxWidth >= 768
                      ? 24.0
                      : 16.0;
              final wallColumns = constraints.maxWidth >= 1560
                  ? 6
                  : constraints.maxWidth >= 1320
                      ? 5
                      : constraints.maxWidth >= 1024
                          ? 4
                          : constraints.maxWidth >= 700
                              ? 3
                              : 2;
              final wallCardWidth = (constraints.maxWidth -
                      horizontalPadding * 2 -
                      (wallColumns - 1) * 18) /
                  wallColumns;
              final wallCardExtent =
                  wallCardWidth / 0.704 + (isMobile ? 140 : 118);
              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                slivers: [
                  if (payload.featured case final TmdbMediaItem featured)
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                          horizontalPadding, 24, horizontalPadding, 28),
                      sliver: SliverToBoxAdapter(
                        child: DiscoverFeaturedHero(
                          item: featured,
                          backdropUrl: _controller
                              .imageUrl(featured.backdropPath, size: 'w1280'),
                          compactLayout: isMobile,
                          onPrimaryAction: () => _handleItemTap(featured),
                          onSecondaryAction: widget.onSaveItem == null
                              ? null
                              : () => widget.onSaveItem!(featured),
                          secondaryActive:
                              widget.isBookmarked?.call(featured) ?? false,
                          quickPlayButtons: _buildQuickPlayButtons(featured,
                              compact: isMobile),
                        ),
                      ),
                    ),
                  if (payload.featured == null)
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  if (payload.wallItems.isNotEmpty)
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                          horizontalPadding, 8, horizontalPadding, 24),
                      sliver: SliverToBoxAdapter(
                        child: _SectionIntro(
                          title: S.of(context).discoverHotWall,
                          subtitle: S.of(context).discoverHotWallSubtitle,
                        ),
                      ),
                    ),
                  if (payload.wallItems.isNotEmpty)
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                          horizontalPadding, 0, horizontalPadding, 36),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = payload.wallItems[index];
                            return DiscoverPosterCard(
                              item: item,
                              posterUrl: _controller.imageUrl(item.posterPath,
                                  size: 'w500'),
                              onTap: () => _handleItemTap(item),
                              quickPlayButtons:
                                  _buildQuickPlayButtons(item, compact: true),
                              overlayAction: _buildBookmarkOverlay(item),
                            );
                          },
                          childCount: payload.wallItems.length,
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: wallColumns,
                          crossAxisSpacing: 18,
                          mainAxisSpacing: 22,
                          mainAxisExtent: wallCardExtent,
                        ),
                      ),
                    ),
                  for (final section in payload.sections)
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                          horizontalPadding, 0, horizontalPadding, 28),
                      sliver: SliverToBoxAdapter(
                        child: DiscoverSectionRow(
                          section: section,
                          imageBuilder: _controller.imageUrl,
                          onItemTap: _handleItemTap,
                          quickPlayBuilder: (item) =>
                              _buildQuickPlayButtons(item, compact: true),
                          overlayActionBuilder: _buildBookmarkOverlay,
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 28)),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _QuickPlayButton extends StatefulWidget {
  const _QuickPlayButton({
    super.key,
    required this.label,
    required this.onTap,
    this.latencyMs,
  });

  final String label;
  final int? latencyMs;
  final VoidCallback onTap;

  @override
  State<_QuickPlayButton> createState() => _QuickPlayButtonState();
}

class _QuickPlayButtonState extends State<_QuickPlayButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = _resolveAccent(context);
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chipBg = isDark ? scheme.surface : Colors.white.withValues(alpha: 0.96);
    final borderColor = isDark
        ? scheme.outline.withValues(alpha: 0.15)
        : scheme.onSurface.withValues(alpha: 0.08);
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.20)
        : scheme.onSurface.withValues(alpha: 0.12);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: DesignSystem.durationFast,
          curve: DesignSystem.easeOutQuart,
          transform: Matrix4.identity()
            ..translateByDouble(0.0, _isHovered ? -2.0 : 0.0, 0.0, 1.0),
          constraints: const BoxConstraints(
            maxWidth: 240,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: chipBg,
            borderRadius: BorderRadius.circular(DesignSystem.radiusFull),
            border: Border.all(color: borderColor),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: shadowColor,
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : const [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.play_circle_fill_rounded,
                size: 16,
                color: accent,
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: DesignSystem.textSm,
                  fontWeight: DesignSystem.weightSemibold,
                  color: scheme.onSurface,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(width: 8),
              DiscoverLatencyIndicator(latencyMs: widget.latencyMs),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionIntro extends StatelessWidget {
  const _SectionIntro({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 34,
            fontWeight: DesignSystem.weightMedium,
            color: scheme.onSurface.withValues(alpha: 0.7),
            letterSpacing: -0.9,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: DesignSystem.textBase,
            color: scheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

class _ConfigurationEmptyState extends StatelessWidget {
  const _ConfigurationEmptyState({required this.feed});

  final DiscoverFeed feed;

  @override
  Widget build(BuildContext context) {
    final accent = _resolveAccent(context);
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l = S.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(DesignSystem.radius2xl),
            border: Border.all(
              color: isDark
                  ? scheme.outline.withValues(alpha: 0.15)
                  : DesignSystem.neutral200,
            ),
            boxShadow: DesignSystem.shadowMd,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(Icons.movie_creation_outlined,
                    color: accent, size: 30),
              ),
              const SizedBox(height: 20),
              Text(
                l.discoverTmdbCredentials(feed.title),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: DesignSystem.weightSemibold,
                  color: scheme.onSurface,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l.discoverTmdbCredentialsHint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: DesignSystem.textBase,
                  color: scheme.onSurface.withValues(alpha: 0.5),
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoverLoadingState extends StatelessWidget {
  const _DiscoverLoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _DiscoverErrorState extends StatelessWidget {
  const _DiscoverErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final accent = _resolveAccent(context);
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l = S.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(DesignSystem.radius2xl),
            border: Border.all(
              color: isDark
                  ? scheme.outline.withValues(alpha: 0.15)
                  : DesignSystem.neutral200,
            ),
            boxShadow: DesignSystem.shadowMd,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wifi_off_rounded,
                color: accent,
                size: 36,
              ),
              const SizedBox(height: 16),
              Text(
                l.discoverUnableToLoad,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: DesignSystem.weightSemibold,
                  color: scheme.onSurface,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: DesignSystem.textBase,
                  color: scheme.onSurface.withValues(alpha: 0.5),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      DesignSystem.radiusFull,
                    ),
                  ),
                ),
                child: Text(l.discoverTryAgain),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared accent color resolver for discover widgets.
Color _resolveAccent(BuildContext context) {
  final mode = context.read<ThemeProvider>().themeMode;
  if (mode == AppThemeMode.cyberpunk) return AppTheme.cyberNeon;
  if (mode == AppThemeMode.sweetiePro) return AppTheme.sweetieHotPink;
  return Theme.of(context).colorScheme.primary;
}
