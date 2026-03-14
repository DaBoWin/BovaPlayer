import 'package:flutter/material.dart';

import '../../../../../core/theme/design_system.dart';
import '../../../../../l10n/generated/app_localizations.dart';
import '../../providers/auth_provider.dart';
import 'account_theme.dart';

/// Logout card with confirmation dialog.
class AccountLogoutCard extends StatelessWidget {
  final AuthProvider authProvider;
  const AccountLogoutCard({super.key, required this.authProvider});

  @override
  Widget build(BuildContext context) {
    final c = AccountColors.of(context);
    final l = S.of(context);

    return AccountSurfacePanel(
      backgroundColor: c.dangerBackground,
      borderColor: c.dangerBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AccountSectionHeader(
            icon: Icons.logout_rounded,
            title: l.accountLogout,
            subtitle: l.accountLogoutDesc,
            iconColor: DesignSystem.error,
            iconBackground: c.isDark || c.isSpecial
                ? DesignSystem.error.withValues(alpha: 0.15)
                : const Color(0xFFFEE2E2),
          ),
          const SizedBox(height: DesignSystem.space4),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showLogoutDialog(context),
              icon: const Icon(Icons.logout, size: 18),
              label: Text(l.accountLogoutButton),
              style: OutlinedButton.styleFrom(
                foregroundColor: DesignSystem.error,
                side: const BorderSide(
                    color: DesignSystem.error, width: 1.5),
                padding: const EdgeInsets.symmetric(
                    vertical: DesignSystem.space4),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(DesignSystem.radiusFull),
                ),
                textStyle: const TextStyle(
                  fontSize: DesignSystem.textBase,
                  fontWeight: DesignSystem.weightSemibold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    final c = AccountColors.of(context);
    final l = S.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: c.panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignSystem.radiusXl),
          ),
          title: Text(
            l.accountLogoutConfirmTitle,
            style: TextStyle(
              color: c.textPrimary,
              fontWeight: DesignSystem.weightSemibold,
            ),
          ),
          content: Text(
            l.accountLogoutConfirmMessage,
            style: TextStyle(
              color: c.textSecondary,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                l.cancel,
                style: TextStyle(color: c.textSecondary),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: DesignSystem.error,
                foregroundColor: Colors.white,
              ),
              child: Text(l.accountLogoutButton),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    Navigator.of(context).pop();
    await authProvider.logout();
  }
}
