import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:multicast_dns/multicast_dns.dart';
import '../models/device_info.dart';

/// mDNS-based discovery of RadioKit WiFi devices.
///
/// Discovers devices advertising `_radiokit._tcp` service type on the
/// local network. Each discovered device is exposed as a [DeviceInfo]
/// with id `ws://<host>:<port>` using the SRV record target hostname.
///
/// The device name is extracted from the PTR record's domain name
/// (DNS-SD format: <Instance>.<Service>.<Domain>).
///
/// Follows the same pattern as [BleProvider] and [SerialProvider].
class MdnsProvider extends ChangeNotifier {
  List<DeviceInfo> _devices = [];
  bool _isScanning = false;
  String? _errorMessage;

  MDnsClient? _client;
  StreamSubscription<PtrResourceRecord>? _ptrSubscription;
  Timer? _scanTimer;

  List<DeviceInfo> get devices => List.unmodifiable(_devices);
  bool get isScanning => _isScanning;
  String? get errorMessage => _errorMessage;

  /// mDNS uses multicast UDP sockets which are not available on web.
  bool get isSupported => !kIsWeb;

  /// Start scanning for `_radiokit._tcp` services on the local network.
  /// Auto-stops after 8 seconds.
  Future<void> startScan() async {
    if (_isScanning) return;

    debugPrint('MDNS_PROVIDER: Starting mDNS scan...');
    _devices = [];
    _errorMessage = null;
    _isScanning = true;
    notifyListeners();

    try {
      _client = MDnsClient();
      await _client!.start();

      // Listen for PTR records matching our service type.
      // Each PTR record represents one discovered service instance.
      _ptrSubscription = _client!
          .lookup<PtrResourceRecord>(
            ResourceRecordQuery.serverPointer('_radiokit._tcp.local'),
          )
          .listen(
            (ptr) => _handlePtrRecord(ptr),
            onError: (error) {
              debugPrint('MDNS_PROVIDER: Scan error: $error');
              _errorMessage = 'mDNS scan error: $error';
              notifyListeners();
            },
            onDone: () {
              debugPrint('MDNS_PROVIDER: Scan stream done');
            },
          );

      // Auto-stop after 8 seconds
      _scanTimer = Timer(const Duration(seconds: 8), () {
        if (_isScanning) stopScan();
      });
    } catch (e) {
      debugPrint('MDNS_PROVIDER: Failed to start scan: $e');
      _errorMessage = 'mDNS not available: $e';
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Resolve a PTR record to get the full service details (host, port, name).
  Future<void> _handlePtrRecord(PtrResourceRecord ptr) async {
    try {
      // Look up SRV record for target hostname and port
      final srv = await _client!
          .lookup<SrvResourceRecord>(
            ResourceRecordQuery.service(ptr.domainName),
          )
          .first;

      // Extract device name from PTR domain name.
      // DNS-SD format: <Instance>.<Service>.<Domain>
      // e.g. "RK_WiFi_Cloud_Switch._radiokit._tcp.local" → "RK_WiFi_Cloud_Switch"
      final deviceName = _deviceNameFromPtr(ptr.domainName);

      final host = srv.target;
      final port = srv.port;

      // Build the WebSocket URL using the SRV target hostname.
      // mDNS resolves SRV targets on the local network, so the hostname
      // works directly in both AP and STA modes.
      final id = 'ws://$host:$port';
      final name = deviceName.isNotEmpty ? deviceName : host;

      final device = DeviceInfo(
        id: id,
        name: name,
        rssi: 0,
        hasFs: false,
      );

      // Update or add the device
      final idx = _devices.indexWhere((d) => d.id == id);
      if (idx >= 0) {
        _devices[idx] = device;
      } else {
        _devices.add(device);
      }
      debugPrint('MDNS_PROVIDER: Discovered device: $name at $id');
      notifyListeners();
    } catch (e) {
      debugPrint('MDNS_PROVIDER: Failed to resolve PTR record: $e');
    }
  }

  /// Extract the device name from a DNS-SD PTR domain name.
  ///
  /// PTR records follow: <Instance>.<Service>.<Domain>
  /// e.g. "RK_WiFi_Cloud_Switch._radiokit._tcp.local" → "RK_WiFi_Cloud_Switch"
  String _deviceNameFromPtr(String domainName) {
    final dotIndex = domainName.indexOf('.');
    if (dotIndex > 0) {
      return domainName.substring(0, dotIndex);
    }
    return domainName;
  }

  /// Stop an active mDNS scan.
  Future<void> stopScan() async {
    debugPrint('MDNS_PROVIDER: Stopping scan');
    _scanTimer?.cancel();
    _scanTimer = null;
    await _ptrSubscription?.cancel();
    _ptrSubscription = null;
    _client?.stop();
    _client = null;
    _isScanning = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _ptrSubscription?.cancel();
    _client?.stop();
    super.dispose();
  }
}
