import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// BovaPlayer 设计系统
///
/// 设计理念：精致极简主义 + 流体动效
/// - 温暖的中性色调（摆脱冷色调 AI 美学）
/// - 精致的微交互和流体动效
/// - 内容优先，UI 退居幕后
/// - 统一的视觉语言和交互模式

class DesignSystem {
  // ============== 颜色系统 ==============

  /// 主色调 - 温暖的石墨色（不是纯黑）
  static const Color neutral900 = Color(0xFF1C1917); // 主文字
  static const Color neutral800 = Color(0xFF292524);
  static const Color neutral700 = Color(0xFF44403C);
  static const Color neutral600 = Color(0xFF57534E);
  static const Color neutral500 = Color(0xFF78716C);
  static const Color neutral400 = Color(0xFFA8A29E);
  static const Color neutral300 = Color(0xFFD6D3D1);
  static const Color neutral200 = Color(0xFFE7E5E4);
  static const Color neutral100 = Color(0xFFF5F5F4);
  static const Color neutral50 = Color(0xFFFAFAF9);

  /// 强调色 - 温暖的琥珀色（不是紫色/蓝色）
  static const Color accent900 = Color(0xFF78350F);
  static const Color accent800 = Color(0xFF92400E);
  static const Color accent700 = Color(0xFFB45309);
  static const Color accent600 = Color(0xFFD97706);
  static const Color accent500 = Color(0xFFF59E0B);
  static const Color accent400 = Color(0xFFFBBF24);
  static const Color accent300 = Color(0xFFFCD34D);
  static const Color accent200 = Color(0xFFFDE68A);
  static const Color accent100 = Color(0xFFFEF3C7);

  /// 功能色
  static const Color success = Color(0xFF059669); // 翡翠绿
  static const Color warning = Color(0xFFEA580C); // 橙色
  static const Color error = Color(0xFFDC2626); // 红色
  static const Color info = Color(0xFF0891B2); // 青色

  /// Pro 用户 - 优雅的紫罗兰
  static const Color proGradientStart = Color(0xFF7C3AED);
  static const Color proGradientEnd = Color(0xFFA855F7);

  /// Lifetime 用户 - 奢华的金色
  static const Color lifetimeGradientStart = Color(0xFFEA580C);
  static const Color lifetimeGradientEnd = Color(0xFFF59E0B);

  // ============== 排版系统 ==============

  /// 字体家族（使用系统字体，但优化权重）
  static const String fontFamily = 'SF Pro Display'; // iOS/macOS
  static const String fontFamilyAndroid = 'Roboto'; // Android

  /// 字体大小 - 使用 Type Scale
  static const double text3xl = 30.0; // 页面标题
  static const double text2xl = 24.0; // 区块标题
  static const double textXl = 20.0; // 卡片标题
  static const double textLg = 18.0; // 副标题
  static const double textBase = 16.0; // 正文
  static const double textSm = 14.0; // 辅助文字
  static const double textXs = 12.0; // 标签

  /// 字重
  static const FontWeight weightLight = FontWeight.w300;
  static const FontWeight weightRegular = FontWeight.w400;
  static const FontWeight weightMedium = FontWeight.w500;
  static const FontWeight weightSemibold = FontWeight.w600;
  static const FontWeight weightBold = FontWeight.w700;

  /// 行高
  static const double lineHeightTight = 1.25;
  static const double lineHeightNormal = 1.5;
  static const double lineHeightRelaxed = 1.75;

  // ============== 间距系统 ==============

  static const double space1 = 4.0;
  static const double space2 = 8.0;
  static const double space3 = 12.0;
  static const double space4 = 16.0;
  static const double space5 = 20.0;
  static const double space6 = 24.0;
  static const double space8 = 32.0;
  static const double space10 = 40.0;
  static const double space12 = 48.0;
  static const double space16 = 64.0;
  static const double space20 = 80.0;

  // ============== 圆角系统 ==============

  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radius2xl = 24.0;
  static const double radiusFull = 9999.0;

  // ============== 阴影系统 ==============

  /// 微妙的阴影（卡片）
  static List<BoxShadow> get shadowSm => [
        BoxShadow(
          color: neutral900.withValues(alpha: 0.04),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];

  /// 中等阴影（悬浮卡片）
  static List<BoxShadow> get shadowMd => [
        BoxShadow(
          color: neutral900.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  /// 大阴影（模态框）
  static List<BoxShadow> get shadowLg => [
        BoxShadow(
          color: neutral900.withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  /// 超大阴影（抽屉）
  static List<BoxShadow> get shadowXl => [
        BoxShadow(
          color: neutral900.withValues(alpha: 0.12),
          blurRadius: 40,
          offset: const Offset(0, 16),
        ),
      ];

  // ============== 动画系统 ==============

  /// 动画时长
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 350);

  /// 缓动曲线 - 使用自然的减速曲线
  static const Curve easeOutQuart = Curves.easeOutQuart;
  static const Curve easeOutQuint = Curves.easeOutQuint;
  static const Curve easeOutExpo = Curves.easeOutExpo;
  static const Curve easeInOutQuart = Cubic(0.76, 0, 0.24, 1);

  // ============== 模糊效果 ==============

  static const double blurLight = 8.0;
  static const double blurMedium = 16.0;
  static const double blurHeavy = 24.0;

  // ============== 渐变系统 ==============

  /// Pro 用户渐变
  static LinearGradient get proGradient => const LinearGradient(
        colors: [proGradientStart, proGradientEnd],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// Lifetime 用户渐变
  static LinearGradient get lifetimeGradient => const LinearGradient(
        colors: [lifetimeGradientStart, lifetimeGradientEnd],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// 微妙的背景渐变
  static LinearGradient get subtleGradient => LinearGradient(
        colors: [
          neutral50,
          neutral100.withValues(alpha: 0.5),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );

  // ============== 触摸目标尺寸 ==============

  static const double touchTargetMin = 44.0; // iOS 标准
  static const double touchTargetComfortable = 48.0; // Material 标准

  // ============== 断点系统（响应式）==============

  static const double breakpointMobile = 640.0;
  static const double breakpointTablet = 768.0;
  static const double breakpointDesktop = 1024.0;
  static const double breakpointWide = 1280.0;

  static bool _isDesktopPlatform() {
    if (kIsWeb) return false;
    return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  }

  static bool _isMobilePlatform() {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// 判断是否为移动端
  static bool isMobile(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (_isDesktopPlatform()) return false;
    if (_isMobilePlatform()) return width < breakpointTablet;
    return width < breakpointTablet;
  }

  /// 判断是否为平板
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (_isDesktopPlatform()) return false;
    if (_isMobilePlatform()) {
      return width >= breakpointTablet;
    }
    return width >= breakpointTablet && width < breakpointDesktop;
  }

  /// 判断是否为桌面端
  static bool isDesktop(BuildContext context) {
    if (_isDesktopPlatform()) return true;
    if (_isMobilePlatform()) return false;
    return MediaQuery.of(context).size.width >= breakpointDesktop;
  }
}
