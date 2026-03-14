import 'package:flutter/material.dart';

import '../../../../../core/theme/design_system.dart';
import '../../../../../l10n/generated/app_localizations.dart';
import '../../pages/redemption_admin_page.dart';
import 'account_theme.dart';

/// Admin tools card — redemption code management etc.
class AccountAdminCard extends StatelessWidget {
  const AccountAdminCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AccountColors.of(context);
    final l = S.of(context);

    return AccountSurfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AccountSectionHeader(
            icon: Icons.admin_panel_settings_outlined,
            title: l.accountAdminTools,
            subtitle: l.accountAdminDesc,
            iconColor: DesignSystem.warning,
            iconBackground: c.isDark || c.isSpecial
                ? DesignSystem.warning.withValues(alpha: 0.12)
                : const Color(0xFFFFF1E6),
          ),
          const SizedBox(height: DesignSystem.space4),
          _ActionTile(
            icon: Icons.confirmation_number_outlined,
            title: l.accountRedemptionManagement,
            subtitle: l.accountRedemptionDesc,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RedemptionAdminPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AccountColors.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
        child: Ink(
          padding: const EdgeInsets.all(DesignSystem.space4),
          decoration: BoxDecoration(
            color: c.isDark || c.isSpecial
                ? Colors.white.withValues(alpha: 0.04)
                : DesignSystem.neutral100,
            borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: c.panel,
                  borderRadius:
                      BorderRadius.circular(DesignSystem.radiusFull),
                ),
                child: Icon(icon, size: 20, color: c.textSecondary),
              ),
              const SizedBox(width: DesignSystem.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: DesignSystem.textSm,
                        fontWeight: DesignSystem.weightSemibold,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: DesignSystem.textXs,
                        color: c.textTertiary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: c.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
