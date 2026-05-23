import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:usb_serial/usb_serial.dart';
import '../models/device_info.dart';

/// Raw USB Serial service for Android (native).
///
/// Opens a serial port and streams raw bytes in both directions without
/// any RadioKit protocol framing. Designed for:
///   - USB Serial Monitor (raw terminal)
///   - ESP32 Filesystem browser (protocol built on top)
///
/// On non-Android native platforms (iOS, macOS, Linux, Windows) returns
/// [isSupported] = false.
class RawSerialService {
  UsbPort? _port;
  StreamSubscription<Uint8List>? _rxSub;
  final StreamController<List<int>> _dataController =
      StreamController<List<int>>.broadcast();
  bool _connected = false;

  bool get isSupported =>
      defaultTargetPlatform == TargetPlatform.android;

  bool get isConnected => _connected;

  Stream<List<int>> get dataStream => _dataController.stream;

  // ---------------------------------------------------------------------------
  // Port discovery
  // ---------------------------------------------------------------------------

  /// Enumerates attached USB-CDC devices.
  Stream<DeviceInfo> listPorts() async* {
    if (!isSupported) return;
    final devices = await UsbSerial.listDevices();
    for (final d in devices) {
      final serial = d.serial?.isNotEmpty == true ? d.serial! : d.deviceName;
      yield DeviceInfo(
        id: '${d.vid}:${d.pid}:$serial',
        name: d.productName?.isNotEmpty == true
            ? d.productName!
            : d.deviceName,
        rssi: 0,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Connection
  // ---------------------------------------------------------------------------

  Future<void> connect(
    String portId, {
    int baudRate = 1000000,
    int dataBits = 8,
    int stopBits = 1,
    String parity = 'none',
  }) async {
    if (!isSupported) {
      throw UnsupportedError('Raw serial not supported on this platform');
    }

    final devices = await UsbSerial.listDevices();
    UsbDevice? target;
    for (final d in devices) {
      final serial = d.serial?.isNotEmpty == true ? d.serial! : d.deviceName;
      if ('${d.vid}:${d.pid}:$serial' == portId) {
        target = d;
        break;
      }
    }
    if (target == null) throw Exception('USB device "$portId" not found.');

    final port = await target.create();
    if (port == null) throw Exception('Failed to create USB port.');

    final opened = await port.open();
    if (!opened) throw Exception('USB port refused to open.');

    await port.setDTR(true);
    await port.setRTS(true);

    final int parityInt;
    switch (parity) {
      case 'even':
        parityInt = UsbPort.PARITY_EVEN;
        break;
      case 'odd':
        parityInt = UsbPort.PARITY_ODD;
        break;
      default:
        parityInt = UsbPort.PARITY_NONE;
    }

    port.setPortParameters(
      baudRate,
      dataBits,
      stopBits,
      parityInt,
    );

    _port = port;
    _connected = true;

    _rxSub = port.inputStream?.listen(
      (data) => _dataController.add(data.toList()),
      onError: (e) => _handleDisconnect('Read error: $e'),
      onDone: () => _handleDisconnect('Port closed'),
    );
  }

  // ---------------------------------------------------------------------------
  // Write
  // ---------------------------------------------------------------------------

  Future<void> write(List<int> data) async {
    final port = _port;
    if (port == null) throw StateError('Serial port not open');
    await port.write(Uint8List.fromList(data));
  }

  // ---------------------------------------------------------------------------
  // Disconnect
  // ---------------------------------------------------------------------------

  void _handleDisconnect(String reason) {
    _connected = false;
    _rxSub?.cancel();
    _rxSub = null;
    _port?.close();
    _port = null;
  }

  Future<void> disconnect() async {
    _connected = false;
    await _rxSub?.cancel();
    _rxSub = null;
    try {
      await _port?.close();
    } catch (_) {}
    _port = null;
  }

  void dispose() {
    _dataController.close();
    disconnect();
  }
}
