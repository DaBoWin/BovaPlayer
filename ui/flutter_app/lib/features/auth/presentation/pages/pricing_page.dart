import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/design_system.dart';
import '../../../../core/widgets/bova_button.dart';
import '../../../../core/widgets/bova_text_field.dart';
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

  List<_PlanSpec> get _plans => const [
        _PlanSpec(
          id: 'free',
          title: '社区免费版',
          price: '¥0',
          period: '永久免费',
          badge: 'Starter',
          icon: Icons.person_outline,
          accent: DesignSystem.neutral700,
          accentSoft: DesignSystem.neutral100,
          description: '适合轻量使用与本地播放体验，保留最基础的核心能力。',
          cta: '当前套餐',
          features: [
            '最多 10 个服务器',
            '最多 2 个设备',
            '100 MB 云存储',
            '基础播放功能',
            '社区支持',
          ],
        ),
        _PlanSpec(
          id: 'pro_monthly',
          title: 'Pro 版',
          price: '¥6.9',
          period: '/ 月',
          badge: 'Most Popular',
          icon: Icons.workspace_premium_outlined,
          accent: Color(0xFFA21CAF),
          accentSoft: Color(0xFFFAF5FF),
          description: '给多设备、多媒体库与跨端同步准备的主力方案。',
          cta: '升级到 Pro',
          isFeatured: true,
          features: [
            '无限服务器',
            '最多 5 个设备',
            '1 GB 云存储',
            '高级播放功能',
            '优先支持',
            'GitHub 同步',
          ],
        ),
        _PlanSpec(
          id: 'lifetime',
          title: '永久版',
          price: '¥69',
          period: '一次性付费',
          badge: 'Best Value',
          icon: Icons.auto_awesome_outlined,
          accent: DesignSystem.accent700,
          accentSoft: Color(0xFFFFFBEB),
          description: '一次购买，长期解锁高级同步、完整配额与后续更新。',
          cta: '解锁永久版',
          features: [
            '无限服务器',
            '无限设备',
            '5 GB 云存储',
            '所有高级功能',
            '终身更新',
            '优先支持',
            'GitHub 同步',
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
    final isMobile = _isMobile(context);
    final user = context.watch<AuthProvider>().user;
    final currentPlanId = _currentPlanId(user);

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
        title: const Text(
          '会员方案',
          style: TextStyle(
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
                _buildHero(),
                const SizedBox(height: DesignSystem.space5),
                isMobile
                    ? _buildMobileLayout(currentPlanId)
                    : _buildDesktopLayout(currentPlanId),
                const SizedBox(height: DesignSystem.space5),
                _buildFeatureComparison(currentPlanId),
                const SizedBox(height: DesignSystem.space5),
                _buildFAQ(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
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
              const Text(
                '选择适合你的套餐',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: DesignSystem.weightBold,
                  color: DesignSystem.neutral900,
                  letterSpacing: -1.0,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: DesignSystem.space3),
              const Text(
                '账户、权益与升级流程统一到同一套工作区界面里。你可以直接升级，也可以先输入兑换码。',
                style: TextStyle(
                  fontSize: DesignSystem.textSm,
                  color: DesignSystem.neutral600,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: DesignSystem.space4),
              const Wrap(
                spacing: DesignSystem.space3,
                runSpacing: DesignSystem.space3,
                children: [
                  _HeroStat(label: '跨设备同步', value: 'Included'),
                  _HeroStat(label: '设备额度', value: 'Up to Unlimited'),
                  _HeroStat(label: '云存储', value: '100 MB → 5 GB'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(String currentPlanId) {
    final cardWidth = MediaQuery.of(context).size.width - 40;
    return SizedBox(
      height: 560,
      child: ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: _plans.length,
        separatorBuilder: (_, __) => const SizedBox(width: DesignSystem.space4),
        itemBuilder: (context, index) => SizedBox(
          width: cardWidth,
          child: _buildPricingCard(_plans[index], currentPlanId),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(String currentPlanId) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int index = 0; index < _plans.length; index++) ...[
          Expanded(child: _buildPricingCard(_plans[index], currentPlanId)),
          if (index != _plans.length - 1)
            const SizedBox(width: DesignSystem.space4),
        ],
      ],
    );
  }

  Widget _buildPricingCard(_PlanSpec plan, String currentPlanId) {
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
                    child: const Text(
                      '推荐',
                      style: TextStyle(
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
            const Spacer(),
            const SizedBox(height: DesignSystem.space3),
            BovaButton(
              text: isCurrentPlan ? '当前套餐' : plan.cta,
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

  Widget _buildFeatureComparison(String currentPlanId) {
    return _buildPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.table_chart_outlined,
            title: '功能对比',
            subtitle: '用同一张表快速对比不同方案的核心能力。',
          ),
          const SizedBox(height: DesignSystem.space5),
          ClipRRect(
            borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
            child: Column(
              children: [
                _buildComparisonHeader(currentPlanId),
                _buildComparisonRow('服务器数量', const ['10', '无限', '无限']),
                _buildComparisonRow('设备数量', const ['2', '5', '无限']),
                _buildComparisonRow('云存储', const ['100 MB', '1 GB', '5 GB']),
                _buildComparisonRow('GitHub 同步', const ['—', '支持', '支持']),
                _buildComparisonRow('优先支持', const ['—', '支持', '支持']),
                _buildComparisonRow('终身更新', const ['—', '—', '支持'],
                    isLast: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonHeader(String currentPlanId) {
    final headers = [
      const SizedBox(),
      for (final plan in _plans)
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

  Widget _buildFAQ() {
    return _buildPanel(
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FaqHeader(),
          SizedBox(height: DesignSystem.space5),
          _FaqItem(
            question: '购买后多久生效？',
            answer: '支付或兑换成功后会立刻更新账号权益，重新进入账户页即可看到最新状态。',
          ),
          SizedBox(height: DesignSystem.space3),
          _FaqItem(
            question: '可以先输入兑换码吗？',
            answer: '可以。在购买确认弹窗里直接输入兑换码，系统会优先尝试兑换。',
          ),
          SizedBox(height: DesignSystem.space3),
          _FaqItem(
            question: 'Pro 和永久版区别是什么？',
            answer: 'Pro 更适合月度订阅与持续使用；永久版更适合长期主力使用，权益一次性解锁。',
          ),
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
    final codeController = TextEditingController();
    final paymentUrl = _getPaymentUrl(plan);

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
            const Expanded(
              child: Text(
                '确认购买',
                style: TextStyle(
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
                '${_getPlanName(plan)} · ${_getPlanPrice(plan)}',
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
                    const Text(
                      '有兑换码？',
                      style: TextStyle(
                        fontSize: DesignSystem.textSm,
                        fontWeight: DesignSystem.weightSemibold,
                        color: DesignSystem.neutral900,
                      ),
                    ),
                    const SizedBox(height: DesignSystem.space2),
                    BovaTextField(
                      controller: codeController,
                      label: '兑换码',
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
            child: const Text(
              '取消',
              style: TextStyle(color: DesignSystem.neutral600),
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
              codeController.text.trim().isNotEmpty ? '兑换' : '去支付',
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
      await _launchPaymentUrl(paymentUrl);
    }
  }

  Future<void> _redeemCode(String code) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: _pricingAccent),
      ),
    );

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final result = await authProvider.redeemCode(code);

      if (mounted) Navigator.pop(context);

      if (result['success'] == true) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignSystem.radiusXl),
            ),
            title: const Text(
              '兑换成功',
              style: TextStyle(
                color: DesignSystem.neutral900,
                fontWeight: DesignSystem.weightSemibold,
              ),
            ),
            content: Text(
              result['message'] ?? '账号权益已更新。',
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
                child: const Text('确定'),
              ),
            ],
          ),
        );
        if (mounted) Navigator.pop(context);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? '兑换失败'),
            backgroundColor: DesignSystem.error,
          ),
        );
      }
    } catch (error) {
      if (mounted) Navigator.pop(context);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('兑换失败: $error'),
          backgroundColor: DesignSystem.error,
        ),
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

  String _getPaymentUrl(String plan) {
    return 'https://payment.bovaplayer.com/checkout?plan=$plan';
  }

  String _getPlanName(String plan) {
    switch (plan) {
      case 'pro_monthly':
        return 'Pro 版（月付）';
      case 'lifetime':
        return '永久版';
      default:
        return '社区免费版';
    }
  }

  String _getPlanPrice(String plan) {
    switch (plan) {
      case 'pro_monthly':
        return '¥6.9 / 月';
      case 'lifetime':
        return '¥69（一次性）';
      default:
        return '¥0';
    }
  }

  Future<void> _launchPaymentUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
  const _FaqHeader();

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
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '常见问题',
                style: TextStyle(
                  fontSize: DesignSystem.textBase,
                  fontWeight: DesignSystem.weightSemibold,
                  color: DesignSystem.neutral900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '购买与兑换前最常被问到的几个问题。',
                style: TextStyle(
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
