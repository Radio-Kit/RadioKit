import 'package:flutter/material.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Maps preset names to RKTokens instances.
const Map<String, RKTokens> kTokenPresets = {
  'dragon': RKTokens.dragon,
  'minimal': RKTokens.minimal,
  'retro': RKTokens.retro,
  'rose': RKTokens.rose,
  'debug': RKTokens.debug,
};

/// The UI-facing provider that manages the active RKTokens preset.
class ThemePresetProvider extends ChangeNotifier {
  static const String _prefsKey = 'active_theme';

  String _activePreset = 'dragon';
  RKTokens _tokens = RKTokens.dragon;

  ThemePresetProvider();

  /// Initialize from persisted preference.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved != null && kTokenPresets.containsKey(saved)) {
        _activePreset = saved;
        _tokens = kTokenPresets[saved]!;
      } else if (saved == 'debug') {
        // Fallback if they were on the debug skin (not in picker)
        _activePreset = 'dragon';
        _tokens = RKTokens.dragon;
      } else if (saved == 'rambros') {
        // Legacy alias — rambros is now dragon
        _activePreset = 'dragon';
        _tokens = RKTokens.dragon;
      }
    } catch (_) {}
    notifyListeners();
  }

  /// The currently active RKTokens.
  RKTokens get tokens => _tokens;

  /// The currently active preset name.
  String get themeName => _activePreset;

  /// Available preset names.
  List<String> get availableThemes => kTokenPresets.keys.toList();

  /// Switches the active theme preset.
  Future<void> setTheme(String presetName) async {
    if (!kTokenPresets.containsKey(presetName)) return;
    _activePreset = presetName;
    _tokens = kTokenPresets[presetName]!;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, presetName);
    } catch (_) {}
  }
}
