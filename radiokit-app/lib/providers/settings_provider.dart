import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages runtime application settings that cannot be configured via compile-time macros.
class SettingsProvider with ChangeNotifier {
  static const _storageKey = 'radiokit_settings';
  static const _defaultUseFullscreen = true;
  static const _defaultEnableRemoteAccess = false;
  static const _defaultFollowRemoteAccess = false;
  static const _defaultOverrideTheme = false;

  bool _useFullscreen = _defaultUseFullscreen;
  bool _enableRemoteAccess = _defaultEnableRemoteAccess;
  bool _followRemoteAccess = _defaultFollowRemoteAccess;
  bool _overrideTheme = _defaultOverrideTheme;

  bool get useFullscreen => _useFullscreen;
  bool get enableRemoteAccess => _enableRemoteAccess;
  bool get followRemoteAccess => _followRemoteAccess;
  bool get overrideTheme => _overrideTheme;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> setUseFullscreen(bool value) async {
    if (_useFullscreen != value) {
      _useFullscreen = value;
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

  Future<void> setOverrideTheme(bool value) async {
    if (_overrideTheme != value) {
      _overrideTheme = value;
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
        _useFullscreen = decoded['useFullscreen'] ?? _defaultUseFullscreen;
        _enableRemoteAccess = decoded['enableRemoteAccess'] ?? _defaultEnableRemoteAccess;
        _followRemoteAccess = decoded['followRemoteAccess'] ?? _defaultFollowRemoteAccess;
        _overrideTheme = decoded['overrideTheme'] ?? _defaultOverrideTheme;
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
        'useFullscreen': _useFullscreen,
        'enableRemoteAccess': _enableRemoteAccess,
        'followRemoteAccess': _followRemoteAccess,
        'overrideTheme': _overrideTheme,
      });
      await prefs.setString(_storageKey, data);
    } catch (e) {
      debugPrint('RadioKit: Failed to persist settings: $e');
    }
  }
}