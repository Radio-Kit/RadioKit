/// Adapts a [FlSerial] port to implement [SerialPortInterface] from
/// `platform_serial`, allowing it to be injected into [EspTransport].
///
/// This bridges flserial's event-driven streaming API to platform_serial's
/// imperative read/write contract.
///
/// ## DTR/RTS on Android
/// flserial's native `setDTR()`/`setRTS()` only work on Linux (termios ioctl).
/// On Android, we use a custom MethodChannel (`radiokit/usb_control`) backed
/// by [UsbControlTransferPlugin] (Kotlin) which sends CDC
/// `SET_CONTROL_LINE_STATE` (0x21, 0x22) via [UsbDeviceConnection.controlTransfer].
///
/// ## DTR/RTS on Linux
/// flserial's native FFI bindings call termios `TIOCMSET` ioctl directly —
/// this works correctly for `/dev/ttyACM0` and `/dev/ttyUSB*` ports.
library;

import 'dart:async';
import 'dart:convert';

import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flserial/flserial.dart' as fs;
import 'package:platform_serial/platform_serial.dart' as ps;

/// Adapts [fs.FlSerial] to [ps.SerialPortInterface].
class FlserialPortAdapter implements ps.SerialPortInterface {
  final String _portName;
  fs.FlSerial? _serial;
  bool _isOpen = false;
  ps.SerialConfig _config = ps.SerialConfig(portName: '');

  /// Internal read buffer — flserial pushes data as it arrives.
  final List<int> _buffer = [];
  StreamSubscription<Uint8List>? _dataSub;

  /// Completer fired when new data arrives or the port is closed.
  Completer<void>? _readCompleter;

  /// Cached DTR/RTS states for [getControlSignals].
  bool _dtrState = false;
  bool _rtsState = false;

  // Stream controllers for interface compliance.
  final StreamController<Uint8List> _dataStreamController =
      StreamController<Uint8List>.broadcast();
  final StreamController<String> _textStreamController =
      StreamController<String>.broadcast();
  final StreamController<ps.SerialError> _errorStreamController =
      StreamController<ps.SerialError>.broadcast();

  // ── Interface properties ─────────────────────────────────────────

  @override
  ps.SerialConfig get config => _config;

  @override
  bool get isOpen => _isOpen;

  @override
  Stream<Uint8List> get dataStream => _dataStreamController.stream;

  @override
  Stream<String> get textStream => _textStreamController.stream;

  @override
  Stream<ps.SerialError> get errorStream => _errorStreamController.stream;

  // ── Constructor ──────────────────────────────────────────────────

  /// Method channel for flserial's native Android USB plugin.
  /// We invoke 'setControlLines' on it to toggle DTR/RTS through flserial's
  /// already-opened, interface-claimed UsbDeviceConnection.
  static const _flserialChannel = MethodChannel('io.github.grzesl.flserial/usb');

  /// Whether the adapter should use the Android USB control transfer
  /// instead of flserial's native FFI for DTR/RTS.
  static bool get _useAndroidControlTransfer =>
      defaultTargetPlatform == TargetPlatform.android;

  FlserialPortAdapter(this._portName);

  /// Extract the raw device name from flserial's `usb:`-prefixed path.
  /// e.g. `usb:/dev/bus/usb/001/005` → `/dev/bus/usb/001/005`
  String get _androidDeviceName {
    if (_portName.startsWith('usb:')) return _portName.substring(4);
    return _portName;
  }

  // ── Connection lifecycle ─────────────────────────────────────────

  @override
  Future<void> open(ps.SerialConfig config) async {
    // If already open, handle reconfiguration without fully closing.
    // When baud rate changes (e.g. after chip negotiates to flashBaudRate),
    // close and reopen at the new rate. flserial.open() calls _stopSession()
    // internally, which properly teardowns and re-establishes the connection.
    if (_isOpen) {
      if (_config.portName == config.portName &&
          _config.baudRate == config.baudRate) {
        // Already open with matching config — just update and reset buffers.
        _config = config;
        await resetBuffers();
        return;
      }
      // Config changed (e.g. baud rate) — close first so reopen applies
      // the new settings.
      await close();
    }

    _config = config;

    final serial = fs.FlSerial();
    _serial = serial;

    // Subscribe to data events *before* opening to avoid races.
    _dataSub = serial.dataStream.listen(_onData, onError: _onStreamError);

    final fsConfig = fs.SerialConfig(
      baudRate: config.baudRate,
      dataBits: _mapDataBits(config.dataBits),
      stopBits: _mapStopBits(config.stopBits),
      parity: _mapParity(config.parity),
      flowControl: _mapFlowControl(config.flowControl),
    );

    final ok = await serial.open(_portName, fsConfig);
    if (!ok) {
      _dataSub?.cancel();
      _dataSub = null;
      _serial = null;
      throw ps.SerialError(
        type: ps.SerialErrorType.portNotFound,
        message: 'Failed to open $_portName',
      );
    }

    _isOpen = true;
  }

