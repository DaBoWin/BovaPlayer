import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _localePrefsKey = 'app_locale';

/// 语言切换 Provider
class LocaleProvider with ChangeNotifier {
  Locale? _locale;
  static String? _currentLanguageCode;

  Locale? get locale => _locale;
  static String? get currentLanguageCode => _currentLanguageCode;

  static const supportedLocales = [
    Locale('en'),
    Locale('zh'),
  ];

  LocaleProvider() {
    _loadSavedLocale();
  }

  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_localePrefsKey);
    if (code != null) {
      _locale = Locale(code);
      _currentLanguageCode = code;
      notifyListeners();
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    _currentLanguageCode = locale.languageCode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localePrefsKey, locale.languageCode);
  }

  Future<void> clearLocale() async {
    _locale = null;
    _currentLanguageCode = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localePrefsKey);
  }
}
