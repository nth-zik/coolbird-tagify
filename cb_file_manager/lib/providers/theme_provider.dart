import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/theme_config.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'app_theme';

  AppThemeType _currentTheme = AppThemeType.light;

  AppThemeType get currentTheme => _currentTheme;
  ThemeData get themeData => ThemeConfig.getTheme(_currentTheme);

  // For backward compatibility
  ThemeMode get themeMode {
    switch (_currentTheme) {
      case AppThemeType.light:
      case AppThemeType.blue:
      case AppThemeType.green:
      case AppThemeType.purple:
      case AppThemeType.orange:
        return ThemeMode.light;
      case AppThemeType.dark:
      case AppThemeType.amoled:
        return ThemeMode.dark;
    }
  }

  bool get isDarkMode => themeMode == ThemeMode.dark;

  ThemeData get lightTheme => ThemeConfig.lightTheme;
  ThemeData get darkTheme => ThemeConfig.darkTheme;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeString = prefs.getString(_themeKey) ?? 'light';

    try {
      _currentTheme = AppThemeType.values.firstWhere(
        (theme) => theme.name == themeString,
        orElse: () => AppThemeType.light,
      );
    } catch (e) {
      _currentTheme = AppThemeType.light;
    }

    notifyListeners();
  }

  Future<void> setTheme(AppThemeType theme) async {
    _currentTheme = theme;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, theme.name);
  }

  // Legacy method for backward compatibility
  Future<void> setThemeMode(ThemeMode themeMode) async {
    switch (themeMode) {
      case ThemeMode.light:
        await setTheme(AppThemeType.light);
        break;
      case ThemeMode.dark:
        await setTheme(AppThemeType.dark);
        break;
      case ThemeMode.system:
        await setTheme(AppThemeType.light);
        break;
    }
  }

  Future<void> toggleTheme() async {
    if (_currentTheme == AppThemeType.light) {
      await setTheme(AppThemeType.dark);
    } else {
      await setTheme(AppThemeType.light);
    }
  }
}
