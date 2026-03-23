import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_system.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../models/tmdb_media_item.dart';

class DiscoverFeaturedHero extends StatelessWidget {
  const DiscoverFeaturedHero({
    super.key,
    required this.item,
    required this.backdropUrl,
    required this.onPrimaryAction,
    this.compactLayout = false,
    this.onSecondaryAction,
    this.secondaryActive = false,
    this.quickPlayButtons = const [],
  });

  final TmdbMediaItem item;
  final String backdropUrl;
  final VoidCallback onPrimaryAction;
  final bool compactLayout;
  final VoidCallback? onSecondaryAction;
  final bool secondaryActive;
  final List<Widget> quickPlayButtons;

  @override
  Widget build(BuildContext context) {
    final l = S.of(context);
    final accent = _accent(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final hasQuickPlay = quickPlayButtons.isNotEmpty;
        final isCompact = compactLayout || width < 760;
        final isMedium = !isCompact && width < 1100;

        final heroHeight = isCompact
            ? (width * 0.70).clamp(320.0, 380.0)
            : (width * (hasQuickPlay ? 0.44 : 0.40)).clamp(
                isMedium ? 400.0 : 420.0,
                hasQuickPlay ? 520.0 : 500.0,
              );
        final contentMaxWidth = isCompact
            ? (width * 0.82).clamp(260.0, 320.0)
            : (width * (isMedium ? 0.52 : 0.46)).clamp(360.0, 480.0);
        final titleSize = isCompact
            ? 34.0
            : isMedium
                ? 44.0
                : 54.0;
        final overviewLines = isCompact
            ? 2
            : hasQuickPlay
                ? 2
                : 3;
        final contentPadding = isCompact
            ? const EdgeInsets.fromLTRB(24, 24, 24, 22)
            : isMedium
                ? const EdgeInsets.fromLTRB(36, 32, 36, 28)
                : const EdgeInsets.fromLTRB(48, 38, 48, 34);
        final titleLetterSpacing = isCompact
            ? -1.2
            : isMedium
                ? -1.6
                : -2.0;
        final overviewFontSize = isCompact
            ? DesignSystem.textSm
            : isMedium
                ? DesignSystem.textSm
                : DesignSystem.textBase;
        final overviewLineHeight = isCompact ? 1.45 : 1.6;
        final primaryLabel = isCompact ? l.discoverOpen : l.discoverExplore;
        final meta = <String>[
          if (item.year.isNotEmpty) item.year,
          item.mediaLabel,
          if (item.voteAverage > 0) '★ ${item.voteAverage.toStringAsFixed(1)}',
        ].join('   ');

        return Container(
          height: heroHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DesignSystem.radius2xl + 8),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.10),
                blurRadius: 30,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(DesignSystem.radius2xl + 8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (backdropUrl.isNotEmpty)
                  Image.network(
                    backdropUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _HeroFallback(item: item),
                  )
                else
                  _HeroFallback(item: item),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          const Color(0xFF111827).withValues(alpha: 0.78),
                          const Color(0xFF111827).withValues(alpha: 0.38),
                          const Color(0xFF111827).withValues(alpha: 0.14),
                        ],
                        stops: const [0.0, 0.34, 1.0],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: contentPadding,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: contentMaxWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(
                                DesignSystem.radiusFull,
                              ),
                            ),
                            child: Text(
                              l.discoverFeatured,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: DesignSystem.textSm,
                                fontWeight: DesignSystem.weightSemibold,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: isCompact
                                ? DesignSystem.space4
                                : DesignSystem.space5,
                          ),
                          Text(
                            item.title,
                            maxLines: isCompact ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: titleSize,
                              height: 0.95,
                              fontWeight: FontWeight.w800,
                              letterSpacing: titleLetterSpacing,
                            ),
                          ),
                          SizedBox(
                            height: isCompact
                                ? DesignSystem.space3
                                : DesignSystem.space4,
                          ),
                          Text(
                            meta,
                            style: const TextStyle(
                              color: Color(0xFFE5E7EB),
                              fontSize: DesignSystem.textSm,
                              fontWeight: DesignSystem.weightMedium,
                              letterSpacing: 0.6,
                            ),
                          ),
                          SizedBox(
                            height: isCompact
                                ? DesignSystem.space3
                                : DesignSystem.space4,
                          ),
                          Expanded(
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: Text(
                                item.overview.isEmpty
                                    ? 'No synopsis available yet.'
                                    : item.overview,
                                maxLines: overviewLines,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: const Color(0xFFF3F4F6),
                                  fontSize: overviewFontSize,
                                  height: overviewLineHeight,
                                  fontWeight: DesignSystem.weightRegular,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: isCompact
                                ? DesignSystem.space4
                                : DesignSystem.space5,
                          ),
                          Wrap(
                            spacing: DesignSystem.space3,
                            runSpacing: DesignSystem.space3,
                            children: [
                              FilledButton.icon(
                                onPressed: onPrimaryAction,
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF111827),
                                  minimumSize: const Size(0, 44),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: DesignSystem.space6,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      DesignSystem.radiusFull,
                                    ),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 20,
                                ),
                                label: Text(primaryLabel),
                              ),
                              if (!isCompact)
                                OutlinedButton.icon(
                                  onPressed: onSecondaryAction,
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor:
                                        secondaryActive ? accent : Colors.white,
                                    foregroundColor: secondaryActive
                                        ? Colors.white
                                        : const Color(0xFF111827),
                                    minimumSize: const Size(0, 44),
                                    side: BorderSide(
                                      color: secondaryActive
                                          ? accent
                                          : Colors.white.withValues(alpha: 0.92),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: DesignSystem.space5,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        DesignSystem.radiusFull,
                                      ),
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: DesignSystem.textBase,
                                      fontWeight: DesignSystem.weightSemibold,
                                    ),
                                  ),
                                  icon: Icon(
                                    secondaryActive
                                        ? Icons.bookmark_rounded
                                        : Icons.bookmark_border_rounded,
                                    size: 18,
                                  ),
                                  label: Text(
                                    secondaryActive
                                        ? S.of(context).bookmarkSaved
                                        : S.of(context).bookmarkSave,
                                  ),
                                ),
                            ],
                          ),
                          if (hasQuickPlay) ...[
                            const SizedBox(height: DesignSystem.space4),
                            SizedBox(
                              width: double.infinity,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    for (var index = 0;
                                        index < quickPlayButtons.length;
                                        index++) ...[
                                      if (index > 0)
                                        const SizedBox(
                                          width: DesignSystem.space3,
                                        ),
                                      quickPlayButtons[index],
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _accent(BuildContext context) {
    final mode = context.read<ThemeProvider>().themeMode;
    if (mode == AppThemeMode.cyberpunk) return AppTheme.cyberNeon;
    if (mode == AppThemeMode.sweetiePro) return AppTheme.sweetieHotPink;
    return Theme.of(context).colorScheme.primary;
  }
}

class _HeroFallback extends StatelessWidget {
  const _HeroFallback({required this.item});

  final TmdbMediaItem item;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF111827),
            Color(0xFF1F2937),
            Color(0xFF334155),
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(DesignSystem.space8),
          child: Text(
            item.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.5,
            ),
          ),
        ),
      ),
    );
  }
}
