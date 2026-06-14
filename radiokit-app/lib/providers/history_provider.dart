import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device_info.dart';

/// Helper to convert a [TransportType] to its string form.
String _transportTypeToString(TransportType t) {
  switch (t) {
    case TransportType.ble:    return 'ble';
    case TransportType.wifi:   return 'wifi';
    case TransportType.cloud:  return 'cloud';
    case TransportType.serial: return 'serial';
    case TransportType.demo:   return 'demo';
  }
}

/// Represents a previously connected device in the history.
class PairedDevice {
  /// Unique device identity (UID from device NVS or synthetic for demos).
  final String uid;

  final String name;
  final String type;
  final String? configName;
  final String? description;
  final String? preferredTransport;
  final String? deviceIcon;

  /// Per-transport connection addresses for reconnection.
  final String? bleAddress;
  final String? wifiAddress;
  final String? cloudAddress;
  final String? serialAddress;

  /// Cloud account (Ed25519 public key hex) from the device's cloud_info.
  /// Cached so reconnection can decide whether cloud fallback is viable.
  final String? cloudAccount;

  /// Which transport was last used ('ble', 'wifi', 'cloud', 'serial').
  final String? lastUsedTransport;

  final DateTime lastConnected;

  PairedDevice({
    required this.uid,
    required this.name,
    required this.type,
    this.configName,
    this.description,
    this.preferredTransport,
    this.deviceIcon,
    this.bleAddress,
    this.wifiAddress,
    this.cloudAddress,
    this.serialAddress,
    this.cloudAccount,
    this.lastUsedTransport,
    required this.lastConnected,
  });

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'name': name,
        'type': type,
        'configName': configName,
        'description': description,
        'preferredTransport': preferredTransport,
        'deviceIcon': deviceIcon,
        'bleAddress': bleAddress,
        'wifiAddress': wifiAddress,
        'cloudAddress': cloudAddress,
        'serialAddress': serialAddress,
        'cloudAccount': cloudAccount,
        'lastUsedTransport': lastUsedTransport,
        'lastConnected': lastConnected.toIso8601String(),
      };

  factory PairedDevice.fromJson(Map<String, dynamic> json) => PairedDevice(
        uid: (json['uid'] ?? json['id']) as String,  // fallback to old 'id' key
        name: json['name'],
        type: json['type'],
        configName: json['configName'],
        description: json['description'],
        preferredTransport: json['preferredTransport'] as String?,
        deviceIcon: json['deviceIcon'] as String?,
        bleAddress: json['bleAddress'] as String?,
        wifiAddress: json['wifiAddress'] as String?,
        cloudAddress: json['cloudAddress'] as String?,
        serialAddress: json['serialAddress'] as String?,
        cloudAccount: json['cloudAccount'] as String?,
        lastUsedTransport: json['lastUsedTransport'] as String?,
        lastConnected: DateTime.parse(json['lastConnected']),
      );

  /// Create a [DeviceInfo] suitable for reconnection.
  /// Uses [lastUsedTransport] to pick the right transport address.
  DeviceInfo toDeviceInfo() {
    // Determine which transport address to use
    String? address;
    TransportType transport = TransportType.ble;
    final lastType = lastUsedTransport;

    if (lastType == 'wifi' && wifiAddress != null) {
      address = wifiAddress;
      transport = TransportType.wifi;
    } else if (lastType == 'cloud' && cloudAddress != null) {
      address = cloudAddress;
      transport = TransportType.cloud;
    } else if (lastType == 'serial' && serialAddress != null) {
      address = serialAddress;
      transport = TransportType.serial;
    } else if (bleAddress != null) {
      address = bleAddress;
      transport = TransportType.ble;
    } else if (wifiAddress != null) {
      address = wifiAddress;
      transport = TransportType.wifi;
    } else if (cloudAddress != null) {
      address = cloudAddress;
      transport = TransportType.cloud;
    } else if (serialAddress != null) {
      address = serialAddress;
      transport = TransportType.serial;
    } else if (type == 'demo') {
      // Demo device — no real transport address
      return DeviceInfo(
        id: uid,
        name: name,
        rssi: 0,
        preferredTransport: preferredTransport,
        deviceIcon: deviceIcon,
        currentTransport: TransportType.demo,
      );
    }

    return DeviceInfo(
      id: uid,
      name: name,
      rssi: 0,
      preferredTransport: preferredTransport,
      deviceIcon: deviceIcon,
      transportAddress: address,
      currentTransport: transport,
    );
  }
}

