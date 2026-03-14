import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_system.dart';

class DiscoverBookmarkButton extends StatefulWidget {
  const DiscoverBookmarkButton({
    super.key,
    required this.isActive,
    required this.onTap,
    this.size = 36,
  });

  final bool isActive;
  final VoidCallback onTap;
  final double size;

  @override
  State<DiscoverBookmarkButton> createState() =>
      _DiscoverBookmarkButtonState();
}

class _DiscoverBookmarkButtonState extends State<DiscoverBookmarkButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final mode = context.read<ThemeProvider>().themeMode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSpecial = mode == AppThemeMode.cyberpunk || mode == AppThemeMode.sweetiePro;
    final accent = mode == AppThemeMode.cyberpunk
        ? AppTheme.cyberNeon
        : mode == AppThemeMode.sweetiePro
            ? AppTheme.sweetieHotPink
            : Theme.of(context).colorScheme.primary;
    final inactiveColor = isDark || isSpecial
        ? Colors.white.withValues(alpha: 0.70)
        : DesignSystem.neutral700;
    final bgInactive = isDark || isSpecial
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.94);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        duration: DesignSystem.durationFast,
        curve: DesignSystem.easeOutQuart,
        scale: _isHovered ? 1.04 : 1.0,
        child: Material(
          color: widget.isActive
              ? accent.withValues(alpha: 0.14)
              : bgInactive,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: widget.onTap,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Icon(
                widget.isActive
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                color: widget.isActive ? accent : inactiveColor,
                size: widget.size * 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
