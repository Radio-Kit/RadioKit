import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:usb_serial/usb_serial.dart';
import '../models/device_info.dart';
import 'protocol_service.dart';
import 'transport_service.dart';
export 'transport_service.dart';

/// Native USB-CDC Serial transport (Android).
///
/// Uses the `usb_serial` ^0.5.2 package to enumerate USB-CDC devices
/// (FTDI, CDC ACM, CP210x, CH340 …) and open a bidirectional byte stream.
/// Received bytes are fed into the same RadioKit framing buffer used by
/// the BLE service.
///
/// [isConnected] returns true for [_kSessionTimeout] after the last valid
/// packet — matching the Arduino firmware's 3-second keep-alive window.
class SerialService implements TransportService {
  static const _kSessionTimeout = Duration(seconds: 3);
  static const _kDefaultBaud = 1000000;

  @override PacketReceivedCallback? onPacketReceived;
  @override ConnectionLostCallback? onConnectionLost;
  
  final _logController = StreamController<String>.broadcast();
  @override Stream<String> get logStream => _logController.stream;



  UsbPort? _port;
  StreamSubscription<Uint8List>? _rxSub;
  Timer? _sessionTimer;
  bool _connected = false;

  final List<int> _receiveBuffer = [];

  bool get isSupported => true;

  @override
  bool get isConnected => _connected;

  // ---------------------------------------------------------------------------
  // Port discovery
  // ---------------------------------------------------------------------------

  /// Enumerates attached USB-CDC devices and yields them as [DeviceInfo].
  /// The [DeviceInfo.id] encodes `"<vid>:<pid>:<serial|deviceName>"` so
  /// that [connect] can locate the exact device.
  Stream<DeviceInfo> listPorts() async* {
    final devices = await UsbSerial.listDevices();
    for (final d in devices) {
      final serial = d.serial?.isNotEmpty == true ? d.serial! : d.deviceName;
      yield DeviceInfo(
        id: '${d.vid}:${d.pid}:$serial',
        name: d.productName?.isNotEmpty == true
            ? d.productName!
            : d.deviceName,
        rssi: 0, // not applicable for serial
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Connection
  // ---------------------------------------------------------------------------

  @override
  Future<void> connect(String deviceId, {int baudRate = _kDefaultBaud}) async {
    final devices = await UsbSerial.listDevices();

    UsbDevice? target;
    for (final d in devices) {
      final serial = d.serial?.isNotEmpty == true ? d.serial! : d.deviceName;
      if ('${d.vid}:${d.pid}:$serial' == deviceId) {
        target = d;
        break;
      }
    }
    if (target == null) throw Exception('USB device "$deviceId" not found.');

    final port = await target.create();
    if (port == null) throw Exception('Failed to create USB port.');

    final opened = await port.open();
    if (!opened) throw Exception('USB port refused to open.');

    await port.setDTR(true);
    await port.setRTS(true);
    port.setPortParameters(
      baudRate,
      UsbPort.DATABITS_8,
      UsbPort.STOPBITS_1,
      UsbPort.PARITY_NONE,
    );

    _port = port;
    _receiveBuffer.clear();
    _connected = false;

    _rxSub = port.inputStream?.listen(
      _onBytesReceived,
      onError: (e) => _handleDisconnect('Serial read error: $e'),
      onDone: ()   => _handleDisconnect('Serial port closed'),
    );
  }

  // ---------------------------------------------------------------------------
  // Receive path
  // ---------------------------------------------------------------------------

  void _onBytesReceived(Uint8List data) {
    _receiveBuffer.addAll(data);
    _processBuffer();
  }

  void _processBuffer() {
    while (_receiveBuffer.length >= 6) {
      final startIdx = _receiveBuffer.indexOf(0x55);
      if (startIdx < 0) { _receiveBuffer.clear(); return; }
      if (startIdx > 0) { _receiveBuffer.removeRange(0, startIdx); continue; }

      if (_receiveBuffer.length < 3) return;
      final length = _receiveBuffer[1] | (_receiveBuffer[2] << 8);

      if (length < 6) { _receiveBuffer.removeAt(0); continue; }
      if (_receiveBuffer.length < length) return;

      final packetBytes = _receiveBuffer.sublist(0, length);
      _receiveBuffer.removeRange(0, length);

      final packet = ProtocolService.parsePacket(packetBytes);
      if (packet != null) {
        _connected = true;
        _resetSessionTimer();
        onPacketReceived?.call(packet);
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
    await port.write(data);
  }

  @override
  Future<int?> getRssi() async => null;

  // ---------------------------------------------------------------------------
  // Disconnect / dispose
  // ---------------------------------------------------------------------------

  void _handleDisconnect(String reason) {
    _connected = false;
    _sessionTimer?.cancel();
    _rxSub?.cancel();
    _rxSub = null;
    _port?.close();
    _port = null;
    onConnectionLost?.call(reason);
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _sessionTimer?.cancel();
    await _rxSub?.cancel();
    _rxSub = null;
    try { await _port?.close(); } catch (_) {}
    _port = null;
    _receiveBuffer.clear();
  }

  @override
  Future<void> dispose() => disconnect();
}
