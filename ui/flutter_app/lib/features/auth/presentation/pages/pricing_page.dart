import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../../../widgets/custom_app_bar.dart';
import '../providers/auth_provider.dart';

/// 价目表页面
class PricingPage extends StatefulWidget {
  const PricingPage({super.key});

  @override
  State<PricingPage> createState() => _PricingPageState();
}

class _PricingPageState extends State<PricingPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // 在手机端，自动滚动到 Pro 版
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isMobile(context)) {
        // 延迟一下，等待布局完成
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_scrollController.hasClients) {
            // 滚动到第二个卡片（Pro 版）
            _scrollController.animateTo(
              MediaQuery.of(context).size.width * 0.85, // 大约一个卡片的宽度
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          }
        });
      }
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

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: CustomAppBar(
        showBackButton: true,
        title: '选择套餐',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题
            const Text(
              '选择适合你的套餐',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              '解锁更多功能，享受更好的体验',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // 价格卡片 - 根据屏幕大小选择布局
            if (isMobile)
              _buildMobileLayout()
            else
              _buildDesktopLayout(),

            const SizedBox(height: 32),

            // 功能对比表
            _buildFeatureComparison(),
            const SizedBox(height: 32),

            // 常见问题
            _buildFAQ(),
          ],
        ),
      ),
    );
  }

  // 手机端布局：横向滚动
  Widget _buildMobileLayout() {
    return SizedBox(
      height: 520,
      child: ListView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        children: [
          SizedBox(
            width: MediaQuery.of(context).size.width - 32,
            child: _buildPricingCard(
              context: context,
              title: '社区免费版',
              price: '¥0',
              period: '永久免费',
              icon: Icons.person_outline,
              color: const Color(0xFF6B7280),
              features: [
                '最多 10 个服务器',
                '最多 2 个设备',
                '100 MB 云存储',
                '基础播放功能',
                '社区支持',
              ],
              isCurrentPlan: true,
              onTap: null,
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: MediaQuery.of(context).size.width - 32,
            child: _buildPricingCard(
              context: context,
              title: 'Pro 版',
              price: '¥6.9',
              period: '/ 月',
              icon: Icons.workspace_premium,
              color: const Color(0xFF3B82F6),
              features: [
                '无限服务器',
                '最多 5 个设备',
                '1 GB 云存储',
                '高级播放功能',
                '优先支持',
                'GitHub 同步',
              ],
              isRecommended: true,
              onTap: () => _handlePurchase(context, 'pro_monthly'),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: MediaQuery.of(context).size.width - 32,
            child: _buildPricingCard(
              context: context,
              title: '永久版',
              price: '¥69',
              period: '一次性付费',
              icon: Icons.stars,
              color: const Color(0xFFF59E0B),
              features: [
                '无限服务器',
                '无限设备',
                '5 GB 云存储',
                '所有高级功能',
                '终身更新',
                '优先支持',
                'GitHub 同步',
              ],
              badge: '最超值',
              onTap: () => _handlePurchase(context, 'lifetime'),
            ),
          ),
        ],
      ),
    );
  }

  // PC 端布局：三列并排
  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildPricingCard(
            context: context,
            title: '社区免费版',
            price: '¥0',
            period: '永久免费',
            icon: Icons.person_outline,
            color: const Color(0xFF6B7280),
            features: [
              '最多 10 个服务器',
              '最多 2 个设备',
              '100 MB 云存储',
              '基础播放功能',
              '社区支持',
            ],
            isCurrentPlan: true,
            onTap: null,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildPricingCard(
            context: context,
            title: 'Pro 版',
            price: '¥6.9',
            period: '/ 月',
            icon: Icons.workspace_premium,
            color: const Color(0xFF3B82F6),
            features: [
              '无限服务器',
              '最多 5 个设备',
              '1 GB 云存储',
              '高级播放功能',
              '优先支持',
              'GitHub 同步',
            ],
            isRecommended: true,
            onTap: () => _handlePurchase(context, 'pro_monthly'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildPricingCard(
            context: context,
            title: '永久版',
            price: '¥69',
            period: '一次性付费',
            icon: Icons.stars,
            color: const Color(0xFFF59E0B),
            features: [
              '无限服务器',
              '无限设备',
              '5 GB 云存储',
              '所有高级功能',
              '终身更新',
              '优先支持',
              'GitHub 同步',
            ],
            badge: '最超值',
            onTap: () => _handlePurchase(context, 'lifetime'),
          ),
        ),
      ],
    );
  }

  Widget _buildPricingCard({
    required BuildContext context,
    required String title,
    required String price,
    required String period,
    required IconData icon,
    required Color color,
    required List<String> features,
    bool isCurrentPlan = false,
    bool isRecommended = false,
    String? badge,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isRecommended
            ? Border.all(color: color, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 图标和标题
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [color, color.withOpacity(0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Icon(icon, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          if (badge != null)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                badge,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 价格
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        period,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 功能列表
                ...features.map((feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 20,
                            color: color,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              feature,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 24),

                // 按钮
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isCurrentPlan ? null : onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCurrentPlan
                          ? const Color(0xFFE5E7EB)
                          : color,
                      foregroundColor: isCurrentPlan
                          ? const Color(0xFF6B7280)
                          : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      isCurrentPlan ? '当前套餐' : '立即购买',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isRecommended)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                child: const Text(
                  '推荐',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeatureComparison() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '功能对比',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16),
          _buildComparisonRow('服务器数量', '10', '无限', '无限'),
          _buildComparisonRow('设备数量', '2', '5', '无限'),
          _buildComparisonRow('云存储', '100 MB', '1 GB', '5 GB'),
          _buildComparisonRow('GitHub 同步', '✗', '✓', '✓'),
          _buildComparisonRow('优先支持', '✗', '✓', '✓'),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(
    String feature,
    String free,
    String pro,
    String lifetime,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              feature,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          Expanded(
            child: Text(
              free,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF1F2937),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              pro,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF3B82F6),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              lifetime,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFFF59E0B),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQ() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '常见问题',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16),
          _buildFAQItem(
            '如何升级到 Pro 版？',
            '点击"立即购买"按钮，选择支付方式完成支付即可。',
          ),
          _buildFAQItem(
            '永久版和 Pro 版有什么区别？',
            '永久版是一次性付费，终身享受所有功能。Pro 版是按月订阅。',
          ),
          _buildFAQItem(
            '可以随时取消订阅吗？',
            '可以。Pro 版订阅可以随时取消，取消后在当前周期结束前仍可使用。',
          ),
          _buildFAQItem(
            '支持哪些支付方式？',
            '支持支付宝、微信支付、Stripe 等多种支付方式。',
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            answer,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePurchase(BuildContext context, String plan) async {
    final codeCtrl = TextEditingController();
    final paymentUrl = _getPaymentUrl(plan);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              '确认购买',
              style: TextStyle(
                color: Color(0xFF1F2937),
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '套餐：${_getPlanName(plan)}\n价格：${_getPlanPrice(plan)}',
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                const Text(
                  '🎫 有兑换码？',
                  style: TextStyle(
                    color: Color(0xFF1F2937),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 14,
                    letterSpacing: 1.2,
                  ),
                  decoration: InputDecoration(
                    hintText: 'BOVA-XXXX-XXXX-XXXX',
                    hintStyle: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Color(0xFF3B82F6),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text(
                  '取消',
                  style: TextStyle(color: Color(0xFF6B7280)),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  final code = codeCtrl.text.trim();
                  if (code.isNotEmpty) {
                    Navigator.pop(ctx, 'redeem:$code');
                  } else {
                    Navigator.pop(ctx, 'pay');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F2937),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(codeCtrl.text.trim().isNotEmpty ? '兑换' : '去支付'),
              ),
            ],
          );
        },
      ),
    );

    if (result == null) return;

    if (result.startsWith('redeem:')) {
      final code = result.substring(7);
      await _redeemCode(code);
    } else if (result == 'pay') {
      await _launchPaymentUrl(paymentUrl);
    }
  }

  Future<void> _redeemCode(String code) async {
    // 显示加载
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
      ),
    );

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final result = await authProvider.redeemCode(code);
      
      // 关闭加载
      if (mounted) Navigator.pop(context);

      if (result['success'] == true) {
        // 成功提示
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Text('🎉 ', style: TextStyle(fontSize: 24)),
                  Text(
                    '兑换成功',
                    style: TextStyle(
                      color: Color(0xFF1F2937),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              content: Text(
                result['message'] ?? '账号已升级！',
                style: const TextStyle(color: Color(0xFF6B7280)),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context); // 返回上一页
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('确定'),
                ),
              ],
            ),
          );
        }
      } else {
        // 失败提示
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? '兑换失败'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('兑换失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getPaymentUrl(String plan) {
    // TODO: 替换为实际的支付 URL
    return 'https://payment.bovaplayer.com/checkout?plan=$plan';
  }

  String _getPlanName(String plan) {
    switch (plan) {
      case 'pro_monthly':
        return 'Pro 版（月付）';
      case 'lifetime':
        return '永久版';
      default:
        return '未知套餐';
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
    } else {
      print('[Pricing] 无法打开支付 URL: $url');
    }
  }
}
