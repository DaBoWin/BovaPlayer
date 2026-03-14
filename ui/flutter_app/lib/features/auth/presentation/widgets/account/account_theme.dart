import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/providers/theme_provider.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/theme/design_system.dart';
import '../../../domain/entities/user.dart';

/// Runtime theme-aware colors for the Account module.
///
/// Usage: `final c = AccountColors.of(context);`
class AccountColors {
  final bool isDark;
  final bool isCyberpunk;
  final bool isSweetie;
  final ColorScheme colorScheme;

  AccountColors._(this.isDark, this.isCyberpunk, this.isSweetie, this.colorScheme);

  factory AccountColors.of(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final mode = context.read<ThemeProvider>().themeMode;
    return AccountColors._(
      brightness == Brightness.dark,
      mode == AppThemeMode.cyberpunk,
      mode == AppThemeMode.sweetiePro,
      Theme.of(context).colorScheme,
    );
  }

  bool get isSpecial => isCyberpunk || isSweetie;
  Color get _neon => isSweetie ? AppTheme.sweetieHotPink : AppTheme.cyberNeon;

  Color get accent => isSpecial ? _neon : colorScheme.primary;

  Color get accentSoft => isSpecial
      ? _neon.withValues(alpha: 0.10)
      : isDark
          ? colorScheme.primary.withValues(alpha: 0.15)
          : const Color(0xFFFCE7F3);

  Color get canvas => isSpecial
      ? (isSweetie ? AppTheme.sweetieBg : AppTheme.cyberBg)
      : isDark
          ? const Color(0xFF111114)
          : const Color(0xFFF1F3F6);

  Color get panel => isSpecial
      ? (isSweetie ? AppTheme.sweetieCard : AppTheme.cyberCard)
      : isDark
          ? const Color(0xFF1A1A1F)
          : Colors.white;

  Color get panelBorder => isSpecial
      ? _neon.withValues(alpha: 0.12)
      : isDark
          ? const Color(0xFF2A2A30)
          : const Color(0xFFE7EAF0);

  Color get textPrimary => colorScheme.onSurface;
  Color get textSecondary => colorScheme.onSurface.withValues(alpha: 0.6);
  Color get textTertiary => colorScheme.onSurface.withValues(alpha: 0.4);

  Color get overlayWhite => isDark || isCyberpunk
      ? Colors.white.withValues(alpha: 0.06)
      : Colors.white.withValues(alpha: 0.92);

  Color get overlayWhiteStrong => isDark || isCyberpunk
      ? Colors.white.withValues(alpha: 0.10)
      : Colors.white.withValues(alpha: 0.72);

  Color get overlayWhiteMedium => isDark || isCyberpunk
      ? Colors.white.withValues(alpha: 0.08)
      : Colors.white.withValues(alpha: 0.52);

  Color get dangerBackground => isDark || isCyberpunk
      ? DesignSystem.error.withValues(alpha: 0.10)
      : const Color(0xFFFFFBFB);

  Color get dangerBorder => isDark || isCyberpunk
      ? DesignSystem.error.withValues(alpha: 0.25)
      : const Color(0xFFF8D7DA);
}

/// Palette for different account levels (free / pro / lifetime).
class AccountPalette {
  final Color base;
  final Color surface;
  final Color deep;
  final Color text;
  final IconData icon;

  const AccountPalette({
    required this.base,
    required this.surface,
    required this.deep,
    required this.text,
    required this.icon,
  });

  static AccountPalette forType(AccountType type, AccountColors c) {
    switch (type) {
      case AccountType.free:
        return AccountPalette(
          base: const Color(0xFFFFD2E6),
          surface: const Color(0xFFFFF4F8),
          deep: c.accent,
          text: c.accent,
          icon: Icons.person_outline,
        );
      case AccountType.pro:
        return const AccountPalette(
          base: Color(0xFFFFD8BD),
          surface: Color(0xFFFFF3E8),
          deep: AppTheme.sweetiePeachGlow,
          text: Color(0xFFB56A1F),
          icon: Icons.workspace_premium_outlined,
        );
      case AccountType.lifetime:
        return const AccountPalette(
          base: Color(0xFFFEF3C7),
          surface: Color(0xFFFFFBEB),
          deep: DesignSystem.accent700,
          text: DesignSystem.accent700,
          icon: Icons.auto_awesome_outlined,
        );
    }
  }
}

/// Shared surface panel used across all account cards.
class AccountSurfacePanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final List<BoxShadow>? boxShadow;

  const AccountSurfacePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(DesignSystem.space5),
    this.backgroundColor,
    this.borderColor,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final c = AccountColors.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? c.panel,
        borderRadius: BorderRadius.circular(DesignSystem.radius2xl),
        border: Border.all(color: borderColor ?? c.panelBorder),
        boxShadow: boxShadow ?? DesignSystem.shadowSm,
      ),
      child: child,
    );
  }
}

/// Shared section header used across account cards.
class AccountSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? iconColor;
  final Color? iconBackground;
  final Widget? trailing;

  const AccountSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
    this.iconBackground,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final c = AccountColors.of(context);
    final effectiveIconColor = iconColor ?? c.accent;
    final effectiveIconBg = iconBackground ?? c.accentSoft;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: effectiveIconBg,
            borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
          ),
          child: Icon(icon, color: effectiveIconColor, size: 20),
        ),
        const SizedBox(width: DesignSystem.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: DesignSystem.textBase,
                  fontWeight: DesignSystem.weightSemibold,
                  color: c.textPrimary,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: DesignSystem.textSm,
                    color: c.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: DesignSystem.space3),
          trailing!,
        ],
      ],
    );
  }
}

/// Format a DateTime to yyyy-MM-dd.
String formatAccountDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
