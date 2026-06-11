/// Represents a discovered BLE device during scanning.
class DeviceInfo {
  final String id;
  final String name;
  final int rssi;

  /// Whether the device exposes the bulk-FS (0xAA) protocol.
  /// Demos hardcode `true`; real devices need a probe (TODO).
  final bool hasFs;

  /// Preferred transport for connecting to this device.
  /// `null` or `'auto'` means auto-detect (use whatever was used last).
  /// `'ble'`, `'wifi'`, `'cloud'` for explicit preference.
  final String? preferredTransport;

  const DeviceInfo({
    required this.id,
    required this.name,
    required this.rssi,
    this.hasFs = false,
    this.preferredTransport,
  });

  /// Return a new [DeviceInfo] with the given fields replaced.
  DeviceInfo copyWith({String? name, int? rssi, bool? hasFs, String? preferredTransport}) {
    return DeviceInfo(
      id: id,
      name: name ?? this.name,
      rssi: rssi ?? this.rssi,
      hasFs: hasFs ?? this.hasFs,
      preferredTransport: preferredTransport ?? this.preferredTransport,
    );
  }

  /// Display name — falls back to 'Unknown Device' if no name is advertised.
  String get displayName => name.isNotEmpty ? name : 'Unknown Device';

  /// Signal quality classification based on RSSI.
  SignalStrength get signalStrength {
    if (rssi >= -60) return SignalStrength.excellent;
    if (rssi >= -70) return SignalStrength.good;
    if (rssi >= -80) return SignalStrength.fair;
    return SignalStrength.weak;
  }

  /// Number of signal bars to display (1-4).
  int get signalBars {
    switch (signalStrength) {
      case SignalStrength.excellent:
        return 4;
      case SignalStrength.good:
        return 3;
      case SignalStrength.fair:
        return 2;
      case SignalStrength.weak:
        return 1;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is DeviceInfo && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'DeviceInfo(id=$id, name=$name, rssi=$rssi)';
}

enum SignalStrength { excellent, good, fair, weak }
