import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import '../models/device_info.dart';
import 'protocol_service.dart';
import 'transport_service.dart';
export 'transport_service.dart';

/// USB Serial transport for Linux desktop.
///
/// Uses [flutter_libserialport] which wraps the native `libserialport` C
/// library, providing proper termios-based serial port access on Linux.
///
/// Ports are identified by their device path (e.g. `/dev/ttyACM0`).
class LinuxSerialService implements TransportService {
  static const _kSessionTimeout = Duration(seconds: 3);

  @override PacketReceivedCallback? onPacketReceived;
  @override FsPacketReceivedCallback? onFsPacketReceived;
  @override ConnectionLostCallback? onConnectionLost;

  final _logController = StreamController<String>.broadcast();
  @override Stream<String> get logStream => _logController.stream;

  SerialPort? _port;
  SerialPortReader? _reader;
  StreamSubscription<Uint8List>? _rxSub;
  Timer? _sessionTimer;
  bool _connected = false;

  final List<int> _receiveBuffer = [];

  bool get isSupported => true;

  @override
  bool get isConnected => _connected;

  void _log(String msg) {
    debugPrint('LINUX_SERIAL: $msg');
    _logController.add(msg);
  }

  // ---------------------------------------------------------------------------
  // Port discovery
  // ---------------------------------------------------------------------------

  /// Enumerates available serial ports and yields them as [DeviceInfo].
  ///
  /// The [DeviceInfo.id] is the port name (e.g. `/dev/ttyACM0`) which is
  /// passed directly to [connect].
  Stream<DeviceInfo> listPorts() async* {
    final ports = SerialPort.availablePorts;
    for (final portName in ports) {
      String displayName = portName;
      try {
        final sp = SerialPort(portName);
        final desc = sp.description;
        final mfr = sp.manufacturer;
        if (desc != null && desc.isNotEmpty) {
          displayName = mfr != null && mfr.isNotEmpty
              ? '$desc ($mfr)'
              : desc;
        }
        sp.dispose();
      } catch (_) {}
      yield DeviceInfo(
        id: portName,
        name: displayName,
        rssi: 0,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Connection
  // ---------------------------------------------------------------------------

  @override
  Future<void> connect(String deviceId, {int baudRate = 1000000}) async {
    await disconnect();

    _log('Opening $deviceId @ $baudRate baud…');
    final port = SerialPort(deviceId);

    if (!port.openReadWrite()) {
      final err = SerialPort.lastError;
      port.dispose();
      throw Exception('Failed to open $deviceId: $err');
    }

    final config = SerialPortConfig()
      ..baudRate = baudRate
      ..bits = 8
      ..stopBits = 1
      ..parity = SerialPortParity.none
      ..setFlowControl(SerialPortFlowControl.none);
    port.config = config;

    _port = port;
    _receiveBuffer.clear();
    _connected = false;

    final reader = SerialPortReader(port, timeout: 100);
    _reader = reader;

    _rxSub = reader.stream.listen(
      _onBytesReceived,
      onError: (e) => _handleDisconnect('Serial read error: $e'),
      onDone: () => _handleDisconnect('Serial port closed'),
    );

    _log('Port opened: $deviceId');
  }

  // ---------------------------------------------------------------------------
  // Receive path
  // ---------------------------------------------------------------------------

  void _onBytesReceived(Uint8List data) {
    _receiveBuffer.addAll(data);
    _processBuffer();
  }

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

  // ---------------------------------------------------------------------------
  // Write path
  // ---------------------------------------------------------------------------

  @override
  Future<void> writePacket(Uint8List data) async {
    final port = _port;
    if (port == null) throw StateError('Serial port not open');
    port.write(data);
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
    _rxSub?.cancel();
    _rxSub = null;
    _reader?.close();
    _reader = null;
    try { _port?.close(); } catch (_) {}
    try { _port?.dispose(); } catch (_) {}
    _port = null;
    onConnectionLost?.call(reason);
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _sessionTimer?.cancel();
    await _rxSub?.cancel();
    _rxSub = null;
    _reader?.close();
    _reader = null;
    try { _port?.close(); } catch (_) {}
    try { _port?.dispose(); } catch (_) {}
    _port = null;
    _receiveBuffer.clear();
  }

  @override
  Future<void> dispose() => disconnect();
}
