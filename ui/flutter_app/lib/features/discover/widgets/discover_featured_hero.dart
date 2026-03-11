import 'package:flutter/material.dart';

import '../../../core/theme/design_system.dart';
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
    final heroHeight = compactLayout ? 330.0 : 446.0;
    final contentMaxWidth = compactLayout ? 280.0 : 430.0;
    final titleSize = compactLayout ? 34.0 : 54.0;
    final overviewLines = compactLayout ? 2 : 4;
    final contentPadding = compactLayout
        ? const EdgeInsets.fromLTRB(24, 24, 24, 22)
        : const EdgeInsets.fromLTRB(48, 38, 48, 34);
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
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFE11D48).withValues(alpha: 0.92),
                          borderRadius:
                              BorderRadius.circular(DesignSystem.radiusFull),
                        ),
                        child: const Text(
                          'Featured',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: DesignSystem.textSm,
                            fontWeight: DesignSystem.weightSemibold,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: compactLayout
                            ? DesignSystem.space4
                            : DesignSystem.space6,
                      ),
                      Text(
                        item.title,
                        maxLines: compactLayout ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: titleSize,
                          height: 0.95,
                          fontWeight: FontWeight.w800,
                          letterSpacing: compactLayout ? -1.2 : -2.0,
                        ),
                      ),
                      SizedBox(
                        height: compactLayout
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
                        height: compactLayout
                            ? DesignSystem.space3
                            : DesignSystem.space5,
                      ),
                      Text(
                        item.overview.isEmpty
                            ? 'No synopsis available yet.'
                            : item.overview,
                        maxLines: overviewLines,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFFF3F4F6),
                          fontSize: compactLayout
                              ? DesignSystem.textSm
                              : DesignSystem.textBase,
                          height: compactLayout ? 1.45 : 1.7,
                          fontWeight: DesignSystem.weightRegular,
                        ),
                      ),
                      SizedBox(
                        height: compactLayout
                            ? DesignSystem.space4
                            : DesignSystem.space6,
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
                            icon:
                                const Icon(Icons.play_arrow_rounded, size: 20),
                            label: Text(compactLayout ? '打开' : 'Explore'),
                          ),
                          if (!compactLayout)
                            OutlinedButton.icon(
                              onPressed: onSecondaryAction,
                              style: OutlinedButton.styleFrom(
                                backgroundColor: secondaryActive
                                    ? const Color(0xFFE11D48)
                                    : Colors.white,
                                foregroundColor: secondaryActive
                                    ? Colors.white
                                    : const Color(0xFF111827),
                                minimumSize: const Size(0, 44),
                                side: BorderSide(
                                  color: secondaryActive
                                      ? const Color(0xFFE11D48)
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
                              label: Text(secondaryActive ? 'Saved' : 'Save'),
                            ),
                        ],
                      ),
                      if (quickPlayButtons.isNotEmpty) ...[
                        const SizedBox(height: DesignSystem.space4),
                        Wrap(
                          spacing: DesignSystem.space3,
                          runSpacing: DesignSystem.space3,
                          children: quickPlayButtons,
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
