import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/design_system.dart';
import '../../../../core/widgets/bova_button.dart';
import '../../../../core/widgets/bova_text_field.dart';
import '../../domain/entities/user.dart';
import '../providers/auth_provider.dart';
import 'pricing_page.dart';
import 'redemption_admin_page.dart';

const String _avatarPrefsKey = 'local_avatar_path';

const Color _accountAccent = Color(0xFFE11D48);
const Color _accountAccentSoft = Color(0xFFFCE7F3);
const Color _accountCanvas = Color(0xFFF1F3F6);
const Color _accountPanel = Colors.white;
const Color _accountPanelBorder = Color(0xFFE7EAF0);
const double _overviewCardMinHeight = 332;

class AccountPage extends StatefulWidget {
  const AccountPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage>
    with TickerProviderStateMixin {
  bool _isUploadingAvatar = false;
  bool _isRefreshing = false;
  String? _localAvatarPath;

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
    _loadLocalAvatar();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadLocalAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_avatarPrefsKey);
    if (!mounted) return;

    if (path != null && File(path).existsSync()) {
      setState(() => _localAvatarPath = path);
    }
  }

  Future<void> _pickAndSaveAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (image == null) return;

    setState(() => _isUploadingAvatar = true);

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final avatarDir = Directory('${appDir.path}/avatars');
      if (!avatarDir.existsSync()) {
        avatarDir.createSync(recursive: true);
      }

      final dotIndex = image.path.lastIndexOf('.');
      final ext = dotIndex >= 0 ? image.path.substring(dotIndex) : '';
      final destPath = '${avatarDir.path}/avatar$ext';
      await File(image.path).copy(destPath);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_avatarPrefsKey, destPath);

      if (!mounted) return;
      setState(() => _localAvatarPath = destPath);
      _showSnackBar('头像已更新');
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('保存失败：$error', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  Future<void> _refreshUser(AuthProvider authProvider) async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);
    await authProvider.refreshUser();
    if (!mounted) return;
    setState(() => _isRefreshing = false);

    if (authProvider.user != null) {
      _showSnackBar('账号数据已刷新');
    } else {
      _showSnackBar('刷新失败，请稍后重试', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? DesignSystem.error : DesignSystem.neutral900,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignSystem.radiusMd),
        ),
        margin: const EdgeInsets.all(DesignSystem.space4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: user == null
                      ? [
                          _buildMissingUserState(),
                        ]
                      : [
                          _buildHeroCard(user, authProvider),
                          const SizedBox(height: DesignSystem.space4),
                          _buildOverviewGrid(user),
                          const SizedBox(height: DesignSystem.space4),
                          _buildSyncCard(authProvider),
                          if (user.isAdmin) ...[
                            const SizedBox(height: DesignSystem.space4),
                            _buildAdminCard(),
                          ],
                          if (!user.isLifetime) ...[
                            const SizedBox(height: DesignSystem.space4),
                            _buildUpgradeCard(user),
                          ],
                          const SizedBox(height: DesignSystem.space4),
                          _buildLogoutCard(authProvider),
                        ],
                ),
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
          return ColoredBox(
            color: _accountCanvas,
            child: content,
          );
        }

        return SafeArea(
          top: true,
          child: content,
        );
      },
    );

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      backgroundColor: _accountCanvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: DesignSystem.neutral900,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '账号中心',
          style: TextStyle(
            fontSize: DesignSystem.textLg,
            fontWeight: DesignSystem.weightSemibold,
            color: DesignSystem.neutral900,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          Consumer<AuthProvider>(
            builder: (context, authProvider, _) {
              return Padding(
                padding: const EdgeInsets.only(right: DesignSystem.space3),
                child: _buildRefreshButton(authProvider),
              );
            },
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildRefreshButton(AuthProvider authProvider) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: IconButton(
        onPressed: _isRefreshing ? null : () => _refreshUser(authProvider),
        tooltip: '刷新账号信息',
        splashRadius: 20,
        icon: _isRefreshing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: DesignSystem.neutral700,
                ),
              )
            : const Icon(
                Icons.refresh_rounded,
                size: 18,
                color: DesignSystem.neutral700,
              ),
      ),
    );
  }

  Widget _buildSurfacePanel({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(DesignSystem.space5),
    Color backgroundColor = _accountPanel,
    Color borderColor = _accountPanelBorder,
    List<BoxShadow>? boxShadow,
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(DesignSystem.radius2xl),
        border: Border.all(color: borderColor),
        boxShadow: boxShadow ?? DesignSystem.shadowSm,
      ),
      child: child,
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    Color iconColor = _accountAccent,
    Color iconBackground = _accountAccentSoft,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
          ),
          child: Icon(icon, color: iconColor, size: 20),
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
              if (subtitle.isNotEmpty) ...[
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
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: DesignSystem.space3),
          trailing,
        ],
      ],
    );
  }

  Widget _buildMissingUserState() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: _buildSurfacePanel(
          padding: const EdgeInsets.all(DesignSystem.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: _accountAccentSoft,
                  borderRadius: BorderRadius.circular(DesignSystem.radiusXl),
                ),
                child: const Icon(
                  Icons.person_off_outlined,
                  color: _accountAccent,
                  size: 30,
                ),
              ),
              const SizedBox(height: DesignSystem.space4),
              const Text(
                '未获取到账号信息',
                style: TextStyle(
                  fontSize: DesignSystem.textXl,
                  fontWeight: DesignSystem.weightSemibold,
                  color: DesignSystem.neutral900,
                ),
              ),
              const SizedBox(height: DesignSystem.space2),
              const Text(
                '请重新登录或返回上一页后再次进入账户中心。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: DesignSystem.textSm,
                  color: DesignSystem.neutral600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: DesignSystem.space5),
              BovaButton(
                text: '返回',
                onPressed: () => Navigator.pop(context),
                isFullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(User user, AuthProvider authProvider) {
    final palette = _paletteFor(user.accountType);
    final levelLabel = switch (user.accountType) {
      AccountType.free => '基础账号',
      AccountType.pro => 'Pro 会员',
      AccountType.lifetime => '永久会员',
    };

    return _buildSurfacePanel(
      padding: EdgeInsets.zero,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DesignSystem.radius2xl),
          gradient: LinearGradient(
            colors: [
              Colors.white,
              palette.surface.withValues(alpha: 0.55),
              _accountAccentSoft.withValues(alpha: 0.35),
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAvatar(user, palette),
                  const SizedBox(width: DesignSystem.space4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: DesignSystem.space2,
                                runSpacing: DesignSystem.space2,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: DesignSystem.space3,
                                      vertical: DesignSystem.space1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: palette.surface
                                          .withValues(alpha: 0.95),
                                      borderRadius: BorderRadius.circular(
                                        DesignSystem.radiusFull,
                                      ),
                                      border: Border.all(
                                        color:
                                            palette.base.withValues(alpha: 0.8),
                                      ),
                                    ),
                                    child: Text(
                                      levelLabel,
                                      style: TextStyle(
                                        fontSize: DesignSystem.textXs,
                                        fontWeight: DesignSystem.weightSemibold,
                                        color: palette.text,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: DesignSystem.space3),
                            _buildRefreshButton(authProvider),
                          ],
                        ),
                        const SizedBox(height: DesignSystem.space3),
                        Text(
                          user.username ?? '未设置用户名',
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: DesignSystem.weightBold,
                            color: DesignSystem.neutral900,
                            letterSpacing: -0.8,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: DesignSystem.space2),
                        Text(
                          user.email,
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
              ),
              const SizedBox(height: DesignSystem.space5),
              Wrap(
                spacing: DesignSystem.space3,
                runSpacing: DesignSystem.space3,
                children: [
                  _buildHeroMeta(
                    icon: Icons.calendar_today_outlined,
                    label: '注册时间',
                    value: _formatDate(user.createdAt),
                  ),
                  _buildHeroMeta(
                    icon: Icons.update_outlined,
                    label: '最近更新',
                    value: _formatDate(user.updatedAt),
                  ),
                  _buildHeroMeta(
                    icon: Icons.verified_outlined,
                    label: '云同步',
                    value: context.read<AuthProvider>().isSyncEnabled
                        ? '已启用'
                        : '未启用',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(User user, _AccountPalette palette) {
    final initial =
        (user.username?.isNotEmpty == true ? user.username! : user.email)
            .substring(0, 1)
            .toUpperCase();

    Widget child;
    if (_isUploadingAvatar) {
      child = const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: DesignSystem.neutral700,
          ),
        ),
      );
    } else if (_localAvatarPath != null) {
      child = ClipOval(
        child: Image.file(
          File(_localAvatarPath!),
          width: 88,
          height: 88,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildAvatarFallback(initial, palette),
        ),
      );
    } else {
      child = _buildAvatarFallback(initial, palette);
    }

    return GestureDetector(
      onTap: _isUploadingAvatar ? null : _pickAndSaveAvatar,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 92,
            height: 92,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.72),
            ),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: child,
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: DesignSystem.neutral900,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.camera_alt_outlined,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarFallback(String initial, _AccountPalette palette) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [palette.base, palette.deep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: DesignSystem.weightBold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildHeroMeta({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 168),
      padding: const EdgeInsets.symmetric(
        horizontal: DesignSystem.space3,
        vertical: DesignSystem.space3,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
        border: Border.all(color: _accountPanelBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _accountAccentSoft,
              borderRadius: BorderRadius.circular(DesignSystem.radiusMd),
            ),
            child: Icon(icon, size: 16, color: _accountAccent),
          ),
          const SizedBox(width: DesignSystem.space2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: DesignSystem.textXs,
                  color: DesignSystem.neutral500,
                ),
              ),
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
        ],
      ),
    );
  }

  Widget _buildOverviewGrid(User user) {
    final isWide =
        DesignSystem.isDesktop(context) || DesignSystem.isTablet(context);
    final children = [
      _buildPlanCard(user),
      _buildUsageCard(user),
    ];

    if (!isWide) {
      return Column(
        children: [
          children[0],
          const SizedBox(height: DesignSystem.space4),
          children[1],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: children[0]),
        const SizedBox(width: DesignSystem.space4),
        Expanded(child: children[1]),
      ],
    );
  }

  Widget _buildPlanCard(User user) {
    final palette = _paletteFor(user.accountType);
    final isLifetime = user.accountType == AccountType.lifetime;
    final title = switch (user.accountType) {
      AccountType.free => '当前方案',
      AccountType.pro => '会员权益',
      AccountType.lifetime => '永久权益',
    };

    final eyebrow = switch (user.accountType) {
      AccountType.free => 'Current Plan',
      AccountType.pro => 'Pro Access',
      AccountType.lifetime => 'Lifetime Access',
    };

    final description = switch (user.accountType) {
      AccountType.free => '本地播放、媒体库管理与基础服务都已就绪。',
      AccountType.pro => '跨设备同步、更多设备额度与高级体验已经开启。',
      AccountType.lifetime => '包含全部 Pro 高级功能，长期使用无需再关心续费。',
    };

    final features = switch (user.accountType) {
      AccountType.free => const ['本地播放', '媒体库管理', '基础账户服务'],
      AccountType.pro => const ['云同步', '更多设备', '高级工作区', '优先体验新功能'],
      AccountType.lifetime => const [
          '云同步',
          '无限设备',
          '更大配额',
          '高级工作区',
          '优先体验',
          '长期免续费'
        ],
    };

    if (isLifetime) {
      const shellSurface = Color(0xFFF2F4F7);
      const shellSurfaceDeep = Color(0xFFE8ECF1);
      const cardIndigo = Color(0xFF171A4C);
      const cardIndigoDeep = Color(0xFF0D103A);
      const cardText = Color(0xFFF3F0E8);
      const cardMuted = Color(0xFFA3A7C9);
      const actionSurface = Color(0xFFF2E3BD);
      const actionText = Color(0xFF5A431C);

      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _overviewCardMinHeight),
        child: _buildSurfacePanel(
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
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [shellSurface, shellSurfaceDeep],
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
                          const Text(
                            'BovaPlayer\n永久权益',
                            style: TextStyle(
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
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '永久版',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: DesignSystem.weightSemibold,
                                color: actionText,
                                letterSpacing: 0.15,
                              ),
                            ),
                            SizedBox(width: DesignSystem.space2),
                            Icon(
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
                                    'VIP',
                                    style: TextStyle(
                                      fontSize: 92,
                                      fontWeight: FontWeight.w800,
                                      color:
                                          Colors.white.withValues(alpha: 0.12),
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
                                padding:
                                    const EdgeInsets.fromLTRB(28, 34, 28, 26),
                                child: compact
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 54),
                                          titleBlock,
                                          const SizedBox(
                                              height: DesignSystem.space5),
                                          actionChip,
                                        ],
                                      )
                                    : Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 54),
                                              child: titleBlock,
                                            ),
                                          ),
                                          const SizedBox(
                                              width: DesignSystem.space4),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 8),
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

    final gradientColors = switch (user.accountType) {
      AccountType.free => [const Color(0xFFFFFFFF), const Color(0xFFF9F6FA)],
      AccountType.pro => [const Color(0xFFFFFCFE), const Color(0xFFFAF4FB)],
      AccountType.lifetime => [
          const Color(0xFFFFFEFC),
          const Color(0xFFF8F2E8)
        ],
    };

    final borderColor = palette.base.withValues(alpha: 0.16);
    final headlineColor = palette.text;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _overviewCardMinHeight),
      child: _buildSurfacePanel(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color:
                              DesignSystem.neutral900.withValues(alpha: 0.05),
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
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: DesignSystem.weightSemibold,
                              color: DesignSystem.neutral500,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: DesignSystem.textXl,
                              fontWeight: DesignSystem.weightBold,
                              color: DesignSystem.neutral900,
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
                        color: Colors.white.withValues(alpha: 0.72),
                        borderRadius:
                            BorderRadius.circular(DesignSystem.radiusFull),
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
                  style: const TextStyle(
                    fontSize: DesignSystem.textSm,
                    color: DesignSystem.neutral700,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: DesignSystem.space4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.52),
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
                                style: const TextStyle(
                                  fontSize: DesignSystem.textSm,
                                  fontWeight: DesignSystem.weightMedium,
                                  color: DesignSystem.neutral700,
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
                      color: Colors.white.withValues(alpha: 0.64),
                      borderRadius:
                          BorderRadius.circular(DesignSystem.radiusLg),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.schedule_outlined,
                            size: 18, color: headlineColor),
                        const SizedBox(width: DesignSystem.space2),
                        Text(
                          '到期时间 ${_formatDate(user.proExpiresAt!)}',
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

  Widget _buildUsageCard(User user) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _overviewCardMinHeight),
      child: _buildSurfacePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              icon: Icons.equalizer_rounded,
              title: '使用情况',
              subtitle: '',
            ),
            const SizedBox(height: DesignSystem.space2),
            const Text(
              '服务器、设备与空间额度的当前占用。',
              style: TextStyle(
                fontSize: DesignSystem.textSm,
                color: DesignSystem.neutral600,
                height: 1.45,
              ),
            ),
            const SizedBox(height: DesignSystem.space4),
            _buildUsageLine(
              icon: Icons.dns_outlined,
              label: '服务器',
              current: user.usage.serverCount.toDouble(),
              max: user.limits.maxServers.toDouble(),
              formatter: (value) => value.toStringAsFixed(0),
            ),
            const SizedBox(height: DesignSystem.space4),
            _buildUsageLine(
              icon: Icons.devices_outlined,
              label: '设备',
              current: user.usage.deviceCount.toDouble(),
              max: user.limits.maxDevices.toDouble(),
              formatter: (value) => value.toStringAsFixed(0),
            ),
            const SizedBox(height: DesignSystem.space4),
            _buildUsageLine(
              icon: Icons.storage_outlined,
              label: '存储空间',
              current: user.usage.storageUsedMb.toDouble(),
              max: user.limits.storageQuotaMb.toDouble(),
              formatter: (value) =>
                  '${value.toStringAsFixed(value >= 100 ? 0 : 1)} MB',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageLine({
    required IconData icon,
    required String label,
    required double current,
    required double max,
    required String Function(double value) formatter,
  }) {
    final isUnlimited = max == -1;
    final progress = isUnlimited ? 0.0 : (current / max).clamp(0.0, 1.0);
    final isNearLimit = !isUnlimited && progress >= 0.8;
    final accent = isNearLimit ? DesignSystem.warning : DesignSystem.accent600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: DesignSystem.neutral100,
                borderRadius: BorderRadius.circular(DesignSystem.radiusMd),
              ),
              child: Icon(icon, size: 18, color: DesignSystem.neutral700),
            ),
            const SizedBox(width: DesignSystem.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: DesignSystem.textSm,
                      fontWeight: DesignSystem.weightMedium,
                      color: DesignSystem.neutral900,
                    ),
                  ),
                  Text(
                    isUnlimited
                        ? '${formatter(current)} / 无限'
                        : '${formatter(current)} / ${formatter(max)}',
                    style: TextStyle(
                      fontSize: DesignSystem.textXs,
                      fontWeight: DesignSystem.weightMedium,
                      color: isNearLimit
                          ? DesignSystem.warning
                          : DesignSystem.neutral500,
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
              backgroundColor: DesignSystem.neutral200,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSyncCard(AuthProvider authProvider) {
    final user = authProvider.user!;
    final isSyncEnabled = authProvider.isSyncEnabled;
    final isPro = user.isPro;
    return _buildSurfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: isSyncEnabled
                ? Icons.cloud_done_outlined
                : Icons.cloud_outlined,
            title: '云同步',
            subtitle: isSyncEnabled
                ? '媒体服务器与配置数据已安全同步'
                : (isPro ? '输入账号密码即可启用加密同步' : '升级即可开启跨设备同步'),
            iconColor: isSyncEnabled ? DesignSystem.success : _accountAccent,
            iconBackground: isSyncEnabled
                ? DesignSystem.success.withValues(alpha: 0.12)
                : _accountAccentSoft,
            trailing: !isPro
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignSystem.space2,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: DesignSystem.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(
                        DesignSystem.radiusFull,
                      ),
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
              text: isPro ? '启用云同步' : '查看升级方案',
              icon: isPro ? Icons.lock_open_outlined : Icons.workspace_premium,
              onPressed: isPro
                  ? () => _showEnableSyncDialog(authProvider)
                  : _openPricingPage,
              isFullWidth: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdminCard() {
    return _buildSurfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.admin_panel_settings_outlined,
            title: '管理员工具',
            subtitle: '管理兑换码与后台运营配置。',
            iconColor: DesignSystem.warning,
            iconBackground: const Color(0xFFFFF1E6),
          ),
          const SizedBox(height: DesignSystem.space4),
          _buildActionTile(
            icon: Icons.confirmation_number_outlined,
            title: '兑换码管理',
            subtitle: '生成、查看和维护兑换码状态',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RedemptionAdminPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeCard(User user) {
    final isPro = user.accountType == AccountType.pro;
    final gradient = isPro
        ? DesignSystem.lifetimeGradient
        : const LinearGradient(
            colors: [DesignSystem.neutral900, DesignSystem.neutral700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    return _buildSurfacePanel(
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
              const Text(
                'Membership Upgrade',
                style: TextStyle(
                  fontSize: DesignSystem.textXs,
                  fontWeight: DesignSystem.weightSemibold,
                  color: Color(0xFFE7E5E4),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: DesignSystem.space2),
              Text(
                isPro ? '升级到永久版' : '升级到 Pro',
                style: const TextStyle(
                  fontSize: DesignSystem.textLg,
                  fontWeight: DesignSystem.weightSemibold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: DesignSystem.space2),
              Text(
                isPro ? '一次升级，长期保留高级同步与更多设备额度。' : '解锁跨设备同步、更多高级功能与更高配额。',
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
                  onPressed: _openPricingPage,
                  icon: Icon(isPro ? Icons.stars_outlined : Icons.upgrade),
                  label: Text(isPro ? '查看永久版方案' : '查看 Pro 方案'),
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
                        DesignSystem.radiusFull,
                      ),
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

  Widget _buildLogoutCard(AuthProvider authProvider) {
    return _buildSurfacePanel(
      backgroundColor: const Color(0xFFFFFBFB),
      borderColor: const Color(0xFFF8D7DA),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.logout_rounded,
            title: '安全退出',
            subtitle: '退出后需要重新登录，云同步密码也会从本地清除。',
            iconColor: DesignSystem.error,
            iconBackground: const Color(0xFFFEE2E2),
          ),
          const SizedBox(height: DesignSystem.space4),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showLogoutDialog(authProvider),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('登出'),
              style: OutlinedButton.styleFrom(
                foregroundColor: DesignSystem.error,
                side: const BorderSide(color: DesignSystem.error, width: 1.5),
                padding:
                    const EdgeInsets.symmetric(vertical: DesignSystem.space4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DesignSystem.radiusFull),
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

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
        child: Ink(
          padding: const EdgeInsets.all(DesignSystem.space4),
          decoration: BoxDecoration(
            color: DesignSystem.neutral100,
            borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(DesignSystem.radiusFull),
                ),
                child: Icon(icon, size: 20, color: DesignSystem.neutral700),
              ),
              const SizedBox(width: DesignSystem.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: DesignSystem.textSm,
                        fontWeight: DesignSystem.weightSemibold,
                        color: DesignSystem.neutral900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: DesignSystem.textXs,
                        color: DesignSystem.neutral500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: DesignSystem.neutral400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showLogoutDialog(AuthProvider authProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignSystem.radiusXl),
          ),
          title: const Text(
            '确认登出',
            style: TextStyle(
              color: DesignSystem.neutral900,
              fontWeight: DesignSystem.weightSemibold,
            ),
          ),
          content: const Text(
            '登出后将清除本地同步密码，下次使用需要重新登录。',
            style: TextStyle(
              color: DesignSystem.neutral600,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                '取消',
                style: TextStyle(color: DesignSystem.neutral600),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: DesignSystem.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('登出'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    Navigator.of(context).pop();
    await authProvider.logout();
  }

  void _openPricingPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PricingPage()),
    );
  }

  Future<void> _showEnableSyncDialog(AuthProvider authProvider) async {
    final passwordController = TextEditingController();
    bool isSubmitting = false;

    final enabled = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignSystem.radiusXl),
              ),
              title: const Text(
                '启用云同步',
                style: TextStyle(
                  color: DesignSystem.neutral900,
                  fontWeight: DesignSystem.weightSemibold,
                ),
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '请输入当前账号密码，验证成功后会立即开启加密同步。',
                      style: TextStyle(
                        fontSize: DesignSystem.textSm,
                        color: DesignSystem.neutral600,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: DesignSystem.space4),
                    BovaTextField(
                      controller: passwordController,
                      label: '账号密码',
                      hint: '请输入密码',
                      prefixIcon: Icons.lock_outline,
                      obscureText: true,
                      enabled: !isSubmitting,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSubmitting ? null : () => Navigator.pop(dialogContext),
                  child: const Text(
                    '取消',
                    style: TextStyle(color: DesignSystem.neutral600),
                  ),
                ),
                FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final password = passwordController.text.trim();
                          if (password.isEmpty) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text('请输入密码'),
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
                      : const Text('立即启用'),
                ),
              ],
            );
          },
        );
      },
    );

    passwordController.dispose();
    if (!mounted) return;

    if (enabled == true) {
      _showSnackBar('云同步已启用');
    } else if (enabled == false) {
      _showSnackBar('密码错误或启用失败，请重试', isError: true);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  _AccountPalette _paletteFor(AccountType type) {
    switch (type) {
      case AccountType.free:
        return const _AccountPalette(
          base: Color(0xFFFBCFE8),
          surface: Color(0xFFFFF1F6),
          deep: _accountAccent,
          text: _accountAccent,
          icon: Icons.person_outline,
        );
      case AccountType.pro:
        return const _AccountPalette(
          base: Color(0xFFF5D0FE),
          surface: Color(0xFFFAF5FF),
          deep: Color(0xFFA21CAF),
          text: Color(0xFFA21CAF),
          icon: Icons.workspace_premium_outlined,
        );
      case AccountType.lifetime:
        return const _AccountPalette(
          base: Color(0xFFFEF3C7),
          surface: Color(0xFFFFFBEB),
          deep: DesignSystem.accent700,
          text: DesignSystem.accent700,
          icon: Icons.auto_awesome_outlined,
        );
    }
  }
}

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

class _AccountPalette {
  final Color base;
  final Color surface;
  final Color deep;
  final Color text;
  final IconData icon;

  const _AccountPalette({
    required this.base,
    required this.surface,
    required this.deep,
    required this.text,
    required this.icon,
  });
}
