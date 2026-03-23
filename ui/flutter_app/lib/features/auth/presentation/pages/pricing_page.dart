import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/design_system.dart';
import '../../../../core/widgets/bova_button.dart';
import '../../../../core/widgets/bova_text_field.dart';
import '../../../../features/billing/domain/entities/billing_plan.dart';
import '../../../../features/billing/domain/entities/payment_status.dart';
import '../../../../features/billing/presentation/providers/billing_provider.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../providers/auth_provider.dart';

const Color _pricingAccent = Color(0xFFE11D48);
const Color _pricingAccentSoft = Color(0xFFFCE7F3);
const Color _pricingCanvas = Color(0xFFF1F3F6);
const Color _pricingPanel = Colors.white;
const Color _pricingPanelBorder = Color(0xFFE7EAF0);

class PricingPage extends StatefulWidget {
  const PricingPage({super.key});

  @override
  State<PricingPage> createState() => _PricingPageState();
}

class _PricingPageState extends State<PricingPage> {
  final ScrollController _scrollController = ScrollController();

  List<_PlanSpec> _buildPlans(S l10n) => [
        _PlanSpec(
          id: 'free',
          title: l10n.pricingPlanFree,
          price: l10n.pricingPlanFreePrice,
          period: l10n.pricingPlanFreePeriod,
          badge: 'Starter',
          icon: Icons.person_outline,
          accent: DesignSystem.neutral700,
          accentSoft: DesignSystem.neutral100,
          description: l10n.pricingPlanFreeDesc,
          cta: l10n.pricingPlanFreeCta,
          features: [
            l10n.pricingPlanFreeFeature1,
            l10n.pricingPlanFreeFeature2,
            l10n.pricingPlanFreeFeature3,
            l10n.pricingPlanFreeFeature4,
            l10n.pricingPlanFreeFeature5,
          ],
        ),
        _PlanSpec(
          id: 'pro_monthly',
          title: l10n.pricingPlanPro,
          price: l10n.pricingPlanProPrice,
          period: l10n.pricingPlanProPeriod,
          badge: 'Most Popular',
          icon: Icons.workspace_premium_outlined,
          accent: const Color(0xFFA21CAF),
          accentSoft: const Color(0xFFFAF5FF),
          description: l10n.pricingPlanProDesc,
          cta: l10n.pricingPlanProCta,
          isFeatured: true,
          features: [
            l10n.pricingPlanProFeature1,
            l10n.pricingPlanProFeature2,
            l10n.pricingPlanProFeature3,
            l10n.pricingPlanProFeature4,
            l10n.pricingPlanProFeature5,
            l10n.pricingPlanProFeature6,
          ],
        ),
        _PlanSpec(
          id: 'lifetime',
          title: l10n.pricingPlanLifetime,
          price: l10n.pricingPlanLifetimePrice,
          period: l10n.pricingPlanLifetimePeriod,
          badge: 'Best Value',
          icon: Icons.auto_awesome_outlined,
          accent: DesignSystem.accent700,
          accentSoft: const Color(0xFFFFFBEB),
          description: l10n.pricingPlanLifetimeDesc,
          cta: l10n.pricingPlanLifetimeCta,
          features: [
            l10n.pricingPlanLifetimeFeature1,
            l10n.pricingPlanLifetimeFeature2,
            l10n.pricingPlanLifetimeFeature3,
            l10n.pricingPlanLifetimeFeature4,
            l10n.pricingPlanLifetimeFeature5,
            l10n.pricingPlanLifetimeFeature6,
            l10n.pricingPlanLifetimeFeature7,
          ],
        ),
      ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isMobile(context)) return;
      Future.delayed(const Duration(milliseconds: 280), () {
        if (!mounted || !_scrollController.hasClients) return;
        _scrollController.animateTo(
          MediaQuery.of(context).size.width * 0.82,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 768;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final isMobile = _isMobile(context);
    final user = context.watch<AuthProvider>().user;
    final currentPlanId = _currentPlanId(user);
    final plans = _buildPlans(l10n);

    return Scaffold(
      backgroundColor: _pricingCanvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: DesignSystem.neutral900,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.pricingTitle,
          style: const TextStyle(
            fontSize: DesignSystem.textLg,
            fontWeight: DesignSystem.weightSemibold,
            color: DesignSystem.neutral900,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1160),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHero(l10n),
                const SizedBox(height: DesignSystem.space5),
                isMobile
                    ? _buildMobileLayout(plans, currentPlanId, l10n)
                    : _buildDesktopLayout(plans, currentPlanId, l10n),
                const SizedBox(height: DesignSystem.space5),
                _buildFeatureComparison(plans, currentPlanId, l10n),
                const SizedBox(height: DesignSystem.space5),
                _buildFAQ(l10n),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero(S l10n) {
    return _buildPanel(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DesignSystem.radius2xl),
          gradient: LinearGradient(
            colors: [
              Colors.white,
              _pricingAccentSoft.withValues(alpha: 0.55),
              const Color(0xFFFFFBEB),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(DesignSystem.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignSystem.space3,
                  vertical: DesignSystem.space1,
                ),
                decoration: BoxDecoration(
                  color: _pricingAccentSoft,
                  borderRadius: BorderRadius.circular(DesignSystem.radiusFull),
                ),
                child: const Text(
                  'Membership Workspace',
                  style: TextStyle(
                    fontSize: DesignSystem.textXs,
                    fontWeight: DesignSystem.weightSemibold,
                    color: _pricingAccent,
                  ),
                ),
              ),
              const SizedBox(height: DesignSystem.space4),
              Text(
                l10n.pricingChoosePlan,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: DesignSystem.weightBold,
                  color: DesignSystem.neutral900,
                  letterSpacing: -1.0,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: DesignSystem.space3),
              Text(
                l10n.pricingHeroDesc,
                style: const TextStyle(
                  fontSize: DesignSystem.textSm,
                  color: DesignSystem.neutral600,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: DesignSystem.space4),
              Wrap(
                spacing: DesignSystem.space3,
                runSpacing: DesignSystem.space3,
                children: [
                  _HeroStat(label: l10n.pricingCrossDeviceSync, value: 'Included'),
                  _HeroStat(label: l10n.pricingDeviceQuota, value: 'Up to Unlimited'),
                  _HeroStat(label: l10n.pricingCloudStorage, value: '100 MB → 5 GB'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(List<_PlanSpec> plans, String currentPlanId, S l10n) {
    final cardWidth = MediaQuery.of(context).size.width - 40;
    return SizedBox(
      height: 560,
      child: ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: plans.length,
        separatorBuilder: (_, __) => const SizedBox(width: DesignSystem.space4),
        itemBuilder: (context, index) => SizedBox(
          width: cardWidth,
          child: _buildPricingCard(plans[index], currentPlanId, l10n),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(List<_PlanSpec> plans, String currentPlanId, S l10n) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int index = 0; index < plans.length; index++) ...[
          Expanded(child: _buildPricingCard(plans[index], currentPlanId, l10n)),
          if (index != plans.length - 1)
            const SizedBox(width: DesignSystem.space4),
        ],
      ],
    );
  }

  Widget _buildPricingCard(_PlanSpec plan, String currentPlanId, S l10n) {
    final isCurrentPlan = plan.id == currentPlanId;
    final buttonEnabled = !isCurrentPlan && plan.id != 'free';

    return _buildPanel(
      padding: EdgeInsets.zero,
      backgroundColor:
          plan.isFeatured ? const Color(0xFFFFFCFE) : _pricingPanel,
      borderColor: plan.isFeatured
          ? _pricingAccent.withValues(alpha: 0.28)
          : _pricingPanelBorder,
      child: Padding(
        padding: const EdgeInsets.all(DesignSystem.space5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: plan.accentSoft,
                    borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
                  ),
                  child: Icon(plan.icon, size: 22, color: plan.accent),
                ),
                const SizedBox(width: DesignSystem.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.title,
                        style: const TextStyle(
                          fontSize: DesignSystem.textLg,
                          fontWeight: DesignSystem.weightSemibold,
                          color: DesignSystem.neutral900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DesignSystem.space2,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: plan.accentSoft,
                          borderRadius: BorderRadius.circular(
                            DesignSystem.radiusFull,
                          ),
                        ),
                        child: Text(
                          plan.badge,
                          style: TextStyle(
                            fontSize: DesignSystem.textXs,
                            fontWeight: DesignSystem.weightSemibold,
                            color: plan.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (plan.isFeatured)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignSystem.space2,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _pricingAccent,
                      borderRadius: BorderRadius.circular(
                        DesignSystem.radiusFull,
                      ),
                    ),
                    child: Text(
                      l10n.pricingRecommended,
                      style: const TextStyle(
                        fontSize: DesignSystem.textXs,
                        fontWeight: DesignSystem.weightSemibold,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: DesignSystem.space4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  plan.price,
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: DesignSystem.weightBold,
                    color: plan.accent,
                    letterSpacing: -1.0,
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: DesignSystem.space2),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    plan.period,
                    style: const TextStyle(
                      fontSize: DesignSystem.textSm,
                      color: DesignSystem.neutral500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DesignSystem.space3),
            Text(
              plan.description,
              style: const TextStyle(
                fontSize: DesignSystem.textSm,
                color: DesignSystem.neutral600,
                height: 1.6,
              ),
            ),
            const SizedBox(height: DesignSystem.space4),
            ...plan.features.map(
              (feature) => Padding(
                padding: const EdgeInsets.only(bottom: DesignSystem.space3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.only(top: 1),
                      decoration: BoxDecoration(
                        color: plan.accentSoft,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: plan.accent,
                      ),
                    ),
                    const SizedBox(width: DesignSystem.space3),
                    Expanded(
                      child: Text(
                        feature,
                        style: const TextStyle(
                          fontSize: DesignSystem.textSm,
                          color: DesignSystem.neutral800,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: DesignSystem.space5),
            BovaButton(
              text: isCurrentPlan ? l10n.pricingCurrentPlan : plan.cta,
              icon: isCurrentPlan ? Icons.check_rounded : plan.icon,
              onPressed: buttonEnabled
                  ? () => _handlePurchase(context, plan.id)
                  : null,
              style: plan.isFeatured
                  ? BovaButtonStyle.primary
                  : BovaButtonStyle.secondary,
              isFullWidth: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureComparison(List<_PlanSpec> plans, String currentPlanId, S l10n) {
    return _buildPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.table_chart_outlined,
            title: l10n.pricingFeatureComparison,
            subtitle: l10n.pricingFeatureComparisonDesc,
          ),
          const SizedBox(height: DesignSystem.space5),
          ClipRRect(
            borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
            child: Column(
              children: [
                _buildComparisonHeader(plans, currentPlanId),
                _buildComparisonRow(l10n.pricingServerCount, ['10', l10n.pricingUnlimited, l10n.pricingUnlimited]),
                _buildComparisonRow(l10n.pricingDeviceCount, ['2', '5', l10n.pricingUnlimited]),
                _buildComparisonRow(l10n.pricingCloudStorage, const ['100 MB', '1 GB', '5 GB']),
                _buildComparisonRow(l10n.pricingGitHubSync, ['—', l10n.pricingSupported, l10n.pricingSupported]),
                _buildComparisonRow(l10n.pricingPrioritySupport, ['—', l10n.pricingSupported, l10n.pricingSupported]),
                _buildComparisonRow(l10n.pricingLifetimeUpdates, ['—', '—', l10n.pricingSupported],
                    isLast: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonHeader(List<_PlanSpec> plans, String currentPlanId) {
    final headers = [
      const SizedBox(),
      for (final plan in plans)
        _ComparisonCell(
          text: plan.title,
          emphasized: plan.id == currentPlanId || plan.isFeatured,
        ),
    ];

    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(vertical: DesignSystem.space3),
      child: Row(children: headers),
    );
  }

  Widget _buildComparisonRow(
    String label,
    List<String> values, {
    bool isLast = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isLast ? Colors.transparent : _pricingPanelBorder,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: DesignSystem.space3),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: DesignSystem.space4),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: DesignSystem.textSm,
                  fontWeight: DesignSystem.weightMedium,
                  color: DesignSystem.neutral800,
                ),
              ),
            ),
          ),
          for (final value in values)
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: DesignSystem.space2),
                child: Text(
                  value,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: DesignSystem.textSm,
                    color: DesignSystem.neutral600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFAQ(S l10n) {
    return _buildPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FaqHeader(l10n: l10n),
          const SizedBox(height: DesignSystem.space5),
          _FaqItem(question: l10n.pricingFaqQ1, answer: l10n.pricingFaqA1),
          const SizedBox(height: DesignSystem.space3),
          _FaqItem(question: l10n.pricingFaqQ2, answer: l10n.pricingFaqA2),
          const SizedBox(height: DesignSystem.space3),
          _FaqItem(question: l10n.pricingFaqQ3, answer: l10n.pricingFaqA3),
        ],
      ),
    );
  }

  Widget _buildPanel({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(DesignSystem.space5),
    Color backgroundColor = _pricingPanel,
    Color borderColor = _pricingPanelBorder,
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(DesignSystem.radius2xl),
        border: Border.all(color: borderColor),
        boxShadow: DesignSystem.shadowSm,
      ),
      child: child,
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _pricingAccentSoft,
            borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
          ),
          child: const Icon(
            Icons.auto_awesome_outlined,
            color: _pricingAccent,
            size: 20,
          ),
        ),
        const SizedBox(width: DesignSystem.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: DesignSystem.textBase,
                  fontWeight: DesignSystem.weightSemibold,
                  color: DesignSystem.neutral900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: DesignSystem.textSm,
                  color: DesignSystem.neutral600,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handlePurchase(BuildContext context, String plan) async {
    final l10n = S.of(context);
    final codeController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignSystem.radiusXl),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _pricingAccentSoft,
                borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                color: _pricingAccent,
                size: 20,
              ),
            ),
            const SizedBox(width: DesignSystem.space3),
            Expanded(
              child: Text(
                l10n.pricingConfirmPurchase,
                style: const TextStyle(
                  color: DesignSystem.neutral900,
                  fontWeight: DesignSystem.weightSemibold,
                  fontSize: DesignSystem.textLg,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_getPlanName(plan, l10n)} · ${_getPlanPrice(plan, l10n)}',
                style: const TextStyle(
                  fontSize: DesignSystem.textSm,
                  color: DesignSystem.neutral600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: DesignSystem.space4),
              Container(
                padding: const EdgeInsets.all(DesignSystem.space4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
                  border: Border.all(color: _pricingPanelBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.pricingHaveRedemptionCode,
                      style: const TextStyle(
                        fontSize: DesignSystem.textSm,
                        fontWeight: DesignSystem.weightSemibold,
                        color: DesignSystem.neutral900,
                      ),
                    ),
                    const SizedBox(height: DesignSystem.space2),
                    BovaTextField(
                      controller: codeController,
                      label: l10n.pricingRedemptionCode,
                      hint: 'BOVA-XXXX-XXXX-XXXX',
                      prefixIcon: Icons.confirmation_number_outlined,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, null),
            child: Text(
              l10n.cancel,
              style: const TextStyle(color: DesignSystem.neutral600),
            ),
          ),
          FilledButton(
            onPressed: () {
              final code = codeController.text.trim();
              Navigator.pop(
                  dialogContext, code.isNotEmpty ? 'redeem:$code' : 'pay');
            },
            style: FilledButton.styleFrom(
              backgroundColor: _pricingAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignSystem.radiusMd),
              ),
            ),
            child: Text(
              codeController.text.trim().isNotEmpty ? l10n.pricingRedeem : l10n.pricingGoPay,
            ),
          ),
        ],
      ),
    );

    codeController.dispose();
    if (result == null) return;

    if (result.startsWith('redeem:')) {
      await _redeemCode(result.substring(7));
    } else if (result == 'pay') {
      await _startPaymentFlow(plan);
    }
  }

  Future<void> _redeemCode(String code) async {
    final l10n = S.of(context);
    _showBlockingLoading();

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final result = await authProvider.redeemCode(code);

      _dismissBlockingLoading();

      if (result['success'] == true) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignSystem.radiusXl),
            ),
            title: Text(
              l10n.pricingRedeemSuccess,
              style: const TextStyle(
                color: DesignSystem.neutral900,
                fontWeight: DesignSystem.weightSemibold,
              ),
            ),
            content: Text(
              result['message'] ?? l10n.pricingAccountUpdated,
              style: const TextStyle(
                color: DesignSystem.neutral600,
                height: 1.5,
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                style: FilledButton.styleFrom(
                  backgroundColor: _pricingAccent,
                  foregroundColor: Colors.white,
                ),
                child: Text(l10n.pricingOk),
              ),
            ],
          ),
        );
        if (mounted) Navigator.pop(context);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? l10n.pricingRedeemFailed),
            backgroundColor: DesignSystem.error,
          ),
        );
      }
    } catch (error) {
      _dismissBlockingLoading();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.pricingRedeemError(error.toString())),
          backgroundColor: DesignSystem.error,
        ),
      );
    }
  }

  Future<void> _startPaymentFlow(String planId) async {
    final l10n = S.of(context);
    final billingPlan = BillingPlan.tryParse(planId);
    if (billingPlan == null || billingPlan == BillingPlan.free) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.pricingRedeemFailed),
          backgroundColor: DesignSystem.error,
        ),
      );
      return;
    }

    final billingProvider = Provider.of<BillingProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    _showBlockingLoading();

    try {
      final order = await billingProvider.createOrder(plan: billingPlan);

      _dismissBlockingLoading();

      final launched = await _launchPaymentUrl(order.paymentUrl);
      if (!launched) {
        billingProvider.clearState();
        if (!mounted) return;
        await _showPaymentStatusDialog(
          title: '无法打开支付页面',
          message: '订单已创建，但未能自动打开支付链接。你可以重试打开支付页，或稍后前往账户中心查看订阅状态。',
          confirmText: '重试打开',
          onConfirm: () => _launchPaymentUrl(order.paymentUrl),
        );
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已打开支付页面，请完成支付后返回应用等待确认'),
          backgroundColor: DesignSystem.success,
        ),
      );

      _showBlockingLoading(message: '等待支付确认...');

      final status = await billingProvider.waitForPayment(orderId: order.id);

      _dismissBlockingLoading();

      if (status.isPaid) {
        await authProvider.refreshUser();
        billingProvider.clearState();
        if (!mounted) return;
        await _showPaymentStatusDialog(
          title: '支付成功',
          message: status.message?.trim().isNotEmpty == true
              ? status.message!
              : '订阅权益已刷新，你现在可以在账户中心查看最新会员状态。',
          confirmText: '查看账户',
          onConfirm: _openAccountCenter,
        );
        return;
      }

      if (!mounted) return;
      switch (status.state) {
        case PaymentOrderState.pending:
        case PaymentOrderState.unknown:
          await _showPaymentStatusDialog(
            title: '暂未确认支付结果',
            message: status.message?.trim().isNotEmpty == true
                ? status.message!
                : '支付结果还没有同步完成。你可以稍后前往账户中心查看订阅状态，若已扣款通常会在短时间内生效。',
            confirmText: '查看账户',
            onConfirm: _openAccountCenter,
          );
          break;
        case PaymentOrderState.failed:
          await _showPaymentStatusDialog(
            title: '支付失败',
            message: status.message?.trim().isNotEmpty == true
                ? status.message!
                : '支付未完成，请稍后重试。',
            confirmText: '重新打开支付页',
            onConfirm: () => _launchPaymentUrl(order.paymentUrl),
          );
          break;
        case PaymentOrderState.cancelled:
          await _showPaymentStatusDialog(
            title: '支付已取消',
            message: status.message?.trim().isNotEmpty == true
                ? status.message!
                : '你已取消本次支付，如需继续开通可以重新打开支付页面。',
            confirmText: '重新打开支付页',
            onConfirm: () => _launchPaymentUrl(order.paymentUrl),
          );
          break;
        case PaymentOrderState.expired:
          await _showPaymentStatusDialog(
            title: '支付已过期',
            message: status.message?.trim().isNotEmpty == true
                ? status.message!
                : '当前订单已过期，请重新发起下单。',
            confirmText: '我知道了',
          );
          break;
        case PaymentOrderState.paid:
          break;
      }

      billingProvider.clearState();
    } catch (error) {
      _dismissBlockingLoading();
      billingProvider.clearState();
      if (!mounted) return;
      await _showPaymentStatusDialog(
        title: '支付流程失败',
        message: '创建订单或查询支付状态时出现异常：$error',
        confirmText: '我知道了',
      );
    }
  }

  String _currentPlanId(dynamic user) {
    if (user == null) return 'free';
    final accountType = user.accountType;
    if ('$accountType'.contains('lifetime')) return 'lifetime';
    if ('$accountType'.contains('pro')) return 'pro_monthly';
    return 'free';
  }

  void _showBlockingLoading({String message = '处理中...'}) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignSystem.radiusXl),
          ),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: _pricingAccent),
              ),
              const SizedBox(width: DesignSystem.space4),
              Flexible(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: DesignSystem.textSm,
                    color: DesignSystem.neutral700,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _dismissBlockingLoading() {
    if (!mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  Future<void> _showPaymentStatusDialog({
    required String title,
    required String message,
    required String confirmText,
    Future<void> Function()? onConfirm,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignSystem.radiusXl),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: DesignSystem.neutral900,
            fontWeight: DesignSystem.weightSemibold,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: DesignSystem.neutral600,
            height: 1.5,
          ),
        ),
        actions: [
          if (onConfirm != null)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                '关闭',
                style: TextStyle(color: DesignSystem.neutral600),
              ),
            ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              if (onConfirm != null) {
                await onConfirm();
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: _pricingAccent,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  Future<void> _openAccountCenter() async {
    if (!mounted) return;
    await Navigator.of(context).pushNamed('/account');
  }

  String _getPlanName(String plan, S l10n) {
    switch (plan) {
      case 'pro_monthly':
        return l10n.pricingProMonthly;
      case 'lifetime':
        return l10n.pricingPlanLifetime;
      default:
        return l10n.pricingPlanFree;
    }
  }

  String _getPlanPrice(String plan, S l10n) {
    switch (plan) {
      case 'pro_monthly':
        return l10n.pricingProMonthlyPrice;
      case 'lifetime':
        return l10n.pricingLifetimeOnce;
      default:
        return l10n.pricingPlanFreePrice;
    }
  }

  Future<bool> _launchPaymentUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await canLaunchUrl(uri)) {
      return false;
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(
        horizontal: DesignSystem.space3,
        vertical: DesignSystem.space3,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
        border: Border.all(color: _pricingPanelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: DesignSystem.textXs,
              color: DesignSystem.neutral500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: DesignSystem.textSm,
              fontWeight: DesignSystem.weightSemibold,
              color: DesignSystem.neutral900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonCell extends StatelessWidget {
  const _ComparisonCell({required this.text, this.emphasized = false});

  final String text;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DesignSystem.space2),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: DesignSystem.textSm,
            fontWeight: emphasized
                ? DesignSystem.weightSemibold
                : DesignSystem.weightMedium,
            color:
                emphasized ? DesignSystem.neutral900 : DesignSystem.neutral600,
          ),
        ),
      ),
    );
  }
}

