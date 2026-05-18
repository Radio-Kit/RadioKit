import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart';
import 'package:webserial/webserial.dart';
import '../models/device_info.dart';
import 'protocol_service.dart';
import 'transport_service.dart';
export 'transport_service.dart';

/// Web Serial transport (Chrome / Edge — Web Serial API).
///
/// Uses the `webserial` ^1.1.0 package which wraps `window.navigator.serial`
/// via `dart:js_interop` extension types.
///
/// Flow:
///   1. [listPorts] → calls `serial.requestPort(null)` — shows the browser
///      port picker once and yields the selected port as a [DeviceInfo].
///   2. [connect] → opens the port at 115200 baud and starts the read loop.
///   3. [writePacket] → locks the writable stream, writes, then releases lock.
///
/// [isConnected] returns true for [_kSessionTimeout] after the last valid
/// packet — matching the Arduino firmware's 3-second keep-alive window.
class SerialService implements TransportService {
  static const _kSessionTimeout = Duration(seconds: 3);
  static const _kDefaultBaud = 115200;

  @override PacketReceivedCallback? onPacketReceived;
  @override ConnectionLostCallback? onConnectionLost;

  JSSerialPort? _port;
  Timer? _sessionTimer;
  bool _connected = false;
  bool _reading = false;
  bool _pickerOpen = false;
  ReadableStreamDefaultReader? _reader;

  final List<int> _receiveBuffer = [];

  @override
  bool get isConnected => _connected;

  @override
  Stream<String> get logStream => const Stream.empty();

  @override
  Future<int?> getRssi() async => null;

