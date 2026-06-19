/// Raw USB serial service for Android — bypasses the mik3y Java library
/// and writes directly to the CDC ACM bulk OUT endpoint using Android's
/// UsbDeviceConnection API with STALL recovery.
///
/// This is a workaround for the ESP32-S3 USB Serial/JTAG controller's
/// bulk OUT endpoint STALL issue that prevents the mik3y library from
/// sending data in application mode.
library;

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/device_info.dart';
import 'protocol_service.dart';
import 'transport_service.dart';
export 'transport_service.dart';

class RawUsbSerialService implements TransportService {
  static const _channel = MethodChannel('com.rambros3d.radiokit/raw_usb');

  static const _kSessionTimeout = Duration(seconds: 30);

  // ── Callbacks ─────────────────────────────────────────────────
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

  // ── State ─────────────────────────────────────────────────────
  bool _connected = false;
  bool _disposed = false;
  String? _currentPort;
  Timer? _readPollTimer;
  Timer? _sessionTimer;
  final List<int> _receiveBuffer = [];

  // ── Logging ───────────────────────────────────────────────────
  final StreamController<String> _logController =
      StreamController<String>.broadcast();

  @override
  Stream<String> get logStream => _logController.stream;

  void _log(String msg) {
    debugPrint('RAW_USB: $msg');
    _logController.add(msg);
  }

  // ── Connection ────────────────────────────────────────────────

  @override
  bool get isConnected => _connected;

  /// List available USB serial ports via the Kotlin plugin's UsbManager.
  Stream<DeviceInfo> listPorts() async* {
    try {
      final result = await _channel.invokeMethod<List>('listPorts');
      if (result != null) {
        for (final item in result) {
          final m = Map<String, dynamic>.from(item as Map);
          yield DeviceInfo(
            id: m['name'] as String? ?? '',
            name: (m['productName'] as String?)?.isNotEmpty == true
                ? m['productName'] as String
                : (m['name'] as String? ?? ''),
            rssi: 0,
            currentTransport: TransportType.serial,
          );
        }
      }
    } catch (e) {
      _log('listPorts failed: $e');
    }
  }

  @override
  Future<void> connect(String deviceId, {int baudRate = 1000000}) async {
    await disconnect();

    _log('Connecting to $deviceId at $baudRate baud...');
    _currentPort = deviceId;

    // Request USB permission if not already granted
    try {
      final hasPerm = await _channel.invokeMethod<bool>('requestPermission', {
        'name': deviceId,
      });
      _log('USB permission: $hasPerm');
    } catch (e) {
      _log('Permission request error (may already be granted): $e');
    }

    try {
      final result = await _channel.invokeMethod<Map>('open', {
        'name': deviceId,
        'baudRate': baudRate,
      });

      if (result == null || result['ok'] != true) {
        throw Exception('Raw USB open failed: $result');
      }

      _connected = true;
      _log('Port opened: write=${result["writeEndpoint"]}, '
          'read=${result["readEndpoint"]}, '
          'maxPacket=${result["maxPacketSize"]}');

      // Start polling for incoming data
      _startReadPoll();
      _resetSessionTimer();
    } catch (e) {
      _connected = false;
      _log('Connection failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _sessionTimer?.cancel();
    _stopReadPoll();

    try {
      await _channel.invokeMethod('close');
      _log('Disconnected');
    } catch (e) {
      _log('Disconnect error: $e');
    }

    _receiveBuffer.clear();
    _currentPort = null;
  }

  // ── Write ─────────────────────────────────────────────────────

  @override
  Future<void> writePacket(Uint8List data) async {
    if (!_connected || _disposed) return;

    _resetSessionTimer();

    try {
      final result = await _channel.invokeMethod<Map>('write', {
        'data': data,
      });

      if (result != null) {
        final bytes = result['bytes'] as int? ?? 0;
        final method = result['method'] as String? ?? 'unknown';
        if (method != 'bulk') {
          _log('TX ${data.length} bytes via $method (stall recovery)');
        }
      }
    } on PlatformException catch (e) {
      _log('Write failed: ${e.message}');
      // Don't disconnect on write failure — the device might still be
      // readable. The session timeout will catch genuine disconnects.
    }
  }

  // ── Read polling ──────────────────────────────────────────────

  void _startReadPoll() {
    _stopReadPoll();
    _readPollTimer = Timer.periodic(const Duration(milliseconds: 10), (_) {
      _pollRead();
    });
  }

  void _stopReadPoll() {
    _readPollTimer?.cancel();
    _readPollTimer = null;
  }

  Future<void> _pollRead() async {
    if (!_connected || _disposed) return;

    try {
      final data = await _channel.invokeMethod<Uint8List>('read', {
        'maxLength': 4096,
        'timeout': 100,
      });

      if (data != null && data.isNotEmpty) {
        final hex = data
            .take(64)
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join(' ');
        final suffix = data.length > 64 ? ' ... (${data.length} total)' : '';
        _log('RX ${data.length} bytes: $hex$suffix');
        _receiveBuffer.addAll(data);
        _processBuffer();
      }
    } catch (_) {
      // Read errors during polling are non-fatal
    }
  }

  // ── Buffer processing ─────────────────────────────────────────

  void _processBuffer() {
    while (true) {
      final drained = ProtocolService.drainBuffer(_receiveBuffer);
      if (drained == null) break;
      _connected = true;
      _resetSessionTimer();
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

  void _resetSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer(_kSessionTimeout, () {
      if (_connected) {
        _connected = false;
        onConnectionLost?.call('Serial session timed out (no packet for 30s)');
      }
    });
  }

  // ── Lifecycle ─────────────────────────────────────────────────

  @override
  Future<void> dispose() async {
    _disposed = true;
    await disconnect();
    await _logController.close();
  }

  @override
  Future<int?> getRssi() async => null;
}
