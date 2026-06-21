import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/demo_fs_transport.dart';
import '../models/device_info.dart';
import 'device_provider.dart';
import 'console_provider.dart';
import 'theme_preset_provider.dart';
import 'history_provider.dart';
import '../services/transport_service.dart';
import '../services/debug_transport.dart';

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

  /// Entries as (mapKey, DeviceProvider) pairs. The mapKey is the original
  /// device ID passed to connectDevice, which may differ from
  /// dp.connectedDevice?.id after connection.
  List<(String, DeviceProvider)> get deviceEntries =>
      List.unmodifiable(_devices.entries.map((e) => (e.key, e.value)));

  /// Read-only view of all connected DeviceProviders.
  List<DeviceProvider> get devices => List.unmodifiable(_devices.values);

  /// The currently focused DeviceProvider (control screen), or null.
  DeviceProvider? get focusedDevice =>
      _focusedDeviceId != null ? getDevice(_focusedDeviceId!) : null;

  /// The currently focused device ID, or null.
  String? get focusedDeviceId => _focusedDeviceId;

  /// Number of connected/connecting devices.
  int get deviceCount => _devices.length;

  /// Whether any device is in the collection.
  bool get hasConnectedDevices => _devices.isNotEmpty;

  /// Whether any device is in the connected state.
  bool get anyConnected => _devices.values.any((dp) => dp.isConnected);

  /// Get the DeviceProvider for a specific device.
  DeviceProvider? getDevice(String deviceId) {
    final direct = _devices[deviceId];
    if (direct != null) return direct;
    for (final dp in _devices.values) {
      if (dp.connectedDevice?.id == deviceId) {
        return dp;
      }
    }
    return null;
  }

  /// Whether a specific device is connected.
  bool isDeviceConnected(String deviceId) {
    final dp = getDevice(deviceId);
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

    // Return existing provider if device is already connected/connecting
    DeviceProvider? existing;
    for (final entry in _devices.entries) {
      final key = entry.key;
      final dp = entry.value;
      final conn = dp.connectedDevice;

      // Match by map key or post-handshake UID
      if (key == deviceId || conn?.id == deviceId) {
        existing = dp;
        break;
      }

      // Match by BLE address
      if (device.bleAddress != null && device.bleAddress!.isNotEmpty) {
        if (conn?.bleAddress == device.bleAddress ||
            conn?.transportAddress == device.bleAddress ||
            key == device.bleAddress) {
          existing = dp;
          break;
        }
      }
      // Match by WiFi address
      if (device.wifiAddress != null && device.wifiAddress!.isNotEmpty) {
        if (conn?.wifiAddress == device.wifiAddress ||
            conn?.transportAddress == device.wifiAddress ||
            key == device.wifiAddress) {
          existing = dp;
          break;
        }
      }
      // Match by transportAddress
      if (device.transportAddress != null && device.transportAddress!.isNotEmpty) {
        if (conn?.transportAddress == device.transportAddress ||
            conn?.bleAddress == device.transportAddress ||
            conn?.wifiAddress == device.transportAddress ||
            key == device.transportAddress) {
          existing = dp;
          break;
        }
      }
    }

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

    deviceProvider.addListener(notifyListeners);
    deviceProvider.addListener(_onDeviceChange);
    _devices[deviceId] = deviceProvider;
    notifyListeners();

    try {
      // Start connection (async - state will settle via notifyListeners)
      await deviceProvider.connectToDevice(device, baudRate: baudRate);
    } catch (e) {
      // Connection failed - clean up the provider
      _devices.remove(deviceId);
      deviceProvider.removeListener(notifyListeners);
      deviceProvider.removeListener(_onDeviceChange);
      notifyListeners();
      return deviceProvider; // Return the provider so caller can check state
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

    deviceProvider.addListener(notifyListeners);
    deviceProvider.addListener(_onDeviceChange);
    _devices[deviceId] = deviceProvider;
    notifyListeners();

    // Load demo config (delegates to DeviceProvider.loadDemo)
    await deviceProvider.loadDemo(demoId);

    return deviceProvider;
  }

  Future<void> disconnectDevice(String deviceId) async {
    String? mapKey;
    if (_devices.containsKey(deviceId)) {
      mapKey = deviceId;
    } else {
      for (final entry in _devices.entries) {
        final conn = entry.value.connectedDevice;
        if (conn?.id == deviceId ||
            conn?.bleAddress == deviceId ||
            conn?.wifiAddress == deviceId ||
            conn?.transportAddress == deviceId) {
          mapKey = entry.key;
          break;
        }
      }
    }
    if (mapKey == null) return;
    final dp = _devices.remove(mapKey);
    if (dp == null) return;

    dp.removeListener(notifyListeners);
    dp.removeListener(_onDeviceChange);
    await dp.disconnect();
    dp.dispose();

    // Clear focus if the disconnected device was focused
    if (_focusedDeviceId == mapKey || _focusedDeviceId == deviceId) {
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
    _pruneDisconnectedDevices();
    notifyListeners();
  }

  /// Reconnect a device that was previously connected.
  Future<void> reconnectDevice(String deviceId) async {
    final dp = getDevice(deviceId);
    if (dp == null) return;

    final device = dp.connectedDevice;
    if (device == null) return;

    await dp.connectToDevice(device);
    notifyListeners();
  }

  void _onDeviceChange() {
    // Run in a microtask to avoid modifying during notification/build phase
    Future.microtask(() {
      final beforeCount = _devices.length;
      _pruneDisconnectedDevices();
      if (_devices.length != beforeCount) {
        notifyListeners();
      }
    });
  }

  void _pruneDisconnectedDevices() {
    final toPrune = <String>[];
    for (final entry in _devices.entries) {
      final key = entry.key;
      final dp = entry.value;
      final state = dp.connectionState;

      final isDisconnected = state == DeviceConnectionState.disconnected ||
                             state == DeviceConnectionState.error;

      final isFocused = _focusedDeviceId != null &&
          (key == _focusedDeviceId || dp.connectedDevice?.id == _focusedDeviceId);

      if (isDisconnected && !isFocused) {
        toPrune.add(key);
      }
    }

    for (final key in toPrune) {
      final dp = _devices.remove(key);
      if (dp != null) {
        dp.removeListener(notifyListeners);
        dp.removeListener(_onDeviceChange);
        dp.disconnect().then((_) {
          dp.dispose();
        }).catchError((_) {
          dp.dispose();
        });
      }
    }
  }

  @override
  void dispose() {
    for (final dp in _devices.values) {
      dp.removeListener(notifyListeners);
      dp.removeListener(_onDeviceChange);
      dp.dispose();
    }
    _devices.clear();
    super.dispose();
  }
}
