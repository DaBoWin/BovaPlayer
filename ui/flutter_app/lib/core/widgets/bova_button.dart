import 'package:flutter/material.dart';
import '../theme/design_system.dart';

const Color _bovaButtonAccent = Color(0xFFE11D48);

/// BovaPlayer 按钮组件
///
/// 提供三种样式：
/// - primary: 主要操作（填充背景）
/// - secondary: 次要操作（描边）
/// - ghost: 幽灵按钮（无边框）
class BovaButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final BovaButtonStyle style;
  final BovaButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;

  const BovaButton({
    super.key,
    required this.text,
    this.onPressed,
    this.style = BovaButtonStyle.primary,
    this.size = BovaButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  @override
  State<BovaButton> createState() => _BovaButtonState();
}

class _BovaButtonState extends State<BovaButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: DesignSystem.durationFast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: DesignSystem.easeOutQuart),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      _controller.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;

    // 尺寸配置
    final double height;
    final double horizontalPadding;
    final double fontSize;
    final double iconSize;

    switch (widget.size) {
      case BovaButtonSize.small:
        height = 36;
        horizontalPadding = DesignSystem.space4;
        fontSize = DesignSystem.textSm;
        iconSize = 16;
        break;
      case BovaButtonSize.medium:
        height = 44;
        horizontalPadding = DesignSystem.space6;
        fontSize = DesignSystem.textBase;
        iconSize = 18;
        break;
      case BovaButtonSize.large:
        height = 52;
        horizontalPadding = DesignSystem.space8;
        fontSize = DesignSystem.textLg;
        iconSize = 20;
        break;
    }

    // 样式配置
    final Color backgroundColor;
    final Color foregroundColor;
    final Color? borderColor;

    switch (widget.style) {
      case BovaButtonStyle.primary:
        backgroundColor =
            isDisabled ? DesignSystem.neutral200 : _bovaButtonAccent;
        foregroundColor = isDisabled ? DesignSystem.neutral400 : Colors.white;
        borderColor = null;
        break;
      case BovaButtonStyle.secondary:
        backgroundColor = Colors.white;
        foregroundColor =
            isDisabled ? DesignSystem.neutral400 : DesignSystem.neutral900;
        borderColor =
            isDisabled ? DesignSystem.neutral200 : DesignSystem.neutral300;
        break;
      case BovaButtonStyle.ghost:
        backgroundColor = Colors.transparent;
        foregroundColor =
            isDisabled ? DesignSystem.neutral400 : DesignSystem.neutral700;
        borderColor = null;
        break;
    }

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: isDisabled ? null : widget.onPressed,
        child: Container(
          height: height,
          width: widget.isFullWidth ? double.infinity : null,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(DesignSystem.radiusFull),
            border: borderColor != null
                ? Border.all(color: borderColor, width: 1.2)
                : null,
            boxShadow: widget.style == BovaButtonStyle.primary && !isDisabled
                ? [
                    BoxShadow(
                      color: _bovaButtonAccent.withValues(alpha: 0.24),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize:
                widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isLoading)
                SizedBox(
                  width: iconSize,
                  height: iconSize,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
                  ),
                )
              else if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: iconSize,
                  color: foregroundColor,
                ),
                const SizedBox(width: DesignSystem.space2),
              ],
              Text(
                widget.text,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: DesignSystem.weightSemibold,
                  color: foregroundColor,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum BovaButtonStyle {
  primary,
  secondary,
  ghost,
}

enum BovaButtonSize {
  small,
  medium,
  large,
}
