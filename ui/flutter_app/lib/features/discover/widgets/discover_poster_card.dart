import 'package:flutter/material.dart';

import '../../../core/theme/design_system.dart';
import '../models/tmdb_media_item.dart';

/// A poster card for discover section items. Text adapts to theme brightness.
class DiscoverPosterCard extends StatefulWidget {
  const DiscoverPosterCard({
    super.key,
    required this.item,
    required this.posterUrl,
    this.width,
    this.onTap,
    this.quickPlayButtons = const [],
    this.overlayAction,
    this.overlayBadge,
    this.overlayActionAlwaysVisible = false,
  });

  final TmdbMediaItem item;
  final String posterUrl;
  final double? width;
  final VoidCallback? onTap;
  final List<Widget> quickPlayButtons;
  final Widget? overlayAction;
  final Widget? overlayBadge;
  final bool overlayActionAlwaysVisible;

  @override
  State<DiscoverPosterCard> createState() => _DiscoverPosterCardState();
}

class _DiscoverPosterCardState extends State<DiscoverPosterCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final metaParts = <String>[
      if (widget.item.year.isNotEmpty) widget.item.year,
      widget.item.mediaLabel,
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedWidth = widget.width ?? constraints.maxWidth;

        return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            behavior: HitTestBehavior.deferToChild,
            child: AnimatedContainer(
              duration: DesignSystem.durationNormal,
              curve: DesignSystem.easeOutQuart,
              width: widget.width,
              transform: Matrix4.identity()
                ..translateByDouble(0.0, _isHovered ? -8.0 : 0.0, 0.0, 1.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: DesignSystem.durationNormal,
                    curve: DesignSystem.easeOutQuart,
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(DesignSystem.radiusXl),
                      boxShadow: _isHovered
                          ? [
                              BoxShadow(
                                color: const Color(0xFF111827)
                                    .withValues(alpha: 0.16),
                                blurRadius: 30,
                                offset: const Offset(0, 18),
                              ),
                            ]
                          : DesignSystem.shadowSm,
                    ),
                    child: AspectRatio(
                      aspectRatio: 0.704,
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(DesignSystem.radiusXl),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (widget.posterUrl.isNotEmpty)
                              Image.network(
                                widget.posterUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _PosterFallback(item: widget.item),
                              )
                            else
                              _PosterFallback(item: widget.item),
                            if (widget.overlayBadge != null)
                              Positioned(
                                right: 12,
                                bottom: 12,
                                child: AnimatedOpacity(
                                  duration: DesignSystem.durationFast,
                                  opacity: widget.overlayActionAlwaysVisible ||
                                          _isHovered
                                      ? 1.0
                                      : 0.92,
                                  child: widget.overlayBadge!,
                                ),
                              ),
                            if (widget.overlayAction != null)
                              Positioned(
                                top: 12,
                                right: 12,
                                child: AnimatedOpacity(
                                  duration: DesignSystem.durationFast,
                                  opacity: widget.overlayActionAlwaysVisible ||
                                          _isHovered
                                      ? 1.0
                                      : 0.84,
                                  child: widget.overlayAction!,
                                ),
                              ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withValues(alpha: 0.12),
                                        Colors.black.withValues(alpha: 0.48),
                                      ],
                                    ),
                                  ),
                                  child: SizedBox(height: resolvedWidth * 0.24),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: DesignSystem.textLg,
                      fontWeight: DesignSystem.weightSemibold,
                      color: Theme.of(context).colorScheme.onSurface,
                      letterSpacing: -0.4,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    metaParts.join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: DesignSystem.textSm,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                      fontWeight: DesignSystem.weightMedium,
                      height: 1.15,
                    ),
                  ),
                  if (widget.quickPlayButtons.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var index = 0;
                            index < widget.quickPlayButtons.length;
                            index++) ...[
                          if (index > 0) const SizedBox(height: 8),
                          widget.quickPlayButtons[index],
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PosterFallback extends StatelessWidget {
  const _PosterFallback({required this.item});

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
            Color(0xFF374151),
            Color(0xFF6B7280),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DesignSystem.space5),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Text(
            item.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: DesignSystem.textLg,
              fontWeight: DesignSystem.weightBold,
              height: 1.05,
            ),
          ),
        ),
      ),
    );
  }
}
