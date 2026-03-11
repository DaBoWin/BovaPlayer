import 'package:flutter/material.dart';

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
    const accent = Color(0xFFE11D48);

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
              : Colors.white.withValues(alpha: 0.94),
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
                color: widget.isActive ? accent : DesignSystem.neutral700,
                size: widget.size * 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
