import 'package:flutter/material.dart';
import '../theme/design_system.dart';

/// BovaPlayer 输入框组件
class BovaTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int? maxLines;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool autofocus;
  
  const BovaTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.maxLines = 1,
    this.enabled = true,
    this.onChanged,
    this.onTap,
    this.autofocus = false,
  });
  
  @override
  State<BovaTextField> createState() => _BovaTextFieldState();
}

class _BovaTextFieldState extends State<BovaTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;
  
  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }
  
  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }
  
  void _handleFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标签
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: const TextStyle(
              fontSize: DesignSystem.textSm,
              fontWeight: DesignSystem.weightSemibold,
              color: DesignSystem.neutral900,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: DesignSystem.space2),
        ],
        
        // 输入框
        AnimatedContainer(
          duration: DesignSystem.durationFast,
          curve: DesignSystem.easeOutQuart,
          decoration: BoxDecoration(
            color: widget.enabled 
                ? DesignSystem.neutral100 
                : DesignSystem.neutral50,
            borderRadius: BorderRadius.circular(DesignSystem.radiusMd),
            border: Border.all(
              color: hasError
                  ? DesignSystem.error
                  : _isFocused
                      ? DesignSystem.accent600
                      : Colors.transparent,
              width: _isFocused || hasError ? 2 : 1,
            ),
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType,
            maxLines: widget.maxLines,
            enabled: widget.enabled,
            autofocus: widget.autofocus,
            onChanged: widget.onChanged,
            onTap: widget.onTap,
            style: const TextStyle(
              fontSize: DesignSystem.textBase,
              color: DesignSystem.neutral900,
              letterSpacing: -0.1,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: const TextStyle(
                color: DesignSystem.neutral400,
                fontSize: DesignSystem.textBase,
              ),
              prefixIcon: widget.prefixIcon != null
                  ? Icon(
                      widget.prefixIcon,
                      size: 20,
                      color: _isFocused 
                          ? DesignSystem.accent600 
                          : DesignSystem.neutral500,
                    )
                  : null,
              suffixIcon: widget.suffixIcon,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: widget.prefixIcon != null ? 0 : DesignSystem.space4,
                vertical: DesignSystem.space3,
              ),
            ),
          ),
        ),
        
        // 辅助文字或错误信息
        if (widget.helperText != null || widget.errorText != null) ...[
          const SizedBox(height: DesignSystem.space1),
          Text(
            widget.errorText ?? widget.helperText!,
            style: TextStyle(
              fontSize: DesignSystem.textXs,
              color: hasError 
                  ? DesignSystem.error 
                  : DesignSystem.neutral600,
              letterSpacing: 0,
            ),
          ),
        ],
      ],
    );
  }
}

/// 搜索框组件
class BovaSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  
  const BovaSearchField({
    super.key,
    this.controller,
    this.hint,
    this.onChanged,
    this.onClear,
  });
  
  @override
  Widget build(BuildContext context) {
    return BovaTextField(
      controller: controller,
      hint: hint ?? '搜索...',
      prefixIcon: Icons.search,
      suffixIcon: controller?.text.isNotEmpty == true
          ? IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () {
                controller?.clear();
                onClear?.call();
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            )
          : null,
      onChanged: onChanged,
    );
  }
}
