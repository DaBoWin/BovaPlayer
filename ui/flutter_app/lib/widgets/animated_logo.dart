import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 动态变色的 BovaPlayer Logo
class AnimatedLogo extends StatefulWidget {
  final double size;
  final List<Color>? colors;
  final bool animate;
  
  const AnimatedLogo({
    super.key,
    this.size = 120,
    this.colors,
    this.animate = true,
  });
  
  @override
  State<AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<AnimatedLogo> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    if (widget.animate) {
      _controller.repeat();
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _LogoPainter(
            animation: _controller.value,
            colors: widget.colors ?? [
              const Color(0xFFFFD700), // 金色
              const Color(0xFFFFA500), // 橙色
              const Color(0xFFFF8C00), // 深橙色
            ],
          ),
        );
      },
    );
  }
}

class _LogoPainter extends CustomPainter {
  final double animation;
  final List<Color> colors;
  
  _LogoPainter({
    required this.animation,
    required this.colors,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // 创建渐变
    final gradient = LinearGradient(
      colors: colors,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    
    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    
    // 定义两个三角形的顶点
    final leftX = size.width * 0.25;
    final rightX = size.width * 0.75;
    final gap = size.height * 0.05; // 两个三角形之间的间隙
    
    // 上三角形（播放按钮）
    final topTriangle = Path();
    topTriangle.moveTo(leftX, size.height * 0.15); // 左上
    topTriangle.lineTo(leftX, center.dy - gap); // 左下
    topTriangle.lineTo(rightX, size.height * 0.3); // 右中
    topTriangle.close();
    
    // 下三角形（播放按钮）
    final bottomTriangle = Path();
    bottomTriangle.moveTo(leftX, center.dy + gap); // 左上
    bottomTriangle.lineTo(leftX, size.height * 0.85); // 左下
    bottomTriangle.lineTo(rightX, size.height * 0.7); // 右中
    bottomTriangle.close();
    
    // 添加阴影
    canvas.drawShadow(topTriangle, Colors.black.withOpacity(0.2), 8, true);
    canvas.drawShadow(bottomTriangle, Colors.black.withOpacity(0.2), 8, true);
    
    // 绘制两个三角形
    canvas.drawPath(topTriangle, paint);
    canvas.drawPath(bottomTriangle, paint);
    
    // 添加动态高光效果
    if (animation > 0) {
      final highlightPaint = Paint()
        ..color = Colors.white.withOpacity(0.3 * math.sin(animation * math.pi * 2))
        ..style = PaintingStyle.fill;
      
      // 上三角形高光
      final topHighlight = Path();
      topHighlight.moveTo(leftX, size.height * 0.15);
      topHighlight.lineTo(leftX + size.width * 0.15, size.height * 0.2);
      topHighlight.lineTo(rightX - size.width * 0.1, size.height * 0.3);
      topHighlight.close();
      canvas.drawPath(topHighlight, highlightPaint);
      
      // 下三角形高光
      final bottomHighlight = Path();
      bottomHighlight.moveTo(leftX, center.dy + gap);
      bottomHighlight.lineTo(leftX + size.width * 0.15, center.dy + gap + size.height * 0.05);
      bottomHighlight.lineTo(rightX - size.width * 0.1, size.height * 0.7);
      bottomHighlight.close();
      canvas.drawPath(bottomHighlight, highlightPaint);
    }
  }
  
  @override
  bool shouldRepaint(_LogoPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}

/// 简化版静态 Logo
class StaticLogo extends StatelessWidget {
  final double size;
  final List<Color>? colors;
  
  const StaticLogo({
    super.key,
    this.size = 120,
    this.colors,
  });
  
  @override
  Widget build(BuildContext context) {
    return AnimatedLogo(
      size: size,
      colors: colors,
      animate: false,
    );
  }
}
