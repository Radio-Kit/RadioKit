import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages runtime application settings that cannot be configured via compile-time macros.
class SettingsProvider with ChangeNotifier {
  static const _storageKey = 'radiokit_settings';
  static const _defaultShowDemo = true;
  static const _defaultUseFullscreen = false;
  static const _defaultEnableDevTools = true;
  static const _defaultInterfaceScale = 100;
  static const _defaultEnableRemoteAccess = false;
  static const _defaultFollowRemoteAccess = false;

  bool _showDemo = _defaultShowDemo;
  bool _useFullscreen = _defaultUseFullscreen;
  bool _enableDevTools = _defaultEnableDevTools;
  int _interfaceScale = _defaultInterfaceScale;
  bool _enableRemoteAccess = _defaultEnableRemoteAccess;
  bool _followRemoteAccess = _defaultFollowRemoteAccess;

  bool get showDemo => _showDemo;
  bool get useFullscreen => _useFullscreen;
  bool get enableDevTools => _enableDevTools;
  int get interfaceScale => _interfaceScale;
  bool get enableRemoteAccess => _enableRemoteAccess;
  bool get followRemoteAccess => _followRemoteAccess;

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

  Future<void> setInterfaceScale(int value) async {
    final clamped = value.clamp(50, 200);
    if (_interfaceScale != clamped) {
      _interfaceScale = clamped;
      notifyListeners();
      await _persist();
    }
  }

  Future<void> setEnableRemoteAccess(bool value) async {
    if (_enableRemoteAccess != value) {
      _enableRemoteAccess = value;
      notifyListeners();
      await _persist();
    }
  }

  Future<void> setFollowRemoteAccess(bool value) async {
    if (_followRemoteAccess != value) {
      _followRemoteAccess = value;
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
        _interfaceScale = decoded['interfaceScale'] ?? _defaultInterfaceScale;
        _enableRemoteAccess = decoded['enableRemoteAccess'] ?? _defaultEnableRemoteAccess;
        _followRemoteAccess = decoded['followRemoteAccess'] ?? _defaultFollowRemoteAccess;
      }
      notifyListeners();
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
        'interfaceScale': _interfaceScale,
        'enableRemoteAccess': _enableRemoteAccess,
        'followRemoteAccess': _followRemoteAccess,
      });
      await prefs.setString(_storageKey, data);
    } catch (e) {
      debugPrint('RadioKit: Failed to persist settings: $e');
    }
  }
}