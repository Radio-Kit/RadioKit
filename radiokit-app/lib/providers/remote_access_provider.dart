import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/api_log_entry.dart';
import '../services/remote_access_service.dart'
    if (dart.library.html) '../services/remote_access_service_stub.dart';

import 'device_provider.dart';
import 'multi_device_provider.dart';
import 'ble_provider.dart';
import 'serial_provider.dart';
import 'history_provider.dart';
import 'settings_provider.dart';
import 'console_provider.dart';
import 'designs_provider.dart';
import 'cloud_identity_provider.dart';
import 'account_provider.dart';
import 'flasher_provider.dart';

class RemoteAccessProvider extends ChangeNotifier {
  final SettingsProvider _settingsProvider;
  final MultiDeviceProvider _multiDeviceProvider;
  /// Backward-compatible getter: returns the primary (focused or first connected) DeviceProvider.
  /// Used by RemoteAccessService which still expects a single DeviceProvider.
  if (_activeDevice == null) return;
  DeviceProvider? get _activeDevice => _activeDevice.primaryDevice;
  final BleProvider _bleProvider;
  final SerialProvider _serialProvider;
  final HistoryProvider _historyProvider;
  final ConsoleProvider _consoleProvider;
  final DesignsProvider _designsProvider;
  final CloudIdentityProvider _cloudIdentityProvider;
  final AccountProvider _accountProvider;
  final FlasherProvider _flasherProvider;

  RemoteAccessService? _service;
  bool _isRunning = false;
  String _lastError = '';
  String _localIp = '127.0.0.1';
  int _actualPort = 0;

  final List<ApiLogEntry> _logs = [];
  static const int _maxLogEntries = 500;

  /// Follow-mode navigation target. Consumed by [consumeFollowTarget].
  final ValueNotifier<String?> followNavigationTarget = ValueNotifier(null);
  final ValueNotifier<Color> glowColor = ValueNotifier(Colors.yellowAccent);

  /// Current route tracked by _FollowModeWrapper, exposed via /api/session/route.
  String _currentRoute = '';

  bool get isRunning => _isRunning;
  String get lastError => _lastError;
  String get localIp => _localIp;
  int get actualPort => _actualPort;
  String get actualUrl =>
      _isRunning ? 'http://$_localIp:$_actualPort' : '';
  List<ApiLogEntry> get logs => List.unmodifiable(_logs);
  String get currentRoute => _currentRoute;

  /// Called by _FollowModeWrapper whenever the route changes.
  void updateCurrentRoute(String route) {
    _currentRoute = route;
    notifyListeners();
  }

  RemoteAccessProvider({
    required SettingsProvider settingsProvider,
    required MultiDeviceProvider multiDeviceProvider,
    required BleProvider bleProvider,
    required SerialProvider serialProvider,
    required HistoryProvider historyProvider,
    required ConsoleProvider consoleProvider,
    required DesignsProvider designsProvider,
    required CloudIdentityProvider cloudIdentityProvider,
    required AccountProvider accountProvider,
    required FlasherProvider flasherProvider,
  })  : _settingsProvider = settingsProvider,
        _cloudIdentityProvider = cloudIdentityProvider,
        _accountProvider = accountProvider,
        _flasherProvider = flasherProvider,
        _multiDeviceProvider = multiDeviceProvider,        _bleProvider = bleProvider,
        _serialProvider = serialProvider,
        _historyProvider = historyProvider,
        _consoleProvider = consoleProvider,
        _designsProvider = designsProvider {
    if (kDebugMode) {
      start();
    }
  }

  Future<String?> start() async {
    if (_isRunning) return null;

    _service = RemoteAccessService(
      deviceProvider: _activeDevice,
      bleProvider: _bleProvider,
      serialProvider: _serialProvider,
      historyProvider: _historyProvider,
      settingsProvider: _settingsProvider,
      consoleProvider: _consoleProvider,
      designsProvider: _designsProvider,
      cloudIdentityProvider: _cloudIdentityProvider,
      accountProvider: _accountProvider,
      flasherProvider: _flasherProvider,
      onLog: _addLogEntry,
      onFollowEvent: _onFollowEvent,
      currentRouteGetter: () => _currentRoute,
    );

    final error = await _service!.start();
    if (error != null) {
      _lastError = error;
      _service = null;
      _isRunning = false;
      notifyListeners();
      return error;
    }

    _isRunning = true;
    _actualPort = _service!.actualPort;
    _localIp = _service!.localIp;
    _lastError = '';
    _addLogEntry(ApiLogEntry(
      timestamp: DateTime.now(),
      method: 'SRV',
      path: 'Remote access server started on $actualUrl',
      statusCode: 0,
      durationMs: 0,
    ));
    notifyListeners();
    return null;
  }

  Future<void> stop() async {
    if (!_isRunning) return;
    await _service?.stop();
    _service = null;
    _isRunning = false;
    _actualPort = 0;
    _addLogEntry(ApiLogEntry(
      timestamp: DateTime.now(),
      method: 'SRV',
      path: 'Remote access server stopped',
      statusCode: 0,
      durationMs: 0,
    ));
    notifyListeners();
  }

  Future<void> toggle() async {
    if (_isRunning) {
      await stop();
      await _settingsProvider.setEnableRemoteAccess(false);
    } else {
      final error = await start();
      if (error == null) {
        await _settingsProvider.setEnableRemoteAccess(true);
      }
    }
  }

  void clearLog() {
    _logs.clear();
    notifyListeners();
  }

  /// Read and clear the current follow target.
  String? consumeFollowTarget() {
    final target = followNavigationTarget.value;
    if (target != null) followNavigationTarget.value = null;
    return target;
  }

  void _addLogEntry(ApiLogEntry entry) {
    _logs.add(entry);
    if (_logs.length > _maxLogEntries) {
      _logs.removeAt(0);
    }
    notifyListeners();
  }

  void _onFollowEvent(String route) {
    followNavigationTarget.value = route;
    glowColor.value = const Color(0xFF4488FF);
    Future.delayed(const Duration(milliseconds: 500), () {
      glowColor.value = Colors.yellowAccent;
    });
  }

  @override
  void dispose() {
    followNavigationTarget.dispose();
    glowColor.dispose();
    stop();
    super.dispose();
  }
}
