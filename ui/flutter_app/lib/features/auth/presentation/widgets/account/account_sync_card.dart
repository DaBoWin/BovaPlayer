import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/design_system.dart';
import '../../../../../core/widgets/bova_button.dart';
import '../../../../../core/widgets/bova_text_field.dart';
import '../../../../../l10n/generated/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../pages/pricing_page.dart';
import 'account_theme.dart';

/// Cloud sync card — shows sync status and enable button.
class AccountSyncCard extends StatelessWidget {
  const AccountSyncCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AccountColors.of(context);
    final l = S.of(context);

    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.user;
        if (user == null) return const SizedBox.shrink();

        final isSyncEnabled = authProvider.isSyncEnabled;
        final isPro = user.isPro;

        final subtitle = isSyncEnabled
            ? l.accountSyncEnabledDesc
            : (isPro ? l.accountSyncDisabledProDesc : l.accountSyncDisabledFreeDesc);

        return AccountSurfacePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AccountSectionHeader(
                icon: isSyncEnabled
                    ? Icons.cloud_done_outlined
                    : Icons.cloud_outlined,
                title: l.accountSyncTitle,
                subtitle: subtitle,
                iconColor: isSyncEnabled ? DesignSystem.success : c.accent,
                iconBackground: isSyncEnabled
                    ? DesignSystem.success.withValues(alpha: 0.12)
                    : c.accentSoft,
                trailing: !isPro
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DesignSystem.space2,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: DesignSystem.warning.withValues(alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(DesignSystem.radiusFull),
                        ),
                        child: const Text(
                          'Pro',
                          style: TextStyle(
                            fontSize: DesignSystem.textXs,
                            fontWeight: DesignSystem.weightSemibold,
                            color: DesignSystem.warning,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: DesignSystem.space4),
              if (!isSyncEnabled) ...[
                const SizedBox(height: DesignSystem.space4),
                BovaButton(
                  text: isPro ? l.accountEnableSync : l.accountViewUpgrade,
                  icon: isPro
                      ? Icons.lock_open_outlined
                      : Icons.workspace_premium,
                  onPressed: isPro
                      ? () => _showEnableSyncDialog(context, authProvider)
                      : () => _openPricingPage(context),
                  isFullWidth: true,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _openPricingPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PricingPage()),
    );
  }

  Future<void> _showEnableSyncDialog(
      BuildContext context, AuthProvider authProvider) async {
    final c = AccountColors.of(context);
    final l = S.of(context);
    final passwordController = TextEditingController();
    bool isSubmitting = false;

    final enabled = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: c.panel,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignSystem.radiusXl),
              ),
              title: Text(
                l.accountEnableSyncTitle,
                style: TextStyle(
                  color: c.textPrimary,
                  fontWeight: DesignSystem.weightSemibold,
                ),
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.accountEnableSyncMessage,
                      style: TextStyle(
                        fontSize: DesignSystem.textSm,
                        color: c.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: DesignSystem.space4),
                    BovaTextField(
                      controller: passwordController,
                      label: l.accountPasswordLabel,
                      hint: l.accountPasswordHint,
                      prefixIcon: Icons.lock_outline,
                      obscureText: true,
                      enabled: !isSubmitting,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: Text(
                    l.cancel,
                    style: TextStyle(color: c.textSecondary),
                  ),
                ),
                FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final password = passwordController.text.trim();
                          if (password.isEmpty) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text(l.accountPasswordRequired),
                                backgroundColor: DesignSystem.error,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }
                          setState(() => isSubmitting = true);
                          final success = await authProvider
                              .enableSyncWithPassword(password);
                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext, success);
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(l.accountEnableSyncButton),
                ),
              ],
            );
          },
        );
      },
    );

    passwordController.dispose();
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    if (enabled == true) {
      messenger.showSnackBar(SnackBar(
        content: Text(l.accountSyncEnabledSuccess),
        backgroundColor: DesignSystem.neutral900,
        behavior: SnackBarBehavior.floating,
      ));
    } else if (enabled == false) {
      messenger.showSnackBar(SnackBar(
        content: Text(l.accountSyncEnableFailed),
        backgroundColor: DesignSystem.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }
}
