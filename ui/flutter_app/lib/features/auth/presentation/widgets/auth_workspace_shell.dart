import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../../../core/theme/design_system.dart';

const Color authWorkspaceAccent = Color(0xFFE11D48);
const Color authWorkspaceAccentSoft = Color(0xFFFCE7F3);
const Color authWorkspaceCanvas = Color(0xFFF1F3F6);
const Color authWorkspacePanel = Colors.white;
const Color authWorkspacePanelBorder = Color(0xFFE7EAF0);

class AuthWorkspaceScaffold extends StatelessWidget {
  const AuthWorkspaceScaffold({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.heroGraphic,
    this.facts = const [],
    this.showBackButton = true,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final Widget? heroGraphic;
  final List<AuthWorkspaceFact> facts;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final isMobile = DesignSystem.isMobile(context);
    final isDesktop =
        !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

    return Scaffold(
      backgroundColor: authWorkspaceCanvas,
      appBar: !isDesktop && showBackButton
          ? AppBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: DesignSystem.neutral900,
                  size: 20,
                ),
                onPressed: () => Navigator.maybePop(context),
              ),
            )
          : null,
      body: Column(
        children: [
          if (isDesktop)
            _AuthDesktopWindowBar(showBackButton: showBackButton),
          Expanded(
            child: Stack(
              children: [
                if (isDesktop)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onPanStart: (_) async {
                        await windowManager.startDragging();
                      },
                      onDoubleTap: () async {
                        final isMaximized = await windowManager.isMaximized();
                        if (isMaximized) {
                          await windowManager.unmaximize();
                        } else {
                          await windowManager.maximize();
                        }
                      },
                      child: const SizedBox.expand(),
                    ),
                  ),
                SafeArea(
                  top: false,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        isMobile ? DesignSystem.space4 : DesignSystem.space6,
                        showBackButton && !isDesktop
                            ? DesignSystem.space2
                            : DesignSystem.space6,
                        isMobile ? DesignSystem.space4 : DesignSystem.space6,
                        DesignSystem.space8,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1120),
                        child: isMobile
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _HeroPanel(
                                    eyebrow: eyebrow,
                                    title: title,
                                    subtitle: subtitle,
                                    icon: icon,
                                    heroGraphic: heroGraphic,
                                    facts: facts,
                                  ),
                                  const SizedBox(height: DesignSystem.space5),
                                  child,
                                ],
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 11,
                                    child: _HeroPanel(
                                      eyebrow: eyebrow,
                                      title: title,
                                      subtitle: subtitle,
                                      icon: icon,
                                      heroGraphic: heroGraphic,
                                      facts: facts,
                                    ),
                                  ),
                                  const SizedBox(width: DesignSystem.space5),
                                  Expanded(flex: 9, child: child),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthDesktopWindowBar extends StatefulWidget {
  const _AuthDesktopWindowBar({required this.showBackButton});

  final bool showBackButton;

  @override
  State<_AuthDesktopWindowBar> createState() => _AuthDesktopWindowBarState();
}

class _AuthDesktopWindowBarState extends State<_AuthDesktopWindowBar>
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
    return Container(
      height: 54,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: authWorkspacePanelBorder),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) async {
                await windowManager.startDragging();
              },
              onDoubleTap: _toggleMaximize,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    if (widget.showBackButton)
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: DesignSystem.neutral900,
                          size: 18,
                        ),
                        onPressed: () => Navigator.maybePop(context),
                      )
                    else
                      const SizedBox(width: 12),
                    const SizedBox(width: 8),
                    const Text(
                      'BovaPlayer',
                      style: TextStyle(
                        fontSize: DesignSystem.textSm,
                        fontWeight: DesignSystem.weightSemibold,
                        color: DesignSystem.neutral900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const _AuthDesktopWindowControls(),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _AuthDesktopWindowControls extends StatelessWidget {
  const _AuthDesktopWindowControls();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AuthWindowActionButton(
          icon: Icons.minimize_rounded,
          onPressed: () => windowManager.minimize(),
        ),
        const SizedBox(width: 8),
        _AuthWindowActionButton(
          icon: Icons.crop_square_rounded,
          onPressed: () async {
            final isMaximized = await windowManager.isMaximized();
            if (isMaximized) {
              await windowManager.unmaximize();
            } else {
              await windowManager.maximize();
            }
          },
        ),
        const SizedBox(width: 8),
        _AuthWindowActionButton(
          icon: Icons.close_rounded,
          hoverColor: authWorkspaceAccent,
          iconColor: authWorkspaceAccent,
          hoverIconColor: Colors.white,
          onPressed: () => windowManager.close(),
        ),
      ],
    );
  }
}

