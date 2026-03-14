import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../providers/theme_provider.dart';
import 'design_system.dart';

/// BovaPlayer 应用主题
class AppTheme {
  static const Color buttonAccent = Color(0xFFE11D48);

  /// 根据 AppThemeMode 获取对应主题
  static ThemeData themeFor(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return lightTheme;
      case AppThemeMode.dark:
        return darkTheme;
      case AppThemeMode.cyberpunk:
        return cyberpunkTheme;
      case AppThemeMode.sweetiePro:
        return sweetieProTheme;
    }
  }

  /// 浅色主题
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: buttonAccent,
        onPrimary: Colors.white,
        secondary: buttonAccent,
        onSecondary: Colors.white,
        error: DesignSystem.error,
        onError: Colors.white,
        surface: DesignSystem.neutral50,
        onSurface: DesignSystem.neutral900,
        surfaceContainerHighest: DesignSystem.neutral100,
      ),
      scaffoldBackgroundColor: DesignSystem.neutral50,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: DesignSystem.neutral900,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          color: DesignSystem.neutral900,
          fontSize: DesignSystem.textLg,
          fontWeight: DesignSystem.weightSemibold,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(DesignSystem.radiusLg),
          ),
        ),
        shadowColor: DesignSystem.neutral900.withValues(alpha: 0.06),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: DesignSystem.neutral100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(DesignSystem.radiusMd),
          ),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(DesignSystem.radiusMd),
          ),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(DesignSystem.radiusMd),
          ),
          borderSide: BorderSide(
            color: buttonAccent,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(DesignSystem.radiusMd),
          ),
          borderSide: BorderSide(
            color: DesignSystem.error,
            width: 1,
          ),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: DesignSystem.space4,
          vertical: DesignSystem.space3,
        ),
        hintStyle: TextStyle(
          color: DesignSystem.neutral400,
          fontSize: DesignSystem.textBase,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: buttonAccent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: DesignSystem.space6,
            vertical: DesignSystem.space4,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(DesignSystem.radiusFull),
            ),
          ),
          textStyle: const TextStyle(
            fontSize: DesignSystem.textBase,
            fontWeight: DesignSystem.weightSemibold,
            letterSpacing: -0.2,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: buttonAccent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: DesignSystem.space6,
            vertical: DesignSystem.space4,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(DesignSystem.radiusFull),
            ),
          ),
          textStyle: const TextStyle(
            fontSize: DesignSystem.textBase,
            fontWeight: DesignSystem.weightSemibold,
            letterSpacing: -0.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: buttonAccent,
          padding: const EdgeInsets.symmetric(
            horizontal: DesignSystem.space4,
            vertical: DesignSystem.space3,
          ),
          textStyle: const TextStyle(
            fontSize: DesignSystem.textBase,
            fontWeight: DesignSystem.weightMedium,
            letterSpacing: -0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: DesignSystem.neutral900,
          backgroundColor: Colors.white,
          side: const BorderSide(
            color: DesignSystem.neutral300,
            width: 1.5,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: DesignSystem.space6,
            vertical: DesignSystem.space4,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(DesignSystem.radiusFull),
            ),
          ),
          textStyle: const TextStyle(
            fontSize: DesignSystem.textBase,
            fontWeight: DesignSystem.weightMedium,
            letterSpacing: -0.2,
          ),
        ),
      ),
      iconTheme: const IconThemeData(
        color: DesignSystem.neutral700,
        size: 20,
      ),
      dividerTheme: const DividerThemeData(
        color: DesignSystem.neutral200,
        thickness: 1,
        space: 1,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: DesignSystem.accent600,
        unselectedItemColor: DesignSystem.neutral500,
        selectedLabelStyle: TextStyle(
          fontSize: DesignSystem.textXs,
          fontWeight: DesignSystem.weightSemibold,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: DesignSystem.textXs,
          fontWeight: DesignSystem.weightMedium,
        ),
        elevation: 0,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: DesignSystem.text3xl,
          fontWeight: DesignSystem.weightBold,
          color: DesignSystem.neutral900,
          letterSpacing: -0.5,
          height: DesignSystem.lineHeightTight,
        ),
        displayMedium: TextStyle(
          fontSize: DesignSystem.text2xl,
          fontWeight: DesignSystem.weightBold,
          color: DesignSystem.neutral900,
          letterSpacing: -0.4,
          height: DesignSystem.lineHeightTight,
        ),
        displaySmall: TextStyle(
          fontSize: DesignSystem.textXl,
          fontWeight: DesignSystem.weightSemibold,
          color: DesignSystem.neutral900,
          letterSpacing: -0.3,
          height: DesignSystem.lineHeightNormal,
        ),
        headlineMedium: TextStyle(
          fontSize: DesignSystem.textLg,
          fontWeight: DesignSystem.weightSemibold,
          color: DesignSystem.neutral900,
          letterSpacing: -0.2,
          height: DesignSystem.lineHeightNormal,
        ),
        titleLarge: TextStyle(
          fontSize: DesignSystem.textBase,
          fontWeight: DesignSystem.weightSemibold,
          color: DesignSystem.neutral900,
          letterSpacing: -0.2,
          height: DesignSystem.lineHeightNormal,
        ),
        bodyLarge: TextStyle(
          fontSize: DesignSystem.textBase,
          fontWeight: DesignSystem.weightRegular,
          color: DesignSystem.neutral900,
          letterSpacing: -0.1,
          height: DesignSystem.lineHeightNormal,
        ),
        bodyMedium: TextStyle(
          fontSize: DesignSystem.textSm,
          fontWeight: DesignSystem.weightRegular,
          color: DesignSystem.neutral700,
          letterSpacing: -0.1,
          height: DesignSystem.lineHeightNormal,
        ),
        bodySmall: TextStyle(
          fontSize: DesignSystem.textXs,
          fontWeight: DesignSystem.weightRegular,
          color: DesignSystem.neutral600,
          letterSpacing: 0,
          height: DesignSystem.lineHeightNormal,
        ),
        labelLarge: TextStyle(
          fontSize: DesignSystem.textSm,
          fontWeight: DesignSystem.weightMedium,
          color: DesignSystem.neutral700,
          letterSpacing: -0.1,
        ),
      ),
    );
  }

  // ============== 暗黑主题 ==============

  static const Color _darkSurface = Color(0xFF0F0F11);
  static const Color _darkCard = Color(0xFF1A1A1F);
  static const Color _darkCardBorder = Color(0xFF2A2A30);
  static const Color _darkTextPrimary = Color(0xFFF0F0F2);
  static const Color _darkTextSecondary = Color(0xFFA0A0A8);
  static const Color _darkTextTertiary = Color(0xFF6B6B75);
  static const Color _darkAccent = Color(0xFFE11D48);
  static const Color _darkInputFill = Color(0xFF222228);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: _darkAccent,
        onPrimary: Colors.white,
        secondary: _darkAccent,
        onSecondary: Colors.white,
        error: Color(0xFFEF4444),
        onError: Colors.white,
        surface: _darkSurface,
        onSurface: _darkTextPrimary,
        surfaceContainerHighest: _darkCard,
      ),
      scaffoldBackgroundColor: _darkSurface,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: _darkSurface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: _darkTextPrimary,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          color: _darkTextPrimary,
          fontSize: DesignSystem.textLg,
          fontWeight: DesignSystem.weightSemibold,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: _darkCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(DesignSystem.radiusLg),
          ),
          side: BorderSide(color: _darkCardBorder, width: 1),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: _darkInputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(DesignSystem.radiusMd),
          ),
          borderSide: BorderSide(color: _darkCardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(DesignSystem.radiusMd),
          ),
          borderSide: BorderSide(color: _darkCardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(DesignSystem.radiusMd),
          ),
          borderSide: BorderSide(color: _darkAccent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(DesignSystem.radiusMd),
          ),
          borderSide: BorderSide(color: Color(0xFFEF4444), width: 1),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: DesignSystem.space4,
          vertical: DesignSystem.space3,
        ),
        hintStyle: TextStyle(
          color: _darkTextTertiary,
          fontSize: DesignSystem.textBase,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: _darkAccent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: DesignSystem.space6,
            vertical: DesignSystem.space4,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(DesignSystem.radiusFull),
            ),
          ),
          textStyle: const TextStyle(
            fontSize: DesignSystem.textBase,
            fontWeight: DesignSystem.weightSemibold,
            letterSpacing: -0.2,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _darkAccent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: DesignSystem.space6,
            vertical: DesignSystem.space4,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(DesignSystem.radiusFull),
            ),
          ),
          textStyle: const TextStyle(
            fontSize: DesignSystem.textBase,
            fontWeight: DesignSystem.weightSemibold,
            letterSpacing: -0.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _darkAccent,
          padding: const EdgeInsets.symmetric(
            horizontal: DesignSystem.space4,
            vertical: DesignSystem.space3,
          ),
          textStyle: const TextStyle(
            fontSize: DesignSystem.textBase,
            fontWeight: DesignSystem.weightMedium,
            letterSpacing: -0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _darkTextPrimary,
          backgroundColor: _darkCard,
          side: const BorderSide(color: _darkCardBorder, width: 1.5),
          padding: const EdgeInsets.symmetric(
            horizontal: DesignSystem.space6,
            vertical: DesignSystem.space4,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(DesignSystem.radiusFull),
            ),
          ),
          textStyle: const TextStyle(
            fontSize: DesignSystem.textBase,
            fontWeight: DesignSystem.weightMedium,
            letterSpacing: -0.2,
          ),
        ),
      ),
      iconTheme: const IconThemeData(
        color: _darkTextSecondary,
        size: 20,
      ),
      dividerTheme: const DividerThemeData(
        color: _darkCardBorder,
        thickness: 1,
        space: 1,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _darkSurface,
        selectedItemColor: _darkAccent,
        unselectedItemColor: _darkTextTertiary,
        selectedLabelStyle: TextStyle(
          fontSize: DesignSystem.textXs,
          fontWeight: DesignSystem.weightSemibold,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: DesignSystem.textXs,
          fontWeight: DesignSystem.weightMedium,
        ),
        elevation: 0,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: DesignSystem.text3xl,
          fontWeight: DesignSystem.weightBold,
          color: _darkTextPrimary,
          letterSpacing: -0.5,
          height: DesignSystem.lineHeightTight,
        ),
        displayMedium: TextStyle(
          fontSize: DesignSystem.text2xl,
          fontWeight: DesignSystem.weightBold,
          color: _darkTextPrimary,
          letterSpacing: -0.4,
          height: DesignSystem.lineHeightTight,
        ),
        displaySmall: TextStyle(
          fontSize: DesignSystem.textXl,
          fontWeight: DesignSystem.weightSemibold,
          color: _darkTextPrimary,
          letterSpacing: -0.3,
          height: DesignSystem.lineHeightNormal,
        ),
        headlineMedium: TextStyle(
          fontSize: DesignSystem.textLg,
          fontWeight: DesignSystem.weightSemibold,
          color: _darkTextPrimary,
          letterSpacing: -0.2,
          height: DesignSystem.lineHeightNormal,
        ),
        titleLarge: TextStyle(
          fontSize: DesignSystem.textBase,
          fontWeight: DesignSystem.weightSemibold,
          color: _darkTextPrimary,
          letterSpacing: -0.2,
          height: DesignSystem.lineHeightNormal,
        ),
        bodyLarge: TextStyle(
          fontSize: DesignSystem.textBase,
          fontWeight: DesignSystem.weightRegular,
          color: _darkTextPrimary,
          letterSpacing: -0.1,
          height: DesignSystem.lineHeightNormal,
        ),
        bodyMedium: TextStyle(
          fontSize: DesignSystem.textSm,
          fontWeight: DesignSystem.weightRegular,
          color: _darkTextSecondary,
          letterSpacing: -0.1,
          height: DesignSystem.lineHeightNormal,
        ),
        bodySmall: TextStyle(
          fontSize: DesignSystem.textXs,
          fontWeight: DesignSystem.weightRegular,
          color: _darkTextTertiary,
          letterSpacing: 0,
          height: DesignSystem.lineHeightNormal,
        ),
        labelLarge: TextStyle(
          fontSize: DesignSystem.textSm,
          fontWeight: DesignSystem.weightMedium,
          color: _darkTextSecondary,
          letterSpacing: -0.1,
        ),
      ),
    );
  }

  // ============== 赛博朋克 Pro 主题 ==============

  static const Color _cyberBg = Color(0xFF0A0A12);
  static const Color _cyberCard = Color(0xFF12121E);
  static const Color _cyberCardBorder = Color(0xFF1E1E35);
  static const Color _cyberNeon = Color(0xFF00F0FF);      // 霓虹青
  static const Color _cyberPink = Color(0xFFFF2D7A);      // 霓虹粉
  static const Color _cyberPurple = Color(0xFFA855F7);    // 霓虹紫
  static const Color _cyberYellow = Color(0xFFFFE600);    // 霓虹黄
  static const Color _cyberTextPrimary = Color(0xFFE8E8F0);
  static const Color _cyberTextSecondary = Color(0xFF8888A0);
  static const Color _cyberTextTertiary = Color(0xFF555570);
  static const Color _cyberInputFill = Color(0xFF16162A);

  // 赛博朋克主题公开颜色（供组件使用）
  static const Color cyberNeon = _cyberNeon;
  static const Color cyberPink = _cyberPink;
  static const Color cyberPurple = _cyberPurple;
  static const Color cyberYellow = _cyberYellow;
  static const Color cyberBg = _cyberBg;
  static const Color cyberCard = _cyberCard;
  static const Color cyberCardBorder = _cyberCardBorder;

  // ============== 小蜜 Pro 主题颜色 ==============
  static const Color _sweetieBg            = Color(0xFFFFF6FA);   // 奶油粉背景
  static const Color _sweetieCard          = Color(0xFFFFFDFE);   // 微暖白卡片
  static const Color _sweetieCardBorder    = Color(0xFFFFD9E8);   // 柔亮粉边框
  static const Color _sweetieHotPink       = Color(0xFFFF4FAF);   // 亮玫粉主色
  static const Color _sweetieSoftPink      = Color(0xFFFFC2D9);   // 云朵粉辅色
  static const Color _sweetiePeachGlow     = Color(0xFFFFB86C);   // 蜜桃高光色
  static const Color _sweetieTextPrimary   = Color(0xFF452338);   // 莓果棕主文字
  static const Color _sweetieTextSecondary = Color(0xFF8F5A74);   // 柔莓副文字
  static const Color _sweetieTextTertiary  = Color(0xFFC792AB);   // 浅莓弱文字
  static const Color _sweetieInputFill     = Color(0xFFFFF2F7);   // 柔粉输入底

  // 小蜜主题公开颜色（供组件使用）
  static const Color sweetieHotPink    = _sweetieHotPink;
  static const Color sweetieSoftPink   = _sweetieSoftPink;
  static const Color sweetiePeachGlow  = _sweetiePeachGlow;
  static const Color sweetieBg         = _sweetieBg;
  static const Color sweetieCard       = _sweetieCard;
  static const Color sweetieCardBorder = _sweetieCardBorder;

  static ThemeData get cyberpunkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: _cyberNeon,
        onPrimary: _cyberBg,
        secondary: _cyberPink,
        onSecondary: Colors.white,
        tertiary: _cyberPurple,
        error: Color(0xFFFF4757),
        onError: Colors.white,
        surface: _cyberBg,
        onSurface: _cyberTextPrimary,
        surfaceContainerHighest: _cyberCard,
      ),
      scaffoldBackgroundColor: _cyberBg,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: _cyberBg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: _cyberTextPrimary,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          color: _cyberNeon,
          fontSize: DesignSystem.textLg,
          fontWeight: DesignSystem.weightBold,
          letterSpacing: 1.5,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: _cyberCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(
            Radius.circular(DesignSystem.radiusMd),
          ),
          side: BorderSide(
            color: _cyberNeon.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _cyberInputFill,
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(
            Radius.circular(DesignSystem.radiusSm),
          ),
          borderSide: BorderSide(color: _cyberNeon.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(
            Radius.circular(DesignSystem.radiusSm),
          ),
          borderSide: BorderSide(color: _cyberNeon.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(
            Radius.circular(DesignSystem.radiusSm),
          ),
          borderSide: BorderSide(
            color: _cyberNeon.withValues(alpha: 0.8),
            width: 2,
          ),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(DesignSystem.radiusSm),
          ),
          borderSide: BorderSide(color: _cyberPink, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DesignSystem.space4,
          vertical: DesignSystem.space3,
        ),
        hintStyle: const TextStyle(
          color: _cyberTextTertiary,
          fontSize: DesignSystem.textBase,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: _cyberNeon,
          foregroundColor: _cyberBg,
          padding: const EdgeInsets.symmetric(
            horizontal: DesignSystem.space6,
            vertical: DesignSystem.space4,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(DesignSystem.radiusSm),
            ),
          ),
          textStyle: const TextStyle(
            fontSize: DesignSystem.textBase,
            fontWeight: DesignSystem.weightBold,
            letterSpacing: 1.0,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _cyberPink,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: DesignSystem.space6,
            vertical: DesignSystem.space4,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(DesignSystem.radiusSm),
            ),
          ),
          textStyle: const TextStyle(
            fontSize: DesignSystem.textBase,
            fontWeight: DesignSystem.weightBold,
            letterSpacing: 1.0,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _cyberNeon,
          padding: const EdgeInsets.symmetric(
            horizontal: DesignSystem.space4,
            vertical: DesignSystem.space3,
          ),
          textStyle: const TextStyle(
            fontSize: DesignSystem.textBase,
            fontWeight: DesignSystem.weightMedium,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _cyberNeon,
          backgroundColor: Colors.transparent,
          side: BorderSide(
            color: _cyberNeon.withValues(alpha: 0.6),
            width: 1.5,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: DesignSystem.space6,
            vertical: DesignSystem.space4,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(DesignSystem.radiusSm),
            ),
          ),
          textStyle: const TextStyle(
            fontSize: DesignSystem.textBase,
            fontWeight: DesignSystem.weightMedium,
            letterSpacing: 0.5,
          ),
        ),
      ),
      iconTheme: const IconThemeData(
        color: _cyberTextSecondary,
        size: 20,
      ),
      dividerTheme: DividerThemeData(
        color: _cyberNeon.withValues(alpha: 0.15),
        thickness: 1,
        space: 1,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _cyberBg,
        selectedItemColor: _cyberNeon,
        unselectedItemColor: _cyberTextTertiary,
        selectedLabelStyle: TextStyle(
          fontSize: DesignSystem.textXs,
          fontWeight: DesignSystem.weightBold,
          letterSpacing: 0.5,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: DesignSystem.textXs,
          fontWeight: DesignSystem.weightMedium,
        ),
        elevation: 0,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: DesignSystem.text3xl,
          fontWeight: DesignSystem.weightBold,
          color: _cyberTextPrimary,
          letterSpacing: 1.0,
          height: DesignSystem.lineHeightTight,
        ),
        displayMedium: TextStyle(
          fontSize: DesignSystem.text2xl,
          fontWeight: DesignSystem.weightBold,
          color: _cyberTextPrimary,
          letterSpacing: 0.5,
          height: DesignSystem.lineHeightTight,
        ),
        displaySmall: TextStyle(
          fontSize: DesignSystem.textXl,
          fontWeight: DesignSystem.weightSemibold,
          color: _cyberTextPrimary,
          letterSpacing: 0.3,
          height: DesignSystem.lineHeightNormal,
        ),
        headlineMedium: TextStyle(
          fontSize: DesignSystem.textLg,
          fontWeight: DesignSystem.weightSemibold,
          color: _cyberTextPrimary,
          letterSpacing: 0.2,
          height: DesignSystem.lineHeightNormal,
        ),
        titleLarge: TextStyle(
          fontSize: DesignSystem.textBase,
          fontWeight: DesignSystem.weightSemibold,
          color: _cyberTextPrimary,
          letterSpacing: 0.2,
          height: DesignSystem.lineHeightNormal,
        ),
        bodyLarge: TextStyle(
          fontSize: DesignSystem.textBase,
          fontWeight: DesignSystem.weightRegular,
          color: _cyberTextPrimary,
          letterSpacing: 0,
          height: DesignSystem.lineHeightNormal,
        ),
        bodyMedium: TextStyle(
          fontSize: DesignSystem.textSm,
          fontWeight: DesignSystem.weightRegular,
          color: _cyberTextSecondary,
          letterSpacing: 0,
          height: DesignSystem.lineHeightNormal,
        ),
        bodySmall: TextStyle(
          fontSize: DesignSystem.textXs,
          fontWeight: DesignSystem.weightRegular,
          color: _cyberTextTertiary,
          letterSpacing: 0,
          height: DesignSystem.lineHeightNormal,
        ),
        labelLarge: TextStyle(
          fontSize: DesignSystem.textSm,
          fontWeight: DesignSystem.weightMedium,
          color: _cyberTextSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ============== 小蜜 Pro 主题 ==============

  static ThemeData get sweetieProTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: _sweetieHotPink,
        onPrimary: Colors.white,
        secondary: _sweetiePeachGlow,
        onSecondary: _sweetieTextPrimary,
        tertiary: _sweetieSoftPink,
        error: Color(0xFFFF4757),
        onError: Colors.white,
        surface: _sweetieBg,
        onSurface: _sweetieTextPrimary,
        surfaceContainerHighest: _sweetieCard,
      ),
      scaffoldBackgroundColor: _sweetieBg,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: _sweetieBg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: _sweetieTextPrimary,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          color: _sweetieHotPink,
          fontSize: DesignSystem.textLg,
          fontWeight: DesignSystem.weightBold,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: _sweetieCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(
            Radius.circular(DesignSystem.radiusMd),
          ),
          side: BorderSide(
            color: _sweetieHotPink.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _sweetieInputFill,
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(DesignSystem.radiusSm)),
          borderSide: BorderSide(color: _sweetieHotPink.withValues(alpha: 0.28)),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(DesignSystem.radiusSm)),
          borderSide: BorderSide(color: _sweetieCardBorder),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(DesignSystem.radiusSm)),
          borderSide: BorderSide(color: _sweetieHotPink, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(DesignSystem.radiusSm)),
          borderSide: BorderSide(color: Color(0xFFFF4757), width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DesignSystem.space4,
          vertical: DesignSystem.space3,
        ),
        hintStyle: const TextStyle(color: _sweetieTextTertiary, fontSize: DesignSystem.textBase),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: _sweetieHotPink,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: DesignSystem.space6, vertical: DesignSystem.space4),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(DesignSystem.radiusFull)),
          ),
          textStyle: const TextStyle(fontSize: DesignSystem.textBase, fontWeight: DesignSystem.weightBold),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _sweetieHotPink,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: DesignSystem.space6, vertical: DesignSystem.space4),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(DesignSystem.radiusFull)),
          ),
          textStyle: const TextStyle(fontSize: DesignSystem.textBase, fontWeight: DesignSystem.weightBold),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _sweetieHotPink,
          padding: const EdgeInsets.symmetric(horizontal: DesignSystem.space4, vertical: DesignSystem.space3),
          textStyle: const TextStyle(fontSize: DesignSystem.textBase, fontWeight: DesignSystem.weightMedium),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _sweetieHotPink,
          backgroundColor: Colors.white,
          side: BorderSide(color: _sweetieHotPink.withValues(alpha: 0.55), width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: DesignSystem.space6, vertical: DesignSystem.space4),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(DesignSystem.radiusFull)),
          ),
          textStyle: const TextStyle(fontSize: DesignSystem.textBase, fontWeight: DesignSystem.weightMedium),
        ),
      ),
      iconTheme: const IconThemeData(color: _sweetieTextSecondary, size: 20),
      dividerTheme: const DividerThemeData(
        color: _sweetieCardBorder,
        thickness: 1,
        space: 1,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _sweetieCard,
        selectedItemColor: _sweetieHotPink,
        unselectedItemColor: _sweetieTextTertiary,
        selectedLabelStyle: TextStyle(fontSize: DesignSystem.textXs, fontWeight: DesignSystem.weightBold),
        unselectedLabelStyle: TextStyle(fontSize: DesignSystem.textXs, fontWeight: DesignSystem.weightMedium),
        elevation: 0,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: DesignSystem.text3xl, fontWeight: DesignSystem.weightBold, color: _sweetieTextPrimary, letterSpacing: -0.5, height: DesignSystem.lineHeightTight),
        displayMedium: TextStyle(fontSize: DesignSystem.text2xl, fontWeight: DesignSystem.weightBold, color: _sweetieTextPrimary, letterSpacing: -0.4, height: DesignSystem.lineHeightTight),
        displaySmall: TextStyle(fontSize: DesignSystem.textXl, fontWeight: DesignSystem.weightSemibold, color: _sweetieTextPrimary, letterSpacing: -0.3, height: DesignSystem.lineHeightNormal),
        headlineMedium: TextStyle(fontSize: DesignSystem.textLg, fontWeight: DesignSystem.weightSemibold, color: _sweetieTextPrimary, letterSpacing: -0.2, height: DesignSystem.lineHeightNormal),
        titleLarge: TextStyle(fontSize: DesignSystem.textBase, fontWeight: DesignSystem.weightSemibold, color: _sweetieTextPrimary, letterSpacing: -0.2, height: DesignSystem.lineHeightNormal),
        bodyLarge: TextStyle(fontSize: DesignSystem.textBase, fontWeight: DesignSystem.weightRegular, color: _sweetieTextPrimary, letterSpacing: -0.1, height: DesignSystem.lineHeightNormal),
        bodyMedium: TextStyle(fontSize: DesignSystem.textSm, fontWeight: DesignSystem.weightRegular, color: _sweetieTextSecondary, letterSpacing: -0.1, height: DesignSystem.lineHeightNormal),
        bodySmall: TextStyle(fontSize: DesignSystem.textXs, fontWeight: DesignSystem.weightRegular, color: _sweetieTextTertiary, letterSpacing: 0, height: DesignSystem.lineHeightNormal),
        labelLarge: TextStyle(fontSize: DesignSystem.textSm, fontWeight: DesignSystem.weightMedium, color: _sweetieTextSecondary, letterSpacing: 0.3),
      ),
    );
  }
}
