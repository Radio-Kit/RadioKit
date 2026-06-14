import 'package:flutter/material.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The UI-facing provider that manages the active RKTokens preset.
class ThemePresetProvider extends ChangeNotifier {
  static const String _prefsKey = 'active_theme';

  String _activePreset = RKTokens.defaultPreset;
  RKTokens _tokens = RKTokens.dragon;

  ThemePresetProvider();

  /// Initialize from persisted preference.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved != null && RKTokens.presetsByName.containsKey(saved)) {
        _activePreset = saved;
        _tokens = RKTokens.presetsByName[saved]!;
      }
    } catch (_) {}
    notifyListeners();
  }

  /// The currently active RKTokens.
  RKTokens get tokens => _tokens;

  /// The currently active preset name.
  String get themeName => _activePreset;

  /// Available preset names.
  List<String> get availableThemes => RKTokens.presetsByName.keys.toList();

  /// Switches the active theme preset.
  Future<void> setTheme(String presetName) async {
    if (!RKTokens.presetsByName.containsKey(presetName)) return;
    _activePreset = presetName;
    _tokens = RKTokens.presetsByName[presetName]!;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, presetName);
    } catch (_) {}
  }
}
