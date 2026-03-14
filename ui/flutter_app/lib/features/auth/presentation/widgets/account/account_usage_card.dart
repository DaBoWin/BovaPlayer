import 'package:flutter/material.dart';

import '../../../../../core/theme/design_system.dart';
import '../../../../../l10n/generated/app_localizations.dart';
import '../../../domain/entities/user.dart';
import 'account_theme.dart';

/// Usage statistics card — servers, devices, storage.
class AccountUsageCard extends StatelessWidget {
  final User user;
  const AccountUsageCard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final c = AccountColors.of(context);
    final l = S.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 332),
      child: AccountSurfacePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AccountSectionHeader(
              icon: Icons.equalizer_rounded,
              title: l.accountUsage,
              subtitle: '',
            ),
            const SizedBox(height: DesignSystem.space2),
            Text(
              l.accountUsageDescription,
              style: TextStyle(
                fontSize: DesignSystem.textSm,
                color: c.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: DesignSystem.space4),
            _UsageLine(
              icon: Icons.dns_outlined,
              label: l.accountUsageServers,
              current: user.usage.serverCount.toDouble(),
              max: user.limits.maxServers.toDouble(),
              unlimitedLabel: l.accountUsageUnlimited,
              formatter: (v) => v.toStringAsFixed(0),
            ),
            const SizedBox(height: DesignSystem.space4),
            _UsageLine(
              icon: Icons.devices_outlined,
              label: l.accountUsageDevices,
              current: user.usage.deviceCount.toDouble(),
              max: user.limits.maxDevices.toDouble(),
              unlimitedLabel: l.accountUsageUnlimited,
              formatter: (v) => v.toStringAsFixed(0),
            ),
            const SizedBox(height: DesignSystem.space4),
            _UsageLine(
              icon: Icons.storage_outlined,
              label: l.accountUsageStorage,
              current: user.usage.storageUsedMb.toDouble(),
              max: user.limits.storageQuotaMb.toDouble(),
              unlimitedLabel: l.accountUsageUnlimited,
              formatter: (v) =>
                  '${v.toStringAsFixed(v >= 100 ? 0 : 1)} MB',
            ),
          ],
        ),
      ),
    );
  }
}

class _UsageLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final double current;
  final double max;
  final String unlimitedLabel;
  final String Function(double) formatter;

  const _UsageLine({
    required this.icon,
    required this.label,
    required this.current,
    required this.max,
    required this.unlimitedLabel,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    final c = AccountColors.of(context);

    final isUnlimited = max == -1;
    final progress = isUnlimited ? 0.0 : (current / max).clamp(0.0, 1.0);
    final isNearLimit = !isUnlimited && progress >= 0.8;
    final barColor = isNearLimit ? DesignSystem.warning : c.accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: c.accentSoft,
                borderRadius: BorderRadius.circular(DesignSystem.radiusMd),
              ),
              child: Icon(icon, size: 18, color: c.textSecondary),
            ),
            const SizedBox(width: DesignSystem.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: DesignSystem.textSm,
                      fontWeight: DesignSystem.weightMedium,
                      color: c.textPrimary,
                    ),
                  ),
                  Text(
                    isUnlimited
                        ? '${formatter(current)} / $unlimitedLabel'
                        : '${formatter(current)} / ${formatter(max)}',
                    style: TextStyle(
                      fontSize: DesignSystem.textXs,
                      fontWeight: DesignSystem.weightMedium,
                      color: isNearLimit
                          ? DesignSystem.warning
                          : c.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (!isUnlimited) ...[
          const SizedBox(height: DesignSystem.space3),
          ClipRRect(
            borderRadius: BorderRadius.circular(DesignSystem.radiusFull),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: c.panelBorder,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ],
      ],
    );
  }
}
