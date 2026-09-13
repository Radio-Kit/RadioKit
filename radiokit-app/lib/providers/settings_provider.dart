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

  bool _hasSeenModelsTour = false;
  bool _hasSeenFlasherTour = false;
  bool _hasSeenDesignerTour = false;

  bool get useFullscreen => _useFullscreen;
  bool get enableRemoteAccess => _enableRemoteAccess;
  bool get followRemoteAccess => _followRemoteAccess;
  bool get overrideTheme => _overrideTheme;

  bool get hasSeenModelsTour => _hasSeenModelsTour;
  bool get hasSeenFlasherTour => _hasSeenFlasherTour;
  bool get hasSeenDesignerTour => _hasSeenDesignerTour;

  SettingsProvider() {
    _loadSettings();
  }

  bool hasSeenTour(String tourId) {
    switch (tourId) {
      case 'models':
        return _hasSeenModelsTour;
      case 'flasher':
        return _hasSeenFlasherTour;
      case 'designer':
        return _hasSeenDesignerTour;
      default:
        return false;
    }
  }

  Future<void> markTourSeen(String tourId) async {
    bool changed = false;
    if (tourId == 'models' && !_hasSeenModelsTour) {
      _hasSeenModelsTour = true;
      changed = true;
    } else if (tourId == 'flasher' && !_hasSeenFlasherTour) {
      _hasSeenFlasherTour = true;
      changed = true;
    } else if (tourId == 'designer' && !_hasSeenDesignerTour) {
      _hasSeenDesignerTour = true;
      changed = true;
    }
    if (changed) {
      notifyListeners();
      await _persist();
    }
  }

  Future<void> resetHelpGuides() async {
    _hasSeenModelsTour = false;
    _hasSeenFlasherTour = false;
    _hasSeenDesignerTour = false;
    notifyListeners();
    await _persist();
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
        _hasSeenModelsTour = decoded['hasSeenModelsTour'] ?? false;
        _hasSeenFlasherTour = decoded['hasSeenFlasherTour'] ?? false;
        _hasSeenDesignerTour = decoded['hasSeenDesignerTour'] ?? false;
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
        'hasSeenModelsTour': _hasSeenModelsTour,
        'hasSeenFlasherTour': _hasSeenFlasherTour,
        'hasSeenDesignerTour': _hasSeenDesignerTour,
      });
      await prefs.setString(_storageKey, data);
    } catch (e) {
      debugPrint('RadioKit: Failed to persist settings: $e');
    }
  }
}