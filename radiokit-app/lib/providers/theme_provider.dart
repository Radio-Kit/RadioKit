import 'package:flutter/material.dart';

/// Manages the application's theme mode (light, dark, or system).
class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;

  /// True when the effective theme is dark.
  ///
  /// When [themeMode] is [ThemeMode.system] we cannot know the system
  /// brightness here without a [BuildContext], so we use the last explicitly
  /// set mode and default to dark.
  bool get isDarkMode => _themeMode != ThemeMode.light;

  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      notifyListeners();
    }
  }

  /// Toggles between dark and light, always landing on an explicit mode
  /// (never [ThemeMode.system]) so [isDarkMode] stays accurate.
  void toggleTheme() {
    setThemeMode(isDarkMode ? ThemeMode.light : ThemeMode.dark);
  }
}
