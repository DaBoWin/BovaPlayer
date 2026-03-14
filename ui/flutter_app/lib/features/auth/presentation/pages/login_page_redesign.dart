import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/design_system.dart';
import '../../../../core/widgets/bova_button.dart';
import '../../../../core/widgets/bova_text_field.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_workspace_shell.dart';

class LoginPageRedesign extends StatefulWidget {
  const LoginPageRedesign({super.key});

  @override
  State<LoginPageRedesign> createState() => _LoginPageRedesignState();
}

class _LoginPageRedesignState extends State<LoginPageRedesign>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_clearAuthErrorIfNeeded);
    _passwordController.addListener(_clearAuthErrorIfNeeded);
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
    _emailController.removeListener(_clearAuthErrorIfNeeded);
    _passwordController.removeListener(_clearAuthErrorIfNeeded);
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _clearAuthErrorIfNeeded() {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.errorMessage != null) {
      authProvider.clearError();
    }
  }

  bool _validateInputs() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || !email.contains('@')) {
      _showSnackBar(S.of(context).authInvalidEmail, isError: true);
      return false;
    }
    if (password.isEmpty) {
      _showSnackBar(S.of(context).authEnterPassword, isError: true);
      return false;
    }
    return true;
  }

  Future<void> _handleLogin() async {
    if (!_validateInputs()) return;
    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      _showSnackBar(S.of(context).authLoginSuccess, isError: false);
    } else {
      _showSnackBar(authProvider.errorMessage ?? S.of(context).authLoginFailed, isError: true);
    }
  }

  Future<void> _handleGitHubLogin() async {
    setState(() => _isLoading = true);
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.loginWithGitHub();
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (!success) {
      _showSnackBar(authProvider.errorMessage ?? S.of(context).authGitHubLoginFailed, isError: true);
    }
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
    final authProvider = context.watch<AuthProvider>();

    return AuthWorkspaceScaffold(
      showBackButton: false,
      eyebrow: '',
      title: 'BovaPlayer',
      subtitle: '',
      icon: Icons.play_circle_outline_rounded,
      heroGraphic: Padding(
        padding: const EdgeInsets.all(10),
        child: Image.asset(
          'assets/icon.png',
          fit: BoxFit.contain,
        ),
      ),
      facts: const [],
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: AuthWorkspacePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  S.of(context).authLoginTitle,
                  style: const TextStyle(
                    fontSize: DesignSystem.textXl,
                    fontWeight: DesignSystem.weightSemibold,
                    color: DesignSystem.neutral900,
                  ),
                ),
                const SizedBox(height: DesignSystem.space2),
                Text(
                  S.of(context).authLoginSubtitle,
                  style: const TextStyle(
                    fontSize: DesignSystem.textSm,
                    color: DesignSystem.neutral600,
                    height: 1.5,
                  ),
                ),
                if (authProvider.errorMessage != null) ...[
                  const SizedBox(height: DesignSystem.space4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignSystem.space4,
                      vertical: DesignSystem.space3,
                    ),
                    decoration: BoxDecoration(
                      color: DesignSystem.error.withValues(alpha: 0.08),
                      borderRadius:
                          BorderRadius.circular(DesignSystem.radiusLg),
                      border: Border.all(
                        color: DesignSystem.error.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.error_outline_rounded,
                            size: 18,
                            color: DesignSystem.error,
                          ),
                        ),
                        const SizedBox(width: DesignSystem.space3),
                        Expanded(
                          child: Text(
                            authProvider.errorMessage!.replaceFirst(
                              'Exception: ',
                              '',
                            ),
                            style: const TextStyle(
                              fontSize: DesignSystem.textSm,
                              color: DesignSystem.error,
                              fontWeight: DesignSystem.weightMedium,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: DesignSystem.space5),
                BovaTextField(
                  controller: _emailController,
                  label: S.of(context).authEmailLabel,
                  hint: 'your@email.com',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: DesignSystem.space4),
                BovaTextField(
                  controller: _passwordController,
                  label: S.of(context).authPasswordLabel,
                  hint: S.of(context).authPasswordHint,
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
                const SizedBox(height: DesignSystem.space2),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading
                        ? null
                        : () =>
                            Navigator.pushNamed(context, '/forgot-password'),
                    child: Text(
                      S.of(context).authForgotPassword,
                      style: TextStyle(
                        fontSize: DesignSystem.textSm,
                        fontWeight: DesignSystem.weightSemibold,
                        color: authWorkspaceAccent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: DesignSystem.space4),
                BovaButton(
                  text: S.of(context).authLoginButton,
                  onPressed: _isLoading ? null : _handleLogin,
                  isLoading: _isLoading,
                  isFullWidth: true,
                  size: BovaButtonSize.large,
                ),
                const SizedBox(height: DesignSystem.space4),
                Row(
                  children: [
                    const Expanded(child: Divider(color: DesignSystem.neutral200)),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: DesignSystem.space3),
                      child: Text(
                        S.of(context).authOrThirdParty,
                        style: const TextStyle(
                          fontSize: DesignSystem.textSm,
                          color: DesignSystem.neutral500,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(color: DesignSystem.neutral200)),
                  ],
                ),
                const SizedBox(height: DesignSystem.space4),
                BovaButton(
                  text: S.of(context).authGitHubLogin,
                  icon: Icons.code_rounded,
                  onPressed: _isLoading ? null : _handleGitHubLogin,
                  style: BovaButtonStyle.secondary,
                  size: BovaButtonSize.large,
                  isFullWidth: true,
                ),
                const SizedBox(height: DesignSystem.space5),
                AuthWorkspaceFooterLink(
                  label: S.of(context).authNoAccount,
                  action: S.of(context).authRegisterNow,
                  enabled: !_isLoading,
                  onTap: () => Navigator.pushNamed(context, '/register'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