class _FaqHeader extends StatelessWidget {
  const _FaqHeader({required this.l10n});

  final S l10n;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _pricingAccentSoft,
            borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
          ),
          child: const Icon(
            Icons.chat_bubble_outline_rounded,
            color: _pricingAccent,
            size: 20,
          ),
        ),
        const SizedBox(width: DesignSystem.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.pricingFaq,
                style: const TextStyle(
                  fontSize: DesignSystem.textBase,
                  fontWeight: DesignSystem.weightSemibold,
                  color: DesignSystem.neutral900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.pricingFaqDesc,
                style: const TextStyle(
                  fontSize: DesignSystem.textSm,
                  color: DesignSystem.neutral600,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FaqItem extends StatelessWidget {
  const _FaqItem({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesignSystem.space4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
        border: Border.all(color: _pricingPanelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(
              fontSize: DesignSystem.textSm,
              fontWeight: DesignSystem.weightSemibold,
              color: DesignSystem.neutral900,
            ),
          ),
          const SizedBox(height: DesignSystem.space2),
          Text(
            answer,
            style: const TextStyle(
              fontSize: DesignSystem.textSm,
              color: DesignSystem.neutral600,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanSpec {
  const _PlanSpec({
    required this.id,
    required this.title,
    required this.price,
    required this.period,
    required this.badge,
    required this.icon,
    required this.accent,
    required this.accentSoft,
    required this.description,
    required this.cta,
    required this.features,
    this.isFeatured = false,
  });

  final String id;
  final String title;
  final String price;
  final String period;
  final String badge;
  final IconData icon;
  final Color accent;
  final Color accentSoft;
  final String description;
  final String cta;
  final List<String> features;
  final bool isFeatured;
}
