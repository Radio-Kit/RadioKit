import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, File;
import 'package:universal_ble/universal_ble.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/protocol.dart';
import '../models/device_info.dart';
import 'protocol_service.dart';
import 'transport_service.dart';
import 'ota_protocol_service.dart';

// Conditionally import JS bridge for Web Mock
import 'ble_js_bridge_stub.dart' if (dart.library.js) 'ble_js_bridge_web.dart';

/// Unified BLE service using universal_ble.
///
/// Three dedicated BLE characteristics prevent notification interleaving:
///   0xFFE1 — Widget protocol (0x55 frames)
///   0xFFE2 — Filesystem protocol (0xAA frames)
///   0xFFE3 — OTA protocol (0xBB frames)
///
/// Each characteristic has its own receive buffer, so one protocol's
/// notifications can never corrupt another's data stream on the phone side.
class BleService implements TransportService {
  BleService() {
    if (_dbusAvailable() || !Platform.isLinux) {
      _setupListeners();
    } else {
      _log('D-Bus system bus not available — BLE disabled');
      _bleOperational = false;
    }
    setupBleJsBridge(this);
  }

  bool _bleOperational = true;

  static bool _dbusAvailable() {
    try {
      return File('/var/run/dbus/system_bus_socket').existsSync();
    } catch (_) {
      return false;
    }
  }

  @override
  PacketReceivedCallback? onPacketReceived;
  @override
  FsPacketReceivedCallback? onFsPacketReceived;
  @override
  OtaPacketReceivedCallback? onOtaPacketReceived;
  @override
  SettingsPacketReceivedCallback? onSettingsPacketReceived;
  @override
  ConnectionLostCallback? onConnectionLost;

  final _logController = StreamController<String>.broadcast();
  @override
  Stream<String> get logStream => _logController.stream;

  void _log(String msg) {
    debugPrint('BLE_SERVICE: $msg');
    _logController.add(msg);
  }

  String? _connectedDeviceId;
  bool _isMockConnected = false;

  // Per-protocol receive buffers — separate buffers prevent interleaving
  final List<int> _receiveBuffer = [];        // Widget (0x55)
  final List<int> _receiveFsBuffer = [];      // FS (0xAA)
  final List<int> _receiveOtaBuffer = [];     // OTA (0xBB)
  final List<int> _receiveSettingsBuffer = []; // Settings (0xDD)

  // Discovered characteristic UUIDs (actual, from BLE discovery)
  String? _charWidgetId;
  String? _charFsId;
  String? _charOtaId;
  String? _charSettingsId;

  /// Negotiated BLE MTU (default 23). Updated after MTU exchange completes.
  /// Used by [writePacket] to fragment large payloads into MTU-sized chunks.
  int _mtu = 23;

  StreamController<DeviceInfo>? _scanController;
  final _availabilityController = StreamController<AvailabilityState>.broadcast();
  Stream<AvailabilityState> get availabilityStream => _availabilityController.stream;

  @override
  bool get isConnected => _isMockConnected || _connectedDeviceId != null;

  String? get connectedDeviceId =>
      _isMockConnected ? 'MOCK-UUID-1234' : _connectedDeviceId;

  /// Returns true if BLE is supported on this platform.
  bool get isSupported => true;

  /// Returns true if Bluetooth is available/enabled.
  Future<bool> get isAvailable async {
    if (!_bleOperational) return false;
    try {
      final state = await UniversalBle.getBluetoothAvailabilityState();
      return state == AvailabilityState.poweredOn;
    } catch (e) {
      _log('isAvailable failed: $e');
      return false;
    }
  }

