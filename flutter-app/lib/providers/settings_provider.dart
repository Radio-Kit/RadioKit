import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages runtime application settings that cannot be configured via compile-time macros.
class SettingsProvider with ChangeNotifier {
  static const _storageKey = 'radiokit_settings';
  static const _defaultShowDemo = true;
  static const _defaultUseFullscreen = false;
  static const _defaultEnableDevTools = true;

  bool _showDemo = _defaultShowDemo;
  bool _useFullscreen = _defaultUseFullscreen;
  bool _enableDevTools = _defaultEnableDevTools;

  bool get showDemo => _showDemo;
  bool get useFullscreen => _useFullscreen;
  bool get enableDevTools => _enableDevTools;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> setShowDemo(bool value) async {
    if (_showDemo != value) {
      _showDemo = value;
      notifyListeners();
      await _persist();
    }
  }

  Future<void> setUseFullscreen(bool value) async {
    if (_useFullscreen != value) {
      _useFullscreen = value;
      notifyListeners();
      await _persist();
    }
  }

  Future<void> setEnableDevTools(bool value) async {
    if (_enableDevTools != value) {
      _enableDevTools = value;
      notifyListeners();
      await _persist();
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_storageKey);
      if (data != null) {
        final decoded = Map<String, dynamic>.from(jsonDecode(data));
        _showDemo = decoded['showDemo'] ?? _defaultShowDemo;
        _useFullscreen = decoded['useFullscreen'] ?? _defaultUseFullscreen;
        _enableDevTools = decoded['enableDevTools'] ?? _defaultEnableDevTools;
      }
    } catch (e) {
      debugPrint('RadioKit: Failed to load settings: $e');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode({
        'showDemo': _showDemo,
        'useFullscreen': _useFullscreen,
        'enableDevTools': _enableDevTools,
      });
      await prefs.setString(_storageKey, data);
    } catch (e) {
      debugPrint('RadioKit: Failed to persist settings: $e');
    }
  }
}