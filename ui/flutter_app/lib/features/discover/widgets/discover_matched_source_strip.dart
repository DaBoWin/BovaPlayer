import 'package:flutter/material.dart';

import '../../../core/theme/design_system.dart';
import '../services/discover_library_resolver_service.dart';
import 'discover_latency_indicator.dart';

class DiscoverMatchedSourceStrip extends StatelessWidget {
  const DiscoverMatchedSourceStrip({
    super.key,
    required this.matches,
    required this.onTap,
    this.height = 36,
    this.chipMaxWidth = 188,
  });

  final List<DiscoverLibraryMatch> matches;
  final ValueChanged<DiscoverLibraryMatch> onTap;
  final double height;
  final double chipMaxWidth;

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return const SizedBox.shrink();
    }

    final primaryMatch = matches.first;
    final hasMore = matches.length > 1;

    return SizedBox(
      width: double.infinity,
      height: height,
      child: Row(
        children: [
          Expanded(
            child: _DiscoverSourceChip(
              label: primaryMatch.source.name,
              latencyMs: primaryMatch.responseTimeMs,
              maxWidth: chipMaxWidth,
              onTap: () => onTap(primaryMatch),
            ),
          ),
          if (hasMore) ...[
            const SizedBox(width: 8),
            _DiscoverSourceMenuButton(
              matches: matches,
              hiddenCount: matches.length - 1,
              onSelected: onTap,
            ),
          ],
        ],
      ),
    );
  }
}

class _DiscoverSourceChip extends StatefulWidget {
  const _DiscoverSourceChip({
    required this.label,
    required this.latencyMs,
    required this.maxWidth,
    required this.onTap,
  });

  final String label;
  final int? latencyMs;
  final double maxWidth;
  final VoidCallback onTap;

  @override
  State<_DiscoverSourceChip> createState() => _DiscoverSourceChipState();
}

class _DiscoverSourceChipState extends State<_DiscoverSourceChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: DesignSystem.durationFast,
          curve: DesignSystem.easeOutQuart,
          transform: Matrix4.identity()
            ..translateByDouble(0.0, _isHovered ? -1.0 : 0.0, 0.0, 1.0),
          constraints: BoxConstraints(
            maxWidth: widget.maxWidth,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.98),
            borderRadius: BorderRadius.circular(DesignSystem.radiusFull),
            border: Border.all(
              color: DesignSystem.neutral200.withValues(alpha: 0.92),
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: const Color(0xFF111827).withValues(alpha: 0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 7),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: const Color(0xFF111827).withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              const Icon(
                Icons.play_circle_fill_rounded,
                size: 15,
                color: Color(0xFFE11D48),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: DesignSystem.textSm,
                    fontWeight: DesignSystem.weightSemibold,
                    color: DesignSystem.neutral900,
                    letterSpacing: -0.15,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              DiscoverLatencyIndicator(
                latencyMs: widget.latencyMs,
                compact: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoverSourceMenuButton extends StatefulWidget {
  const _DiscoverSourceMenuButton({
    required this.matches,
    required this.hiddenCount,
    required this.onSelected,
  });

  final List<DiscoverLibraryMatch> matches;
  final int hiddenCount;
  final ValueChanged<DiscoverLibraryMatch> onSelected;

  @override
  State<_DiscoverSourceMenuButton> createState() =>
      _DiscoverSourceMenuButtonState();
}

class _DiscoverSourceMenuButtonState extends State<_DiscoverSourceMenuButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<DiscoverLibraryMatch>(
      tooltip: '展开另外 ${widget.hiddenCount} 个媒体源',
      onSelected: widget.onSelected,
      color: Colors.white,
      elevation: 10,
      offset: const Offset(0, 8),
      constraints: const BoxConstraints(
        minWidth: 220,
        maxWidth: 260,
        maxHeight: 280,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: DesignSystem.neutral200.withValues(alpha: 0.9),
        ),
      ),
      padding: EdgeInsets.zero,
      itemBuilder: (context) => [
        for (final match in widget.matches)
          PopupMenuItem<DiscoverLibraryMatch>(
            value: match,
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: _DiscoverSourceMenuItem(match: match),
          ),
      ],
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: DesignSystem.durationFast,
          curve: DesignSystem.easeOutQuart,
          transform: Matrix4.identity()
            ..translateByDouble(0.0, _isHovered ? -1.0 : 0.0, 0.0, 1.0),
          constraints: const BoxConstraints(
            minWidth: 26,
            minHeight: 26,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: const Color(0xFFFBCFE8),
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: const Color(0xFF111827).withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: const Color(0xFF111827).withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Center(
            child: Text(
              '+${widget.hiddenCount}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: DesignSystem.weightSemibold,
                color: Color(0xFFBE123C),
                height: 1,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscoverSourceMenuItem extends StatelessWidget {
  const _DiscoverSourceMenuItem({required this.match});

  final DiscoverLibraryMatch match;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.play_circle_fill_rounded,
          size: 15,
          color: Color(0xFFE11D48),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            match.source.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: DesignSystem.textSm,
              fontWeight: DesignSystem.weightSemibold,
              color: DesignSystem.neutral900,
              letterSpacing: -0.15,
            ),
          ),
        ),
        const SizedBox(width: 8),
        DiscoverLatencyIndicator(
          latencyMs: match.responseTimeMs,
          compact: true,
        ),
      ],
    );
  }
}
