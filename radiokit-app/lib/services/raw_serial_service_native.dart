/// Native raw serial service dispatcher.
///
/// `dart.library.io` is true on Android, iOS, and all desktop platforms.
/// Runtime platform check routes to the correct concrete implementation.
///
///   Android → uses usb_serial (this file contains the Android impl)
///   Linux   → delegates to RawSerialService from raw_serial_service_linux.dart
///   Other   → isSupported = false (stub behaviour)
library;

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:usb_serial/usb_serial.dart';
import '../models/device_info.dart';

// Linux implementation (flutter_libserialport)
import 'raw_serial_service_linux.dart' as linux;

/// Platform-dispatched raw serial service.
///
/// On Android wraps USB-CDC via usb_serial.
/// On Linux wraps termios ports via flutter_libserialport.
/// On other platforms returns [isSupported] = false.
class RawSerialService {
  // On Linux, delegate every call to the Linux implementation.
  final linux.RawSerialService? _linuxImpl =
      defaultTargetPlatform == TargetPlatform.linux
          ? linux.RawSerialService()
          : null;

  UsbPort? _port;
  StreamSubscription<Uint8List>? _rxSub;
  final StreamController<List<int>> _dataController =
      StreamController<List<int>>.broadcast();
  bool _androidConnected = false;

  bool get isSupported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.linux;

  bool get isConnected {
    if (_linuxImpl != null) return _linuxImpl.isConnected;
    return _androidConnected;
  }

  Stream<List<int>> get dataStream {
    if (_linuxImpl != null) return _linuxImpl.dataStream;
    return _dataController.stream;
  }

  // ---------------------------------------------------------------------------
  // Port discovery
  // ---------------------------------------------------------------------------

  Stream<DeviceInfo> listPorts() async* {
    if (_linuxImpl != null) {
      yield* _linuxImpl.listPorts();
      return;
    }
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
    if (_linuxImpl != null) {
      return _linuxImpl.connect(
        portId,
        baudRate: baudRate,
        dataBits: dataBits,
        stopBits: stopBits,
        parity: parity,
      );
    }
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
      case 'even':  parityInt = UsbPort.PARITY_EVEN; break;
      case 'odd':   parityInt = UsbPort.PARITY_ODD;  break;
      default:      parityInt = UsbPort.PARITY_NONE;
    }

    port.setPortParameters(baudRate, dataBits, stopBits, parityInt);

    _port = port;
    _androidConnected = true;

    _rxSub = port.inputStream?.listen(
      (data) => _dataController.add(data.toList()),
      onError: (e) => _handleAndroidDisconnect('Read error: $e'),
      onDone: () => _handleAndroidDisconnect('Port closed'),
    );
  }

  // ---------------------------------------------------------------------------
  // Write
  // ---------------------------------------------------------------------------

  Future<void> write(List<int> data) async {
    if (_linuxImpl != null) return _linuxImpl.write(data);
    final port = _port;
    if (port == null) throw StateError('Serial port not open');
    await port.write(Uint8List.fromList(data));
  }

  // ---------------------------------------------------------------------------
  // Disconnect
  // ---------------------------------------------------------------------------

  void _handleAndroidDisconnect(String reason) {
    _androidConnected = false;
    _rxSub?.cancel();
    _rxSub = null;
    _port?.close();
    _port = null;
  }

  Future<void> disconnect() async {
    if (_linuxImpl != null) return _linuxImpl.disconnect();
    _androidConnected = false;
    await _rxSub?.cancel();
    _rxSub = null;
    try { await _port?.close(); } catch (_) {}
    _port = null;
  }

  void dispose() {
    if (_linuxImpl != null) {
      _linuxImpl.dispose();
      return;
    }
    _dataController.close();
    disconnect();
  }
}
