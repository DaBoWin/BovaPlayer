import 'package:flutter/material.dart';

import '../../../../../core/theme/design_system.dart';
import '../../../../../l10n/generated/app_localizations.dart';
import '../../../domain/entities/user.dart';
import 'account_theme.dart';

/// Plan card — shows current plan info (free / pro / lifetime).
/// Lifetime gets a special premium dark card.
class AccountPlanCard extends StatelessWidget {
  final User user;
  const AccountPlanCard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    if (user.accountType == AccountType.lifetime) {
      return _LifetimePlanCard(user: user);
    }
    return _StandardPlanCard(user: user);
  }
}

// ─── Lifetime premium card ───────────────────────────────────────────

class _LifetimePlanCard extends StatelessWidget {
  final User user;
  const _LifetimePlanCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final c = AccountColors.of(context);
    final l = S.of(context);

    const shellSurface = Color(0xFFF2F4F7);
    const shellSurfaceDeep = Color(0xFFE8ECF1);
    const cardIndigo = Color(0xFF171A4C);
    const cardIndigoDeep = Color(0xFF0D103A);
    const cardText = Color(0xFFF3F0E8);
    const cardMuted = Color(0xFFA3A7C9);
    const actionSurface = Color(0xFFF2E3BD);
    const actionText = Color(0xFF5A431C);

    final eyebrow = l.accountLabelLifetime;
    final description = l.accountDescLifetime;

    // Adapt shell gradient for dark / cyberpunk / sweetie
    final shellColors = c.isDark || c.isSpecial
        ? [const Color(0xFF1A1A22), const Color(0xFF14141C)]
        : [shellSurface, shellSurfaceDeep];

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 332),
      child: AccountSurfacePanel(
        padding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        borderColor: Colors.transparent,
        boxShadow: [
          BoxShadow(
            color: DesignSystem.neutral900.withValues(alpha: 0.04),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DesignSystem.radius2xl),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: shellColors,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              DesignSystem.space5,
              DesignSystem.space5,
              DesignSystem.space5,
              DesignSystem.space6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 470;
                    final titleBlock = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          eyebrow,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: DesignSystem.weightSemibold,
                            color: cardMuted,
                            letterSpacing: 0.45,
                          ),
                        ),
                        const SizedBox(height: DesignSystem.space3),
                        Text(
                          l.accountLifetimeRightsTitle,
                          style: const TextStyle(
                            fontSize: 29,
                            fontWeight: DesignSystem.weightBold,
                            color: cardText,
                            letterSpacing: -0.9,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: DesignSystem.space3),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: compact ? constraints.maxWidth : 320,
                          ),
                          child: Text(
                            description,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: DesignSystem.weightMedium,
                              color: cardMuted,
                              height: 1.5,
                              letterSpacing: -0.05,
                            ),
                          ),
                        ),
                      ],
                    );

                    final actionChip = Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DesignSystem.space4,
                        vertical: DesignSystem.space3,
                      ),
                      decoration: BoxDecoration(
                        color: actionSurface,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: actionText.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l.accountLifetimeChip,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: DesignSystem.weightSemibold,
                              color: actionText,
                              letterSpacing: 0.15,
                            ),
                          ),
                          const SizedBox(width: DesignSystem.space2),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: actionText,
                          ),
                        ],
                      ),
                    );

                    return ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 250),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [cardIndigo, cardIndigoDeep],
                          ),
                        ),
                        child: Stack(
                          children: [
                            const Positioned.fill(
                              child: CustomPaint(
                                painter: _PremiumWavePatternPainter(),
                              ),
                            ),
                            Positioned(
                              left: 26,
                              top: 18,
                              child: IgnorePointer(
                                child: Text(
                                  l.accountVip,
                                  style: TextStyle(
                                    fontSize: 92,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white.withValues(alpha: 0.12),
                                    letterSpacing: -3,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white.withValues(alpha: 0.12),
                                      Colors.white.withValues(alpha: 0),
                                      Colors.white.withValues(alpha: 0.02),
                                    ],
                                    stops: const [0, 0.42, 1],
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(28, 34, 28, 26),
                              child: compact
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 54),
                                        titleBlock,
                                        const SizedBox(height: DesignSystem.space5),
                                        actionChip,
                                      ],
                                    )
                                  : Row(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.only(top: 54),
                                            child: titleBlock,
                                          ),
                                        ),
                                        const SizedBox(width: DesignSystem.space4),
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 8),
                                          child: actionChip,
                                        ),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Standard plan card (Free / Pro) ─────────────────────────────────

