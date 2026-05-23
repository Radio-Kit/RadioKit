import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:webserial/webserial.dart';
import '../models/device_info.dart';

/// Raw USB Serial service for web (Chrome/Edge Web Serial API).
///
/// Opens a serial port via the browser's serial port picker and streams raw
/// bytes in both directions without any RadioKit protocol framing.
class RawSerialService {
  JSSerialPort? _port;
  ReadableStreamDefaultReader? _reader;
  WritableStreamDefaultWriter? _writer;
  final StreamController<List<int>> _dataController =
      StreamController<List<int>>.broadcast();
  bool _connected = false;
  bool _reading = false;
  bool _pickerOpen = false;

  bool get isSupported {
    try {
      return serial.isDefinedAndNotNull;
    } catch (_) {
      return false;
    }
  }

  bool get isConnected => _connected;

  Stream<List<int>> get dataStream => _dataController.stream;

  // ---------------------------------------------------------------------------
  // Port discovery — triggers browser picker
  // ---------------------------------------------------------------------------

  /// Opens the browser serial port picker and yields the selected port.
  /// Re-calling will show the picker again (different port).
  Stream<DeviceInfo> listPorts() {
    final controller = StreamController<DeviceInfo>();
    _requestPort(controller);
    return controller.stream;
  }

  Future<void> _requestPort(StreamController<DeviceInfo> controller) async {
    if (!isSupported) {
      controller.addError(Exception(
        'Web Serial is not supported. Use Chrome or Edge on desktop.',
      ));
      await controller.close();
      return;
    }

    if (_pickerOpen) {
      await controller.close();
      return;
    }
    _pickerOpen = true;

    try {
      final port = await requestWebSerialPort(null);
      if (port == null) {
        await controller.close();
        return;
      }

      _port = port;

      final info = port.getInfo();
      final vid =
          (info as JSObject)
              .getProperty<JSNumber?>('usbVendorId'.toJS)
              ?.toDartInt
              .toRadixString(16)
              .padLeft(4, '0') ?? '0000';
      final pid =
          (info as JSObject)
              .getProperty<JSNumber?>('usbProductId'.toJS)
              ?.toDartInt
              .toRadixString(16)
              .padLeft(4, '0') ?? '0000';

      // Also try to get the serial number for stable identification
      final serialNumber =
          (info as JSObject)
              .getProperty<JSString?>('serialNumber'.toJS)
              ?.toDart;

      final id = serialNumber != null
          ? 'serial:$vid:$pid:$serialNumber'
          : 'serial:$vid:$pid';

      controller.add(DeviceInfo(
        id: id,
        name: 'USB Serial ($vid:$pid)',
        rssi: 0,
      ));
    } catch (e) {
      final msg = e.toString();
      if (!msg.contains('NotFoundError') &&
          !msg.contains('SecurityError')) {
        if (!controller.isClosed) {
          controller.addError(Exception('Serial error: $e'));
        }
      }
    } finally {
      _pickerOpen = false;
      if (!controller.isClosed) await controller.close();
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
    final port = _port;
    if (port == null) {
      throw Exception('No serial port selected. Choose a port first.');
    }

    // Close any existing connection first
    try {
      await port.close().toDart.timeout(const Duration(milliseconds: 200));
    } catch (_) {}

    final options = JSSerialOptions(
      baudRate: baudRate,
      dataBits: dataBits,
      stopBits: stopBits,
      parity: parity,
      flowControl: 'none',
      bufferSize: 4096,
    );
    await port.open(options).toDart;

    _connected = true;
    _reading = true;

    try {
      await port
          .setSignals(JSSerialOutputSignals(
            dataTerminalReady: true,
            requestToSend: false,
          ))
          .toDart;
    } catch (_) {}

    _writer = port.writable?.getWriter();
    _readLoop(port);
  }

  // ---------------------------------------------------------------------------
  // Read loop
  // ---------------------------------------------------------------------------

  Future<void> _readLoop(JSSerialPort port) async {
    final readable = port.readable;
    if (readable == null) {
      _handleDisconnect('No readable stream');
      return;
    }

    final reader = readable.getReader() as ReadableStreamDefaultReader;
    _reader = reader;

    try {
      while (_reading) {
        final result = await reader.read().toDart;
        if (result.done) break;

        final jsValue = result.value as JSUint8Array?;
        if (jsValue != null) {
          _dataController.add(jsValue.toDart.toList());
        }
      }
    } catch (e) {
      if (_reading) _handleDisconnect('Read error: $e');
    } finally {
      try {
        reader.releaseLock();
      } catch (_) {}
      if (_reader == reader) _reader = null;
    }
  }

  // ---------------------------------------------------------------------------
  // Write
  // ---------------------------------------------------------------------------

  final List<Uint8List> _writeQueue = [];
  bool _isWriting = false;

  Future<void> write(List<int> data) async {
    if (_port == null) throw StateError('Serial port not open');
    _writeQueue.add(Uint8List.fromList(data));
    _flushWriteQueue();
  }

  Future<void> _flushWriteQueue() async {
    if (_isWriting || _writer == null) return;
    _isWriting = true;
    try {
      while (_writeQueue.isNotEmpty) {
        final chunk = _writeQueue.removeAt(0);
        await _writer!.write(chunk.toJS).toDart;
      }
    } catch (e) {
      debugPrint('RawSerial: write error: $e');
    } finally {
      _isWriting = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Disconnect
  // ---------------------------------------------------------------------------

  void _handleDisconnect(String reason) {
    _reading = false;
    _connected = false;
    disconnect().then((_) {
      _port = null;
    }).catchError((_) {
      _port = null;
    });
  }

  Future<void> disconnect() async {
    _reading = false;
    _connected = false;

    final reader = _reader;
    final writer = _writer;
    final port = _port;
    _reader = null;
    _writer = null;

    if (writer != null) {
      try {
        writer.releaseLock();
      } catch (_) {}
    }
    if (reader != null) {
      try {
        await reader
            .cancel()
            .toDart
            .timeout(const Duration(milliseconds: 500));
      } catch (_) {}
      try {
        reader.releaseLock();
      } catch (_) {}
    }
    if (port != null) {
      try {
        await port
            .close()
            .toDart
            .timeout(const Duration(milliseconds: 500));
      } catch (_) {}
    }
  }

  void dispose() {
    _dataController.close();
    disconnect();
  }
}
