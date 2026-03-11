import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_system.dart';

/// BovaPlayer 应用主题
class AppTheme {
  static const Color buttonAccent = Color(0xFFE11D48);

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

  /// 深色主题（播放器专用）
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: DesignSystem.accent500,
        onPrimary: DesignSystem.neutral900,
        secondary: DesignSystem.accent400,
        onSecondary: DesignSystem.neutral900,
        error: DesignSystem.error,
        onError: Colors.white,
        surface: Color(0xFF0A0A0A),
        onSurface: DesignSystem.neutral100,
        surfaceContainerHighest: Color(0xFF1A1A1A),
      ),
      scaffoldBackgroundColor: const Color(0xFF0A0A0A),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: DesignSystem.neutral100,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          color: DesignSystem.neutral100,
          fontSize: DesignSystem.textLg,
          fontWeight: DesignSystem.weightSemibold,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: Color(0xFF1A1A1A),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(DesignSystem.radiusLg),
          ),
        ),
      ),
      iconTheme: const IconThemeData(
        color: DesignSystem.neutral300,
        size: 20,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: DesignSystem.text3xl,
          fontWeight: DesignSystem.weightBold,
          color: DesignSystem.neutral100,
          letterSpacing: -0.5,
          height: DesignSystem.lineHeightTight,
        ),
        bodyLarge: TextStyle(
          fontSize: DesignSystem.textBase,
          fontWeight: DesignSystem.weightRegular,
          color: DesignSystem.neutral100,
          letterSpacing: -0.1,
          height: DesignSystem.lineHeightNormal,
        ),
        bodyMedium: TextStyle(
          fontSize: DesignSystem.textSm,
          fontWeight: DesignSystem.weightRegular,
          color: DesignSystem.neutral300,
          letterSpacing: -0.1,
          height: DesignSystem.lineHeightNormal,
        ),
      ),
    );
  }
}
