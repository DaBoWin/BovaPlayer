import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../theme/design_system.dart';

class DesktopSidebarDestination {
  const DesktopSidebarDestination({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool isSelected;
  final VoidCallback onTap;
}

class DesktopSidebar extends StatelessWidget {
  const DesktopSidebar({
    super.key,
    required this.isExpanded,
    required this.profileName,
    required this.profileSubtitle,
    required this.avatar,
    required this.destinations,
    required this.onToggle,
    this.onAccountTap,
    this.onLogoutTap,
    this.onSettingsTap,
  });

  final bool isExpanded;
  final String profileName;
  final String profileSubtitle;
  final Widget avatar;
  final List<DesktopSidebarDestination> destinations;
  final VoidCallback onToggle;
  final VoidCallback? onAccountTap;
  final VoidCallback? onLogoutTap;
  final VoidCallback? onSettingsTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeMode = context.watch<ThemeProvider>().themeMode;
    final isCyberpunk = themeMode == AppThemeMode.cyberpunk;
    final isSweetieSide = themeMode == AppThemeMode.sweetiePro;
    final isSpecialSide = isCyberpunk || isSweetieSide;
    final specialNeonSide = isSweetieSide ? AppTheme.sweetieHotPink : AppTheme.cyberNeon;
    final l = S.of(context);

    final sidebarBg = isSpecialSide
        ? (isSweetieSide ? const Color(0xFFFFF0F5) : const Color(0xFF0E0E1A))
        : isDark
            ? const Color(0xFF141418)
            : const Color(0xFFF4F5F7);
    final sidebarBorder = isSpecialSide
        ? specialNeonSide.withValues(alpha: 0.12)
        : isDark
            ? const Color(0xFF2A2A30).withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.7);
    final menuIconColor = isSpecialSide
        ? specialNeonSide.withValues(alpha: 0.6)
        : isDark
            ? const Color(0xFF8888A0)
            : const Color(0xFF6B7280);

    return AnimatedContainer(
      duration: DesignSystem.durationSlow,
      curve: DesignSystem.easeOutQuart,
      width: isExpanded ? 276 : 104,
      padding: EdgeInsets.fromLTRB(
          isExpanded ? 16 : 12, 18, isExpanded ? 16 : 12, 16),
      decoration: BoxDecoration(
        color: sidebarBg,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: sidebarBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: isExpanded ? Alignment.centerRight : Alignment.center,
            child: IconButton(
              onPressed: onToggle,
              icon: Icon(
                isExpanded ? Icons.menu_open_rounded : Icons.menu_rounded,
                color: menuIconColor,
              ),
              tooltip: isExpanded ? l.sidebarCollapse : l.sidebarExpand,
            ),
          ),
          const SizedBox(height: 8),
          _SidebarProfileCard(
            isExpanded: isExpanded,
            profileName: profileName,
            profileSubtitle: profileSubtitle,
            avatar: avatar,
          ),
          const SizedBox(height: 28),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemBuilder: (context, index) => _SidebarDestinationTile(
                destination: destinations[index],
                isExpanded: isExpanded,
              ),
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemCount: destinations.length,
            ),
          ),
          const SizedBox(height: 12),
          if (onSettingsTap != null)
            _SidebarFooterAction(
              icon: Icons.settings_outlined,
              label: l.settingsTitle,
              isExpanded: isExpanded,
              onTap: onSettingsTap!,
            ),
          if (onSettingsTap != null) const SizedBox(height: 8),
          if (onLogoutTap != null)
            _SidebarFooterAction(
              icon: Icons.logout_rounded,
              label: l.sidebarSignOut,
              isExpanded: isExpanded,
              onTap: onLogoutTap!,
              destructive: true,
            ),
        ],
      ),
    );
  }
}

class _SidebarProfileCard extends StatelessWidget {
  const _SidebarProfileCard({
    required this.isExpanded,
    required this.profileName,
    required this.profileSubtitle,
    required this.avatar,
  });

  final bool isExpanded;
  final String profileName;
  final String profileSubtitle;
  final Widget avatar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeMode = context.watch<ThemeProvider>().themeMode;
    final isCyberpunk = themeMode == AppThemeMode.cyberpunk;
    final isSweetieProfile = themeMode == AppThemeMode.sweetiePro;
    final isSpecialProfile = isCyberpunk || isSweetieProfile;
    final specialNeonProfile = isSweetieProfile ? AppTheme.sweetieHotPink : AppTheme.cyberNeon;
    final specialCardProfile = isSweetieProfile ? AppTheme.sweetieCard : AppTheme.cyberCard;

