import 'package:flutter/material.dart';
import 'theme_factory.dart';

enum AppThemeType {
  light,
  dark,
  amoled,
  blue,
  green,
  purple,
  orange,
}

class ThemeConfig {
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color primaryColorDark = Color(0xFF1976D2);
  static const Color accentColor = Color(0xFF03DAC6);

  static const Map<AppThemeType, String> themeNames = {
    AppThemeType.light: 'Light',
    AppThemeType.dark: 'Dark',
    AppThemeType.amoled: 'AMOLED',
    AppThemeType.blue: 'Ocean Blue',
    AppThemeType.green: 'Forest Green',
    AppThemeType.purple: 'Royal Purple',
    AppThemeType.orange: 'Sunset Orange',
  };

  static ThemeData getTheme(AppThemeType themeType) {
    switch (themeType) {
      case AppThemeType.light:
        return lightTheme;
      case AppThemeType.dark:
        return darkTheme;
      case AppThemeType.amoled:
        return amoledTheme;
      case AppThemeType.blue:
        return blueTheme;
      case AppThemeType.green:
        return greenTheme;
      case AppThemeType.purple:
        return purpleTheme;
      case AppThemeType.orange:
        return orangeTheme;
    }
  }

  // Light Theme
  static ThemeData get lightTheme {
    final colorScheme = ThemeFactory.createColorScheme(
      seedColor: primaryColor,
      brightness: Brightness.light,
      background: Colors.white,
      surface: Colors.white,
    );

    return ThemeFactory.createTheme(
      colorScheme: colorScheme,
      brightness: Brightness.light,
      options: const ThemeOptions(
        borderRadius: 8.0,
        elevation: 0.0,
        useMaterial3: true,
        cardElevation: 2.0,
      ),
    );
  }

  // Dark Theme
  static ThemeData get darkTheme {
    final colorScheme = ThemeFactory.createColorScheme(
      seedColor: primaryColor,
      brightness: Brightness.dark,
      background: const Color(0xFF121212),
      surface: const Color(0xFF1F1F1F),
    );

    return ThemeFactory.createTheme(
      colorScheme: colorScheme,
      brightness: Brightness.dark,
      options: const ThemeOptions(
        borderRadius: 8.0,
        elevation: 0.0,
        useMaterial3: true,
        cardElevation: 2.0,
      ),
    );
  }

  // AMOLED Theme (Pure Black)
  static ThemeData get amoledTheme {
    final colorScheme = ThemeFactory.createColorScheme(
      seedColor: primaryColor,
      brightness: Brightness.dark,
      background: Colors.black,
      surface: const Color(0xFF0A0A0A),
    );

    return ThemeFactory.createTheme(
      colorScheme: colorScheme,
      brightness: Brightness.dark,
      options: const ThemeOptions(
        borderRadius: 8.0,
        elevation: 0.0,
        useMaterial3: true,
        cardElevation: 2.0,
      ),
    );
  }

  // Blue Theme
  static ThemeData get blueTheme {
    const blueColor = Color(0xFF0D47A1);
    final colorScheme = ThemeFactory.createColorScheme(
      seedColor: blueColor,
      brightness: Brightness.light,
      background: const Color(0xFFF3F8FF),
      surface: Colors.white,
    );

    return ThemeFactory.createTheme(
      colorScheme: colorScheme,
      brightness: Brightness.light,
      options: const ThemeOptions(
        borderRadius: 8.0,
        elevation: 0.0,
        useMaterial3: true,
        cardElevation: 2.0,
      ),
    );
  }

  // Green Theme
  static ThemeData get greenTheme {
    const greenColor = Color(0xFF2E7D32);
    final colorScheme = ThemeFactory.createColorScheme(
      seedColor: greenColor,
      brightness: Brightness.light,
      background: const Color(0xFFF1F8E9),
      surface: Colors.white,
    );

    return ThemeFactory.createTheme(
      colorScheme: colorScheme,
      brightness: Brightness.light,
      options: const ThemeOptions(
        borderRadius: 8.0,
        elevation: 0.0,
        useMaterial3: true,
        cardElevation: 2.0,
      ),
    );
  }

  // Purple Theme
  static ThemeData get purpleTheme {
    const purpleColor = Color(0xFF6A1B9A);
    final colorScheme = ThemeFactory.createColorScheme(
      seedColor: purpleColor,
      brightness: Brightness.light,
      background: const Color(0xFFF3E5F5),
      surface: Colors.white,
    );

    return ThemeFactory.createTheme(
      colorScheme: colorScheme,
      brightness: Brightness.light,
      options: const ThemeOptions(
        borderRadius: 8.0,
        elevation: 0.0,
        useMaterial3: true,
        cardElevation: 2.0,
      ),
    );
  }

  // Orange Theme
  static ThemeData get orangeTheme {
    const orangeColor = Color(0xFFE65100);
    final colorScheme = ThemeFactory.createColorScheme(
      seedColor: orangeColor,
      brightness: Brightness.light,
      background: const Color(0xFFFFF3E0),
      surface: Colors.white,
    );

    return ThemeFactory.createTheme(
      colorScheme: colorScheme,
      brightness: Brightness.light,
      options: const ThemeOptions(
        borderRadius: 8.0,
        elevation: 0.0,
        useMaterial3: true,
        cardElevation: 2.0,
      ),
    );
  }
}
