import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/design_system.dart';
import '../../../../core/widgets/bova_button.dart';
import '../../../../core/widgets/bova_text_field.dart';
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
      _showSnackBar('请输入正确的邮箱地址', isError: true);
      return false;
    }
    if (password.length < 8) {
      _showSnackBar('密码至少需要 8 位字符', isError: true);
      return false;
    }
    if (password != confirmPassword) {
      _showSnackBar('两次输入的密码不一致', isError: true);
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
      _showSnackBar('注册成功！请查收验证邮件', isError: false);
      Navigator.pop(context);
      return;
    }

    var errorMessage = authProvider.errorMessage ?? '注册失败';
    if (errorMessage.contains('45 seconds')) {
      errorMessage = '请求过于频繁，请等待 45 秒后再试';
    } else if (errorMessage.contains('row-level security')) {
      errorMessage = '数据库配置错误，请联系管理员';
    } else if (errorMessage.contains('already registered')) {
      errorMessage = '该邮箱已被注册';
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
    return AuthWorkspaceScaffold(
      eyebrow: 'Create Account',
      title: '创建你的账户',
      subtitle: '注册后即可开启媒体同步、购买会员方案并管理你的工作区配置。整体界面延续同一套暖中性色与玫红强调。',
      icon: Icons.person_add_alt_rounded,
      facts: const [
        AuthWorkspaceFact(label: '云同步', value: '注册后可启用'),
        AuthWorkspaceFact(label: '权益管理', value: '支持升级与兑换'),
        AuthWorkspaceFact(label: '账号安全', value: '邮箱验证'),
      ],
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: AuthWorkspacePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '注册新账户',
                  style: TextStyle(
                    fontSize: DesignSystem.textXl,
                    fontWeight: DesignSystem.weightSemibold,
                    color: DesignSystem.neutral900,
                  ),
                ),
                const SizedBox(height: DesignSystem.space2),
                const Text(
                  '填写基础信息后即可开始使用。用户名可稍后在账户中心继续调整。',
                  style: TextStyle(
                    fontSize: DesignSystem.textSm,
                    color: DesignSystem.neutral600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: DesignSystem.space5),
                BovaTextField(
                  controller: _usernameController,
                  label: '用户名（可选）',
                  hint: '输入你的用户名',
                  prefixIcon: Icons.person_outline,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: DesignSystem.space4),
                BovaTextField(
                  controller: _emailController,
                  label: '邮箱地址',
                  hint: 'your@email.com',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: DesignSystem.space4),
                BovaTextField(
                  controller: _passwordController,
                  label: '密码',
                  hint: '至少 8 位，建议包含字母和数字',
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
                  label: '确认密码',
                  hint: '再次输入密码',
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
                  text: '注册',
                  onPressed: _isLoading ? null : _handleRegister,
                  isLoading: _isLoading,
                  isFullWidth: true,
                  size: BovaButtonSize.large,
                ),
                const SizedBox(height: DesignSystem.space5),
                AuthWorkspaceFooterLink(
                  label: '已有账号？',
                  action: '立即登录',
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
