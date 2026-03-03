import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../providers/auth_provider.dart';
import '../../domain/entities/user.dart';
import 'pricing_page.dart';
import 'redemption_admin_page.dart';
import '../../../../widgets/custom_app_bar.dart';

/// 本地头像管理的 key
const String _avatarPrefsKey = 'local_avatar_path';

/// 账号信息页面
class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool _isUploadingAvatar = false;
  String? _localAvatarPath;

  @override
  void initState() {
    super.initState();
    _loadLocalAvatar();
  }

  Future<void> _loadLocalAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_avatarPrefsKey);
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
      // 复制到应用目录
      final appDir = await getApplicationDocumentsDirectory();
      final avatarDir = Directory(p.join(appDir.path, 'avatars'));
      if (!avatarDir.existsSync()) {
        avatarDir.createSync(recursive: true);
      }

      final ext = p.extension(image.path);
      final destPath = p.join(avatarDir.path, 'avatar$ext');

      // 复制文件
      await File(image.path).copy(destPath);

      // 保存路径到 SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_avatarPrefsKey, destPath);

      if (mounted) {
        setState(() => _localAvatarPath = destPath);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('头像已更新'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败：$e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: CustomAppBar(
        showBackButton: true,
        title: '账号信息',
        actions: [
          Consumer<AuthProvider>(
            builder: (context, authProvider, _) {
              return IconButton(
                icon: authProvider.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF1F2937),
                        ),
                      )
                    : const Icon(Icons.refresh, color: Color(0xFF1F2937)),
                onPressed: authProvider.isLoading
                    ? null
                    : () async {
                        try {
                          print('[AccountPage] 开始刷新用户数据');
                          await authProvider.refreshUser();
                          print('[AccountPage] 刷新完成');
                          
                          if (context.mounted) {
                            // 检查用户数据是否存在
                            if (authProvider.user != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('数据已刷新'),
                                  backgroundColor: const Color(0xFF1F2937),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('刷新失败：用户数据为空'),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          print('[AccountPage] 刷新失败: $e');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('刷新失败：$e'),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      },
                tooltip: '刷新',
              );
            },
          ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          final user = authProvider.user;

          if (user == null) {
            return const Center(
              child: Text(
                '未登录',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 用户信息卡片
                _buildUserInfoCard(user),
                const SizedBox(height: 16),

                // 账号类型卡片
                _buildAccountTypeCard(user),
                const SizedBox(height: 16),

                // 使用量卡片
                _buildUsageCard(user),
                const SizedBox(height: 16),

                // 同步设置卡片
                _buildSyncSettingsCard(context, authProvider),
                const SizedBox(height: 16),

                // 管理员功能（仅 is_admin 用户可见）
                if (user.isAdmin)
                  _buildAdminCard(context),
                if (user.isAdmin)
                  const SizedBox(height: 16),

                // 升级按钮（非永久版用户可见）
                if (user.accountType != AccountType.lifetime)
                  _buildUpgradeButton(context, user),
                const SizedBox(height: 16),

                // 登出按钮
                _buildLogoutButton(context, authProvider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserInfoCard(User user) {
    // 根据账号类型选择渐变色
    List<Color> avatarGradient;
    switch (user.accountType) {
      case AccountType.lifetime:
        avatarGradient = [const Color(0xFFF59E0B), const Color(0xFFD97706)];
        break;
      case AccountType.pro:
        avatarGradient = [const Color(0xFF3B82F6), const Color(0xFF2563EB)];
        break;
      case AccountType.free:
      default:
        avatarGradient = [const Color(0xFF6B7280), const Color(0xFF4B5563)];
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // 头像 - 可点击更换
            GestureDetector(
              onTap: _isUploadingAvatar ? null : _pickAndSaveAvatar,
              child: Stack(
                children: [
                  // 头像圈
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: avatarGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: avatarGradient[0].withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(3), // 边框宽度
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: _isUploadingAvatar
                              ? const Center(
                                  child: SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : _localAvatarPath != null
                                  ? ClipOval(
                                      child: Image.file(
                                        File(_localAvatarPath!),
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => _buildAvatarInitial(user, avatarGradient),
                                      ),
                                    )
                                  : _buildAvatarInitial(user, avatarGradient),
                        ),
                      ),
                    ),
                  ),
                  // 相机图标
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F2937),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 用户名
            Text(
              user.username ?? '未设置用户名',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 4),

            // 邮箱
            Text(
              user.email,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarInitial(User user, List<Color> gradient) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          user.username?.substring(0, 1).toUpperCase() ??
              user.email.substring(0, 1).toUpperCase(),
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildAccountTypeCard(User user) {
    String typeName;
    Color typeColor;
    Color typeColorDark;
    IconData typeIcon;

    switch (user.accountType) {
      case AccountType.free:
        typeName = '🆓 社区免费版';
        typeColor = const Color(0xFF6B7280);
        typeColorDark = const Color(0xFF4B5563);
        typeIcon = Icons.person_outline;
        break;
      case AccountType.pro:
        typeName = '💎 Pro 版';
        typeColor = const Color(0xFF3B82F6);
        typeColorDark = const Color(0xFF2563EB);
        typeIcon = Icons.workspace_premium;
        break;
      case AccountType.lifetime:
        typeName = '🏆 永久版';
        typeColor = const Color(0xFFF59E0B);
        typeColorDark = const Color(0xFFD97706);
        typeIcon = Icons.stars;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [typeColor, typeColorDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Icon(typeIcon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  '账号类型',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              typeName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: typeColor,
              ),
            ),
            if (user.accountType == AccountType.pro && user.proExpiresAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  '到期时间：${_formatDate(user.proExpiresAt!)}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageCard(User user) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.analytics_outlined, color: Color(0xFF1F2937), size: 20),
                SizedBox(width: 8),
                Text(
                  '使用情况',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 服务器数量
            _buildUsageItem(
              '服务器',
              user.usage.serverCount,
              user.limits.maxServers,
              Icons.dns_outlined,
            ),
            const SizedBox(height: 12),

            // 设备数量
            _buildUsageItem(
              '设备',
              user.usage.deviceCount,
              user.limits.maxDevices,
              Icons.devices_outlined,
            ),
            const SizedBox(height: 12),

            // 存储空间
            _buildStorageItem(
              '存储空间',
              user.usage.storageUsedMb.toDouble(),
              user.limits.storageQuotaMb.toDouble(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageItem(
    String label,
    int current,
    int max,
    IconData icon,
  ) {
    final isUnlimited = max == -1;
    final percentage = isUnlimited ? 0.0 : (current / max).clamp(0.0, 1.0);
    final isNearLimit = percentage > 0.8;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF6B7280)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
              ),
            ),
            const Spacer(),
            Text(
              isUnlimited ? '$current / 无限' : '$current / $max',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isNearLimit ? const Color(0xFFF59E0B) : const Color(0xFF1F2937),
              ),
            ),
          ],
        ),
        if (!isUnlimited) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation<Color>(
                isNearLimit ? const Color(0xFFF59E0B) : const Color(0xFF1F2937),
              ),
              minHeight: 6,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStorageItem(String label, double current, double max) {
    final isUnlimited = max == -1;
    final percentage = isUnlimited ? 0.0 : (current / max).clamp(0.0, 1.0);
    final isNearLimit = percentage > 0.8;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.storage_outlined, size: 16, color: Color(0xFF6B7280)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
              ),
            ),
            const Spacer(),
            Text(
              isUnlimited
                  ? '${current.toStringAsFixed(1)} MB / 无限'
                  : '${current.toStringAsFixed(1)} MB / ${max.toStringAsFixed(0)} MB',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isNearLimit ? const Color(0xFFF59E0B) : const Color(0xFF1F2937),
              ),
            ),
          ],
        ),
        if (!isUnlimited) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation<Color>(
                isNearLimit ? const Color(0xFFF59E0B) : const Color(0xFF1F2937),
              ),
              minHeight: 6,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildUpgradeButton(BuildContext context, User user) {
    final isPro = user.accountType == AccountType.pro;
    final buttonText = isPro ? '升级到永久版' : '升级到 Pro 版';
    final buttonIcon = isPro ? Icons.stars : Icons.upgrade;
    final gradientColors = isPro
        ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
        : [const Color(0xFF1F2937), const Color(0xFF111827)];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PricingPage(),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(buttonIcon, size: 20),
            const SizedBox(width: 8),
            Text(
              buttonText,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, AuthProvider authProvider) {
    return OutlinedButton(
      onPressed: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              '确认登出',
              style: TextStyle(
                color: Color(0xFF1F2937),
                fontWeight: FontWeight.w600,
              ),
            ),
            content: const Text(
              '确定要登出吗？',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  '取消',
                  style: TextStyle(color: Color(0xFF6B7280)),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('登出'),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          // 先关闭对话框和账号页面
          if (context.mounted) {
            Navigator.of(context).pop(); // 关闭账号页面
          }
          
          // 然后执行登出
          await authProvider.logout();
        }
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFEF4444),
        side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.logout, size: 20),
          SizedBox(width: 8),
          Text(
            '登出',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.admin_panel_settings, color: Color(0xFFF59E0B), size: 20),
                SizedBox(width: 8),
                Text(
                  '管理员',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.confirmation_number_outlined, color: Color(0xFF6B7280)),
              title: const Text(
                '兑换码管理',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1F2937),
                ),
              ),
              subtitle: const Text(
                '生成和管理兑换码',
                style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
              ),
              trailing: const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RedemptionAdminPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
  
  Widget _buildSyncSettingsCard(BuildContext context, AuthProvider authProvider) {
    final isSyncEnabled = authProvider.isSyncEnabled;
    final user = authProvider.user;
    final isPro = user?.isPro ?? false;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: isSyncEnabled 
                          ? [const Color(0xFF10B981), const Color(0xFF059669)]
                          : [const Color(0xFF6B7280), const Color(0xFF4B5563)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Icon(
                    isSyncEnabled ? Icons.cloud_done : Icons.cloud_off,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  children: [
                    const Text(
                      '云同步',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    if (!isPro) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Pro',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSyncEnabled ? '已启用' : (isPro ? '未启用' : 'Pro 功能'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSyncEnabled 
                              ? const Color(0xFF10B981) 
                              : (isPro ? const Color(0xFF6B7280) : const Color(0xFFF59E0B)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isSyncEnabled 
                            ? '媒体服务器数据已加密同步'
                            : (isPro ? '需要输入密码以启用同步' : '升级到 Pro 版解锁云同步功能'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isSyncEnabled)
                  ElevatedButton(
                    onPressed: isPro 
                        ? () => _showEnableSyncDialog(context, authProvider)
                        : () => _showUpgradeDialog(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPro ? const Color(0xFF1F2937) : const Color(0xFFF59E0B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      isPro ? '启用' : '升级',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          '升级到 Pro 版',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          '云同步功能仅限 Pro 版和永久版用户使用。\n\n升级后可享受：\n• 无限媒体服务器同步\n• 多设备数据同步\n• 弹幕功能\n• 更多高级功能',
          style: TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '取消',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PricingPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('查看方案'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _showEnableSyncDialog(BuildContext context, AuthProvider authProvider) async {
    final passwordController = TextEditingController();
    bool isLoading = false;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            '启用云同步',
            style: TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '请输入您的账号密码以启用云同步功能',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  enabled: !isLoading,
                  style: const TextStyle(color: Color(0xFF1F2937), fontSize: 14),
                  decoration: InputDecoration(
                    labelText: '密码',
                    hintText: '请输入密码',
                    labelStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                    hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: const Color(0xFF9CA3AF).withOpacity(0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF1F2937), width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext, false),
              child: const Text(
                '取消',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final password = passwordController.text.trim();
                      if (password.isEmpty) {
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: const Text('请输入密码'),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          );
                        }
                        return;
                      }

                      setState(() => isLoading = true);

                      try {
                        final success = await authProvider.enableSyncWithPassword(password);
                        
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, success);
                          
                          if (success) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: const Text('云同步已启用'),
                                backgroundColor: const Color(0xFF10B981),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: const Text('密码错误，请重试'),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (dialogContext.mounted) {
                          setState(() => isLoading = false);
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: Text('错误: $e'),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F2937),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('确认'),
            ),
          ],
        ),
      ),
    );
    
    passwordController.dispose();
  }
}