/// Manages persistent history of connected devices.
class HistoryProvider extends ChangeNotifier {
  static const _storageKey = 'radiokit_paired_models';
  List<PairedDevice> _pairedDevices = [];
  final Completer<void> _ready = Completer<void>();

  HistoryProvider() {
    _loadHistory();
  }

  List<PairedDevice> get pairedDevices => List.unmodifiable(_pairedDevices);

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_storageKey);
      if (data != null) {
        final List<dynamic> decoded = jsonDecode(data);
        _pairedDevices = decoded.map((e) => PairedDevice.fromJson(e)).toList();
        _pairedDevices.sort((a, b) => b.lastConnected.compareTo(a.lastConnected));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('RadioKit: Failed to load history: $e');
    } finally {
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  /// Save or update a device in history.
  ///
  /// Uses [DeviceInfo.id] as the UID for matching. If a device with the same
  /// UID already exists, the entry is merged (transport address fields are
  /// updated while preserving addresses from other transports).
  Future<void> saveDevice(DeviceInfo device, String type, {String? configName, String? description, String? cloudAccount}) async {
    await _ready.future;
    final uid = device.id;  // DeviceInfo.id is the UID after connection
    final now = DateTime.now();
    final transportStr = _transportTypeToString(device.currentTransport);

    // Find existing entry by UID
    final index = _pairedDevices.indexWhere((d) => d.uid == uid);

    if (index != -1) {
      // Merge: keep existing transport addresses, update current transport's address
      final existing = _pairedDevices[index];
      _pairedDevices[index] = PairedDevice(
        uid: existing.uid,
        name: device.displayName,
        type: type,
        configName: configName ?? existing.configName,
        description: description ?? existing.description,
        preferredTransport: device.preferredTransport ?? existing.preferredTransport,
        deviceIcon: device.deviceIcon ?? existing.deviceIcon,
        bleAddress: device.currentTransport == TransportType.ble
            ? (device.bleAddress ?? device.transportAddress) : existing.bleAddress,
        wifiAddress: device.currentTransport == TransportType.wifi
            ? device.transportAddress : existing.wifiAddress,
        cloudAddress: device.currentTransport == TransportType.cloud
            ? device.transportAddress : existing.cloudAddress,
        serialAddress: device.currentTransport == TransportType.serial
            ? device.transportAddress : existing.serialAddress,
        cloudAccount: cloudAccount ?? existing.cloudAccount,
        lastUsedTransport: transportStr,
        lastConnected: now,
      );
    } else {
      // Create new entry with the current transport's address
      _pairedDevices.insert(
        0,
        PairedDevice(
          uid: uid,
          name: device.displayName,
          type: type,
          configName: configName,
          description: description,
          preferredTransport: device.preferredTransport,
          deviceIcon: device.deviceIcon,
          bleAddress: device.currentTransport == TransportType.ble
              ? (device.bleAddress ?? device.transportAddress) : null,
          wifiAddress: device.currentTransport == TransportType.wifi
              ? device.transportAddress : null,
          cloudAddress: device.currentTransport == TransportType.cloud
              ? device.transportAddress : null,
          serialAddress: device.currentTransport == TransportType.serial
              ? device.transportAddress : null,
          cloudAccount: cloudAccount,
          lastUsedTransport: transportStr,
          lastConnected: now,
        ),
      );
    }

    _pairedDevices.sort((a, b) => b.lastConnected.compareTo(a.lastConnected));
    notifyListeners();
    await _persist();
  }

  /// Remove a device by UID.
  Future<void> removeDevice(String uid) async {
    _pairedDevices.removeWhere((d) => d.uid == uid);
    notifyListeners();
    await _persist();
  }

  Future<void> deleteAll() async {
    _pairedDevices.clear();
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(_pairedDevices.map((e) => e.toJson()).toList());
      await prefs.setString(_storageKey, data);
    } catch (e) {
      debugPrint('RadioKit: Failed to persist history: $e');
    }
  }
}
