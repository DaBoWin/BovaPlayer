import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeMode = context.watch<ThemeProvider>().themeMode;
    final isCyberpunk = themeMode == AppThemeMode.cyberpunk;
    final isSweetie = themeMode == AppThemeMode.sweetiePro;
    final isSpecial = isCyberpunk || isSweetie;
    final specialNeon = isSweetie ? AppTheme.sweetieHotPink : AppTheme.cyberNeon;
    final specialBg = isSweetie ? const Color(0xFFFFF0F5) : const Color(0xFF0E0E1A);

    final navBg = isSpecial
        ? specialBg.withValues(alpha: 0.94)
        : isDark
            ? const Color(0xFF141418).withValues(alpha: 0.94)
            : const Color(0xFFF4F5F7).withValues(alpha: 0.94);
    final navBorder = isSpecial
        ? specialNeon.withValues(alpha: 0.12)
        : isDark
            ? const Color(0xFF2A2A30).withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.92);
    final navShadowColor = isSpecial
        ? specialNeon.withValues(alpha: 0.06)
        : DesignSystem.neutral900.withValues(alpha: 0.07);

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
              color: navBg,
              borderRadius: BorderRadius.circular(DesignSystem.radius2xl),
              border: Border.all(color: navBorder),
              boxShadow: [
                BoxShadow(
                  color: navShadowColor,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeMode = context.watch<ThemeProvider>().themeMode;
    final isCyberpunk = themeMode == AppThemeMode.cyberpunk;
    final isSweetieNav = themeMode == AppThemeMode.sweetiePro;
    final isSpecialNav = isCyberpunk || isSweetieNav;
    final specialNeonNav = isSweetieNav ? AppTheme.sweetieHotPink : AppTheme.cyberNeon;

    final accentColor = isSpecialNav ? specialNeonNav : theme.colorScheme.primary;
    final inactiveColor = isSpecialNav
        ? (isSweetieNav ? const Color(0xFFCC88AA) : const Color(0xFF555570))
        : isDark
            ? const Color(0xFF6B6B75)
            : DesignSystem.neutral500;
    final foregroundColor = widget.isSelected ? accentColor : inactiveColor;

    final selectedBg = isSpecialNav
        ? specialNeonNav.withValues(alpha: 0.08)
        : isDark
            ? const Color(0xFF1E1E24).withValues(alpha: 0.98)
            : Colors.white.withValues(alpha: 0.98);
    final selectedBorder = isSpecialNav
        ? specialNeonNav.withValues(alpha: 0.2)
        : isDark
            ? const Color(0xFF2A2A30)
            : const Color(0xFFFBCFE8);

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
            color: widget.isSelected ? selectedBg : Colors.transparent,
            borderRadius: BorderRadius.circular(DesignSystem.radiusFull),
            border: widget.isSelected
                ? Border.all(color: selectedBorder)
                : null,
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: isSpecialNav
                          ? specialNeonNav.withValues(alpha: 0.08)
                          : const Color(0xFF111827).withValues(alpha: 0.05),
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
                  color: accentColor,
                  borderRadius: BorderRadius.circular(DesignSystem.radiusFull),
                  boxShadow: isSpecialNav && widget.isSelected
                      ? [
                          BoxShadow(
                            color: specialNeonNav.withValues(alpha: 0.5),
                            blurRadius: 4,
                          ),
                        ]
                      : null,
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
                  letterSpacing: isSpecialNav ? 0.3 : -0.1,
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
