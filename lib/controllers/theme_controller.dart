import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_constants.dart';

/// ThemeController manages the app's theme mode (light / dark / system).
/// Persists the user's choice in SharedPreferences so it survives restarts.
class ThemeController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  bool get isDark => _themeMode == ThemeMode.dark;

  /// Load persisted theme preference on startup.
  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved  = prefs.getString(AppConstants.prefThemeMode);
    if (saved == 'dark') {
      _themeMode = ThemeMode.dark;
    } else if (saved == 'light') {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  /// Toggle between light and dark. If currently system, resolve first.
  Future<void> toggleTheme(BuildContext context) async {
    final currentlyDark = _resolveIsDark(context);
    await setTheme(currentlyDark ? ThemeMode.light : ThemeMode.dark);
  }

  /// Explicitly set a theme mode.
  Future<void> setTheme(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final value = mode == ThemeMode.dark
        ? 'dark'
        : mode == ThemeMode.light
            ? 'light'
            : 'system';
    await prefs.setString(AppConstants.prefThemeMode, value);
  }

  /// Returns true if the resolved theme (accounting for system) is dark.
  bool _resolveIsDark(BuildContext context) {
    if (_themeMode == ThemeMode.system) {
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  /// Resolved isDark helper available to widgets.
  bool resolveIsDark(BuildContext context) => _resolveIsDark(context);
}
