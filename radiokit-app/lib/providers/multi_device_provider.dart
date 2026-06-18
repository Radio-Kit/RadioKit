import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/demo_fs_transport.dart';
import '../models/device_info.dart';
import 'device_provider.dart';
import 'console_provider.dart';
import 'theme_preset_provider.dart';
import 'history_provider.dart';
import '../services/transport_service.dart';

/// Manages a collection of [DeviceProvider] instances for simultaneous
/// connections to multiple RadioKit devices.
///
/// Each connected device gets its own [DeviceProvider] with its own transport,
/// widget state, auth, FS, and console log. The "focused" device is the one
/// whose control screen is currently active.
class MultiDeviceProvider extends ChangeNotifier {
  /// Map of deviceId -> DeviceProvider for all connected/connecting devices.
  final Map<String, DeviceProvider> _devices = {};

  /// The "focused" device ID - the device whose control screen is currently
  /// active. Null when on models tab or no device is focused.
  String? _focusedDeviceId;

  /// Shared providers injected into each DeviceProvider instance.
  final DebugLogSink? _debugSink;
  final ThemePresetProvider? _themePresetProvider;
  final HistoryProvider? _historyProvider;

  MultiDeviceProvider({
    DebugLogSink? debugSink,
    ThemePresetProvider? themePresetProvider,
    HistoryProvider? historyProvider,
  })  : _debugSink = debugSink,
        _themePresetProvider = themePresetProvider,
        _historyProvider = historyProvider;

  // -- Getters ---------------------------------------------------------------

  /// Read-only view of all connected device IDs.
  List<String> get deviceIds => List.unmodifiable(_devices.keys);

  /// Read-only view of all connected DeviceProviders.
  List<DeviceProvider> get devices => List.unmodifiable(_devices.values);

  /// The currently focused DeviceProvider (control screen), or null.
  DeviceProvider? get focusedDevice =>
      _focusedDeviceId != null ? _devices[_focusedDeviceId] : null;

  /// The currently focused device ID, or null.
  String? get focusedDeviceId => _focusedDeviceId;

  /// Number of connected/connecting devices.
  int get deviceCount => _devices.length;

  /// Whether any device is in the collection.
  bool get hasConnectedDevices => _devices.isNotEmpty;

  /// Whether any device is in the connected state.
  bool get anyConnected => _devices.values.any((dp) => dp.isConnected);

  /// Get the DeviceProvider for a specific device.
  DeviceProvider? getDevice(String deviceId) => _devices[deviceId];

  /// Whether a specific device is connected.
  bool isDeviceConnected(String deviceId) {
    final dp = _devices[deviceId];
    return dp != null && dp.isConnected;
  }

  // -- Convenience: backward-compatible single-device access -----------------

  /// The "primary" device - the focused device, or the first connected device.
  /// Used for backward compatibility during migration.
  DeviceProvider? get primaryDevice {
    if (_focusedDeviceId != null) {
      final focused = _devices[_focusedDeviceId];
      if (focused != null) return focused;
    }
    for (final dp in _devices.values) {
      if (dp.isConnected) return dp;
    }
    return null;
  }

  /// Whether the primary device is connected.
  bool get isPrimaryConnected => primaryDevice?.isConnected ?? false;

  // -- Lifecycle -------------------------------------------------------------

  /// Connect to a new device. Creates a new [DeviceProvider] with its own
  /// transport. Returns the created provider.
  ///
  /// If a device with the same [DeviceInfo.id] is already connected, the
  /// existing provider is returned without creating a duplicate.
  Future<DeviceProvider> connectDevice({
    required DeviceInfo device,
    required TransportService transport,
    int baudRate = 115200,
    ConsoleProvider? console,
  }) async {
    final deviceId = device.id;

    // Return existing provider if device is already connected
    final existing = _devices[deviceId];
    if (existing != null) {
      return existing;
    }

    // Create a per-device console if not provided
    final deviceConsole = console ?? ConsoleProvider();

    // Create a new DeviceProvider for this device
    final deviceProvider = DeviceProvider(
      transport: transport,
      debugSink: _debugSink,
      console: deviceConsole,
      themePresetProvider: _themePresetProvider,
      historyProvider: _historyProvider,
    );

    _devices[deviceId] = deviceProvider;
    notifyListeners();

    try {
      // Start connection (async - state will settle via notifyListeners)
      await deviceProvider.connectToDevice(device, baudRate: baudRate);
    } catch (e) {
      // Connection threw - clean up
      _devices.remove(deviceId);
      notifyListeners();
      rethrow;
    }

    return deviceProvider;
  }

  /// Connect to a demo device by loading its config from assets.
  /// Creates a [DeviceProvider] with a [DemoFsTransport] and loads
  /// the demo JSON config from assets/demos/{demoId}.json.
  Future<DeviceProvider> connectDemo(String demoId) async {
    final deviceId = 'DEMO_$demoId';

    // Return existing provider if demo is already connected
    final existing = _devices[deviceId];
    if (existing != null) {
      return existing;
    }

    final deviceConsole = ConsoleProvider();
    final deviceProvider = DeviceProvider(
      transport: DemoFsTransport(), // Placeholder; loadDemo will set up the real transport
      debugSink: _debugSink,
      console: deviceConsole,
      themePresetProvider: _themePresetProvider,
      historyProvider: _historyProvider,
    );

    _devices[deviceId] = deviceProvider;
    notifyListeners();

    // Load demo config (delegates to DeviceProvider.loadDemo)
    await deviceProvider.loadDemo(demoId);

    return deviceProvider;
  }

  /// Disconnect a specific device by ID. Cleans up its transport and
  /// removes its DeviceProvider from the collection.
  Future<void> disconnectDevice(String deviceId) async {
    final dp = _devices.remove(deviceId);
    if (dp == null) return;

    await dp.disconnect();
    dp.dispose();

    // Clear focus if the disconnected device was focused
    if (_focusedDeviceId == deviceId) {
      _focusedDeviceId = null;
    }

    notifyListeners();
  }

  /// Disconnect all devices.
  Future<void> disconnectAll() async {
    final ids = List<String>.from(_devices.keys);
    for (final id in ids) {
      await disconnectDevice(id);
    }
  }

  /// Set the focused device (when navigating to its control screen).
  /// Pass null when leaving the control screen.
  void setFocusedDevice(String? deviceId) {
    if (_focusedDeviceId == deviceId) return;
    _focusedDeviceId = deviceId;
    notifyListeners();
  }

  /// Reconnect a device that was previously connected.
  Future<void> reconnectDevice(String deviceId) async {
    final dp = _devices[deviceId];
    if (dp == null) return;

    final device = dp.connectedDevice;
    if (device == null) return;

    await dp.connectToDevice(device);
    notifyListeners();
  }

  @override
  void dispose() {
    for (final dp in _devices.values) {
      dp.dispose();
    }
    _devices.clear();
    super.dispose();
  }
}
