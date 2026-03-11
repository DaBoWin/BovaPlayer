import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../core/theme/design_system.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final List<Widget>? actions;
  final Widget? leading;
  final String? title;
  final Widget? titleWidget;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final bool centerTitle;

  const CustomAppBar({
    super.key,
    this.actions,
    this.leading,
    this.title,
    this.titleWidget,
    this.showBackButton = false,
    this.onBackPressed,
    this.centerTitle = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);
    final resolvedTitle = titleWidget ??
        Text(
          title ?? 'BovaPlayer',
          style: const TextStyle(
            color: DesignSystem.neutral900,
            fontSize: DesignSystem.textLg,
            fontWeight: DesignSystem.weightSemibold,
            letterSpacing: -0.3,
          ),
        );

    return PreferredSize(
      preferredSize: preferredSize,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(
              color: DesignSystem.neutral200,
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 56,
            child: centerTitle
                ? Stack(
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
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.center,
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: isDesktop ? 140 : 88,
                              right: isDesktop ? 140 : 88,
                            ),
                            child: IgnorePointer(
                              child: DefaultTextStyle.merge(
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                child: resolvedTitle,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            _LeadingCluster(
                              leading: leading,
                              showBackButton: showBackButton,
                              onBackPressed: onBackPressed,
                            ),
                            const Spacer(),
                            if (actions != null) ...actions!,
                          ],
                        ),
                      ),
                    ],
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        _LeadingCluster(
                          leading: leading,
                          showBackButton: showBackButton,
                          onBackPressed: onBackPressed,
                        ),
                        if (leading != null || showBackButton)
                          const SizedBox(width: 8),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: DefaultTextStyle.merge(
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              child: resolvedTitle,
                            ),
                          ),
                        ),
                        if (actions != null) ...actions!,
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _LeadingCluster extends StatelessWidget {
  final Widget? leading;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const _LeadingCluster({
    required this.leading,
    required this.showBackButton,
    required this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isDesktop && Platform.isMacOS) const SizedBox(width: 68),
        if (showBackButton)
          IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: DesignSystem.neutral900,
              size: 20,
            ),
            onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
            tooltip: '返回',
          )
        else if (leading != null)
          leading!,
      ],
    );
  }
}
