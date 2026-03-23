import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_system.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../services/discover_library_resolver_service.dart';
import 'discover_latency_indicator.dart';

class DiscoverMatchedSourceStrip extends StatefulWidget {
  const DiscoverMatchedSourceStrip({
    super.key,
    required this.matches,
    required this.onTap,
    this.height = 36,
    this.chipMaxWidth = 188,
  });

  final List<DiscoverLibraryMatch> matches;
  final Future<void> Function(DiscoverLibraryMatch match) onTap;
  final double height;
  final double chipMaxWidth;

  @override
  State<DiscoverMatchedSourceStrip> createState() =>
      _DiscoverMatchedSourceStripState();
}

class _DiscoverMatchedSourceStripState
    extends State<DiscoverMatchedSourceStrip> {
  bool _isCoolingDown = false;
  static const Duration _cooldownDuration = Duration(milliseconds: 1200);

  Future<void> _handleTap(DiscoverLibraryMatch match) async {
    if (_isCoolingDown) return;
    setState(() => _isCoolingDown = true);
    try {
      await widget.onTap(match);
    } finally {
      if (mounted) {
        Future<void>.delayed(_cooldownDuration, () {
          if (!mounted) return;
          setState(() => _isCoolingDown = false);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.matches.isEmpty) {
      return const SizedBox.shrink();
    }

    final primaryMatch = widget.matches.first;
    final hasMore = widget.matches.length > 1;

    return SizedBox(
      width: double.infinity,
      height: widget.height,
      child: Opacity(
        opacity: _isCoolingDown ? 0.68 : 1,
        child: Row(
          children: [
            Expanded(
              child: _DiscoverSourceChip(
                label: primaryMatch.source.name,
                latencyMs: primaryMatch.responseTimeMs,
                maxWidth: widget.chipMaxWidth,
                isCoolingDown: _isCoolingDown,
                onTap: () => _handleTap(primaryMatch),
              ),
            ),
            if (hasMore) ...[
              const SizedBox(width: 8),
              _DiscoverSourceMenuButton(
                matches: widget.matches,
                hiddenCount: widget.matches.length - 1,
                isCoolingDown: _isCoolingDown,
                onSelected: _handleTap,
              ),
            ],
          ],
        ),
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
    required this.isCoolingDown,
  });

  final String label;
  final int? latencyMs;
  final double maxWidth;
  final VoidCallback onTap;
  final bool isCoolingDown;

  @override
  State<_DiscoverSourceChip> createState() => _DiscoverSourceChipState();
}

class _DiscoverSourceChipState extends State<_DiscoverSourceChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = _resolveAccent(context);
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chipBg = widget.isCoolingDown
        ? (isDark
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.78)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.92))
        : (isDark ? scheme.surface : Colors.white.withValues(alpha: 0.98));
    final chipBorder = isDark
        ? scheme.outline.withValues(alpha: 0.15)
        : DesignSystem.neutral200.withValues(alpha: 0.92);
    final shadowColor =
        isDark ? Colors.black.withValues(alpha: 0.20) : const Color(0xFF111827);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.isCoolingDown ? null : widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: DesignSystem.durationFast,
          curve: DesignSystem.easeOutQuart,
          transform: Matrix4.identity()
            ..translateByDouble(
              0.0,
              _isHovered && !widget.isCoolingDown ? -1.0 : 0.0,
              0.0,
              1.0,
            ),
          constraints: BoxConstraints(
            maxWidth: widget.maxWidth,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: chipBg,
            borderRadius: BorderRadius.circular(DesignSystem.radiusFull),
            border: Border.all(color: chipBorder),
            boxShadow: _isHovered && !widget.isCoolingDown
                ? [
                    BoxShadow(
                      color: shadowColor.withValues(alpha: 0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 7),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: shadowColor.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Icon(
                Icons.play_circle_fill_rounded,
                size: 15,
                color: widget.isCoolingDown
                    ? scheme.onSurface.withValues(alpha: 0.52)
                    : accent,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: DesignSystem.textSm,
                    fontWeight: DesignSystem.weightSemibold,
                    color: scheme.onSurface.withValues(
                      alpha: widget.isCoolingDown ? 0.62 : 1,
                    ),
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
    required this.isCoolingDown,
  });

  final List<DiscoverLibraryMatch> matches;
  final int hiddenCount;
  final Future<void> Function(DiscoverLibraryMatch match) onSelected;
  final bool isCoolingDown;

  @override
  State<_DiscoverSourceMenuButton> createState() =>
      _DiscoverSourceMenuButtonState();
}

class _DiscoverSourceMenuButtonState extends State<_DiscoverSourceMenuButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = _resolveAccent(context);
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l = S.of(context);
    final chipBg = widget.isCoolingDown
        ? scheme.surfaceContainerHighest.withValues(alpha: 0.78)
        : (isDark ? scheme.surface : Colors.white);
    final accentBorder = accent.withValues(alpha: 0.25);

    return PopupMenuButton<DiscoverLibraryMatch>(
      enabled: !widget.isCoolingDown,
      tooltip: l.discoverExpandSources(widget.hiddenCount),
      onSelected: (match) {
        widget.onSelected(match);
      },
      color: scheme.surface,
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
          color: scheme.outline.withValues(alpha: 0.15),
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
            ..translateByDouble(
              0.0,
              _isHovered && !widget.isCoolingDown ? -1.0 : 0.0,
              0.0,
              1.0,
            ),
          constraints: const BoxConstraints(
            minWidth: 26,
            minHeight: 26,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: chipBg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: accentBorder,
            ),
            boxShadow: _isHovered && !widget.isCoolingDown
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Center(
            child: Text(
              '+${widget.hiddenCount}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: DesignSystem.weightSemibold,
                color: widget.isCoolingDown
                    ? scheme.onSurface.withValues(alpha: 0.52)
                    : accent,
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
    final accent = _resolveAccent(context);
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(
          Icons.play_circle_fill_rounded,
          size: 15,
          color: accent,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            match.source.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: DesignSystem.textSm,
              fontWeight: DesignSystem.weightSemibold,
              color: scheme.onSurface,
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

/// Shared accent color resolver for discover widgets.
Color _resolveAccent(BuildContext context) {
  final mode = context.read<ThemeProvider>().themeMode;
  if (mode == AppThemeMode.cyberpunk) return AppTheme.cyberNeon;
  if (mode == AppThemeMode.sweetiePro) return AppTheme.sweetieHotPink;
  return Theme.of(context).colorScheme.primary;
}
