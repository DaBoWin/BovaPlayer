import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/locale_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_system.dart';
import '../../auth/presentation/pages/pricing_page.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../../l10n/generated/app_localizations.dart';

/// 设置页面 — 外观（主题 + 语言）
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final l = S.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCyberpunk =
        context.watch<ThemeProvider>().themeMode == AppThemeMode.cyberpunk;
    final isSweetieSettings = context.watch<ThemeProvider>().themeMode == AppThemeMode.sweetiePro;
    final isSpecialSettings = isCyberpunk || isSweetieSettings;

    final content = SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        DesignSystem.isMobile(context) ? DesignSystem.space4 : DesignSystem.space6,
        DesignSystem.space4,
        DesignSystem.isMobile(context) ? DesignSystem.space4 : DesignSystem.space6,
        DesignSystem.space8,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: DesignSystem.isDesktop(context) ? 640 : 520,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- 主题选择 ---
              _SectionPanel(
                isCyberpunk: isSpecialSettings,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                      icon: Icons.palette_outlined,
                      title: l.settingsTheme,
                      isCyberpunk: isSpecialSettings,
                    ),
                    const SizedBox(height: DesignSystem.space4),
                    _ThemeSelector(isCyberpunk: isSpecialSettings),
                  ],
                ),
              ),

              const SizedBox(height: DesignSystem.space4),

              // --- 语言选择 ---
              _SectionPanel(
                isCyberpunk: isSpecialSettings,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                      icon: Icons.language_rounded,
                      title: l.settingsLanguage,
                      isCyberpunk: isSpecialSettings,
                    ),
                    const SizedBox(height: DesignSystem.space4),
                    _LanguageSelector(isCyberpunk: isSpecialSettings),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (embedded) {
      return ColoredBox(
        color: colorScheme.surface,
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l.settingsTitle,
          style: TextStyle(
            fontSize: DesignSystem.textLg,
            fontWeight: DesignSystem.weightSemibold,
            color: colorScheme.onSurface,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: content,
    );
  }
}

// ─── 区块面板 ───

class _SectionPanel extends StatelessWidget {
  const _SectionPanel({required this.child, required this.isCyberpunk});

  final Widget child;
  final bool isCyberpunk;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(DesignSystem.space5),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest
            : Colors.white,
        borderRadius: BorderRadius.circular(DesignSystem.radius2xl),
        border: Border.all(
          color: isCyberpunk
              ? AppTheme.cyberNeon.withValues(alpha: 0.15)
              : (isDark ? const Color(0xFF2A2A30) : const Color(0xFFE7EAF0)),
        ),
        boxShadow: isCyberpunk
            ? [
                BoxShadow(
                  color: AppTheme.cyberNeon.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ]
            : DesignSystem.shadowSm,      ),
      child: child,
    );
  }
}

// ─── 区块标题 ───

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.isCyberpunk,
  });

  final IconData icon;
  final String title;
  final bool isCyberpunk;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = isCyberpunk
        ? AppTheme.cyberNeon
        : theme.colorScheme.primary;

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
          ),
          child: Icon(icon, color: accentColor, size: 20),
        ),
        const SizedBox(width: DesignSystem.space3),
        Text(
          title,
          style: TextStyle(
            fontSize: DesignSystem.textBase,
            fontWeight: DesignSystem.weightSemibold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

// ─── 主题选择器 ───

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector({required this.isCyberpunk});

  final bool isCyberpunk;

  @override
  Widget build(BuildContext context) {
    final l = S.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final authProvider = context.watch<AuthProvider>();
    final hasProAccess = authProvider.user?.isPro ?? false;
    final current = themeProvider.themeMode;

    final options = [
      _ThemeOption(
        mode: AppThemeMode.light,
        label: l.settingsThemeLight,
        icon: Icons.light_mode_rounded,
        colors: const [Color(0xFFFAFAF9), Color(0xFFE11D48)],
      ),
      _ThemeOption(
        mode: AppThemeMode.dark,
        label: l.settingsThemeDark,
        icon: Icons.dark_mode_rounded,
        colors: const [Color(0xFF0F0F11), Color(0xFFE11D48)],
      ),
      _ThemeOption(
        mode: AppThemeMode.cyberpunk,
        label: l.settingsThemeCyberpunkPro,
        icon: Icons.auto_awesome,
        colors: const [Color(0xFF0A0A12), Color(0xFF00F0FF)],
        isSpecial: true,
        specialLabel: 'PRO',
        specialColor: AppTheme.cyberNeon,
      ),
      const _ThemeOption(
        mode: AppThemeMode.sweetiePro,
        label: '小蜜 Pro',
        icon: Icons.favorite_rounded,
        colors: [
          AppTheme.sweetieBg,
          AppTheme.sweetiePeachGlow,
          AppTheme.sweetieHotPink,
        ],
        isSpecial: true,
        specialLabel: 'PRO',
        specialColor: AppTheme.sweetieHotPink,
      ),
    ];

    return Wrap(
      spacing: DesignSystem.space3,
      runSpacing: DesignSystem.space3,
      children: options.map((opt) {
        final isSelected = current == opt.mode;
        return _ThemeOptionCard(
          option: opt,
          isSelected: isSelected,
          isCyberpunk: isCyberpunk,
          hasProAccess: hasProAccess,
          onTap: () async {
            if (opt.isSpecial && !hasProAccess) {
              final shouldUpgrade = await _showProThemeDialog(context, opt);
              if (shouldUpgrade == true && context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PricingPage()),
                );
              }
              return;
            }

            await themeProvider.setThemeMode(opt.mode);
          },
        );
      }).toList(),
    );
  }
}