  bool get isSupported {
    try {
      return serial.isDefinedAndNotNull;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Port discovery — triggers browser picker
  // ---------------------------------------------------------------------------

  /// Opens the browser serial port picker and yields the selected port as a
  /// single [DeviceInfo]. The port is cached internally so [connect] can
  /// open it without showing the picker again.
  Stream<DeviceInfo> listPorts() {
    final controller = StreamController<DeviceInfo>();
    _requestPort(controller);
    return controller.stream;
  }

  Future<void> _requestPort(StreamController<DeviceInfo> controller) async {
    if (!isSupported) {
      controller.addError(Exception(
        'Web Serial is not supported in this browser. Use Chrome or Edge on desktop.',
      ));
      await controller.close();
      return;
    }

    if (_pickerOpen) { await controller.close(); return; }
    _pickerOpen = true;

    try {
      // requestWebSerialPort is the top-level helper from webserial package
      final port = await requestWebSerialPort(null);
      if (port == null) {
        // User cancelled — close silently
        await controller.close();
        return;
      }

      _port = port;

      // Build a display ID from vendor/product IDs when available
      final info = port.getInfo();
      final vid = (info as JSObject).getProperty<JSNumber?>('usbVendorId'.toJS)?.toDartInt.toRadixString(16).padLeft(4, '0') ?? '0000';
      final pid = (info as JSObject).getProperty<JSNumber?>('usbProductId'.toJS)?.toDartInt.toRadixString(16).padLeft(4, '0') ?? '0000';
      final id = 'serial:$vid:$pid';

      controller.add(DeviceInfo(
        id: id,
        name: 'USB Serial ($vid:$pid)',
        rssi: 0,
      ));
    } catch (e) {
      final msg = e.toString();
      // Suppress "user cancelled" errors (NotFoundError / SecurityError)
      if (!msg.contains('NotFoundError') && !msg.contains('SecurityError')) {
        if (!controller.isClosed) controller.addError(Exception('Serial error: $e'));
      }
    } finally {
      _pickerOpen = false;
      if (!controller.isClosed) await controller.close();
    }
  }

  // ---------------------------------------------------------------------------
  // Connection
  // ---------------------------------------------------------------------------

  @override
  Future<void> connect(String deviceId, {int baudRate = _kDefaultBaud}) async {
    final port = _port;
    if (port == null) {
      throw Exception('No serial port selected. Please choose a port first.');
    }

    // Proactive reset: if we think we might be in a weird state, try to close
    // but ignore errors (it might already be closed).
    try {
      await port.close().toDart.timeout(const Duration(milliseconds: 200));
    } catch (_) {}

    // Build JSSerialOptions with baudRate
    final options = JSSerialOptions(
      baudRate: baudRate,
      dataBits: 8,
      stopBits: 1,
      parity: 'none',
      flowControl: 'none',
      bufferSize: 4096,
    );
    await port.open(options).toDart;


    _receiveBuffer.clear();
    _writeQueue.clear();
    _connected = false;
    _reading = true;

    // Assert DTR/RTS to standard "Terminal Ready" states
    // Important for Native USB CDC devices so they know a host is listening
    try {
      await port.setSignals(JSSerialOutputSignals(
        dataTerminalReady: true,
        requestToSend: true,
      )).toDart;
    } catch (_) {}

    _writer = port.writable?.getWriter();

    // Start continuous read loop in background
    _readLoop(port);
  }

  // ---------------------------------------------------------------------------
  // Read loop
  // ---------------------------------------------------------------------------

  Future<void> _readLoop(JSSerialPort port) async {
    final readable = port.readable;
    if (readable == null) {
      _handleDisconnect('Serial port has no readable stream');
      return;
    }

    final reader = readable.getReader() as ReadableStreamDefaultReader;
    _reader = reader;

    try {
      while (_reading) {
        final result = await reader.read().toDart;
        final done = result.done;
        if (done) break;

        final jsValue = result.value as JSUint8Array?;
        if (jsValue != null) {
          final bytes = jsValue.toDart;
          _receiveBuffer.addAll(bytes);
          _processBuffer();
        }
      }
    } catch (e) {
      if (_reading) _handleDisconnect('Serial read error: $e');
    } finally {
      try { reader.releaseLock(); } catch (_) {}
      if (_reader == reader) _reader = null;
    }
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
      } else {
        // Log corrupted packet or junk
        final junk = String.fromCharCodes(packetBytes);
        debugPrint('RadioKit: Junk/Partial data: $junk');
      }
    }
    // If there's 1..5 bytes trailing and we haven't found a 0x55, log them too
    if (_receiveBuffer.isNotEmpty && _receiveBuffer[0] != 0x55) {
      final junk = String.fromCharCodes(_receiveBuffer);
      debugPrint('RadioKit: Serial string: $junk');
      _receiveBuffer.clear();
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

  WritableStreamDefaultWriter? _writer;
  final List<Uint8List> _writeQueue = [];
  bool _isWriting = false;

  @override
  Future<void> writePacket(Uint8List data) async {
    if (_port == null) throw StateError('Serial port not open');

    _writeQueue.add(data);
    _flushWriteQueue();
  }

  Future<void> _flushWriteQueue() async {
    if (_isWriting) return;
    if (_writer == null) return;

    _isWriting = true;
    try {
      while (_writeQueue.isNotEmpty) {
        final chunk = _writeQueue.removeAt(0);
        await _writer!.write(chunk.toJS).toDart;
      }
    } catch (e) {
      debugPrint('RadioKit: Serial write error: $e');
    } finally {
      _isWriting = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Disconnect / dispose
  // ---------------------------------------------------------------------------

  void _handleDisconnect(String reason) {
    _reading = false;
    _connected = false;
    _sessionTimer?.cancel();
    try { _port?.close().toDart; } catch (_) {}
    _port = null;
    onConnectionLost?.call(reason);
  }

  @override
  Future<void> disconnect() async {
    _reading = false;
    _connected = false;
    _sessionTimer?.cancel();
    
    // Grab local references and nullify immediately
    final reader = _reader;
    final writer = _writer;
    final port   = _port;
    _reader = null;
    _writer = null;
    // _port is intentionally NOT nullified here so we can reconnect
    // using the same DeviceInfo object without triggering the picker.

    if (writer != null) {
      try { writer.releaseLock(); } catch (_) {}
    }

    if (reader != null) {
      try {
        // Timeout cancel after 500ms to avoid browser/driver hangs
        await reader.cancel().toDart.timeout(const Duration(milliseconds: 500));
      } catch (e) {
        debugPrint('RadioKit: Error/Timeout cancelling serial reader: $e');
      } finally {
        try { reader.releaseLock(); } catch (_) {}
      }
    }

    if (port != null) {
      try {
        // Timeout close after 500ms to avoid browser/driver hangs
        await port.close().toDart.timeout(const Duration(milliseconds: 500));
      } catch (e) {
        debugPrint('RadioKit: Error/Timeout closing serial port: $e');
      }
    }
    
    _receiveBuffer.clear();
  }

  @override
  Future<void> dispose() => disconnect();
}
