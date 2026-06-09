import 'package:flutter/material.dart';

/// Variable type for a telemetry widget value.
enum TelemetryVarType {
  integer,
  floating,
  string,
}

/// A single telemetry widget displayed in the active link card.
///
/// Each widget shows an icon, a formatted value, and an optional unit.
/// Up to 4 telemetry widgets can be configured per device model.
class TelemetryWidgetData {
  /// Icon identifier string (e.g. "battery", "speedometer", "thermometer").
  /// Maps to [kTelemetryIcons] for display.
  final String icon;

  /// The type of the variable value.
  final TelemetryVarType varType;

  /// Optional unit string (e.g. "%", "km/h", "°C").
  final String unit;

  /// Current raw value. For int/float this is a num, for string it's a String.
  dynamic value;

  TelemetryWidgetData({
    required this.icon,
    required this.varType,
    this.unit = '',
    this.value,
  });

  /// The formatted display value string.
  String get displayValue {
    if (value == null) return '--';
    switch (varType) {
      case TelemetryVarType.integer:
        return (value as num).toInt().toString();
      case TelemetryVarType.floating:
        return (value as num).toStringAsFixed(1);
      case TelemetryVarType.string:
        return value as String;
    }
  }

  TelemetryWidgetData copyWith({dynamic value}) {
    return TelemetryWidgetData(
      icon: icon,
      varType: varType,
      unit: unit,
      value: value ?? this.value,
    );
  }
}

/// Maps icon name strings to Material Icons for telemetry display.
const Map<String, IconData> kTelemetryIcons = {
  'battery': Icons.battery_std_rounded,
  'speedometer': Icons.speed_rounded,
  'thermometer': Icons.thermostat_rounded,
  'heartbeat': Icons.favorite_rounded,
  'water': Icons.water_drop_rounded,
  'power': Icons.bolt_rounded,
  'light': Icons.light_mode_rounded,
  'signal': Icons.signal_cellular_alt_rounded,
  'gauge': Icons.speed_rounded,
  'clock': Icons.access_time_rounded,
  'distance': Icons.straighten_rounded,
  'fuel': Icons.local_gas_station_rounded,
  'rpm': Icons.tune_rounded,
  'current': Icons.electric_bolt_rounded,
  'voltage': Icons.electric_meter_rounded,
};

/// Fallback icon for unknown icon names.
const IconData kTelemetryIconFallback = Icons.info_outline_rounded;
