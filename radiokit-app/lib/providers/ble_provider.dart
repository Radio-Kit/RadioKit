import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart' hide BleService;
import '../models/device_info.dart';
import '../services/ble_service.dart';

/// Manages BLE scanning state and the list of discovered devices.
class BleProvider extends ChangeNotifier {
  final BleService _bleService = BleService();

  BleProvider() {
    _bleService.availabilityStream.listen((state) {
      notifyListeners();
    });
  }

  List<DeviceInfo> _devices = [];
  bool _isScanning = false;
  String? _errorMessage;

  StreamSubscription<DeviceInfo>? _scanSubscription;
  Timer? _scanLoopTimer;

  List<DeviceInfo> get devices => List.unmodifiable(_devices);
  bool get isScanning => _isScanning;
  String? get errorMessage => _errorMessage;
  BleService get bleService => _bleService;

  bool get isSupported => _bleService.isSupported;
  Future<bool> get isAvailable => _bleService.isAvailable;

  Future<void> startScan() async {
    if (_isScanning) return;

    debugPrint('BLE_PROVIDER: Starting initialization sequence...');
    _devices = [];
    _errorMessage = null;
    notifyListeners();

    // 1. Request permissions
    debugPrint('BLE_PROVIDER: Requesting permissions...');
    await _bleService.requestPermissions();

    // 2. Wait for Bluetooth to be ready
    debugPrint('BLE_PROVIDER: Checking Bluetooth availability...');
    var state = await _bleService.getAvailability();
    debugPrint('BLE_PROVIDER: Current state: ${state.name}');

    if (state == AvailabilityState.poweredOff) {
      debugPrint('BLE_PROVIDER: Bluetooth is OFF, attempting to enable...');
      await _bleService.enableBluetooth();
      
      // Wait for state to change to poweredOn with a timeout
      int retryCount = 0;
      while (state != AvailabilityState.poweredOn && retryCount < 5) {
        debugPrint('BLE_PROVIDER: Waiting for poweredOn (Attempt ${retryCount + 1})...');
        await Future.delayed(const Duration(milliseconds: 1000));
        state = await _bleService.getAvailability();
        debugPrint('BLE_PROVIDER: State is now: ${state.name}');
        retryCount++;
      }
    }

    if (state != AvailabilityState.poweredOn) {
      debugPrint('BLE_PROVIDER: FAILED - Bluetooth not powered on. State: ${state.name}');
      _errorMessage = 'Bluetooth is not ready: ${state.name.toUpperCase()}';
      notifyListeners();
      return;
    }

    // 3. Check Location Services (Android < 12)
    debugPrint('BLE_PROVIDER: Checking Location services...');
    if (!await _bleService.isLocationServiceEnabled) {
      debugPrint('BLE_PROVIDER: FAILED - Location services disabled');
      _errorMessage = 'Location Services must be enabled for scanning.';
      notifyListeners();
      await _bleService.enableLocationServices();
      return;
    }

    debugPrint('BLE_PROVIDER: Initialization complete. Starting scan loop...');
    _isScanning = true;
    notifyListeners();

    _startScanLoop();
  }

  void _startScanLoop() {
    _runScanCycle();
  }

  void _runScanCycle() {
    if (!_isScanning) return;

    // Scan for 4 seconds
    _scanForDuration(const Duration(seconds: 4)).then((_) {
      if (!_isScanning) return;

      // Wait 4 seconds
      _scanLoopTimer = Timer(const Duration(seconds: 4), () {
        _runScanCycle();
      });
    });
  }

  Future<void> _scanForDuration(Duration duration) async {
    await _scanSubscription?.cancel();

    // Accumulate devices in a local batch so stale entries (out-of-range
    // devices) are dropped when the scan window closes.
    final List<DeviceInfo> batch = [];

    _scanSubscription = _bleService.startScan().listen(
      (device) {
        debugPrint('BLE_PROVIDER: Discovery event for ${device.name} (${device.id})');
        final idx = batch.indexWhere((d) => d.id == device.id);
        if (idx >= 0) {
          batch[idx] = device;
        } else {
          batch.add(device);
        }
        // Expose devices incrementally so the UI updates live during scan.
        _devices = List.unmodifiable(batch);
        notifyListeners();
      },
      onError: (error) {
        debugPrint('BLE_PROVIDER: Scan ERROR received in stream: $error');
        _errorMessage = 'Scan error: $error';
        _isScanning = false;
        notifyListeners();
      },
    );

    // Wait for the scan duration
    final completer = Completer<void>();
    Timer(duration, () {
      if (!completer.isCompleted) completer.complete();
    });
    await completer.future;

    // Stop the current scan
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await _bleService.stopScan();

    // Replace _devices with only the batch from this scan window.
    // Devices that went out of range during the scan are dropped.
    _devices = List.unmodifiable(batch);
    notifyListeners();
  }

  Future<void> stopScan() async {
    _scanLoopTimer?.cancel();
    _scanLoopTimer = null;
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await _bleService.stopScan();
    _isScanning = false;
    notifyListeners();
  }

  void useMockDevice() {
    final mock = DeviceInfo(
      id: 'MOCK-UUID-1234',
      name: 'RadioKit Mock Device',
      rssi: -45,
    );
    _devices = [mock];
    notifyListeners();
  }

  @override
  void dispose() {
    _scanLoopTimer?.cancel();
    _scanSubscription?.cancel();
    _bleService.dispose();
    super.dispose();
  }
}
