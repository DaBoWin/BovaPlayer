import 'package:flutter/material.dart';

import '../../../../../core/theme/design_system.dart';
import '../../../../../l10n/generated/app_localizations.dart';
import '../../../domain/entities/user.dart';
import '../../pages/pricing_page.dart';
import 'account_theme.dart';

/// Upgrade CTA card — prompts free→pro or pro→lifetime.
class AccountUpgradeCard extends StatelessWidget {
  final User user;
  const AccountUpgradeCard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final l = S.of(context);
    final isPro = user.accountType == AccountType.pro;

    final gradient = isPro
        ? DesignSystem.lifetimeGradient
        : const LinearGradient(
            colors: [DesignSystem.neutral900, DesignSystem.neutral700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    return AccountSurfacePanel(
      padding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      borderColor: Colors.transparent,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 18,
          offset: const Offset(0, 10),
        ),
      ],
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(DesignSystem.radius2xl),
        ),
        child: Padding(
          padding: const EdgeInsets.all(DesignSystem.space5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.accountUpgradeTitle,
                style: const TextStyle(
                  fontSize: DesignSystem.textXs,
                  fontWeight: DesignSystem.weightSemibold,
                  color: Color(0xFFE7E5E4),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: DesignSystem.space2),
              Text(
                isPro ? l.accountUpgradeToLifetime : l.accountUpgradeToPro,
                style: const TextStyle(
                  fontSize: DesignSystem.textLg,
                  fontWeight: DesignSystem.weightSemibold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: DesignSystem.space2),
              Text(
                isPro
                    ? l.accountUpgradeLifetimeDesc
                    : l.accountUpgradeProDesc,
                style: TextStyle(
                  fontSize: DesignSystem.textSm,
                  color: Colors.white.withValues(alpha: 0.82),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: DesignSystem.space4),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PricingPage()),
                  ),
                  icon: Icon(
                      isPro ? Icons.stars_outlined : Icons.upgrade),
                  label: Text(isPro
                      ? l.accountViewLifetimePlan
                      : l.accountViewProPlan),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.44),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: DesignSystem.space4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                          DesignSystem.radiusFull),
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
        ),
      ),
    );
  }
}
