import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart' hide BleService;
import '../models/protocol.dart';
import 'protocol_service.dart';
import 'settings_protocol_service.dart';
import 'transport_service.dart';
import 'ble_service_impl.dart';

/// A per-device BLE transport wrapper that delegates to the shared [BleService].
///
/// Each [DeviceProvider] gets its own [BleTransport] instance. The shared
/// [BleService] routes incoming notifications and connection events to the
/// correct transport based on the BLE device ID.
///
/// This enables simultaneous connections to multiple BLE devices on Android
/// (which supports multiple BLE connections at the OS level).
class BleTransport implements TransportService {
  final BleService _bleService;
  String? _deviceId;

  // Per-device receive buffers (mirrors BleService but per-connection)
  final List<int> _widgetBuffer = [];
  final List<int> _fsBuffer = [];
  final List<int> _otaBuffer = [];
  final List<int> _settingsBuffer = [];
  final List<int> _printBuffer = [];

  // Per-device characteristic IDs
  String? _charWidgetId;
  String? _charFsId;
  String? _charOtaId;
  String? _charSettingsId;
  String? _charPrintId;

  int _mtu = 23;
  bool _isConnected = false;

  BleTransport(this._bleService);

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

  @override
  Stream<String> get logStream => _bleService.logStream;

  @override
  bool get isConnected => _isConnected;

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  Future<void> connect(String deviceId, {int baudRate = 1000000}) async {
    _deviceId = deviceId;
    _isConnected = false;

    // Register with the shared BleService so it routes callbacks to us
    _bleService.registerTransport(deviceId, this);

    try {
      await _bleService.connectToDevice(deviceId, transport: this);
      _isConnected = true;
    } catch (e) {
      _bleService.unregisterTransport(deviceId);
      _isConnected = false;
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    final deviceId = _deviceId;
    if (deviceId != null) {
      _bleService.unregisterTransport(deviceId);
      try {
        await _bleService.disconnectDevice(deviceId);
      } catch (_) {}
    }
    _isConnected = false;
    _deviceId = null;
    _charWidgetId = null;
    _charFsId = null;
    _charOtaId = null;
    _charSettingsId = null;
    _charPrintId = null;
    _mtu = 23;
    _widgetBuffer.clear();
    _fsBuffer.clear();
    _otaBuffer.clear();
    _settingsBuffer.clear();
    _printBuffer.clear();
  }

  @override
  Future<void> dispose() async {
    await disconnect();
  }

  // ── Write ────────────────────────────────────────────────────────────────

  @override
  Future<void> writePacket(Uint8List data) async {
    final deviceId = _deviceId;
    if (deviceId == null || !_isConnected) {
      throw StateError('Not connected');
    }
    await _bleService.writePacketToDevice(deviceId, data, _mtu, _charForByte(data));
  }

  @override
  Future<int?> getRssi() async {
    final deviceId = _deviceId;
    if (deviceId == null) return null;
    return _bleService.readRssi(deviceId);
  }

  /// Resolve characteristic UUID for a given start byte.
  String? _charForByte(Uint8List data) {
    if (data.isEmpty) return _charWidgetId;
    final startByte = data[0];
    if (startByte == kFsStartByte) return _charFsId;
    if (startByte == kOtaStartByte) return _charOtaId;
    if (startByte == kSettingsStartByte) return _charSettingsId;
    return _charWidgetId;
  }

  // ── Callbacks from BleService (routed per-device) ──────────────────────

  /// Called by [BleService] when characteristic values arrive for this device.
  void onValueChanged(String characteristicId, Uint8List value) {
    final charId = characteristicId.toLowerCase();

    if (_charSettingsId != null && charId == _charSettingsId!.toLowerCase()) {
      _settingsBuffer.addAll(value);
      _processSettingsBuffer();
    } else if (_charFsId != null && charId == _charFsId!.toLowerCase()) {
      _fsBuffer.addAll(value);
      _processFsBuffer();
    } else if (_charOtaId != null && charId == _charOtaId!.toLowerCase()) {
      _otaBuffer.addAll(value);
      _processOtaBuffer();
    } else if (_charWidgetId != null && charId == _charWidgetId!.toLowerCase()) {
      _widgetBuffer.addAll(value);
      _processWidgetBuffer();
    } else if (_charPrintId != null && charId == _charPrintId!.toLowerCase()) {
      _printBuffer.addAll(value);
      _processPrintBuffer();
    } else {
      // Unknown characteristic — try widget as fallback
      _widgetBuffer.addAll(value);
      _processWidgetBuffer();
    }
  }

  /// Called by [BleService] when the connection state changes for this device.
  void onConnectionChanged(bool connected, String? error) {
    _isConnected = connected;
    if (!connected) {
      _widgetBuffer.clear();
      _fsBuffer.clear();
      _otaBuffer.clear();
      _settingsBuffer.clear();
      _printBuffer.clear();
      _charWidgetId = null;
      _charFsId = null;
      _charOtaId = null;
      _charSettingsId = null;
      _charPrintId = null;
      _mtu = 23;
      onConnectionLost?.call(error ?? 'Connection lost');
    }
  }

  /// Called by [BleService] after service discovery to set characteristic IDs.
  void setCharacteristics({
    String? widgetId,
    String? fsId,
    String? otaId,
    String? settingsId,
    String? printId,
    int mtu = 23,
  }) {
    _charWidgetId = widgetId;
    _charFsId = fsId;
    _charOtaId = otaId;
    _charSettingsId = settingsId;
    _charPrintId = printId;
    _mtu = mtu;
  }

  // ── Per-protocol buffer processing ─────────────────────────────────────

  void _processWidgetBuffer() {
    while (true) {
      final drained = ProtocolService.drainBuffer(_widgetBuffer);
      if (drained == null) break;
      if (drained.kind == 'widget') {
        onPacketReceived?.call(drained.widgetPacket!);
      } else if (drained.kind == 'fs') {
        onFsPacketReceived?.call(drained.fsPacket!);
      } else if (drained.kind == 'ota') {
        onOtaPacketReceived?.call(drained.otaPacket!);
      } else if (drained.kind == 'settings') {
        onSettingsPacketReceived?.call(drained.settingsPacket!);
      }
    }
  }

  void _processFsBuffer() {
    while (true) {
      final drained = ProtocolService.drainBuffer(_fsBuffer);
      if (drained == null) break;
      if (drained.kind == 'fs') {
        onFsPacketReceived?.call(drained.fsPacket!);
      } else if (drained.kind == 'widget') {
        onPacketReceived?.call(drained.widgetPacket!);
      } else if (drained.kind == 'ota') {
        onOtaPacketReceived?.call(drained.otaPacket!);
      } else if (drained.kind == 'settings') {
        onSettingsPacketReceived?.call(drained.settingsPacket!);
      }
    }
  }

  void _processOtaBuffer() {
    while (true) {
      final drained = ProtocolService.drainBuffer(_otaBuffer);
      if (drained == null) break;
      if (drained.kind == 'ota') {
        onOtaPacketReceived?.call(drained.otaPacket!);
      } else if (drained.kind == 'widget') {
        onPacketReceived?.call(drained.widgetPacket!);
      } else if (drained.kind == 'fs') {
        onFsPacketReceived?.call(drained.fsPacket!);
      } else if (drained.kind == 'settings') {
        onSettingsPacketReceived?.call(drained.settingsPacket!);
      }
    }
  }

  void _processSettingsBuffer() {
    while (true) {
      final drained = ProtocolService.drainBuffer(_settingsBuffer);
      if (drained == null) break;
      if (drained.kind == 'settings') {
        onSettingsPacketReceived?.call(drained.settingsPacket!);
      } else if (drained.kind == 'widget') {
        onPacketReceived?.call(drained.widgetPacket!);
      } else if (drained.kind == 'fs') {
        onFsPacketReceived?.call(drained.fsPacket!);
      } else if (drained.kind == 'ota') {
        onOtaPacketReceived?.call(drained.otaPacket!);
      }
    }
  }

  void _processPrintBuffer() {
    while (_printBuffer.length >= 3) {
      final startByte = _printBuffer[0];
      if (startByte != kPrintStartByte) {
        _printBuffer.removeAt(0);
        continue;
      }
      final length = _printBuffer[1] | (_printBuffer[2] << 8);
      if (length < 3 || length > 0x100) {
        _printBuffer.removeAt(0);
        continue;
      }
      if (_printBuffer.length < length) break;
      final frameBytes = Uint8List.fromList(_printBuffer.sublist(0, length));
      _printBuffer.removeRange(0, length);
      final payload = frameBytes.sublist(3);
      onSettingsPacketReceived?.call(
        ParsedSettingsPacket(
          subCmd: kPrintStartByte,
          payload: Uint8List.fromList(payload),
        ),
      );
    }
  }
}
