import 'dart:async';
import 'dart:convert';
import 'package:universal_ble/universal_ble.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/protocol.dart';
import '../models/device_info.dart';
import 'protocol_service.dart';
import 'transport_service.dart';

// Conditionally import JS bridge for Web Mock
import 'ble_js_bridge_stub.dart' if (dart.library.js) 'ble_js_bridge_web.dart';

/// Unified BLE service using universal_ble.
///
/// Handles scanning, connection, and UART-style data transfer across
/// Web, Android, iOS, Windows, macOS, and Linux.
class BleService implements TransportService {
  BleService() {
    _setupListeners();
    setupBleJsBridge(this);
  }

  @override
  PacketReceivedCallback? onPacketReceived;
  @override
  FsPacketReceivedCallback? onFsPacketReceived;
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
  final List<int> _receiveBuffer = [];

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
    final state = await UniversalBle.getBluetoothAvailabilityState();
    return state == AvailabilityState.poweredOn;
  }

  /// Returns true if Location Services are enabled (required for Android < 12).
  Future<bool> get isLocationServiceEnabled async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Only require location services for Android < 12 (SDK < 31)
      // On Android 12+, BLUETOOTH_SCAN permission with neverForLocation flag
      // does not require location services to be enabled
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
    return await UniversalBle.getBluetoothAvailabilityState();
  }

  /// Requests necessary Bluetooth permissions.
  Future<void> requestPermissions() async {
    try {
      debugPrint('BLE_SERVICE: Requesting permissions...');
      await UniversalBle.requestPermissions(
        withAndroidFineLocation: true, // Required for reliable BLE scanning on many Android devices
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

    UniversalBle.onValueChange = (String deviceId, String characteristicId, Uint8List value, int? timestamp) {
      final charId = characteristicId.toLowerCase();
      final targetId = kRadioKitCharUuid.toLowerCase();
      
      // Log ALL incoming data from ANY characteristic
      _log('RAW MCU from $characteristicId: ${value.map((b) => b.toRadixString(16).padLeft(2, "0")).join(" ")}');

      if (deviceId == _connectedDeviceId && charId.contains(targetId)) {
        _log('MATCH! Appending ${value.length} bytes to buffer.');
        _receiveBuffer.addAll(value);
        _processBuffer();
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

      // All RadioKit devices advertise with the "RK_" prefix.
      // Filter by that prefix — no hardcoded device names needed.
      if (!rawName.startsWith('RK_')) return;

      if (!seen.contains(id)) {
        seen.add(id);
        // Strip the "RK_" prefix for display in the app UI.
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

    // Scan all devices — filtering is done by name prefix above.
    // A hardware ScanFilter(withServices:) would be ideal but can miss devices
    // on some Android versions when the service UUID is in the scan response
    // rather than the primary advertisement packet.
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

      // Try to request a larger MTU (default is 23, we want at least 128 for 102 byte payloads)
      try {
        _log('Requesting MTU of 256...');
        await UniversalBle.requestMtu(deviceId, 256);
      } catch (e) {
        _log('MTU request failed (ignoring): $e');
      }

      // Discover services
      _log('Discovering services...');
      final services = await UniversalBle.discoverServices(deviceId);
      for (var s in services) {
        _log('Found Service: ${s.uuid}');
        for (var c in s.characteristics) {
          _log('  -> Characteristic: ${c.uuid} (Notify: ${c.properties.contains(CharacteristicProperty.notify)})');
        }
      }
      
      final serviceUuid = kRadioKitServiceUuid.toLowerCase();
      final charUuid = kRadioKitCharUuid.toLowerCase();

      // Find the actual service/char IDs from the discovery result to be safe
      String? actualServiceId;
      String? actualCharId;

      for (var s in services) {
        if (s.uuid.toLowerCase().contains(serviceUuid)) {
          actualServiceId = s.uuid;
          for (var c in s.characteristics) {
            if (c.uuid.toLowerCase().contains(charUuid)) {
              actualCharId = c.uuid;
              break;
            }
          }
        }
      }

      if (actualServiceId != null && actualCharId != null) {
        _log('Subscribing to $actualCharId...');
        await UniversalBle.subscribeNotifications(deviceId, actualServiceId, actualCharId);
        _log('Subscription SUCCESS');
      } else {
        _log('ERROR - Could not find RadioKit characteristic in discovery!');
      }

      _receiveBuffer.clear();
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
  }

  void _handleDisconnect(String reason) {
    _connectedDeviceId = null;
    _isMockConnected = false;
    _receiveBuffer.clear();
    onConnectionLost?.call(reason);
  }

  // ---------------------------------------------------------------------------
  // Data Transfer
  // ---------------------------------------------------------------------------

  @override
  Future<void> writePacket(Uint8List data) async {
    if (_isMockConnected) {
      _handleMockWrite(data);
      return;
    }

    final deviceId = _connectedDeviceId;
    if (deviceId == null) throw StateError('Not connected');

    await UniversalBle.write(
      deviceId,
      kRadioKitServiceUuid.toLowerCase(),
      kRadioKitCharUuid.toLowerCase(),
      data,
      withoutResponse: true,
    );
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

  void _processBuffer() {
    while (true) {
      final drained = ProtocolService.drainBuffer(_receiveBuffer);
      if (drained == null) break;
      if (drained.kind == 'widget') {
        _log('Widget packet: cmd=0x${drained.widgetPacket!.cmd.toRadixString(16)} '
            'payloadLen=${drained.widgetPacket!.payload.length}');
        onPacketReceived?.call(drained.widgetPacket!);
      } else if (drained.kind == 'fs') {
        _log('FS packet: sub=0x${drained.fsPacket!.subCmd.toRadixString(16)} '
            'payloadLen=${drained.fsPacket!.payload.length}');
        onFsPacketReceived?.call(drained.fsPacket!);
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
        } else if (cmd == kCmdPing) {
          _respondWithPong();
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
  void _respondWithPong() => injectDebugPacket(ProtocolService.buildPacket(kCmdPong));

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