  @override
  Future<void> close() async {
    _isOpen = false;

    // Wake up any pending read.
    _resolveReadCompleter();

    await _dataSub?.cancel();
    _dataSub = null;

    try {
      await _serial?.close();
    } catch (_) {}
    try {
      await _serial?.dispose();
    } catch (_) {}
    _serial = null;

    _buffer.clear();
  }

  // ── Read methods ─────────────────────────────────────────────────

  @override
  Future<Uint8List> readSync({Duration? timeout}) async {
    if (_buffer.isNotEmpty) {
      return _drainBuffer(_buffer.length);
    }
    if (timeout != null) {
      final completer = Completer<void>();
      _readCompleter = completer;
      Timer(timeout, () {
        if (!completer.isCompleted) completer.complete();
      });
      await completer.future;
      return _drainBuffer(_buffer.length);
    }
    return Uint8List(0);
  }

  @override
  Future<String> readTextSync({Duration? timeout}) async {
    final bytes = await readSync(timeout: timeout);
    return utf8.decode(bytes, allowMalformed: true);
  }

  @override
  Future<Uint8List> read(int length, {Duration? timeout}) async {
    if (_buffer.length >= length) return _drainBuffer(length);

    // Set a single timer for the full timeout and let _onData drive the loop.
    final deadline = timeout != null ? DateTime.now().add(timeout) : null;
    Timer? timer;
    if (timeout != null) {
      timer = Timer(timeout, _resolveReadCompleter);
    }

    try {
      while (_buffer.length < length) {
        if (deadline != null && DateTime.now().isAfter(deadline)) break;

        final completer = Completer<void>();
        _readCompleter = completer;
        await completer.future;
      }
    } finally {
      timer?.cancel();
      _readCompleter = null;
    }

    final available = length < _buffer.length ? length : _buffer.length;
    return _drainBuffer(available);
  }

  @override
  Future<String> readUntil(String terminator,
      {Duration? timeout}) async {
    final deadline = timeout != null ? DateTime.now().add(timeout) : null;

    while (true) {
      // Check if terminator is already in buffer.
      final current = utf8.decode(_buffer.toList(), allowMalformed: true);
      final idx = current.indexOf(terminator);
      if (idx >= 0) {
        _buffer.removeRange(0, idx + terminator.length);
        return current.substring(0, idx + terminator.length);
      }

      if (deadline != null && DateTime.now().isAfter(deadline)) {
        // Return everything on timeout.
        final result = utf8.decode(_buffer.take(_buffer.length).toList(),
            allowMalformed: true);
        _buffer.clear();
        return result;
      }

      final completer = Completer<void>();
      _readCompleter = completer;

      final remaining = deadline != null
          ? deadline.difference(DateTime.now())
          : const Duration(milliseconds: 100);

      if (remaining.isNegative || remaining == Duration.zero) break;

      Timer(const Duration(milliseconds: 50), () {
        if (!completer.isCompleted) completer.complete();
      });

      await completer.future;
    }

    // Timeout — return what we have.
    final result =
        utf8.decode(_buffer.take(_buffer.length).toList(), allowMalformed: true);
    _buffer.clear();
    return result;
  }

  // ── Write methods ────────────────────────────────────────────────

  @override
  Future<int> write(Uint8List data, {Duration? timeout}) async {
    if (_serial == null) {
      throw ps.SerialError(
        type: ps.SerialErrorType.portClosed,
        message: 'Port not open',
      );
    }
    _serial!.write(data);
    return data.length;
  }

  @override
  Future<int> writeText(String data, {Duration? timeout}) async {
    final bytes = Uint8List.fromList(utf8.encode(data));
    return write(bytes, timeout: timeout);
  }

  // ── Buffer management ────────────────────────────────────────────

  @override
  Future<void> flush() async {
    // flserial's write is fire-and-forget; nothing to flush.
  }

