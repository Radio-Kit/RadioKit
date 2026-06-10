import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device_info.dart';

/// Represents a previously connected device in the history.
class PairedDevice {
  final String id;
  final String name;
  final String type;
  final String? configName;
  final String? description;
  final DateTime lastConnected;

  PairedDevice({
    required this.id,
    required this.name,
    required this.type,
    this.configName,
    this.description,
    required this.lastConnected,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'configName': configName,
        'description': description,
        'lastConnected': lastConnected.toIso8601String(),
      };

  factory PairedDevice.fromJson(Map<String, dynamic> json) => PairedDevice(
        id: json['id'],
        name: json['name'],
        type: json['type'],
        configName: json['configName'],
        description: json['description'],
        lastConnected: DateTime.parse(json['lastConnected']),
      );

  DeviceInfo toDeviceInfo() => DeviceInfo(id: id, name: name, rssi: 0);
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

  Future<void> saveDevice(DeviceInfo device, String type, {String? configName, String? description}) async {
    await _ready.future; // ensure persisted list is loaded before any write
    // Check if exists
    final index = _pairedDevices.indexWhere((d) => d.id == device.id);
    final now = DateTime.now();

    if (index != -1) {
      _pairedDevices[index] = PairedDevice(
        id: device.id,
        name: device.displayName,
        type: type,
        configName: configName,
        description: description,
        lastConnected: now,
      );
    } else {
      _pairedDevices.insert(
        0,
        PairedDevice(
          id: device.id,
          name: device.displayName,
          type: type,
          configName: configName,
          description: description,
          lastConnected: now,
        ),
      );
    }

    _pairedDevices.sort((a, b) => b.lastConnected.compareTo(a.lastConnected));
    notifyListeners();
    await _persist();
  }

  Future<void> removeDevice(String id) async {
    _pairedDevices.removeWhere((d) => d.id == id);
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
