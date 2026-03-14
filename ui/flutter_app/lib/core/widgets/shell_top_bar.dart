import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../../l10n/generated/app_localizations.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../theme/design_system.dart';

class ShellTopBar extends StatelessWidget {
  const ShellTopBar({
    super.key,
    required this.title,
    required this.sectionIcon,
    required this.actions,
    this.subtitle,
    this.onBack,
  });

  final String title;
  final IconData sectionIcon;
  final String? subtitle;
  final List<Widget> actions;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);
    final showWindowControls =
        !kIsWeb && (Platform.isWindows || Platform.isLinux);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeMode = context.watch<ThemeProvider>().themeMode;
    final isCyberpunk = themeMode == AppThemeMode.cyberpunk;
    final isSweetieBar = themeMode == AppThemeMode.sweetiePro;
    final isSpecialBar = isCyberpunk || isSweetieBar;
    final specialNeonBar = isSweetieBar ? AppTheme.sweetieHotPink : AppTheme.cyberNeon;
    final specialCardBar = isSweetieBar ? AppTheme.sweetieCard : AppTheme.cyberCard;

    final barBg = isSpecialBar
        ? specialCardBar
        : isDark
            ? const Color(0xFF1A1A1F)
            : Colors.white;
    final borderColor = isSpecialBar
        ? specialNeonBar.withValues(alpha: 0.1)
        : isDark
            ? const Color(0xFF2A2A30)
            : const Color(0xFFF0F1F4);
    final accentColor = isSpecialBar ? specialNeonBar : theme.colorScheme.primary;
    final iconBoxBg = isSpecialBar
        ? specialNeonBar.withValues(alpha: 0.08)
        : isDark
            ? const Color(0xFF222228)
            : Colors.white;
    final iconBoxBorder = isSpecialBar
        ? specialNeonBar.withValues(alpha: 0.2)
        : isDark
            ? const Color(0xFF2A2A30)
            : DesignSystem.neutral200;

    return Container(
      height: 84,
      decoration: BoxDecoration(
        color: barBg,
        border: Border(
          bottom: BorderSide(color: borderColor),
        ),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: isDesktop
            ? (_) async {
                await windowManager.startDragging();
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              if (onBack != null) ...[
                IconButton(
                  onPressed: onBack,
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: theme.iconTheme.color,
                    size: 18,
                  ),
                  tooltip: S.of(context).actionBack,
                ),
                const SizedBox(width: 6),
              ],
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBoxBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: iconBoxBorder),
                  boxShadow: isSpecialBar
                      ? [
                          BoxShadow(
                            color: specialNeonBar.withValues(alpha: 0.06),
                            blurRadius: 8,
                          ),
                        ]
                      : DesignSystem.shadowSm,
                ),
                child: Icon(
                  sectionIcon,
                  color: accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: DesignSystem.weightSemibold,
                        color: theme.colorScheme.onSurface,
                        letterSpacing: isSpecialBar ? 0.5 : -0.8,
                        height: 1.0,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: DesignSystem.textSm,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (showWindowControls) ...[
                const SizedBox(width: 12),
                const _DesktopWindowControls(),
                const SizedBox(width: 8),
              ],
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopWindowControls extends StatefulWidget {
  const _DesktopWindowControls();

  @override
  State<_DesktopWindowControls> createState() => _DesktopWindowControlsState();
}

class _DesktopWindowControlsState extends State<_DesktopWindowControls>
    with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _syncWindowState();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    _setMaximized(true);
  }

  @override
  void onWindowUnmaximize() {
    _setMaximized(false);
  }

  Future<void> _syncWindowState() async {
    final isMaximized = await windowManager.isMaximized();
    _setMaximized(isMaximized);
  }

  void _setMaximized(bool value) {
    if (!mounted || _isMaximized == value) {
      return;
    }
    setState(() {
      _isMaximized = value;
    });
  }

  Future<void> _toggleMaximize() async {
    if (_isMaximized) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeMode = context.watch<ThemeProvider>().themeMode;
    final isCyberpunk = themeMode == AppThemeMode.cyberpunk;
    final isSweetieWin = themeMode == AppThemeMode.sweetiePro;
    final isSpecialWin = isCyberpunk || isSweetieWin;
    final specialNeonWin = isSweetieWin ? AppTheme.sweetieHotPink : AppTheme.cyberNeon;

    final iconColor = isSpecialWin
        ? specialNeonWin.withValues(alpha: 0.6)
        : isDark
            ? const Color(0xFF8888A0)
            : DesignSystem.neutral700;
    final hoverBg = isSpecialWin
        ? specialNeonWin.withValues(alpha: 0.1)
        : isDark
            ? const Color(0xFF2A2A30)
            : const Color(0xFFF4F5F7);
    final hoverIconColor = isSpecialWin
        ? specialNeonWin
        : isDark
            ? const Color(0xFFF0F0F2)
            : DesignSystem.neutral900;
    final closeColor = isCyberpunk
        ? AppTheme.cyberPink
        : isSweetieWin
            ? AppTheme.sweetieHotPink
            : theme.colorScheme.primary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WindowActionButton(
          icon: Icons.minimize_rounded,
          tooltip: l.windowMinimize,
          iconColor: iconColor,
          hoverColor: hoverBg,
          hoverIconColor: hoverIconColor,
          onPressed: () => windowManager.minimize(),
        ),
        const SizedBox(width: 8),
        _WindowActionButton(
          icon: _isMaximized
              ? Icons.filter_none_rounded
              : Icons.crop_square_rounded,
          tooltip: _isMaximized ? l.windowRestore : l.windowMaximize,
          iconColor: iconColor,
          hoverColor: hoverBg,
          hoverIconColor: hoverIconColor,
          onPressed: _toggleMaximize,
        ),
        const SizedBox(width: 8),
        _WindowActionButton(
          icon: Icons.close_rounded,
          tooltip: l.windowClose,
          hoverColor: closeColor,
          iconColor: closeColor,
          hoverIconColor: Colors.white,
          onPressed: () => windowManager.close(),
        ),
      ],
    );
  }
}

class _WindowActionButton extends StatefulWidget {
  const _WindowActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.iconColor,
    required this.hoverColor,
    required this.hoverIconColor,
  });

  final IconData icon;
  final String tooltip;
  final Future<void> Function() onPressed;
  final Color iconColor;
  final Color hoverColor;
  final Color hoverIconColor;

  @override
  State<_WindowActionButton> createState() => _WindowActionButtonState();
}

class _WindowActionButtonState extends State<_WindowActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.tooltip,
        child: Material(
          color: _hovered ? widget.hoverColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.onPressed,
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(
                widget.icon,
                size: 18,
                color: _hovered ? widget.hoverIconColor : widget.iconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
