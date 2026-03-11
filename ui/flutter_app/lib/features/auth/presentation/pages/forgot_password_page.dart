import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/design_system.dart';
import '../../../../core/widgets/bova_button.dart';
import '../../../../core/widgets/bova_text_field.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_workspace_shell.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  bool _emailSent = false;
  bool _isLoading = false;

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
    _emailController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleSendResetEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showSnackBar('请输入正确的邮箱地址');
      return;
    }

    setState(() => _isLoading = true);
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.sendPasswordResetEmail(email);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      setState(() => _emailSent = true);
    } else {
      _showSnackBar(authProvider.errorMessage ?? '发送失败');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: DesignSystem.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignSystem.radiusMd),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthWorkspaceScaffold(
      eyebrow: 'Password Recovery',
      title: _emailSent ? '检查你的邮箱' : '重置密码',
      subtitle: _emailSent
          ? '邮件已经发出。回到邮箱完成密码重置后，再重新登录你的工作区。'
          : '输入注册邮箱后，我们会向你发送一封带有重置链接的邮件。这个流程也会保持和账户中心一致的版式。',
      icon: _emailSent
          ? Icons.mark_email_read_outlined
          : Icons.lock_reset_rounded,
      facts: _emailSent
          ? const [
              AuthWorkspaceFact(label: '邮件状态', value: '已发送'),
              AuthWorkspaceFact(label: '下一步', value: '查收并点击链接'),
            ]
          : const [
              AuthWorkspaceFact(label: '邮箱验证', value: '必需'),
              AuthWorkspaceFact(label: '重置方式', value: '邮件链接'),
            ],
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: AuthWorkspacePanel(
            child: _emailSent ? _buildSuccessState() : _buildFormState(),
          ),
        ),
      ),
    );
  }

  Widget _buildFormState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '发送重置链接',
          style: TextStyle(
            fontSize: DesignSystem.textXl,
            fontWeight: DesignSystem.weightSemibold,
            color: DesignSystem.neutral900,
          ),
        ),
        const SizedBox(height: DesignSystem.space2),
        const Text(
          '输入你的注册邮箱，我们会发送一封带有重置密码链接的邮件。',
          style: TextStyle(
            fontSize: DesignSystem.textSm,
            color: DesignSystem.neutral600,
            height: 1.5,
          ),
        ),
        const SizedBox(height: DesignSystem.space5),
        BovaTextField(
          controller: _emailController,
          label: '邮箱地址',
          hint: 'your@email.com',
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          enabled: !_isLoading,
        ),
        const SizedBox(height: DesignSystem.space5),
        BovaButton(
          text: '发送重置链接',
          onPressed: _isLoading ? null : _handleSendResetEmail,
          isLoading: _isLoading,
          isFullWidth: true,
          size: BovaButtonSize.large,
        ),
        const SizedBox(height: DesignSystem.space5),
        AuthWorkspaceFooterLink(
          label: '记起密码了？',
          action: '返回登录',
          enabled: !_isLoading,
          onTap: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildSuccessState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: DesignSystem.success.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(DesignSystem.radiusXl),
          ),
          child: const Icon(
            Icons.mark_email_read_outlined,
            size: 34,
            color: DesignSystem.success,
          ),
        ),
        const SizedBox(height: DesignSystem.space5),
        const Text(
          '邮件已发送',
          style: TextStyle(
            fontSize: DesignSystem.textXl,
            fontWeight: DesignSystem.weightSemibold,
            color: DesignSystem.neutral900,
          ),
        ),
        const SizedBox(height: DesignSystem.space2),
        Text(
          '我们已向 ${_emailController.text} 发送重置密码的链接，请查收邮件并完成后续操作。',
          style: const TextStyle(
            fontSize: DesignSystem.textSm,
            color: DesignSystem.neutral600,
            height: 1.6,
          ),
        ),
        const SizedBox(height: DesignSystem.space5),
        BovaButton(
          text: '返回登录',
          onPressed: () => Navigator.pop(context),
          isFullWidth: true,
          size: BovaButtonSize.large,
        ),
        const SizedBox(height: DesignSystem.space3),
        BovaButton(
          text: '重新发送',
          onPressed: () => setState(() => _emailSent = false),
          style: BovaButtonStyle.secondary,
          isFullWidth: true,
        ),
      ],
    );
  }
}
