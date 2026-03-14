import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../core/theme/design_system.dart';
import '../../../../../l10n/generated/app_localizations.dart';
import '../../../domain/entities/user.dart';
import '../../providers/auth_provider.dart';
import 'account_theme.dart';

const String _avatarPrefsKey = 'local_avatar_path';

/// Hero card showing user avatar, name, level badge and meta info.
class AccountHeroCard extends StatefulWidget {
  const AccountHeroCard({super.key});

  @override
  State<AccountHeroCard> createState() => _AccountHeroCardState();
}

class _AccountHeroCardState extends State<AccountHeroCard> {
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
    if (!mounted) return;
    if (path != null && File(path).existsSync()) {
      setState(() => _localAvatarPath = path);
    }
  }

  Future<void> _pickAndSaveAvatar() async {
    final l = S.of(context);
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
      _showSnackBar(l.accountAvatarUpdated);
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(l.accountAvatarSaveFailed('$error'), isError: true);
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
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
    final c = AccountColors.of(context);
    final l = S.of(context);

    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.user;
        if (user == null) return const SizedBox.shrink();

        final palette = AccountPalette.forType(user.accountType, c);
        final levelLabel = switch (user.accountType) {
          AccountType.free => l.accountTypeFree,
          AccountType.pro => l.accountTypePro,
          AccountType.lifetime => l.accountTypeLifetime,
        };

        return AccountSurfacePanel(
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
                  c.panel,
                  palette.surface.withValues(alpha: 0.55),
                  c.accentSoft.withValues(alpha: 0.35),
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
                      _buildAvatar(user, palette, c),
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
                                          color: palette.surface.withValues(alpha: 0.95),
                                          borderRadius: BorderRadius.circular(DesignSystem.radiusFull),
                                          border: Border.all(
                                            color: palette.base.withValues(alpha: 0.8),
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
                                _AccountRefreshButton(authProvider: authProvider),
                              ],
                            ),
                            const SizedBox(height: DesignSystem.space3),
                            Text(
                              user.username ?? l.accountUsernameNotSet,
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: DesignSystem.weightBold,
                                color: c.textPrimary,
                                letterSpacing: -0.8,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(height: DesignSystem.space2),
                            Text(
                              user.email,
                              style: TextStyle(
                                fontSize: DesignSystem.textSm,
                                color: c.textSecondary,
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
                        label: l.accountRegisteredAt,
                        value: formatAccountDate(user.createdAt),
                        c: c,
                      ),
                      _buildHeroMeta(
                        icon: Icons.update_outlined,
                        label: l.accountLastUpdate,
                        value: formatAccountDate(user.updatedAt),
                        c: c,
                      ),
                      _buildHeroMeta(
                        icon: Icons.verified_outlined,
                        label: l.accountCloudSync,
                        value: context.read<AuthProvider>().isSyncEnabled
                            ? l.accountSyncEnabled
                            : l.accountSyncDisabled,
                        c: c,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatar(User user, AccountPalette palette, AccountColors c) {
    final initial =
        (user.username?.isNotEmpty == true ? user.username! : user.email)
            .substring(0, 1)
            .toUpperCase();

    Widget child;
    if (_isUploadingAvatar) {
      child = Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: c.textSecondary,
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
          errorBuilder: (_, __, ___) =>
              _buildAvatarFallback(initial, palette),
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
              color: c.overlayWhiteStrong,
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.panel,
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
                color: c.textPrimary,
                shape: BoxShape.circle,
                border: Border.all(color: c.panel, width: 2),
              ),
              child: Icon(
                Icons.camera_alt_outlined,
                size: 16,
                color: c.panel,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarFallback(String initial, AccountPalette palette) {
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
    required AccountColors c,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 168),
      padding: const EdgeInsets.symmetric(
        horizontal: DesignSystem.space3,
        vertical: DesignSystem.space3,
      ),
      decoration: BoxDecoration(
        color: c.overlayWhite,
        borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
        border: Border.all(color: c.panelBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: c.accentSoft,
              borderRadius: BorderRadius.circular(DesignSystem.radiusMd),
            ),
            child: Icon(icon, size: 16, color: c.accent),
          ),
          const SizedBox(width: DesignSystem.space2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: DesignSystem.textXs,
                  color: c.textTertiary,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: DesignSystem.textSm,
                  fontWeight: DesignSystem.weightSemibold,
                  color: c.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small refresh button reused in the hero card.
class _AccountRefreshButton extends StatefulWidget {
  final AuthProvider authProvider;
  const _AccountRefreshButton({required this.authProvider});

  @override
  State<_AccountRefreshButton> createState() => _AccountRefreshButtonState();
}

class _AccountRefreshButtonState extends State<_AccountRefreshButton> {
  bool _isRefreshing = false;

  Future<void> _refresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    await widget.authProvider.refreshUser();
    if (!mounted) return;
    setState(() => _isRefreshing = false);

    final l = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (widget.authProvider.user != null) {
      messenger.showSnackBar(SnackBar(
        content: Text(l.accountRefreshed),
        backgroundColor: DesignSystem.neutral900,
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      messenger.showSnackBar(SnackBar(
        content: Text(l.accountRefreshFailed),
        backgroundColor: DesignSystem.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AccountColors.of(context);
    final l = S.of(context);

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: c.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.panelBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: IconButton(
        onPressed: _isRefreshing ? null : _refresh,
        tooltip: l.accountRefreshInfo,
        splashRadius: 20,
        icon: _isRefreshing
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: c.textSecondary,
                ),
              )
            : Icon(
                Icons.refresh_rounded,
                size: 18,
                color: c.textSecondary,
              ),
      ),
    );
  }
}