class _StandardPlanCard extends StatelessWidget {
  final User user;
  const _StandardPlanCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final c = AccountColors.of(context);
    final l = S.of(context);
    final palette = AccountPalette.forType(user.accountType, c);

    final title = switch (user.accountType) {
      AccountType.free => l.accountPlanFree,
      AccountType.pro => l.accountPlanPro,
      AccountType.lifetime => l.accountPlanLifetime,
    };

    final eyebrow = switch (user.accountType) {
      AccountType.free => l.accountLabelFree,
      AccountType.pro => l.accountLabelPro,
      AccountType.lifetime => l.accountLabelLifetime,
    };

    final description = switch (user.accountType) {
      AccountType.free => l.accountDescFree,
      AccountType.pro => l.accountDescPro,
      AccountType.lifetime => l.accountDescLifetime,
    };

    final features = switch (user.accountType) {
      AccountType.free => [
          l.accountFeatureLocalPlayback,
          l.accountFeatureLibraryManagement,
          l.accountFeatureBasicService,
        ],
      AccountType.pro => [
          l.accountFeatureCloudSync,
          l.accountFeatureMoreDevices,
          l.accountFeatureAdvancedWorkspace,
          l.accountFeaturePriorityAccess,
        ],
      AccountType.lifetime => [
          l.accountFeatureCloudSync,
          l.accountFeatureUnlimitedDevices,
          l.accountFeatureLargerQuota,
          l.accountFeatureAdvancedWorkspace,
          l.accountFeaturePriorityAccess,
          l.accountFeatureNoRenewal,
        ],
    };

    final isFree = user.accountType == AccountType.free;
    final gradientColors = c.isDark || c.isSpecial
        ? [c.panel, c.panel.withValues(alpha: 0.85)]
        : switch (user.accountType) {
            AccountType.free => [const Color(0xFFFFF7FB), const Color(0xFFFFE8F3)],
            AccountType.pro => [const Color(0xFFFFFCFE), const Color(0xFFFAF4FB)],
            AccountType.lifetime => [const Color(0xFFFFFEFC), const Color(0xFFF8F2E8)],
          };

