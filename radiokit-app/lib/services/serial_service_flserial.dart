/// flserial-based serial transport (active on Linux).
///
/// Key advantages over dart_periphery:
///  - Event-based I/O (Stream<SerialEvent>) instead of polling
///  - Built-in port enumeration via [FlSerial.availablePorts]
///  - Cross-platform (Linux, macOS, Windows, Android, Web)
///
/// NOTE: Flutter's generated_plugins.cmake unconditionally calls
/// add_subdirectory(.../flserial/linux) for FFI plugins. Since flserial uses
/// native assets (hook/build.dart) and has no linux/ directory, we created a
/// stub CMakeLists.txt in the pub-cache. See llm-docs/native-assets-issue.md
/// for the full technical analysis.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flserial/flserial.dart';
import '../models/device_info.dart';
import 'protocol_service.dart';
import 'transport_service.dart';
export 'transport_service.dart';

/// USB Serial transport using `flserial`.
///
/// Active on both Android and Linux. Uses Dart FFI + termios directly
/// (no libserialport or c-periphery). Event-based I/O via [FlSerial.events]
/// stream — no polling needed.
class FlserialSerialService implements TransportService {
  /// Time before declaring the session dead when no packets arrive.
  /// Increased from 3s to 30s because serial protocol requests (auth, FS)
  /// can take several seconds round-trip. Also resets on outgoing writes.
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

  FlSerial? _serial;
  StreamSubscription<SerialEvent>? _eventSub;
  Timer? _sessionTimer;
  bool _connected = false;

  final List<int> _receiveBuffer = [];

  bool get isSupported => true;

  @override
  bool get isConnected => _connected;

  void _log(String msg) {
    debugPrint('FLSERIAL: $msg');
    _logController.add(msg);
  }

  // ---------------------------------------------------------------------------
  // Port discovery
  // ---------------------------------------------------------------------------

  Stream<DeviceInfo> listPorts() async* {
    try {
      final ports = await FlSerial.availablePorts();
      for (final port in ports) {
        yield DeviceInfo(
          id: port.path,
          // Use the USB product description (e.g. "CP2102N USB to UART Bridge")
          // as the display name, falling back to the path segment.
          name: port.description.isNotEmpty
              ? port.description
              : port.path.split('/').last,
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
  Future<void> connect(String deviceId, {int baudRate = _kDefaultBaud}) async {
    await disconnect();

    _log('Opening $deviceId @ $baudRate baud...');

    final serial = FlSerial();
    _serial = serial;

    // Listen for events BEFORE opening to avoid race conditions.
    _eventSub = serial.events.listen(_onSerialEvent);

    final config = SerialConfig(baudRate: baudRate);
    try {
      final ok = await serial.open(deviceId, config);
      if (!ok) {
        _eventSub?.cancel();
        _eventSub = null;
        _serial = null;
        _log('open() returned false for $deviceId — check USB permission or interface claim');
        throw Exception('Failed to open $deviceId');
      }
    } catch (e) {
      _eventSub?.cancel();
      _eventSub = null;
      _serial = null;
      _log('open() threw: $e');
      rethrow;
    }

    _receiveBuffer.clear();
    _connected = true;
    _log('Port opened: $deviceId');
  }

  // ---------------------------------------------------------------------------
  // Event handler
  // ---------------------------------------------------------------------------

  void _onSerialEvent(SerialEvent event) {
    switch (event.type) {
      case SerialEventType.data:
        if (event.data is Uint8List) {
          final data = event.data as Uint8List;
          if (data.isNotEmpty) {
            final hex = data.take(64).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
            final suffix = data.length > 64 ? ' ... (${data.length} total)' : '';
            _log('RX ${data.length} bytes: $hex$suffix');
            _receiveBuffer.addAll(data);
            _processBuffer();
          }
        }
        break;

      case SerialEventType.connected:
        _log('Port connected event');
        break;

      case SerialEventType.disconnected:
        _log('Port disconnected event');
        _handleDisconnect('Serial port disconnected');
        break;

      default:
        debugPrint('FLSERIAL: unhandled event type: ${event.type}');
    }
  }

  @override
  Future<void> writePacket(Uint8List data) async {
    final serial = _serial;
    if (serial == null) throw StateError('Serial not connected');
    _resetSessionTimer();
    _log('TX ${data.length} bytes: ${data.length > 20 ? "${data[0].toRadixString(16).padLeft(2, '0')}..${data[data.length-1].toRadixString(16).padLeft(2, '0')}" : data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(" ")}');
    serial.write(data);
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
        onConnectionLost?.call('Serial session timed out (no packet for 3 s)');
      }
    });
  }

  @override
  Future<int?> getRssi() async => null;

  // ---------------------------------------------------------------------------
  // Disconnect / dispose
  // ---------------------------------------------------------------------------

  void _handleDisconnect(String reason) {
    _log('Disconnected: $reason');
    _connected = false;
    _sessionTimer?.cancel();
    _eventSub?.cancel();
    _eventSub = null;
    try {
      _serial?.close();
    } catch (_) {}
    try {
      _serial?.dispose();
    } catch (_) {}
    _serial = null;
    onConnectionLost?.call(reason);
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _sessionTimer?.cancel();
    _eventSub?.cancel();
    _eventSub = null;
    try {
      await _serial?.close();
    } catch (_) {}
    try {
      await _serial?.dispose();
    } catch (_) {}
    _serial = null;
    _receiveBuffer.clear();
  }

  @override
  Future<void> dispose() => disconnect();
}
