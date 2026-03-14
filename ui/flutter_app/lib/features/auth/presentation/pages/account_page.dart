import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/design_system.dart';
import '../../../../core/widgets/bova_button.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/user.dart';
import '../providers/auth_provider.dart';
import '../widgets/account/account_admin_card.dart';
import '../widgets/account/account_hero_card.dart';
import '../widgets/account/account_logout_card.dart';
import '../widgets/account/account_plan_card.dart';
import '../widgets/account/account_sync_card.dart';
import '../widgets/account/account_theme.dart';
import '../widgets/account/account_upgrade_card.dart';
import '../widgets/account/account_usage_card.dart';

/// Account center page.
///
/// Set [embedded] = true when shown inside the desktop workspace shell
/// (no Scaffold / AppBar of its own).
class AccountPage extends StatefulWidget {
  const AccountPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: DesignSystem.durationSlow,
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: DesignSystem.easeOutQuint,
      ),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: DesignSystem.easeOutQuint,
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AccountColors.of(context);
    final isMobile = DesignSystem.isMobile(context);

    final body = Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.user;
        final scrollContent = FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: DesignSystem.isDesktop(context) ? 920 : 760,
                ),
                child: user == null
                    ? _MissingUserState(embedded: widget.embedded)
                    : _AccountBody(user: user, authProvider: authProvider),
              ),
            ),
          ),
        );

        final content = SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            isMobile ? DesignSystem.space4 : DesignSystem.space6,
            DesignSystem.space4,
            isMobile ? DesignSystem.space4 : DesignSystem.space6,
            DesignSystem.space8,
          ),
          child: scrollContent,
        );

        if (widget.embedded) {
          return ColoredBox(color: c.canvas, child: content);
        }

        return SafeArea(top: true, child: content);
      },
    );

    if (widget.embedded) return body;

    final l = S.of(context);
    return Scaffold(
      backgroundColor: c.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: c.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l.accountCenter,
          style: TextStyle(
            fontSize: DesignSystem.textLg,
            fontWeight: DesignSystem.weightSemibold,
            color: c.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: body,
    );
  }
}

// ─── Body: the column of cards ──────────────────────────────────────

class _AccountBody extends StatelessWidget {
  final User user;
  final AuthProvider authProvider;

  const _AccountBody({required this.user, required this.authProvider});

  @override
  Widget build(BuildContext context) {
    final isWide =
        DesignSystem.isDesktop(context) || DesignSystem.isTablet(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hero
        const AccountHeroCard(),
        const SizedBox(height: DesignSystem.space4),

        // Plan + Usage side-by-side on desktop
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: AccountPlanCard(user: user)),
              const SizedBox(width: DesignSystem.space4),
              Expanded(child: AccountUsageCard(user: user)),
            ],
          )
        else ...[
          AccountPlanCard(user: user),
          const SizedBox(height: DesignSystem.space4),
          AccountUsageCard(user: user),
        ],

        const SizedBox(height: DesignSystem.space4),

        // Cloud Sync
        const AccountSyncCard(),

        // Admin (only if admin)
        if (user.isAdmin) ...[
          const SizedBox(height: DesignSystem.space4),
          const AccountAdminCard(),
        ],

        // Upgrade CTA (not for lifetime)
        if (!user.isLifetime) ...[
          const SizedBox(height: DesignSystem.space4),
          AccountUpgradeCard(user: user),
        ],

        // Logout
        const SizedBox(height: DesignSystem.space4),
        AccountLogoutCard(authProvider: authProvider),
      ],
    );
  }
}

// ─── Missing user fallback ──────────────────────────────────────────

class _MissingUserState extends StatelessWidget {
  final bool embedded;
  const _MissingUserState({required this.embedded});

  @override
  Widget build(BuildContext context) {
    final c = AccountColors.of(context);
    final l = S.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: AccountSurfacePanel(
          padding: const EdgeInsets.all(DesignSystem.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: c.accentSoft,
                  borderRadius:
                      BorderRadius.circular(DesignSystem.radiusXl),
                ),
                child: Icon(
                  Icons.person_off_outlined,
                  color: c.accent,
                  size: 30,
                ),
              ),
              const SizedBox(height: DesignSystem.space4),
              Text(
                l.accountNoInfo,
                style: TextStyle(
                  fontSize: DesignSystem.textXl,
                  fontWeight: DesignSystem.weightSemibold,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: DesignSystem.space2),
              Text(
                l.accountNoInfoHint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: DesignSystem.textSm,
                  color: c.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: DesignSystem.space5),
              BovaButton(
                text: l.accountGoBack,
                onPressed: () => Navigator.pop(context),
                isFullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
