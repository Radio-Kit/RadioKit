/// flutter_serial_communication-based serial transport (Android only).
///
/// Wraps the `flutter_serial_communication` package which internally uses
/// the `usb-serial-for-android` Java library (mik3y). This provides a
/// different USB communication path than flserial's native FFI approach,
/// which may help with ESP32-S3 USB Serial/JTAG controller compatibility
/// on Android.
///
/// On non-Android platforms, [FlserialSerialService] is used instead.
library;

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_serial_communication/flutter_serial_communication.dart'
    as fsc;
import 'package:flutter_serial_communication/models/device_info.dart'
    as fsc_model;
import '../models/device_info.dart';
import 'protocol_service.dart';
import 'transport_service.dart';
export 'transport_service.dart';

/// USB Serial transport using `flutter_serial_communication` (Android only).
///
/// Uses `usb-serial-for-android` Java library internally, which provides
/// a different USB communication path than flserial's native FFI approach.
class FlutterSerialCommunicationService implements TransportService {
  /// Time before declaring the session dead when no packets arrive.
  static const _kSessionTimeout = Duration(seconds: 30);

  /// Default baud rate — 1 Mbps for RadioKit protocol.
  static const _kDefaultBaud = 1000000;

  @override PacketReceivedCallback? onPacketReceived;
  @override FsPacketReceivedCallback? onFsPacketReceived;
  @override OtaPacketReceivedCallback? onOtaPacketReceived;
  @override SettingsPacketReceivedCallback? onSettingsPacketReceived;
  @override ConnectionLostCallback? onConnectionLost;

  final _logController = StreamController<String>.broadcast();
  @override Stream<String> get logStream => _logController.stream;

  fsc.FlutterSerialCommunication? _plugin;
  StreamSubscription<dynamic>? _eventSub;
  Timer? _sessionTimer;
  bool _connected = false;

  final List<int> _receiveBuffer = [];

  @override
  bool get isConnected => _connected;

  void _log(String msg) {
    debugPrint('FSC: $msg');
    _logController.add(msg);
  }

  // ---------------------------------------------------------------------------
  // Port discovery
  // ---------------------------------------------------------------------------

  /// List available serial ports via flutter_serial_communication.
  Stream<DeviceInfo> listPorts() async* {
    try {
      final plugin = fsc.FlutterSerialCommunication();
      final devices = await plugin.getAvailableDevices();
      for (final device in devices) {
        yield DeviceInfo(
          id: device.deviceName,
          name: device.productName.isNotEmpty
              ? device.productName
              : device.deviceName,
          rssi: 0,
          currentTransport: TransportType.serial,
        );
      }
    } catch (e) {
      _log('Port enumeration error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Connection
  // ---------------------------------------------------------------------------

  @override
  Future<void> connect(String deviceId,
      {int baudRate = _kDefaultBaud}) async {
    await disconnect();

    _log('Opening $deviceId @ $baudRate baud...');

    final plugin = fsc.FlutterSerialCommunication();
    _plugin = plugin;

    try {
      // List devices to find the matching one
      final devices = await plugin.getAvailableDevices();
      // Use FSC's DeviceInfo type (from flutter_serial_communication package)
      fsc_model.DeviceInfo? targetDevice;
      for (final device in devices) {
        if (device.deviceName == deviceId) {
          targetDevice = device;
          break;
        }
      }

      if (targetDevice == null) {
        _plugin = null;
        _log('Device $deviceId not found in available ports');
        throw Exception('Device $deviceId not found');
      }

      // Connect (positional args: DeviceInfo, baudRate)
      final connected = await plugin.connect(targetDevice, baudRate);
      if (!connected) {
        _plugin = null;
        _log('connect() returned false for $deviceId');
        throw Exception('Failed to connect to $deviceId');
      }

      // Assert DTR/RTS — required by ESP32-S3 native USB Serial/JTAG
      // controller to activate the data path. Without this, the device
      // never transmits data on Android.
      try {
        await plugin.setDTR(true);
        await plugin.setRTS(true);
        _log('DTR/RTS asserted');
      } catch (e) {
        _log('WARNING: Failed to set DTR/RTS: $e');
      }
    } catch (e) {
      _plugin = null;
      _log('connect() threw: $e');
      rethrow;
    }

    // Listen for incoming data via EventChannel.
    // NOTE: We do NOT subscribe to getDeviceConnectionListener().
    // The mik3y Java library fires a false disconnect event ~7s after
    // opening the CDC ACM port on ESP32-S3 USB Serial/JTAG. Even if
    // we ignore it in Dart, the Java side marks the device as
    // disconnected internally, causing all subsequent write() calls
    // to return false. Disconnect detection is handled by:
    //   1. write() returning false (write failure)
    //   2. Session timeout (30s with no received packets)
    //   3. EventChannel errors
    final eventChannel = plugin.getSerialMessageListener();
    _eventSub = eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Uint8List && event.isNotEmpty) {
          _onData(event);
        }
      },
      onError: (error) {
        _log('EventChannel error: $error');
        _handleDisconnect('EventChannel error: $error');
      },
    );

    _receiveBuffer.clear();
    _connected = true;
    _log('Port opened: $deviceId');
  }

  // ---------------------------------------------------------------------------
  // Data handler
  // ---------------------------------------------------------------------------

  void _onData(Uint8List data) {
    final hex = data
        .take(64)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ');
    final suffix = data.length > 64 ? ' ... (${data.length} total)' : '';
    _log('RX ${data.length} bytes: $hex$suffix');
    _receiveBuffer.addAll(data);
    _processBuffer();
  }

  @override
  Future<void> writePacket(Uint8List data) async {
    final plugin = _plugin;
    if (plugin == null) throw StateError('Serial not connected');
    _resetSessionTimer();
    _log('TX ${data.length} bytes: ${data.length > 20 ? "${data[0].toRadixString(16).padLeft(2, '0')}..${data[data.length - 1].toRadixString(16).padLeft(2, '0')}" : data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(" ")}');
    final sent = await plugin.write(data);
    if (!sent) _log('WARNING: write() returned false');
  }

  // ---------------------------------------------------------------------------
  // Receive path (event-driven)
  // ---------------------------------------------------------------------------

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

  @override
  Future<int?> getRssi() async => null;

  // ---------------------------------------------------------------------------
  // Disconnect / dispose
  // ---------------------------------------------------------------------------

  void _handleDisconnect(String reason) {
    if (!_connected) return; // Already disconnected — no-op
    _log('Disconnected: $reason');
    _connected = false;
    _sessionTimer?.cancel();
    _eventSub?.cancel();
    _eventSub = null;
    try {
      _plugin?.disconnect();
    } catch (_) {}
    _plugin = null;
    _receiveBuffer.clear();
    onConnectionLost?.call(reason);
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _sessionTimer?.cancel();
    _eventSub?.cancel();
    _eventSub = null;
    try {
      await _plugin?.disconnect();
    } catch (_) {}
    _plugin = null;
    _receiveBuffer.clear();
  }

  @override
  Future<void> dispose() => disconnect();
}
