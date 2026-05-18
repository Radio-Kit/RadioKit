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

    debugPrint('BLE_PROVIDER: Initialization complete. Activating scanner...');
    _isScanning = true;
    notifyListeners();

    await _scanSubscription?.cancel();

    _scanSubscription = _bleService.startScan().listen(
      (device) {
        debugPrint('BLE_PROVIDER: Discovery event for ${device.name} (${device.id})');
        final idx = _devices.indexWhere((d) => d.id == device.id);
        if (idx >= 0) {
          _devices[idx] = device;
        } else {
          _devices.add(device);
        }
        notifyListeners();
      },
      onError: (error) {
        debugPrint('BLE_PROVIDER: Scan ERROR received in stream: $error');
        _errorMessage = 'Scan error: $error';
        _isScanning = false;
        notifyListeners();
      },
    );

    // Auto-stop after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (_isScanning) {
        debugPrint('BLE_PROVIDER: Auto-stopping scan after 10s');
        stopScan();
      }
    });
  }

  Future<void> stopScan() async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await _bleService.stopScan();
    _isScanning = false;
    notifyListeners();
  }

  void useMockDevice() {
    final mock = const DeviceInfo(
      id: 'MOCK-UUID-1234',
      name: 'RadioKit Mock Device',
      rssi: -45,
    );
    _devices = [mock];
    notifyListeners();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _bleService.dispose();
    super.dispose();
  }
}
