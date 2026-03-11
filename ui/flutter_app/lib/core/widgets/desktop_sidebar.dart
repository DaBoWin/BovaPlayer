import 'package:flutter/material.dart';

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
  });

  final bool isExpanded;
  final String profileName;
  final String profileSubtitle;
  final Widget avatar;
  final List<DesktopSidebarDestination> destinations;
  final VoidCallback onToggle;
  final VoidCallback? onAccountTap;
  final VoidCallback? onLogoutTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: DesignSystem.durationSlow,
      curve: DesignSystem.easeOutQuart,
      width: isExpanded ? 276 : 104,
      padding: EdgeInsets.fromLTRB(
          isExpanded ? 16 : 12, 18, isExpanded ? 16 : 12, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
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
                color: const Color(0xFF6B7280),
              ),
              tooltip: isExpanded ? 'Collapse' : 'Expand',
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
          if (onAccountTap != null)
            _SidebarFooterAction(
              icon: Icons.settings_outlined,
              label: 'Account',
              isExpanded: isExpanded,
              onTap: onAccountTap!,
            ),
          if (onLogoutTap != null) const SizedBox(height: 8),
          if (onLogoutTap != null)
            _SidebarFooterAction(
              icon: Icons.logout_rounded,
              label: 'Sign out',
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
    return AnimatedContainer(
      duration: DesignSystem.durationSlow,
      curve: DesignSystem.easeOutQuart,
      padding: EdgeInsets.symmetric(
          horizontal: isExpanded ? 18 : 6, vertical: isExpanded ? 18 : 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(28),
        boxShadow: DesignSystem.shadowSm,
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
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Hi, $profileName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: DesignSystem.weightSemibold,
                    color: Color(0xFFE11D48),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  profileSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: DesignSystem.textSm,
                    color: DesignSystem.neutral400,
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
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: Colors.white, width: 2),
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
    const accent = Color(0xFFE11D48);
    final foreground =
        destination.isSelected ? accent : const Color(0xFF9CA3AF);

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
          color: destination.isSelected ? Colors.white : Colors.transparent,
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
                    letterSpacing: -0.4,
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
    final color =
        destructive ? const Color(0xFFE11D48) : const Color(0xFF6B7280);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 48,
        padding: EdgeInsets.symmetric(horizontal: isExpanded ? 14 : 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white.withValues(alpha: 0.8),
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