  /// Returns true if Location Services are enabled (required for Android < 12).
  Future<bool> get isLocationServiceEnabled async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt < 31) {
        return await Geolocator.isLocationServiceEnabled();
      }
      return true;
    }
    return true;
  }

  /// Returns the current Bluetooth availability state.
  Future<AvailabilityState> getAvailability() async {
    if (!_bleOperational) return AvailabilityState.unsupported;
    try {
      return await UniversalBle.getBluetoothAvailabilityState();
    } catch (e) {
      _log('getAvailability failed: $e');
      return AvailabilityState.unsupported;
    }
  }

  /// Requests necessary Bluetooth permissions.
  Future<void> requestPermissions() async {
    try {
      debugPrint('BLE_SERVICE: Requesting permissions...');
      await UniversalBle.requestPermissions(
        withAndroidFineLocation: true,
      );
      debugPrint('BLE_SERVICE: Permissions request completed.');
    } catch (e) {
      debugPrint('BLE_SERVICE: Error requesting BLE permissions: $e');
    }
  }

  /// Prompts user to enable Bluetooth (Android only).
  Future<void> enableBluetooth() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await UniversalBle.enableBluetooth();
      } catch (e) {
        debugPrint('Error enabling Bluetooth: $e');
      }
    }
  }

  /// Prompts user to enable Location Services (Android only).
  Future<void> enableLocationServices() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await Geolocator.openLocationSettings();
      } catch (e) {
        debugPrint('Error opening location settings: $e');
      }
    }
  }

  void _setupListeners() {
    UniversalBle.onAvailabilityChange = (state) {
      _availabilityController.add(state);
    };

    UniversalBle.onConnectionChange = (String deviceId, bool isConnected, String? error) {
      if (deviceId == _connectedDeviceId && !isConnected) {
        _handleDisconnect(error ?? 'Connection lost');
      }
    };

    // Per-characteristic notification handler — routes to the correct buffer.
    UniversalBle.onValueChange = (String deviceId, String characteristicId, Uint8List value, int? timestamp) {
      if (deviceId != _connectedDeviceId) return;

      final charId = characteristicId.toLowerCase();

      // Verbose hex logging for debugging
      _log('RAW MCU from $characteristicId: ${value.map((b) => b.toRadixString(16).padLeft(2, "0")).join(" ")}');

      // Determine which protocol this characteristic belongs to
      if (_charSettingsId != null && charId == _charSettingsId!.toLowerCase()) {
        _receiveSettingsBuffer.addAll(value);
        _processSettingsBuffer();
      } else if (_charFsId != null && charId == _charFsId!.toLowerCase()) {
        _receiveFsBuffer.addAll(value);
        _processFsBuffer();
      } else if (_charOtaId != null && charId == _charOtaId!.toLowerCase()) {
        _receiveOtaBuffer.addAll(value);
        _processOtaBuffer();
      } else if (_charWidgetId != null && charId == _charWidgetId!.toLowerCase()) {
        _receiveBuffer.addAll(value);
        _processWidgetBuffer();
      } else {
        // Unknown characteristic — try widget as fallback
        _log('Unknown char $characteristicId, routing to widget buffer');
        _receiveBuffer.addAll(value);
        _processWidgetBuffer();
      }
    };
  }

  // ---------------------------------------------------------------------------
  // Scanning
  // ---------------------------------------------------------------------------

  Stream<DeviceInfo> startScan() {
    debugPrint('BLE_SERVICE: startScan() called');
    _scanController?.close();
    final controller = StreamController<DeviceInfo>.broadcast();
    _scanController = controller;
    final seen = <String>{};

    UniversalBle.onScanResult = (BleDevice result) {
      final id = result.deviceId;
      final rawName = result.name ?? '';

      if (!rawName.startsWith('RK_')) return;

      if (!seen.contains(id)) {
        seen.add(id);
        final displayName = rawName.substring(3);
        debugPrint('BLE_SERVICE: Found RadioKit device: $displayName ($id)');
        final info = DeviceInfo(
          id: id,
          name: displayName,
          rssi: result.rssi ?? -100,
        );
        if (!controller.isClosed) {
          controller.add(info);
        }
      }
    };

    UniversalBle.startScan(
      scanFilter: ScanFilter(),
    ).then((_) {
      debugPrint('BLE_SERVICE: UniversalBle.startScan success');
    }).catchError((error) {
      debugPrint('BLE_SERVICE: UniversalBle.startScan ERROR: $error');
      if (!controller.isClosed) {
        controller.addError(error);
      }
    });

    return controller.stream;
  }

  Future<void> stopScan() async {
    UniversalBle.onScanResult = null;
    await UniversalBle.stopScan();
    await _scanController?.close();
    _scanController = null;
  }

  // ---------------------------------------------------------------------------
  // Connection
  // ---------------------------------------------------------------------------

  @override
  Future<void> connect(String deviceId, {int baudRate = 1000000}) async {
    if (deviceId == 'MOCK-UUID-1234') {
      _isMockConnected = true;
      return;
    }

    try {
      _log('Connecting to $deviceId...');
      await UniversalBle.connect(deviceId);
      _connectedDeviceId = deviceId;

      // Request large MTU
      try {
        _log('Requesting MTU of 512...');
        final negotiated = await UniversalBle.requestMtu(deviceId, 512);
        _log('MTU requestMtu returned: $negotiated');
        _mtu = (negotiated - 3).clamp(23, 600);
        _log('Using effective MTU: $_mtu (max BLE write payload: ${_mtu - 3})');
      } catch (e) {
        _log('MTU request failed, using default 23: $e');
        _mtu = 23;
      }

      // Discover services — find all three characteristics
      _log('Discovering services...');
      final services = await UniversalBle.discoverServices(deviceId);
      for (var s in services) {
        _log('Found Service: ${s.uuid}');
        for (var c in s.characteristics) {
          _log('  -> Characteristic: ${c.uuid} (Notify: ${c.properties.contains(CharacteristicProperty.notify)})');
        }
      }

      final serviceUuid = kRadioKitServiceUuid.toLowerCase();
      final widgetCharUuid = kRadioKitCharWidgetUuid.toLowerCase();
      final fsCharUuid = kRadioKitCharFsUuid.toLowerCase();
      final otaCharUuid = kRadioKitCharOtaUuid.toLowerCase();
      final settingsCharUuid = kRadioKitCharSettingsUuid.toLowerCase();

      String? actualServiceId;
      _charWidgetId = null;
      _charFsId = null;
      _charOtaId = null;
      _charSettingsId = null;

      for (var s in services) {
        if (s.uuid.toLowerCase().contains(serviceUuid)) {
          actualServiceId = s.uuid;
          for (var c in s.characteristics) {
            final cuuid = c.uuid.toLowerCase();
            // UUID matching: check both full UUID (e.g. "0000ffe2-...") and
            // short 16-bit UUID (e.g. "ffe2") since BLE stacks differ by platform.
            if (cuuid.contains(widgetCharUuid) || widgetCharUuid.contains(cuuid)) {
              _charWidgetId = c.uuid;
            }
            if (cuuid.contains(fsCharUuid) || fsCharUuid.contains(cuuid)) {
              _charFsId = c.uuid;
            }
            if (cuuid.contains(otaCharUuid) || otaCharUuid.contains(cuuid)) {
              _charOtaId = c.uuid;
            }
            if (cuuid.contains(settingsCharUuid) || settingsCharUuid.contains(cuuid)) {
              _charSettingsId = c.uuid;
            }
          }
        }
      }

      if (actualServiceId == null) {
        _log('ERROR - Could not find RadioKit service in discovery!');
        return;
      }

      _log('Discovered chars: widget=$_charWidgetId, fs=$_charFsId, ota=$_charOtaId, settings=$_charSettingsId');

      // Subscribe to all discovered characteristics
      if (_charWidgetId != null) {
        _log('Subscribing to widget char $_charWidgetId...');
        await UniversalBle.subscribeNotifications(deviceId, actualServiceId, _charWidgetId!);
        _log('Widget subscription SUCCESS');
      } else {
        _log('WARNING - Widget char not found (0xFFE1)');
      }

      if (_charFsId != null) {
        _log('Subscribing to FS char $_charFsId...');
        await UniversalBle.subscribeNotifications(deviceId, actualServiceId, _charFsId!);
        _log('FS subscription SUCCESS');
      } else {
        _log('WARNING - FS char not found (0xFFE2)');
      }

      if (_charOtaId != null) {
        _log('Subscribing to OTA char $_charOtaId...');
        await UniversalBle.subscribeNotifications(deviceId, actualServiceId, _charOtaId!);
        _log('OTA subscription SUCCESS');
      } else {
        _log('WARNING - OTA char not found (0xFFE3)');
      }

      if (_charSettingsId != null) {
        _log('Subscribing to Settings char $_charSettingsId...');
        await UniversalBle.subscribeNotifications(deviceId, actualServiceId, _charSettingsId!);
        _log('Settings subscription SUCCESS');
      } else {
        _log('WARNING - Settings char not found (0xFFE4)');
      }

      // Clear all buffers
      _receiveBuffer.clear();
      _receiveFsBuffer.clear();
      _receiveOtaBuffer.clear();
      _receiveSettingsBuffer.clear();
    } catch (e) {
      _log('Connection ERROR: $e');
      _connectedDeviceId = null;
      throw Exception('Failed to connect: $e');
    }
  }

  @override
  Future<void> disconnect() async {
    if (_isMockConnected) {
      _isMockConnected = false;
      return;
    }

    final id = _connectedDeviceId;
    if (id != null) {
      await UniversalBle.disconnect(id);
      _connectedDeviceId = null;
    }
    _receiveBuffer.clear();
    _receiveFsBuffer.clear();
    _receiveOtaBuffer.clear();
    _receiveSettingsBuffer.clear();
    _charWidgetId = null;
    _charFsId = null;
    _charOtaId = null;
    _charSettingsId = null;
  }

  void _handleDisconnect(String reason) {
    _connectedDeviceId = null;
    _isMockConnected = false;
    _receiveBuffer.clear();
    _receiveFsBuffer.clear();
    _receiveOtaBuffer.clear();
    _receiveSettingsBuffer.clear();
    _charWidgetId = null;
    _charFsId = null;
    _charOtaId = null;
    _charSettingsId = null;
    _mtu = 23;
    onConnectionLost?.call(reason);
  }

  // ---------------------------------------------------------------------------
  // Data Transfer
  // ---------------------------------------------------------------------------

  /// Route a write to the correct characteristic based on the start byte.
  /// Returns the characteristic UUID to use, or null if none found.
  String? _charIdForByte(int startByte) {
    if (startByte == kFsStartByte) return _charFsId;
    if (startByte == kOtaStartByte) return _charOtaId;
    if (startByte == kSettingsStartByte) return _charSettingsId;
    return _charWidgetId; // 0x55 or unknown
  }

  @override
  Future<void> writePacket(Uint8List data) async {
    if (_isMockConnected) {
      _handleMockWrite(data);
      return;
    }

    final deviceId = _connectedDeviceId;
    if (deviceId == null) throw StateError('Not connected');

    final serviceId = kRadioKitServiceUuid.toLowerCase();
    final charId = _charIdForByte(data.isNotEmpty ? data[0] : kStartByte);
    if (charId == null) {
      _log('ERROR - No characteristic found for start byte 0x${data[0].toRadixString(16)}');
      return;
    }

    // Calculate the maximum payload per BLE write command.
    final chunkSize = (_mtu - 3).clamp(20, _mtu - 3);

    if (data.length <= chunkSize) {
      await UniversalBle.write(
        deviceId,
        serviceId,
        charId,
        data,
        withoutResponse: true,
      );
      return;
    }

    for (int i = 0; i < data.length; i += chunkSize) {
      final end = (i + chunkSize).clamp(0, data.length);
      final chunk = Uint8List.sublistView(data, i, end);

      await UniversalBle.write(
        deviceId,
        serviceId,
        charId,
        chunk,
        withoutResponse: true,
      );
    }
  }

  @override
  Future<int?> getRssi() async {
    if (_isMockConnected) return -42;
    final id = _connectedDeviceId;
    if (id == null) return null;
    try {
      return await UniversalBle.readRssi(id);
    } catch (e) {
      debugPrint('BLE_SERVICE: getRssi error: $e');
      return null;
    }
  }

  // ── Per-protocol buffer processing ────────────────────────────────────────
  // Widget, FS, OTA, and Settings buffers are processed independently because
  // they arrive on different BLE characteristics. No protocol interleaving.

  void _processWidgetBuffer() {
    while (true) {
      final drained = ProtocolService.drainBuffer(_receiveBuffer);
      if (drained == null) break;
      if (drained.kind == 'widget') {
        _log('Widget packet: cmd=0x${drained.widgetPacket!.cmd.toRadixString(16)} '
            'payloadLen=${drained.widgetPacket!.payload.length}');
        onPacketReceived?.call(drained.widgetPacket!);
      } else if (drained.kind == 'fs') {
        _log('Unexpected FS packet on widget buffer');
        onFsPacketReceived?.call(drained.fsPacket!);
      } else if (drained.kind == 'ota') {
        _log('Unexpected OTA packet on widget buffer');
        onOtaPacketReceived?.call(drained.otaPacket!);
      } else if (drained.kind == 'settings') {
        _log('Unexpected Settings packet on widget buffer');
        onSettingsPacketReceived?.call(drained.settingsPacket!);
      }
    }
  }

  void _processFsBuffer() {
    while (true) {
      final drained = ProtocolService.drainBuffer(_receiveFsBuffer);
      if (drained == null) break;
      if (drained.kind == 'fs') {
        _log('FS packet: sub=0x${drained.fsPacket!.subCmd.toRadixString(16)} '
            'payloadLen=${drained.fsPacket!.payload.length}');
        onFsPacketReceived?.call(drained.fsPacket!);
      } else if (drained.kind == 'widget') {
        _log('Unexpected widget packet on FS buffer, forwarding');
        onPacketReceived?.call(drained.widgetPacket!);
      } else if (drained.kind == 'ota') {
        _log('Unexpected OTA packet on FS buffer');
        onOtaPacketReceived?.call(drained.otaPacket!);
      } else if (drained.kind == 'settings') {
        _log('Unexpected Settings packet on FS buffer');
        onSettingsPacketReceived?.call(drained.settingsPacket!);
      }
    }
  }

  void _processOtaBuffer() {
    while (true) {
      final drained = ProtocolService.drainBuffer(_receiveOtaBuffer);
      if (drained == null) break;
      if (drained.kind == 'ota') {
        _log('OTA packet: sub=0x${drained.otaPacket!.subCmd.toRadixString(16)} '
            'payloadLen=${drained.otaPacket!.payload.length}');
        onOtaPacketReceived?.call(drained.otaPacket!);
      } else if (drained.kind == 'widget') {
        _log('Unexpected widget packet on OTA buffer, forwarding');
        onPacketReceived?.call(drained.widgetPacket!);
      } else if (drained.kind == 'fs') {
        _log('Unexpected FS packet on OTA buffer');
        onFsPacketReceived?.call(drained.fsPacket!);
      } else if (drained.kind == 'settings') {
        _log('Unexpected Settings packet on OTA buffer');
        onSettingsPacketReceived?.call(drained.settingsPacket!);
      }
    }
  }

  void _processSettingsBuffer() {
    while (true) {
      final drained = ProtocolService.drainBuffer(_receiveSettingsBuffer);
      if (drained == null) break;
      if (drained.kind == 'settings') {
        _log('Settings packet: sub=0x${drained.settingsPacket!.subCmd.toRadixString(16)} '
            'payloadLen=${drained.settingsPacket!.payload.length}');
        onSettingsPacketReceived?.call(drained.settingsPacket!);
      } else if (drained.kind == 'widget') {
        _log('Unexpected widget packet on Settings buffer, forwarding');
        onPacketReceived?.call(drained.widgetPacket!);
      } else if (drained.kind == 'fs') {
        _log('Unexpected FS packet on Settings buffer');
        onFsPacketReceived?.call(drained.fsPacket!);
      } else if (drained.kind == 'ota') {
        _log('Unexpected OTA packet on Settings buffer');
        onOtaPacketReceived?.call(drained.otaPacket!);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Mock / Simulation Logic
  // ---------------------------------------------------------------------------

  /// [Debug only] Manually inject a packet into the received stream.
  void injectDebugPacket(List<int> packetBytes) {
    final packet = ProtocolService.parsePacket(Uint8List.fromList(packetBytes));
    if (packet != null) {
      onPacketReceived?.call(packet);
    }
  }

  int _mockButtonValue = 0;
  int _mockSwitchValue = 1;
  int _mockSliderValue = 50;
  int _mockJoyX = 0;
  int _mockJoyY = 0;
  int _mockLedValue = 1;
  String _mockTextValue = 'Demo Mode Active';

  void _handleMockWrite(Uint8List data) {
    if (data.length >= 4 && data[0] == kStartByte) {
      final cmd = data[3];
      final payload = data.sublist(4, data.length - 2);

      Future.delayed(const Duration(milliseconds: 30), () {
        if (cmd == kCmdGetConf) {
          _respondWithMockConf();
        } else if (cmd == kCmdGetVars) {
          _respondWithMockVars();
        } else if (cmd == kCmdSetInput) {
          if (payload.length >= 5) {
            _mockButtonValue = payload[0];
            _mockSwitchValue = payload[1];
            _mockSliderValue = payload[2];
            _mockJoyX = _toSigned(payload[3]);
            _mockJoyY = _toSigned(payload[4]);
            _mockLedValue = _mockSwitchValue;
            _mockTextValue = 'Val: $_mockSliderValue | Joy: $_mockJoyX,$_mockJoyY';
          }
          _respondWithAck();
        }
      });
    }
  }

  void _respondWithMockConf() {
    injectDebugPacket([
      0x55, 0x5B, 0x00, 0x02,
      0x02, 0x00, 0x06,
      0x01, 0x00, 0x26, 0x19, 0x0F, 0x19, 0x00, 0x06,
      0x42, 0x75, 0x74, 0x74, 0x6F, 0x6E,
      0x02, 0x01, 0x3F, 0x4B, 0x0F, 0x10, 0x00, 0x06,
      0x53, 0x77, 0x69, 0x74, 0x63, 0x68,
      0x03, 0x02, 0x0C, 0x33, 0x0A, 0x32, 0x00, 0x06,
      0x53, 0x6C, 0x69, 0x64, 0x65, 0x72,
      0x04, 0x03, 0x7F, 0x33, 0x26, 0x0A, 0x00, 0x07,
      0x43, 0x6F, 0x6E, 0x74, 0x72, 0x6F, 0x6C,
      0x05, 0x04, 0x0C, 0x50, 0x0C, 0x0A, 0x00, 0x03,
      0x4C, 0x45, 0x44,
      0x06, 0x05, 0x33, 0x50, 0x0C, 0x28, 0x00, 0x06,
      0x53, 0x74, 0x61, 0x74, 0x75, 0x73,
      0x26, 0x2E,
    ]);
  }

  void _respondWithMockVars() {
    final textBytes = Uint8List(32);
    final encoded = utf8.encode(_mockTextValue);
    for (int i = 0; i < encoded.length && i < 32; i++) {
      textBytes[i] = encoded[i];
    }
    final payload = [
      _mockButtonValue,
      _mockSwitchValue,
      _mockSliderValue,
      _mockJoyX < 0 ? _mockJoyX + 256 : _mockJoyX,
      _mockJoyY < 0 ? _mockJoyY + 256 : _mockJoyY,
      _mockLedValue,
      ...textBytes,
    ];
    injectDebugPacket(ProtocolService.buildPacket(kCmdVarData, Uint8List.fromList(payload)));
  }

  void _respondWithAck() => injectDebugPacket(ProtocolService.buildPacket(kCmdAck));

  static int _toSigned(int byte) {
    final b = byte & 0xFF;
    return b >= 128 ? b - 256 : b;
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  @override
  Future<void> dispose() async {
    await stopScan();
    await disconnect();
    await _availabilityController.close();
  }
}