Future<bool?> _showProThemeDialog(BuildContext context, _ThemeOption option) {
  final theme = Theme.of(context);
  final l = S.of(context);

  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignSystem.radiusXl),
      ),
      title: Row(
        children: [
          Icon(Icons.lock_rounded, color: option.specialColor, size: 20),
          const SizedBox(width: DesignSystem.space2),
          Expanded(
            child: Text(
              '${option.label} ${option.specialLabel}',
              style: TextStyle(
                fontSize: DesignSystem.textLg,
                fontWeight: DesignSystem.weightSemibold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        '该主题仅限 Pro 或永久会员设置，升级后即可使用 ${option.label}。',
        style: TextStyle(
          fontSize: DesignSystem.textSm,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
          height: 1.45,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: FilledButton.styleFrom(
            backgroundColor: option.specialColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('查看会员方案'),
        ),
      ],
    ),
  );
}

class _ThemeOption {
  final AppThemeMode mode;
  final String label;
  final IconData icon;
  final List<Color> colors;
  final bool isSpecial;
  final String specialLabel;
  final Color specialColor;

  const _ThemeOption({
    required this.mode,
    required this.label,
    required this.icon,
    required this.colors,
    this.isSpecial = false,
    this.specialLabel = 'PRO',
    this.specialColor = AppTheme.cyberNeon,
  });
}

class _ThemeOptionCard extends StatelessWidget {
  const _ThemeOptionCard({
    required this.option,
    required this.isSelected,
    required this.isCyberpunk,
    required this.hasProAccess,
    required this.onTap,
  });

  final _ThemeOption option;
  final bool isSelected;
  final bool isCyberpunk;
  final bool hasProAccess;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isLocked = option.isSpecial && !hasProAccess;

    Color borderColor;
    if (isSelected) {
      borderColor = isCyberpunk
          ? AppTheme.cyberNeon
          : (option.isSpecial ? option.specialColor : theme.colorScheme.primary);
    } else {
      borderColor = isDark ? const Color(0xFF2A2A30) : const Color(0xFFE7EAF0);
    }

    final accentColor = option.isSpecial
        ? option.specialColor
        : (isCyberpunk ? AppTheme.cyberNeon : theme.colorScheme.primary);

    return GestureDetector(
      onTap: () {
        onTap();
      },
      child: AnimatedContainer(
        duration: DesignSystem.durationNormal,
        curve: DesignSystem.easeOutQuart,
        width: 160,
        padding: const EdgeInsets.all(DesignSystem.space3),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1A1A22)
              : (isLocked ? const Color(0xFFFCF7FA) : const Color(0xFFF8F9FA)),
          borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected && option.isSpecial
              ? [
                  BoxShadow(
                    color: option.specialColor.withValues(alpha: 0.18),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            // 预览色块
            Stack(
              children: [
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(DesignSystem.radiusSm),
                    gradient: LinearGradient(
                      colors: option.colors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: option.isSpecial
                        ? Border.all(
                            color: option.specialColor.withValues(alpha: 0.3),
                          )
                        : null,
                  ),
                  child: option.isSpecial
                      ? Center(
                          child: Text(
                            'PRO',
                            style: TextStyle(
                              color: option.specialColor,
                              fontSize: DesignSystem.textXs,
                              fontWeight: DesignSystem.weightBold,
                              letterSpacing: 2,
                            ),
                          ),
                        )
                      : null,
                ),
                if (isLocked)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        shape: BoxShape.circle,
                        boxShadow: DesignSystem.shadowSm,
                      ),
                      child: Icon(
                        Icons.lock_rounded,
                        size: 13,
                        color: option.specialColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: DesignSystem.space2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  option.icon,
                  size: 16,
                  color: isSelected ? accentColor : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    option.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: DesignSystem.textSm,
                      fontWeight: isSelected ? DesignSystem.weightSemibold : DesignSystem.weightMedium,
                      color: isLocked
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.78)
                          : isSelected
                          ? accentColor
                          : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
            if (isLocked) ...[
              const SizedBox(height: 6),
              Text(
                '仅 Pro / 永久会员',
                style: TextStyle(
                  fontSize: DesignSystem.textXs,
                  fontWeight: DesignSystem.weightMedium,
                  color: option.specialColor.withValues(alpha: 0.88),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── 语言选择器 ───

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({required this.isCyberpunk});

  final bool isCyberpunk;

  @override
  Widget build(BuildContext context) {
    final l = S.of(context);
    final localeProvider = context.watch<LocaleProvider>();
    final currentLocale = localeProvider.locale?.languageCode ??
        Localizations.localeOf(context).languageCode;

    final options = [
      _LanguageOption(locale: const Locale('en'), label: l.settingsLanguageEn, flag: 'EN'),
      _LanguageOption(locale: const Locale('zh'), label: l.settingsLanguageZh, flag: 'ZH'),
    ];

    return Column(
      children: options.map((opt) {
        final isSelected = currentLocale == opt.locale.languageCode;
        return Padding(
          padding: const EdgeInsets.only(bottom: DesignSystem.space2),
          child: _LanguageOptionTile(
            option: opt,
            isSelected: isSelected,
            isCyberpunk: isCyberpunk,
            onTap: () => localeProvider.setLocale(opt.locale),
          ),
        );
      }).toList(),
    );
  }
}

class _LanguageOption {
  final Locale locale;
  final String label;
  final String flag;

  const _LanguageOption({
    required this.locale,
    required this.label,
    required this.flag,
  });
}

class _LanguageOptionTile extends StatelessWidget {
  const _LanguageOptionTile({
    required this.option,
    required this.isSelected,
    required this.isCyberpunk,
    required this.onTap,
  });

  final _LanguageOption option;
  final bool isSelected;
  final bool isCyberpunk;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor =
        isCyberpunk ? AppTheme.cyberNeon : theme.colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: DesignSystem.durationNormal,
        curve: DesignSystem.easeOutQuart,
        padding: const EdgeInsets.symmetric(
          horizontal: DesignSystem.space4,
          vertical: DesignSystem.space3,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
          border: Border.all(
            color: isSelected
                ? accentColor.withValues(alpha: 0.4)
                : (isDark ? const Color(0xFF2A2A30) : const Color(0xFFE7EAF0)),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? accentColor.withValues(alpha: 0.15)
                    : (isDark ? const Color(0xFF222228) : const Color(0xFFF1F3F5)),
                borderRadius: BorderRadius.circular(DesignSystem.radiusMd),
              ),
              child: Center(
                child: Text(
                  option.flag,
                  style: TextStyle(
                    fontSize: DesignSystem.textXs,
                    fontWeight: DesignSystem.weightBold,
                    color: isSelected
                        ? accentColor
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(width: DesignSystem.space3),
            Expanded(
              child: Text(
                option.label,
                style: TextStyle(
                  fontSize: DesignSystem.textBase,
                  fontWeight: isSelected
                      ? DesignSystem.weightSemibold
                      : DesignSystem.weightMedium,
                  color: isSelected
                      ? accentColor
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_rounded, color: accentColor, size: 20),
          ],
        ),
      ),
    );
  }
}
