import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

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

    return Container(
      height: 84,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFF0F1F4)),
        ),
      ),
      child: Stack(
        children: [
          if (isDesktop)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanStart: (_) async {
                  await windowManager.startDragging();
                },
                child: const SizedBox.expand(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                if (onBack != null) ...[
                  IconButton(
                    onPressed: onBack,
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: DesignSystem.neutral700,
                      size: 18,
                    ),
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 6),
                ],
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: DesignSystem.neutral200),
                    boxShadow: DesignSystem.shadowSm,
                  ),
                  child: Icon(
                    sectionIcon,
                    color: const Color(0xFFE11D48),
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
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: DesignSystem.weightSemibold,
                          color: DesignSystem.neutral900,
                          letterSpacing: -0.8,
                          height: 1.0,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: DesignSystem.textSm,
                            color: DesignSystem.neutral400,
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
        ],
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WindowActionButton(
          icon: Icons.minimize_rounded,
          tooltip: '最小化',
          onPressed: () => windowManager.minimize(),
        ),
        const SizedBox(width: 8),
        _WindowActionButton(
          icon: _isMaximized
              ? Icons.filter_none_rounded
              : Icons.crop_square_rounded,
          tooltip: _isMaximized ? '还原' : '最大化',
          onPressed: _toggleMaximize,
        ),
        const SizedBox(width: 8),
        _WindowActionButton(
          icon: Icons.close_rounded,
          tooltip: '关闭',
          hoverColor: const Color(0xFFE11D48),
          iconColor: const Color(0xFFE11D48),
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
    this.iconColor = DesignSystem.neutral700,
    this.hoverColor = const Color(0xFFF4F5F7),
    this.hoverIconColor = DesignSystem.neutral900,
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
