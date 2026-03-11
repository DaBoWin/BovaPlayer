import 'package:flutter/material.dart';
import '../theme/design_system.dart';

/// BovaPlayer 卡片组件
/// 
/// 特点：
/// - 微妙的阴影和圆角
/// - 悬停时的流体动效
/// - 可点击的交互反馈
class BovaCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final bool showShadow;
  final double? width;
  final double? height;
  
  const BovaCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.backgroundColor,
    this.showShadow = true,
    this.width,
    this.height,
  });
  
  @override
  State<BovaCard> createState() => _BovaCardState();
}

class _BovaCardState extends State<BovaCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _elevationAnimation;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: DesignSystem.durationNormal,
      vsync: this,
    );
    
    _elevationAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: DesignSystem.easeOutQuart),
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _controller, curve: DesignSystem.easeOutQuart),
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  void _handleHoverEnter(PointerEvent event) {
    if (widget.onTap != null) {
      setState(() => _isHovered = true);
      _controller.forward();
    }
  }
  
  void _handleHoverExit(PointerEvent event) {
    setState(() => _isHovered = false);
    _controller.reverse();
  }
  
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: _handleHoverEnter,
      onExit: _handleHoverExit,
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: widget.width,
                height: widget.height,
                padding: widget.padding ?? const EdgeInsets.all(DesignSystem.space4),
                decoration: BoxDecoration(
                  color: widget.backgroundColor ?? Colors.white,
                  borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
                  boxShadow: widget.showShadow
                      ? [
                          BoxShadow(
                            color: DesignSystem.neutral900.withOpacity(
                              0.04 + (_elevationAnimation.value * 0.04),
                            ),
                            blurRadius: 6 + (_elevationAnimation.value * 6),
                            offset: Offset(0, 2 + (_elevationAnimation.value * 2)),
                          ),
                        ]
                      : null,
                ),
                child: widget.child,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 媒体卡片（用于视频/音频缩略图）
class BovaMediaCard extends StatelessWidget {
  final String? imageUrl;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? badge;
  final double aspectRatio;
  
  const BovaMediaCard({
    super.key,
    this.imageUrl,
    required this.title,
    this.subtitle,
    this.onTap,
    this.badge,
    this.aspectRatio = 16 / 9,
  });
  
  @override
  Widget build(BuildContext context) {
    return BovaCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 缩略图
          AspectRatio(
            aspectRatio: aspectRatio,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(DesignSystem.radiusLg),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 图片或占位符
                  if (imageUrl != null)
                    Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildPlaceholder();
                      },
                    )
                  else
                    _buildPlaceholder(),
                  
                  // 渐变遮罩（底部）
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.6),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // 徽章（右上角）
                  if (badge != null)
                    Positioned(
                      top: DesignSystem.space2,
                      right: DesignSystem.space2,
                      child: badge!,
                    ),
                ],
              ),
            ),
          ),
          
          // 标题和副标题
          Padding(
            padding: const EdgeInsets.all(DesignSystem.space3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: DesignSystem.textBase,
                    fontWeight: DesignSystem.weightSemibold,
                    color: DesignSystem.neutral900,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: DesignSystem.space1),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: DesignSystem.textSm,
                      color: DesignSystem.neutral600,
                      letterSpacing: -0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPlaceholder() {
    return Container(
      color: DesignSystem.neutral100,
      child: const Center(
        child: Icon(
          Icons.play_circle_outline,
          size: 48,
          color: DesignSystem.neutral400,
        ),
      ),
    );
  }
}
