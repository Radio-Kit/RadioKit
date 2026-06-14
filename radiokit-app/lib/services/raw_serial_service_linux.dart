import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import '../models/device_info.dart';

/// Raw USB Serial service for Linux desktop.
///
/// Opens a serial port and streams raw bytes in both directions without
/// any RadioKit protocol framing. Designed for:
///   - USB Serial Monitor (raw terminal)
///   - ESP32 Filesystem browser (protocol built on top)
///
/// Port IDs are device paths (e.g. `/dev/ttyACM0`).
class RawSerialService {
  SerialPort? _port;
  SerialPortReader? _reader;
  StreamSubscription<Uint8List>? _rxSub;
  final StreamController<List<int>> _dataController =
      StreamController<List<int>>.broadcast();
  bool _connected = false;

  bool get isSupported => true;
  bool get isConnected => _connected;
  Stream<List<int>> get dataStream => _dataController.stream;

  // ---------------------------------------------------------------------------
  // Port discovery
  // ---------------------------------------------------------------------------

  Stream<DeviceInfo> listPorts() async* {
    for (final portName in SerialPort.availablePorts) {
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

  Future<void> connect(
    String portId, {
    int baudRate = 1000000,
    int dataBits = 8,
    int stopBits = 1,
    String parity = 'none',
  }) async {
    await disconnect();

    debugPrint('RAW_SERIAL_LINUX: Opening $portId @ $baudRate baud');
    final port = SerialPort(portId);

    if (!port.openReadWrite()) {
      final err = SerialPort.lastError;
      port.dispose();
      throw Exception('Failed to open $portId: $err');
    }

    final int parityConst;
    switch (parity) {
      case 'even':  parityConst = SerialPortParity.even; break;
      case 'odd':   parityConst = SerialPortParity.odd;  break;
      default:      parityConst = SerialPortParity.none;
    }

    final config = SerialPortConfig()
      ..baudRate = baudRate
      ..bits = dataBits
      ..stopBits = stopBits
      ..parity = parityConst
      ..setFlowControl(SerialPortFlowControl.none);
    port.config = config;

    _port = port;
    _connected = true;

    final reader = SerialPortReader(port, timeout: 100);
    _reader = reader;

    _rxSub = reader.stream.listen(
      (data) => _dataController.add(data.toList()),
      onError: (e) => _handleDisconnect('Read error: $e'),
      onDone:  () => _handleDisconnect('Port closed'),
    );
  }

  // ---------------------------------------------------------------------------
  // Write
  // ---------------------------------------------------------------------------

  Future<void> write(List<int> data) async {
    final port = _port;
    if (port == null) throw StateError('Serial port not open');
    port.write(Uint8List.fromList(data));
  }

  // ---------------------------------------------------------------------------
  // Disconnect
  // ---------------------------------------------------------------------------

  void _handleDisconnect(String reason) {
    debugPrint('RAW_SERIAL_LINUX: $reason');
    _connected = false;
    _rxSub?.cancel();
    _rxSub = null;
    _reader?.close();
    _reader = null;
    try { _port?.close(); } catch (_) {}
    try { _port?.dispose(); } catch (_) {}
    _port = null;
  }

  Future<void> disconnect() async {
    _connected = false;
    await _rxSub?.cancel();
    _rxSub = null;
    _reader?.close();
    _reader = null;
    try { _port?.close(); } catch (_) {}
    try { _port?.dispose(); } catch (_) {}
    _port = null;
  }

  void dispose() {
    _dataController.close();
    disconnect();
  }
}
