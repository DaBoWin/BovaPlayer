import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/config/env_config.dart';
import '../../../../core/theme/design_system.dart';
import '../../../../core/widgets/bova_button.dart';
import '../../../../core/widgets/bova_text_field.dart';
import '../../../../features/billing/domain/entities/billing_plan.dart';
import '../../../../features/billing/domain/entities/payment_order.dart';
import '../../../../features/billing/domain/entities/payment_status.dart';
import '../../../../features/billing/domain/entities/pricing_config.dart';
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
  bool _hasRequestedPricingConfigs = false;

  List<_PlanSpec> _buildPlans(S l10n, BillingProvider billingProvider) {
    final pricingByPlanId = <String, PricingConfig>{
      for (final config in billingProvider.pricingConfigs)
        if (config.isActive) config.planId: config,
    };

    return [
      _buildFreePlan(l10n),
      _buildPlanFromConfig(
        l10n,
        pricingByPlanId['pro_monthly'],
        planId: 'pro_monthly',
        fallbackTitle: l10n.pricingPlanPro,
        fallbackPrice: l10n.pricingPlanProPrice,
        fallbackPeriod: l10n.pricingPlanProPeriod,
        fallbackDescription: l10n.pricingPlanProDesc,
        fallbackBadge: l10n.pricingBadgeMostPopular,
        fallbackCta: l10n.pricingPlanProCta,
        fallbackFeatures: [
          l10n.pricingPlanProFeature1,
          l10n.pricingPlanProFeature2,
          l10n.pricingPlanProFeature3,
          l10n.pricingPlanProFeature4,
          l10n.pricingPlanProFeature5,
          l10n.pricingPlanProFeature6,
        ],
        icon: Icons.workspace_premium_outlined,
        accent: const Color(0xFFA21CAF),
        accentSoft: const Color(0xFFFAF5FF),
        isFeatured: true,
      ),
      _buildPlanFromConfig(
        l10n,
        pricingByPlanId['lifetime'],
        planId: 'lifetime',
        fallbackTitle: l10n.pricingPlanLifetime,
        fallbackPrice: l10n.pricingPlanLifetimePrice,
        fallbackPeriod: l10n.pricingPlanLifetimePeriod,
        fallbackDescription: l10n.pricingPlanLifetimeDesc,
        fallbackBadge: l10n.pricingBadgeBestValue,
        fallbackCta: l10n.pricingPlanLifetimeCta,
        fallbackFeatures: [
          l10n.pricingPlanLifetimeFeature1,
          l10n.pricingPlanLifetimeFeature2,
          l10n.pricingPlanLifetimeFeature3,
          l10n.pricingPlanLifetimeFeature4,
          l10n.pricingPlanLifetimeFeature5,
          l10n.pricingPlanLifetimeFeature6,
          l10n.pricingPlanLifetimeFeature7,
        ],
        icon: Icons.auto_awesome_outlined,
        accent: DesignSystem.accent700,
        accentSoft: const Color(0xFFFFFBEB),
      ),
    ];
  }

  _PlanSpec _buildFreePlan(S l10n) {
    return _PlanSpec(
      id: 'free',
      title: l10n.pricingPlanFree,
      price: l10n.pricingPlanFreePrice,
      period: l10n.pricingPlanFreePeriod,
      badge: l10n.pricingStarter,
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
      priceValue: 0,
      maxServers: 10,
      maxDevices: 2,
      storageQuotaMb: 100,
      supportsGithubSync: false,
      supportsPrioritySupport: false,
      supportsLifetimeUpdates: false,
    );
  }

  _PlanSpec _buildPlanFromConfig(
    S l10n,
    PricingConfig? config, {
    required String planId,
    required String fallbackTitle,
    required String fallbackPrice,
    required String fallbackPeriod,
    required String fallbackDescription,
    required String fallbackBadge,
    required String fallbackCta,
    required List<String> fallbackFeatures,
    required IconData icon,
    required Color accent,
    required Color accentSoft,
    bool isFeatured = false,
  }) {
    final effectiveConfig = config;
    return _PlanSpec(
      id: effectiveConfig?.planId ?? planId,
      title: effectiveConfig?.displayName.trim().isNotEmpty == true
          ? effectiveConfig!.displayName
          : fallbackTitle,
      price: effectiveConfig != null
          ? _formatPrice(effectiveConfig.priceCny)
          : fallbackPrice,
      period: effectiveConfig != null
          ? _displayPeriod(effectiveConfig, l10n)
          : fallbackPeriod,
      badge: _badgeForPlanId(effectiveConfig?.planId, fallbackBadge, l10n),
      icon: icon,
      accent: accent,
      accentSoft: accentSoft,
      description: effectiveConfig?.description.trim().isNotEmpty == true
          ? effectiveConfig!.description
          : fallbackDescription,
      cta: fallbackCta,
      features: fallbackFeatures,
      isFeatured: isFeatured,
      priceValue: effectiveConfig?.priceCny,
      maxServers: effectiveConfig?.maxServers,
      maxDevices: effectiveConfig?.maxDevices,
      storageQuotaMb: effectiveConfig?.storageQuotaMb,
      supportsGithubSync: effectiveConfig != null,
      supportsPrioritySupport: effectiveConfig != null,
      supportsLifetimeUpdates: effectiveConfig?.isLifetime ?? false,
    );
  }


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final l10n = S.of(context);
      final billingProvider = context.read<BillingProvider>();
      if (!_hasRequestedPricingConfigs &&
          !billingProvider.isLoadingPricingConfigs &&
          billingProvider.pricingConfigs.isEmpty) {
        _hasRequestedPricingConfigs = true;
        billingProvider.loadPricingConfigs().catchError((Object error) {
          debugPrint('[BillingUI] loadPricingConfigs error: $error');
          if (!mounted) {
            return <PricingConfig>[];
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.pricingLoadConfigsFailed(error.toString())),
              backgroundColor: DesignSystem.error,
            ),
          );
          return <PricingConfig>[];
        });
      }

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
    final billingProvider = context.watch<BillingProvider>();
    final plans = _buildPlans(l10n, billingProvider);

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
                _buildHero(l10n, plans),
                const SizedBox(height: DesignSystem.space5),
                if (billingProvider.isLoadingPricingConfigs &&
                    billingProvider.pricingConfigs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: DesignSystem.space6),
                    child: Center(
                      child: CircularProgressIndicator(color: _pricingAccent),
                    ),
                  )
                else ...[
                  isMobile
                      ? _buildMobileLayout(plans, currentPlanId, l10n)
                      : _buildDesktopLayout(plans, currentPlanId, l10n),
                  const SizedBox(height: DesignSystem.space5),
                  _buildFeatureComparison(plans, currentPlanId, l10n),
                ],
                const SizedBox(height: DesignSystem.space5),
                _buildFAQ(l10n),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero(S l10n, List<_PlanSpec> plans) {
    final paidPlans = plans.where((plan) => plan.id != 'free').toList(growable: false);
    final maxDevices = paidPlans
        .map((plan) => plan.maxDevices)
        .whereType<int>()
        .fold<int>(0, (previous, value) => value > previous ? value : previous);
    final maxStorageMb = paidPlans
        .map((plan) => plan.storageQuotaMb)
        .whereType<int>()
        .fold<int>(0, (previous, value) => value > previous ? value : previous);

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
                child: Text(
                  l10n.pricingWorkspace,
                  style: const TextStyle(
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
                  _HeroStat(label: l10n.pricingCrossDeviceSync, value: l10n.pricingIncluded),
                  _HeroStat(
                    label: l10n.pricingDeviceQuota,
                    value: maxDevices > 0 ? _formatLimit(maxDevices, l10n) : '—',
                  ),
                  _HeroStat(
                    label: l10n.pricingCloudStorage,
                    value: maxStorageMb > 0 ? _formatStorage(maxStorageMb) : '—',
                  ),
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
                _buildComparisonRow(
                  l10n.pricingServerCount,
                  plans
                      .map((plan) => _formatLimit(plan.maxServers, l10n))
                      .toList(growable: false),
                ),
                _buildComparisonRow(
                  l10n.pricingDeviceCount,
                  plans
                      .map((plan) => _formatLimit(plan.maxDevices, l10n))
                      .toList(growable: false),
                ),
                _buildComparisonRow(
                  l10n.pricingCloudStorage,
                  plans
                      .map((plan) => _formatStorage(plan.storageQuotaMb))
                      .toList(growable: false),
                ),
                _buildComparisonRow(
                  l10n.pricingGitHubSync,
                  plans
                      .map((plan) => _formatSupport(plan.supportsGithubSync, l10n))
                      .toList(growable: false),
                ),
                _buildComparisonRow(
                  l10n.pricingPrioritySupport,
                  plans
                      .map(
                        (plan) => _formatSupport(plan.supportsPrioritySupport, l10n),
                      )
                      .toList(growable: false),
                ),
                _buildComparisonRow(
                  l10n.pricingLifetimeUpdates,
                  plans
                      .map(
                        (plan) => _formatSupport(plan.supportsLifetimeUpdates, l10n),
                      )
                      .toList(growable: false),
                  isLast: true,
                ),
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
    final billingProvider = Provider.of<BillingProvider>(context, listen: false);
    final planSpec = _buildPlans(l10n, billingProvider).firstWhere(
      (item) => item.id == plan,
      orElse: () => _buildFreePlan(l10n),
    );
    debugPrint('[BillingUI] _handlePurchase start: plan=$plan');
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
                '${planSpec.title} · ${planSpec.price}${planSpec.period}',
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
    debugPrint('[BillingUI] _handlePurchase dialog result: $result');
    if (result == null) {
      debugPrint('[BillingUI] _handlePurchase cancelled by user');
      return;
    }

    if (result.startsWith('redeem:')) {
      debugPrint('[BillingUI] _handlePurchase entering redeem flow');
      await _redeemCode(result.substring(7));
    } else if (result == 'pay') {
      debugPrint('[BillingUI] _handlePurchase entering payment flow');
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
    debugPrint('[BillingUI] _startPaymentFlow start: planId=$planId parsedPlan=${billingPlan?.id} apiBaseUrl=${EnvConfig.apiBaseUrl}');
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
    final supabase = Supabase.instance.client;
    final accessToken = supabase.auth.currentSession?.accessToken;
    debugPrint('[BillingUI] session state before createOrder: hasSession=${supabase.auth.currentSession != null} userId=${supabase.auth.currentUser?.id} authState=${authProvider.state.name} accessToken=$accessToken');

    _showBlockingLoading();

    try {
      final order = await billingProvider.createOrder(plan: billingPlan);
      debugPrint('[BillingUI] createOrder success: orderId=${order.id} paymentUrlHost=${Uri.tryParse(order.paymentUrl)?.host} qrCodeUrlHost=${Uri.tryParse(order.qrCodeUrl ?? '')?.host}');

      _dismissBlockingLoading();

      final paymentSheetCompleted = await _showPaymentCheckoutDialog(order);
      debugPrint('[BillingUI] payment checkout dialog completed: completed=$paymentSheetCompleted orderId=${order.id}');
      if (!paymentSheetCompleted) {
        billingProvider.clearState();
        debugPrint('[BillingUI] payment checkout dialog cancelled by user');
        return;
      }

      debugPrint('[BillingUI] waitForPayment start: orderId=${order.id}');
      _showBlockingLoading(message: l10n.pricingWaitingForConfirmation);

      final status = await billingProvider.waitForPayment(orderId: order.id);
      debugPrint('[BillingUI] waitForPayment completed: orderId=${order.id} state=${status.state.name} isPaid=${status.isPaid} message=${status.message}');

      _dismissBlockingLoading();

      if (status.isPaid) {
        await authProvider.refreshUser();
        billingProvider.clearState();
        if (!mounted) return;
        await _showPaymentStatusDialog(
          title: l10n.pricingPaymentSuccessTitle,
          message: status.message?.trim().isNotEmpty == true
              ? status.message!
              : l10n.pricingPaymentSuccessMessage,
          confirmText: l10n.pricingViewAccount,
          onConfirm: _openAccountCenter,
        );
        return;
      }

      if (!mounted) return;
      switch (status.state) {
        case PaymentOrderState.pending:
        case PaymentOrderState.unknown:
          await _showPaymentStatusDialog(
            title: l10n.pricingPaymentPendingTitle,
            message: status.message?.trim().isNotEmpty == true
                ? status.message!
                : l10n.pricingPaymentPendingMessage,
            confirmText: l10n.pricingViewAccount,
            onConfirm: _openAccountCenter,
          );
          break;
        case PaymentOrderState.failed:
          await _showPaymentStatusDialog(
            title: l10n.pricingPaymentFailedTitle,
            message: status.message?.trim().isNotEmpty == true
                ? status.message!
                : l10n.pricingPaymentFailedMessage,
            confirmText: l10n.pricingReopenPayment,
            onConfirm: () => _showPaymentCheckoutDialog(order),
          );
          break;
        case PaymentOrderState.cancelled:
          await _showPaymentStatusDialog(
            title: l10n.pricingPaymentCancelledTitle,
            message: status.message?.trim().isNotEmpty == true
                ? status.message!
                : l10n.pricingPaymentCancelledMessage,
            confirmText: l10n.pricingReopenPayment,
            onConfirm: () => _showPaymentCheckoutDialog(order),
          );
          break;
        case PaymentOrderState.expired:
          await _showPaymentStatusDialog(
            title: l10n.pricingPaymentExpiredTitle,
            message: status.message?.trim().isNotEmpty == true
                ? status.message!
                : l10n.pricingPaymentExpiredMessage,
            confirmText: l10n.pricingAcknowledge,
          );
          break;
        case PaymentOrderState.paid:
          break;
      }

      billingProvider.clearState();
      debugPrint('[BillingUI] payment flow finished with non-paid state, provider state cleared');
    } catch (error) {
      _dismissBlockingLoading();
      billingProvider.clearState();
      debugPrint('[BillingUI] payment flow exception: $error');
      if (!mounted) return;
      await _showPaymentStatusDialog(
        title: l10n.pricingPaymentFlowFailedTitle,
        message: l10n.pricingPaymentFlowFailedMessage(error.toString()),
        confirmText: l10n.pricingAcknowledge,
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

  void _showBlockingLoading({String? message}) {
    final l10n = S.of(context);
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
                  message ?? l10n.pricingProcessing,
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
    final l10n = S.of(context);
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
              child: Text(
                l10n.pricingClose,
                style: const TextStyle(color: DesignSystem.neutral600),
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

  Future<bool> _showPaymentCheckoutDialog(PaymentOrder order) async {
    if (!mounted) return false;

    final l10n = S.of(context);
    final paymentUrl = order.paymentUrl.trim();
    debugPrint('[BillingUI] _showPaymentCheckoutDialog: orderId=${order.id} paymentUrl=$paymentUrl');

    final initialUri = Uri.tryParse(paymentUrl);
    if (initialUri == null ||
        !(initialUri.scheme == 'http' || initialUri.scheme == 'https')) {
      debugPrint('[BillingUI] _showPaymentCheckoutDialog invalid payment url: $paymentUrl');
      return await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignSystem.radiusXl),
              ),
              title: Text(l10n.pricingCheckoutUnavailableTitle),
              content: SelectableText(
                paymentUrl.isEmpty
                    ? l10n.pricingCheckoutUnavailableMessage
                    : paymentUrl,
                style: const TextStyle(color: DesignSystem.neutral600, height: 1.5),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(l10n.cancel),
                ),
              ],
            ),
          ) ??
          false;
    }

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            final isHttp = uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
            debugPrint('[BillingUI] payment webview navigate: ${request.url} isMainFrame=${request.isMainFrame}');
            if (isHttp) {
              return NavigationDecision.navigate;
            }
            debugPrint('[BillingUI] payment webview blocked non-http scheme: ${request.url}');
            return NavigationDecision.prevent;
          },
          onWebResourceError: (error) {
            debugPrint('[BillingUI] payment webview error: code=${error.errorCode} type=${error.errorType} desc=${error.description}');
          },
        ),
      )
      ..loadRequest(initialUri);

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            final screenSize = MediaQuery.of(dialogContext).size;
            final dialogWidth = screenSize.width >= 980 ? 860.0 : screenSize.width - 48;
            final dialogHeight = screenSize.height >= 900 ? 760.0 : screenSize.height - 96;

            return AlertDialog(
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
                      Icons.account_balance_wallet_rounded,
                      color: _pricingAccent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: DesignSystem.space3),
                  Expanded(
                    child: Text(
                      l10n.pricingCheckoutTitle,
                      style: const TextStyle(
                        color: DesignSystem.neutral900,
                        fontWeight: DesignSystem.weightSemibold,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: dialogWidth,
                height: dialogHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.pricingCheckoutInstruction,
                      style: const TextStyle(
                        color: DesignSystem.neutral600,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: DesignSystem.space4),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
                          border: Border.all(color: _pricingPanelBorder),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: WebViewWidget(controller: controller),
                      ),
                    ),
                    const SizedBox(height: DesignSystem.space4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(DesignSystem.space4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
                        border: Border.all(color: _pricingPanelBorder),
                      ),
                      child: Wrap(
                        spacing: DesignSystem.space5,
                        runSpacing: DesignSystem.space2,
                        children: [
                          Text(
                            l10n.pricingOrderId(order.id),
                            style: const TextStyle(
                              color: DesignSystem.neutral700,
                              fontWeight: DesignSystem.weightMedium,
                            ),
                          ),
                          Text(
                            l10n.pricingAmountValue(order.amountCny.toStringAsFixed(2)),
                            style: const TextStyle(
                              color: DesignSystem.neutral600,
                            ),
                          ),
                          if (order.expiresAt != null)
                            Text(
                              l10n.pricingExpiresAtValue(
                                order.expiresAt!.toLocal().toString(),
                              ),
                              style: const TextStyle(
                                color: DesignSystem.neutral600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(
                    l10n.cancel,
                    style: const TextStyle(color: DesignSystem.neutral600),
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: _pricingAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(l10n.pricingPaymentCompleted),
                ),
              ],
            );
          },
        ) ??
        false;
  }



  String _formatPrice(double priceCny) {
    if (priceCny == priceCny.roundToDouble()) {
      return '¥${priceCny.toStringAsFixed(0)}';
    }
    return '¥${priceCny.toStringAsFixed(1)}';
  }

  String _displayPeriod(PricingConfig config, S l10n) {
    switch (config.billingPeriod.trim()) {
      case 'month':
        return l10n.pricingPlanProPeriod;
      case 'year':
        return l10n.pricingPeriodYear;
      case 'lifetime':
      case 'one_time':
        return l10n.pricingPlanLifetimePeriod;
      default:
        return config.isLifetime ? l10n.pricingPlanLifetimePeriod : l10n.pricingPlanProPeriod;
    }
  }

  String _badgeForPlanId(String? planId, String fallbackBadge, S l10n) {
    switch (planId) {
      case 'pro_monthly':
        return l10n.pricingBadgeMostPopular;
      case 'pro_yearly':
        return l10n.pricingBadgeBestForTeams;
      case 'lifetime':
        return l10n.pricingBadgeBestValue;
      default:
        return fallbackBadge;
    }
  }

  String _formatLimit(int? value, S l10n) {
    if (value == null || value <= 0) {
      return '—';
    }
    return '$value';
  }

  String _formatStorage(int? storageQuotaMb) {
    if (storageQuotaMb == null || storageQuotaMb <= 0) {
      return '—';
    }
    if (storageQuotaMb >= 1024) {
      final storageGb = storageQuotaMb / 1024;
      if (storageGb == storageGb.roundToDouble()) {
        return '${storageGb.toStringAsFixed(0)} GB';
      }
      return '${storageGb.toStringAsFixed(1)} GB';
    }
    return '$storageQuotaMb MB';
  }

  String _formatSupport(bool enabled, S l10n) {
    return enabled ? l10n.pricingIncluded : l10n.pricingUnsupported;
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
    this.priceValue,
    this.maxServers,
    this.maxDevices,
    this.storageQuotaMb,
    this.supportsGithubSync = false,
    this.supportsPrioritySupport = false,
    this.supportsLifetimeUpdates = false,
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
  final double? priceValue;
  final int? maxServers;
  final int? maxDevices;
  final int? storageQuotaMb;
  final bool supportsGithubSync;
  final bool supportsPrioritySupport;
  final bool supportsLifetimeUpdates;
}