class _AuthWindowActionButton extends StatefulWidget {
  const _AuthWindowActionButton({
    required this.icon,
    required this.onPressed,
    this.iconColor = DesignSystem.neutral700,
    this.hoverColor = const Color(0xFFF4F5F7),
    this.hoverIconColor = DesignSystem.neutral900,
  });

  final IconData icon;
  final Future<void> Function() onPressed;
  final Color iconColor;
  final Color hoverColor;
  final Color hoverIconColor;

  @override
  State<_AuthWindowActionButton> createState() =>
      _AuthWindowActionButtonState();
}

class _AuthWindowActionButtonState extends State<_AuthWindowActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
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
    );
  }
}

class AuthWorkspacePanel extends StatelessWidget {
  const AuthWorkspacePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(DesignSystem.space6),
    this.backgroundColor = authWorkspacePanel,
    this.borderColor = authWorkspacePanelBorder,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(DesignSystem.radius2xl),
        border: Border.all(color: borderColor),
        boxShadow: DesignSystem.shadowSm,
      ),
      child: child,
    );
  }
}

class AuthWorkspaceFact {
  const AuthWorkspaceFact({required this.label, required this.value});

  final String label;
  final String value;
}

class AuthWorkspaceFooterLink extends StatelessWidget {
  const AuthWorkspaceFooterLink({
    super.key,
    required this.label,
    required this.action,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final String action;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: DesignSystem.textSm,
            color: DesignSystem.neutral600,
          ),
        ),
        TextButton(
          onPressed: enabled ? onTap : null,
          style: TextButton.styleFrom(
            padding:
                const EdgeInsets.symmetric(horizontal: DesignSystem.space2),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            action,
            style: const TextStyle(
              fontSize: DesignSystem.textSm,
              fontWeight: DesignSystem.weightSemibold,
              color: authWorkspaceAccent,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.heroGraphic,
    required this.facts,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? heroGraphic;
  final List<AuthWorkspaceFact> facts;

  @override
  Widget build(BuildContext context) {
    final compactHero = eyebrow.isEmpty &&
        subtitle.isEmpty &&
        facts.isEmpty &&
        heroGraphic != null;

    return AuthWorkspacePanel(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DesignSystem.radius2xl),
          gradient: LinearGradient(
            colors: [
              Colors.white,
              authWorkspaceAccentSoft.withValues(alpha: 0.58),
              const Color(0xFFFFFBEB),
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
              if (eyebrow.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignSystem.space3,
                    vertical: DesignSystem.space1,
                  ),
                  decoration: BoxDecoration(
                    color: authWorkspaceAccentSoft,
                    borderRadius:
                        BorderRadius.circular(DesignSystem.radiusFull),
                  ),
                  child: Text(
                    eyebrow,
                    style: const TextStyle(
                      fontSize: DesignSystem.textXs,
                      fontWeight: DesignSystem.weightSemibold,
                      color: authWorkspaceAccent,
                    ),
                  ),
                ),
                const SizedBox(height: DesignSystem.space5),
              ],
              if (compactHero)
                Row(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius:
                            BorderRadius.circular(DesignSystem.radiusXl),
                        border: Border.all(color: authWorkspacePanelBorder),
                      ),
                      child: heroGraphic,
                    ),
                    const SizedBox(width: DesignSystem.space4),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: DesignSystem.weightBold,
                          color: DesignSystem.neutral900,
                          letterSpacing: -1.0,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ],
                )
              else ...[
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(DesignSystem.radiusXl),
                    border: Border.all(color: authWorkspacePanelBorder),
                  ),
                  child: heroGraphic ??
                      Icon(icon, size: 30, color: authWorkspaceAccent),
                ),
                const SizedBox(height: DesignSystem.space5),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: DesignSystem.weightBold,
                    color: DesignSystem.neutral900,
                    letterSpacing: -1.0,
                    height: 1.0,
                  ),
                ),
              ],
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: DesignSystem.space3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: DesignSystem.textSm,
                    color: DesignSystem.neutral600,
                    height: 1.7,
                  ),
                ),
              ],
              if (facts.isNotEmpty) ...[
                const SizedBox(height: DesignSystem.space5),
                Wrap(
                  spacing: DesignSystem.space3,
                  runSpacing: DesignSystem.space3,
                  children: facts
                      .map(
                        (fact) => _FactPill(
                          label: fact.label,
                          value: fact.value,
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FactPill extends StatelessWidget {
  const _FactPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(
        horizontal: DesignSystem.space3,
        vertical: DesignSystem.space3,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
        border: Border.all(color: authWorkspacePanelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: DesignSystem.textXs,
              color: DesignSystem.neutral500,
            ),
          ),
          const SizedBox(height: 4),
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
    );
  }
}