    final borderColor = isFree
        ? palette.deep.withValues(alpha: 0.18)
        : palette.base.withValues(alpha: 0.16);
    final headlineColor = palette.text;
    final iconTileColor = isFree ? const Color(0xFFFFF1F7) : c.overlayWhiteStrong;
    final featurePanelColor = isFree ? const Color(0xFFFFF8FB) : c.overlayWhiteMedium;
    final titleColor = isFree ? const Color(0xFF2B1220) : c.textPrimary;
    final descriptionColor = isFree ? const Color(0xFF7A6570) : c.textSecondary;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 332),
      child: AccountSurfacePanel(
        padding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        borderColor: borderColor,
        boxShadow: [
          BoxShadow(
            color: DesignSystem.neutral900.withValues(alpha: 0.045),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DesignSystem.radius2xl),
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(DesignSystem.space5),
            child: isFree
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 250),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFFFFCFE), Color(0xFFFFE7F2)],
                        ),
                        border: Border.all(
                          color: palette.deep.withValues(alpha: 0.14),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: palette.deep.withValues(alpha: 0.10),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -28,
                            top: -18,
                            child: Container(
                              width: 164,
                              height: 164,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: palette.base.withValues(alpha: 0.18),
                              ),
                            ),
                          ),
                          Positioned(
                            left: -12,
                            bottom: -42,
                            child: Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: palette.base.withValues(alpha: 0.10),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 28,
                            top: 20,
                            child: IgnorePointer(
                              child: Text(
                                'FREE',
                                style: TextStyle(
                                  fontSize: 84,
                                  fontWeight: FontWeight.w800,
                                  color: palette.deep.withValues(alpha: 0.08),
                                  letterSpacing: -3,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.30),
                                    Colors.white.withValues(alpha: 0.02),
                                    palette.base.withValues(alpha: 0.04),
                                  ],
                                  stops: const [0, 0.46, 1],
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: iconTileColor,
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: palette.deep.withValues(alpha: 0.10),
                                        ),
                                      ),
                                      child: Icon(
                                        palette.icon,
                                        color: headlineColor,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: DesignSystem.space3),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            eyebrow,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: DesignSystem.weightSemibold,
                                              color: c.textTertiary,
                                              letterSpacing: 0.4,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            title,
                                            style: TextStyle(
                                              fontSize: 30,
                                              fontWeight: DesignSystem.weightBold,
                                              color: titleColor,
                                              letterSpacing: -0.9,
                                              height: 1.02,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: DesignSystem.space3,
                                        vertical: DesignSystem.space2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF9FC),
                                        borderRadius: BorderRadius.circular(
                                          DesignSystem.radiusFull,
                                        ),
                                        border: Border.all(color: borderColor),
                                      ),
                                      child: Text(
                                        user.accountType.displayName,
                                        style: TextStyle(
                                          fontSize: DesignSystem.textXs,
                                          fontWeight: DesignSystem.weightSemibold,
                                          color: headlineColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: DesignSystem.space5),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 420),
                                  child: Text(
                                    description,
                                    style: TextStyle(
                                      fontSize: DesignSystem.textSm,
                                      color: descriptionColor,
                                      height: 1.6,
                                      fontWeight: DesignSystem.weightMedium,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: DesignSystem.space5),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                                  decoration: BoxDecoration(
                                    color: featurePanelColor,
                                    borderRadius: BorderRadius.circular(
                                      DesignSystem.radiusXl,
                                    ),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Wrap(
                                    spacing: DesignSystem.space4,
                                    runSpacing: DesignSystem.space3,
                                    children: features
                                        .map(
                                          (feature) => Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 6,
                                                height: 6,
                                                decoration: BoxDecoration(
                                                  color: headlineColor.withValues(
                                                    alpha: 0.78,
                                                  ),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(
                                                width: DesignSystem.space2,
                                              ),
                                              Text(
                                                feature,
                                                style: TextStyle(
                                                  fontSize: DesignSystem.textSm,
                                                  fontWeight:
                                                      DesignSystem.weightMedium,
                                                  color: c.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: iconTileColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: DesignSystem.neutral900.withValues(alpha: 0.05),
                              ),
                            ),
                            child: Icon(palette.icon, color: headlineColor, size: 22),
                          ),
                          const SizedBox(width: DesignSystem.space3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  eyebrow,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: DesignSystem.weightSemibold,
                                    color: c.textTertiary,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: DesignSystem.textXl,
                                    fontWeight: DesignSystem.weightBold,
                                    color: titleColor,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: DesignSystem.space3,
                              vertical: DesignSystem.space1,
                            ),
                            decoration: BoxDecoration(
                              color: c.overlayWhiteStrong,
                              borderRadius: BorderRadius.circular(
                                DesignSystem.radiusFull,
                              ),
                              border: Border.all(color: borderColor),
                            ),
                            child: Text(
                              user.accountType.displayName,
                              style: TextStyle(
                                fontSize: DesignSystem.textXs,
                                fontWeight: DesignSystem.weightSemibold,
                                color: headlineColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: DesignSystem.space4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: DesignSystem.textSm,
                          color: descriptionColor,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: DesignSystem.space4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        decoration: BoxDecoration(
                          color: featurePanelColor,
                          borderRadius: BorderRadius.circular(DesignSystem.radiusXl),
                          border: Border.all(color: borderColor),
                        ),
                        child: Wrap(
                          spacing: DesignSystem.space4,
                          runSpacing: DesignSystem.space3,
                          children: features
                              .map(
                                (feature) => Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 5,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: headlineColor.withValues(alpha: 0.78),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: DesignSystem.space2),
                                    Text(
                                      feature,
                                      style: TextStyle(
                                        fontSize: DesignSystem.textSm,
                                        fontWeight: DesignSystem.weightMedium,
                                        color: c.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      if (user.accountType == AccountType.pro &&
                          user.proExpiresAt != null) ...[
                        const SizedBox(height: DesignSystem.space4),
                        Container(
                          padding: const EdgeInsets.all(DesignSystem.space4),
                          decoration: BoxDecoration(
                            color: c.overlayWhiteMedium,
                            borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.schedule_outlined, size: 18, color: headlineColor),
                              const SizedBox(width: DesignSystem.space2),
                              Text(
                                l.accountExpiresAt(formatAccountDate(user.proExpiresAt!)),
                                style: TextStyle(
                                  fontSize: DesignSystem.textSm,
                                  fontWeight: DesignSystem.weightMedium,
                                  color: headlineColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── Premium wave pattern painter ────────────────────────────────────

class _PremiumWavePatternPainter extends CustomPainter {
  const _PremiumWavePatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35
      ..color = Colors.white.withValues(alpha: 0.07)
      ..isAntiAlias = true;

    for (var index = 0; index < 12; index++) {
      final y = size.height * 0.12 + index * 18;
      final path = Path()
        ..moveTo(size.width * 0.28, y)
        ..quadraticBezierTo(
          size.width * 0.54,
          y - 26,
          size.width * 1.02,
          y + 12,
        );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