    final cardBg = isSpecialProfile
        ? specialCardProfile.withValues(alpha: 0.9)
        : isDark
            ? const Color(0xFF1E1E24).withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.9);
    final accentColor = isSpecialProfile ? specialNeonProfile : theme.colorScheme.primary;
    final subtitleColor = isSpecialProfile
        ? specialNeonProfile.withValues(alpha: 0.4)
        : isDark
            ? const Color(0xFF6B6B75)
            : DesignSystem.neutral400;
    final dotBorderColor = isSpecialProfile
        ? specialCardProfile
        : isDark
            ? const Color(0xFF1E1E24)
            : Colors.white;

    return AnimatedContainer(
      duration: DesignSystem.durationSlow,
      curve: DesignSystem.easeOutQuart,
      padding: EdgeInsets.symmetric(
          horizontal: isExpanded ? 18 : 6, vertical: isExpanded ? 18 : 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(28),
        border: isSpecialProfile
            ? Border.all(color: specialNeonProfile.withValues(alpha: 0.1))
            : null,
        boxShadow: isSpecialProfile
            ? [
                BoxShadow(
                  color: specialNeonProfile.withValues(alpha: 0.05),
                  blurRadius: 12,
                )
              ]
            : DesignSystem.shadowSm,
      ),
      child: isExpanded
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipOval(
                            child:
                                SizedBox(width: 52, height: 52, child: avatar)),
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                        color: isSpecialProfile
                                  ? specialNeonProfile
                                  : const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(99),
                              border:
                                  Border.all(color: dotBorderColor, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  S.of(context).profileGreeting(profileName),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: DesignSystem.weightSemibold,
                    color: accentColor,
                    letterSpacing: isSpecialProfile ? 0.5 : -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  profileSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: DesignSystem.textSm,
                    color: subtitleColor,
                  ),
                ),
              ],
            )
          : Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipOval(
                      child: SizedBox(width: 44, height: 44, child: avatar)),
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: isSpecialProfile
                            ? specialNeonProfile
                            : const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: dotBorderColor, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SidebarDestinationTile extends StatelessWidget {
  const _SidebarDestinationTile({
    required this.destination,
    required this.isExpanded,
  });

  final DesktopSidebarDestination destination;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeMode = context.watch<ThemeProvider>().themeMode;
    final isCyberpunk = themeMode == AppThemeMode.cyberpunk;
    final isSweetieTile = themeMode == AppThemeMode.sweetiePro;
    final isSpecialTile = isCyberpunk || isSweetieTile;
    final specialNeonTile = isSweetieTile ? AppTheme.sweetieHotPink : AppTheme.cyberNeon;

    final accent = isSpecialTile ? specialNeonTile : theme.colorScheme.primary;
    final inactiveColor = isSpecialTile
        ? (isSweetieTile ? const Color(0xFF885566) : const Color(0xFF555570))
        : isDark
            ? const Color(0xFF6B6B75)
            : const Color(0xFF9CA3AF);
    final foreground = destination.isSelected ? accent : inactiveColor;
    final selectedBg = isSpecialTile
        ? specialNeonTile.withValues(alpha: 0.08)
        : isDark
            ? const Color(0xFF1E1E24)
            : Colors.white;

    return InkWell(
      onTap: destination.onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: DesignSystem.durationNormal,
        curve: DesignSystem.easeOutQuart,
        height: 54,
        padding: EdgeInsets.symmetric(horizontal: isExpanded ? 16 : 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: destination.isSelected ? selectedBg : Colors.transparent,
          border: destination.isSelected && isSpecialTile
              ? Border.all(color: specialNeonTile.withValues(alpha: 0.15))
              : null,
        ),
        child: Row(
          mainAxisAlignment:
              isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            Container(
              width: 4,
              height: destination.isSelected ? 34 : 10,
              decoration: BoxDecoration(
                color: destination.isSelected ? accent : Colors.transparent,
                borderRadius: BorderRadius.circular(99),
                boxShadow: destination.isSelected && isSpecialTile
                    ? [
                        BoxShadow(
                          color: specialNeonTile.withValues(alpha: 0.4),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
            ),
            SizedBox(width: isExpanded ? 14 : 0),
            Icon(
              destination.isSelected
                  ? destination.activeIcon
                  : destination.icon,
              size: 22,
              color: foreground,
            ),
            if (isExpanded) ...[
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: DesignSystem.textLg,
                    fontWeight: destination.isSelected
                        ? DesignSystem.weightSemibold
                        : DesignSystem.weightMedium,
                    color: foreground,
                    letterSpacing: isSpecialTile ? 0.3 : -0.4,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SidebarFooterAction extends StatelessWidget {
  const _SidebarFooterAction({
    required this.icon,
    required this.label,
    required this.isExpanded,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final bool isExpanded;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeMode = context.watch<ThemeProvider>().themeMode;
    final isCyberpunk = themeMode == AppThemeMode.cyberpunk;
    final isSweetieFooter = themeMode == AppThemeMode.sweetiePro;
    final isSpecialFooter = isCyberpunk || isSweetieFooter;
    final specialNeonFooter = isSweetieFooter ? AppTheme.sweetieHotPink : AppTheme.cyberNeon;
    final specialCardFooter = isSweetieFooter ? AppTheme.sweetieCard : AppTheme.cyberCard;

    final color = destructive
        ? (isCyberpunk
            ? AppTheme.cyberPink
            : isSweetieFooter
                ? AppTheme.sweetieHotPink
                : theme.colorScheme.primary)
        : isSpecialFooter
            ? specialNeonFooter.withValues(alpha: 0.6)
            : isDark
                ? const Color(0xFF8888A0)
                : const Color(0xFF6B7280);
    final bgColor = isSpecialFooter
        ? specialCardFooter.withValues(alpha: 0.8)
        : isDark
            ? const Color(0xFF1E1E24).withValues(alpha: 0.8)
            : Colors.white.withValues(alpha: 0.8);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 48,
        padding: EdgeInsets.symmetric(horizontal: isExpanded ? 14 : 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: bgColor,
        ),
        child: Row(
          mainAxisAlignment:
              isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            if (isExpanded) ...[
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: DesignSystem.weightMedium,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
