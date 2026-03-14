import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/design_system.dart';
import '../../../../core/widgets/bova_button.dart';
import '../../../../core/widgets/bova_text_field.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_workspace_shell.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
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
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  bool _validateInputs() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (email.isEmpty || !email.contains('@')) {
      _showSnackBar(S.of(context).authInvalidEmail, isError: true);
      return false;
    }
    if (password.length < 8) {
      _showSnackBar(S.of(context).authPasswordMinLength, isError: true);
      return false;
    }
    if (password != confirmPassword) {
      _showSnackBar(S.of(context).authPasswordMismatch, isError: true);
      return false;
    }
    return true;
  }

  Future<void> _handleRegister() async {
    if (!_validateInputs()) return;
    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      username: _usernameController.text.trim().isEmpty
          ? null
          : _usernameController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      _showSnackBar(S.of(context).authRegisterSuccess, isError: false);
      Navigator.pop(context);
      return;
    }

    final l10n = S.of(context);
    var errorMessage = authProvider.errorMessage ?? l10n.authRegisterFailed;
    if (errorMessage.contains('45 seconds')) {
      errorMessage = l10n.authRegisterTooFrequent;
    } else if (errorMessage.contains('row-level security')) {
      errorMessage = l10n.authRegisterDbError;
    } else if (errorMessage.contains('already registered')) {
      errorMessage = l10n.authRegisterEmailTaken;
    }
    _showSnackBar(errorMessage, isError: true);
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? DesignSystem.error : DesignSystem.success,
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
    final l10n = S.of(context);
    return AuthWorkspaceScaffold(
      eyebrow: 'Create Account',
      title: l10n.authRegisterHeading,
      subtitle: l10n.authRegisterSubtitle,
      icon: Icons.person_add_alt_rounded,
      facts: [
        AuthWorkspaceFact(label: l10n.authRegisterFactSync, value: l10n.authRegisterFactSyncValue),
        AuthWorkspaceFact(label: l10n.authRegisterFactRights, value: l10n.authRegisterFactRightsValue),
        AuthWorkspaceFact(label: l10n.authRegisterFactSecurity, value: l10n.authRegisterFactSecurityValue),
      ],
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: AuthWorkspacePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.authRegisterTitle,
                  style: const TextStyle(
                    fontSize: DesignSystem.textXl,
                    fontWeight: DesignSystem.weightSemibold,
                    color: DesignSystem.neutral900,
                  ),
                ),
                const SizedBox(height: DesignSystem.space2),
                Text(
                  l10n.authRegisterDesc,
                  style: const TextStyle(
                    fontSize: DesignSystem.textSm,
                    color: DesignSystem.neutral600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: DesignSystem.space5),
                BovaTextField(
                  controller: _usernameController,
                  label: l10n.authUsernameLabel,
                  hint: l10n.authUsernameHint,
                  prefixIcon: Icons.person_outline,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: DesignSystem.space4),
                BovaTextField(
                  controller: _emailController,
                  label: l10n.authEmailLabel,
                  hint: 'your@email.com',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: DesignSystem.space4),
                BovaTextField(
                  controller: _passwordController,
                  label: l10n.authPasswordLabel,
                  hint: l10n.authPasswordHintRegister,
                  prefixIcon: Icons.lock_outlined,
                  obscureText: _obscurePassword,
                  enabled: !_isLoading,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: DesignSystem.neutral500,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                ),
                const SizedBox(height: DesignSystem.space4),
                BovaTextField(
                  controller: _confirmPasswordController,
                  label: l10n.authConfirmPasswordLabel,
                  hint: l10n.authConfirmPasswordHint,
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscureConfirmPassword,
                  enabled: !_isLoading,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: DesignSystem.neutral500,
                    ),
                    onPressed: () {
                      setState(() =>
                          _obscureConfirmPassword = !_obscureConfirmPassword);
                    },
                  ),
                ),
                const SizedBox(height: DesignSystem.space5),
                BovaButton(
                  text: l10n.authRegisterButton,
                  onPressed: _isLoading ? null : _handleRegister,
                  isLoading: _isLoading,
                  isFullWidth: true,
                  size: BovaButtonSize.large,
                ),
                const SizedBox(height: DesignSystem.space5),
                AuthWorkspaceFooterLink(
                  label: l10n.authHasAccount,
                  action: l10n.authLoginNow,
                  enabled: !_isLoading,
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
