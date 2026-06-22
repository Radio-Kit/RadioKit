import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/device_info.dart';
import '../services/serial_service.dart';

/// Manages Serial port discovery state and the [SerialService] instance.
///
/// Mirrors [BleProvider] so that [ScanScreen] can treat both uniformly.
class SerialProvider extends ChangeNotifier {
  final SerialService _serialService = SerialService();

  List<DeviceInfo> _ports = [];
  bool _isScanning = false;
  String? _errorMessage;

  StreamSubscription<DeviceInfo>? _scanSubscription;
  Timer? _scanLoopTimer;

  List<DeviceInfo> get ports => List.unmodifiable(_ports);
  bool get isScanning => _isScanning;
  String? get errorMessage => _errorMessage;
  SerialService get serialService => _serialService;
  bool get isSupported => _serialService.isSupported;

  // ---------------------------------------------------------------------------
  // Port discovery
  // ---------------------------------------------------------------------------

  /// On native: enumerates attached USB-CDC devices and populates [ports].
  /// On web: opens the browser port picker (one-shot).
  ///
  /// Scans every second on native, one-shot on web.
  Future<DeviceInfo?> startScan() async {
    if (_isScanning) return _ports.isNotEmpty ? _ports.first : null;

    debugPrint('SERIAL_PROVIDER: Starting scan loop...');
    _ports = [];
    _errorMessage = null;
    _isScanning = true;
    notifyListeners();

    if (kIsWeb) {
      // Web: one-shot scan (browser picker)
      return _scanOnce();
    } else {
      // Native: scan every second
      _startScanLoop();
      return null;
    }
  }

  void _startScanLoop() {
    _scanOnce();
    _scanLoopTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _scanOnce();
    });
  }

  Future<DeviceInfo?> _scanOnce() async {
    final completer = Completer<DeviceInfo?>();
    
    await _scanSubscription?.cancel();

    // Accumulate ports in a local list so stale entries (unplugged devices)
    // are dropped when the stream completes with only the current set.
    final List<DeviceInfo> batch = [];

    _scanSubscription = _serialService.listPorts().listen(
      (port) {
        batch.add(port);
        if (!completer.isCompleted) completer.complete(port);
      },
      onError: (error) {
        _errorMessage = 'Serial scan error: $error';
        _isScanning = false;
        _ports = [];
        notifyListeners();
        if (!completer.isCompleted) completer.complete(null);
      },
      onDone: () {
        _ports = List.unmodifiable(batch);
        notifyListeners();
        if (!completer.isCompleted) completer.complete(null);
      },
    );

    return completer.future;
  }

  /// Stop an active scan (no-op on web where the picker is one-shot).
  Future<void> stopScan() async {
    _scanLoopTimer?.cancel();
    _scanLoopTimer = null;
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    _isScanning = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _scanLoopTimer?.cancel();
    _scanSubscription?.cancel();
    _serialService.dispose();
    super.dispose();
  }
}
