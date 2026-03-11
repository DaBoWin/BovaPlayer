import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/design_system.dart';

class BovaBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<BovaBottomNavItem> items;

  const BovaBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DesignSystem.space3,
        0,
        DesignSystem.space3,
        DesignSystem.space3,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DesignSystem.radius2xl),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: DesignSystem.blurMedium,
            sigmaY: DesignSystem.blurMedium,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF4F5F7).withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(DesignSystem.radius2xl),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.92),
              ),
              boxShadow: [
                BoxShadow(
                  color: DesignSystem.neutral900.withValues(alpha: 0.07),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 74,
                child: Row(
                  children: List.generate(
                    items.length,
                    (index) => Expanded(
                      child: _BottomNavItemWidget(
                        item: items[index],
                        isSelected: currentIndex == index,
                        onTap: () => onTap(index),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItemWidget extends StatefulWidget {
  final BovaBottomNavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _BottomNavItemWidget({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_BottomNavItemWidget> createState() => _BottomNavItemWidgetState();
}

class _BottomNavItemWidgetState extends State<_BottomNavItemWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _iconScaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: DesignSystem.durationNormal,
      vsync: this,
    );

    _iconScaleAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _controller, curve: DesignSystem.easeOutQuart),
    );

    if (widget.isSelected) {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(_BottomNavItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foregroundColor =
        widget.isSelected ? const Color(0xFFE11D48) : DesignSystem.neutral500;

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AnimatedContainer(
          duration: DesignSystem.durationNormal,
          curve: DesignSystem.easeOutQuart,
          padding: const EdgeInsets.symmetric(
            horizontal: DesignSystem.space4,
            vertical: DesignSystem.space2 + 1,
          ),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? Colors.white.withValues(alpha: 0.98)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(DesignSystem.radiusFull),
            border: widget.isSelected
                ? Border.all(
                    color: const Color(0xFFFBCFE8),
                  )
                : null,
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF111827).withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: DesignSystem.durationNormal,
                curve: DesignSystem.easeOutQuart,
                width: widget.isSelected ? 18 : 0,
                height: 3,
                margin: EdgeInsets.only(bottom: widget.isSelected ? 5 : 0),
                decoration: BoxDecoration(
                  color: const Color(0xFFE11D48),
                  borderRadius: BorderRadius.circular(DesignSystem.radiusFull),
                ),
              ),
              ScaleTransition(
                scale: _iconScaleAnimation,
                child: Icon(
                  widget.isSelected ? widget.item.activeIcon : widget.item.icon,
                  size: 24,
                  color: foregroundColor,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: DesignSystem.durationNormal,
                curve: DesignSystem.easeOutQuart,
                style: TextStyle(
                  fontSize: DesignSystem.textXs,
                  fontWeight: widget.isSelected
                      ? DesignSystem.weightSemibold
                      : DesignSystem.weightMedium,
                  color: foregroundColor,
                  letterSpacing: -0.1,
                ),
                child: Text(widget.item.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BovaBottomNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const BovaBottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
