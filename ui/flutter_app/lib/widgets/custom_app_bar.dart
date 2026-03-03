import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:window_manager/window_manager.dart';
import 'dart:io' show Platform;

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final List<Widget>? actions;
  final Widget? leading;
  final String? title;
  final Widget? titleWidget;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const CustomAppBar({
    super.key,
    this.actions,
    this.leading,
    this.title,
    this.titleWidget,
    this.showBackButton = false,
    this.onBackPressed,
  });

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

    if (isDesktop) {
      return PreferredSize(
        preferredSize: preferredSize,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                color: Color(0xFFE5E7EB),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // macOS 红黄绿按钮占位
                  if (Platform.isMacOS) const SizedBox(width: 68),
                  
                  // 返回按钮（在红绿灯旁边）
                  if (showBackButton)
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Color(0xFF1F2937), size: 20),
                      onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  
                  // 左侧自定义按钮
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: 12),
                  ],
                  
                  // 标题居中 - 可拖动区域
                  Expanded(
                    child: GestureDetector(
                      onPanStart: (_) async {
                        await windowManager.startDragging();
                      },
                      child: Center(
                        child: titleWidget ?? Text(
                          title ?? 'BovaPlayer',
                          style: const TextStyle(
                            color: Color(0xFF1F2937),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // 右侧按钮
                  if (actions != null) ...actions!,
                ],
              ),
            ),
          ),
        ),
      );
    }

    // 移动端
    return AppBar(
      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF1F2937)),
              onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
            )
          : leading,
      title: titleWidget ?? Text(
        title ?? 'BovaPlayer',
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
          color: Color(0xFF1F2937),
        ),
      ),
      centerTitle: true,
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1F2937),
      elevation: 0,
      actions: actions,
    );
  }
}
