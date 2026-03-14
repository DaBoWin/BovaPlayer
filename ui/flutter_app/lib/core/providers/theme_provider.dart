import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _themePrefsKey = 'app_theme_mode';

/// 应用主题模式
enum AppThemeMode {
  light,
  dark,
  cyberpunk,
  sweetiePro,
}

/// 主题切换 Provider
class ThemeProvider with ChangeNotifier {
  AppThemeMode _themeMode = AppThemeMode.light;

  AppThemeMode get themeMode => _themeMode;

  static bool isProTheme(AppThemeMode mode) =>
      mode == AppThemeMode.cyberpunk || mode == AppThemeMode.sweetiePro;

  bool get isDark =>
      _themeMode == AppThemeMode.dark ||
      _themeMode == AppThemeMode.cyberpunk;

  ThemeProvider() {
    _loadSavedTheme();
  }

  Future<void> _loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_themePrefsKey);
    if (saved != null) {
      _themeMode = AppThemeMode.values.firstWhere(
        (e) => e.name == saved,
        orElse: () => AppThemeMode.light,
      );
      notifyListeners();
    }
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePrefsKey, mode.name);
  }

  Future<void> ensureThemeAccess({
    required bool hasProAccess,
    AppThemeMode fallbackMode = AppThemeMode.light,
  }) async {
    if (hasProAccess || !isProTheme(_themeMode)) return;
    await setThemeMode(fallbackMode);
  }
}