  @override
  Future<int> bytesAvailable() async => _buffer.length;

  @override
  Future<void> resetBuffers() async {
    _buffer.clear();
    _resolveReadCompleter();
    // flserial doesn't expose a hardware buffer reset, so we just clear Dart
    // side. For the ESP protocol this is sufficient since the sync/connect
    // flow handles stale bytes through the SLIP framing.
  }

  // ── Control signals ──────────────────────────────────────────────

  @override
  Future<ps.SerialControlSignals> getControlSignals() async {
    final modem = _serial?.getModemStatus() ?? {};
    return ps.SerialControlSignals(
      rts: _rtsState,
      dtr: _dtrState,
      cts: modem['CTS'] ?? false,
      dsr: modem['DSR'] ?? false,
      dcd: modem['DCD'] ?? false,
      mask: 0,
    );
  }

  @override
  Future<bool> getCts() async {
    final modem = _serial?.getModemStatus() ?? {};
    return modem['CTS'] ?? false;
  }

  @override
  Future<void> setDtr(bool enabled) async {
    _dtrState = enabled;
    if (_useAndroidControlTransfer) {
      await _androidSetControlLines(_dtrState, _rtsState);
    } else {
      _serial?.setDTR(enabled);
    }
  }

  @override
  Future<void> setRts(bool enabled) async {
    _rtsState = enabled;
    if (_useAndroidControlTransfer) {
      await _androidSetControlLines(_dtrState, _rtsState);
    } else {
      _serial?.setRTS(enabled);
    }
  }

  /// Send CDC SET_CONTROL_LINE_STATE via Android MethodChannel.
  ///
  /// Opens a temporary [UsbDeviceConnection], sends the control transfer,
  /// and closes the connection. This avoids claiming the interface (which
  /// flserial already owns) while still toggling DTR/RTS.
  Future<void> _androidSetControlLines(bool dtr, bool rts) async {
    try {
      await _flserialChannel.invokeMethod<void>(
        'setControlLines',
        {
          'name': _androidDeviceName,
          'dtr': dtr,
          'rts': rts,
        },
      );
    } on MissingPluginException {
      debugPrint('[FlserialPortAdapter] setControlLines not available in flserial plugin');
    } catch (e) {
      debugPrint('[FlserialPortAdapter] setControlLines error: $e');
    }
  }

  // ── Internal helpers ─────────────────────────────────────────────

  void _onData(Uint8List data) {
    _buffer.addAll(data);
    _dataStreamController.add(data);
    _resolveReadCompleter();
  }

  void _onStreamError(Object error) {
    if (error is ps.SerialError) {
      _errorStreamController.add(error);
    }
  }

  void _resolveReadCompleter() {
    final c = _readCompleter;
    if (c != null && !c.isCompleted) {
      c.complete();
    }
    _readCompleter = null;
  }

  Uint8List _drainBuffer(int count) {
    final actual = count.clamp(0, _buffer.length);
    final bytes = Uint8List.fromList(_buffer.sublist(0, actual));
    _buffer.removeRange(0, actual);
    return bytes;
  }

  // ── Config mapping helpers ───────────────────────────────────────

  static int _mapDataBits(int dataBits) => dataBits.clamp(5, 8);

  static int _mapStopBits(ps.SerialStopBits stopBits) {
    switch (stopBits) {
      case ps.SerialStopBits.one:
        return 1;
      case ps.SerialStopBits.onePointFive:
        return 1; // flserial doesn't support 1.5 stop bits; fall back to 1
      case ps.SerialStopBits.two:
        return 2;
    }
  }

  static int _mapParity(ps.SerialParity parity) {
    switch (parity) {
      case ps.SerialParity.none:
        return 0;
      case ps.SerialParity.odd:
        return 1;
      case ps.SerialParity.even:
        return 2;
      case ps.SerialParity.mark:
        return 1; // flserial doesn't support mark parity; fall back to odd
      case ps.SerialParity.space:
        return 0; // flserial doesn't support space parity; fall back to none
    }
  }

  static int _mapFlowControl(ps.SerialFlowControl flowControl) {
    switch (flowControl) {
      case ps.SerialFlowControl.none:
        return 0;
      case ps.SerialFlowControl.rtscts:
        return 1;
      case ps.SerialFlowControl.xonxoff:
        return 2;
    }
  }

  /// Release all resources.
  void dispose() {
    close();
    _dataStreamController.close();
    _textStreamController.close();
    _errorStreamController.close();
  }
}
