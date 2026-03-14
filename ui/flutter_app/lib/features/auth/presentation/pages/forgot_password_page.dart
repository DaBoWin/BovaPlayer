import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/design_system.dart';
import '../../../../core/widgets/bova_button.dart';
import '../../../../core/widgets/bova_text_field.dart';
import '../../../../l10n/generated/app_localizations.dart';
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
      _showSnackBar(S.of(context).authInvalidEmail);
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
      _showSnackBar(authProvider.errorMessage ?? S.of(context).authForgotSendFailed);
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
    final l10n = S.of(context);
    return AuthWorkspaceScaffold(
      eyebrow: 'Password Recovery',
      title: _emailSent ? l10n.authForgotCheckEmail : l10n.authForgotTitle,
      subtitle: _emailSent
          ? l10n.authForgotSubtitleSent
          : l10n.authForgotSubtitleForm,
      icon: _emailSent
          ? Icons.mark_email_read_outlined
          : Icons.lock_reset_rounded,
      facts: _emailSent
          ? [
              AuthWorkspaceFact(label: l10n.authForgotFactEmailStatus, value: l10n.authForgotFactEmailSent),
              AuthWorkspaceFact(label: l10n.authForgotFactNextStep, value: l10n.authForgotFactNextStepValue),
            ]
          : [
              AuthWorkspaceFact(label: l10n.authForgotFactEmailVerify, value: l10n.authForgotFactRequired),
              AuthWorkspaceFact(label: l10n.authForgotFactResetMethod, value: l10n.authForgotFactResetViaEmail),
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
    final l10n = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.authForgotSendLink,
          style: const TextStyle(
            fontSize: DesignSystem.textXl,
            fontWeight: DesignSystem.weightSemibold,
            color: DesignSystem.neutral900,
          ),
        ),
        const SizedBox(height: DesignSystem.space2),
        Text(
          l10n.authForgotFormDesc,
          style: const TextStyle(
            fontSize: DesignSystem.textSm,
            color: DesignSystem.neutral600,
            height: 1.5,
          ),
        ),
        const SizedBox(height: DesignSystem.space5),
        BovaTextField(
          controller: _emailController,
          label: l10n.authEmailLabel,
          hint: 'your@email.com',
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          enabled: !_isLoading,
        ),
        const SizedBox(height: DesignSystem.space5),
        BovaButton(
          text: l10n.authForgotSendLink,
          onPressed: _isLoading ? null : _handleSendResetEmail,
          isLoading: _isLoading,
          isFullWidth: true,
          size: BovaButtonSize.large,
        ),
        const SizedBox(height: DesignSystem.space5),
        AuthWorkspaceFooterLink(
          label: l10n.authForgotRemembered,
          action: l10n.authForgotBackToLogin,
          enabled: !_isLoading,
          onTap: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildSuccessState() {
    final l10n = S.of(context);
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
        Text(
          l10n.authForgotEmailSentTitle,
          style: const TextStyle(
            fontSize: DesignSystem.textXl,
            fontWeight: DesignSystem.weightSemibold,
            color: DesignSystem.neutral900,
          ),
        ),
        const SizedBox(height: DesignSystem.space2),
        Text(
          l10n.authForgotEmailSentDesc(_emailController.text),
          style: const TextStyle(
            fontSize: DesignSystem.textSm,
            color: DesignSystem.neutral600,
            height: 1.6,
          ),
        ),
        const SizedBox(height: DesignSystem.space5),
        BovaButton(
          text: l10n.authForgotReturnLogin,
          onPressed: () => Navigator.pop(context),
          isFullWidth: true,
          size: BovaButtonSize.large,
        ),
        const SizedBox(height: DesignSystem.space3),
        BovaButton(
          text: l10n.authForgotResend,
          onPressed: () => setState(() => _emailSent = false),
          style: BovaButtonStyle.secondary,
          isFullWidth: true,
        ),
      ],
    );
  }
}
