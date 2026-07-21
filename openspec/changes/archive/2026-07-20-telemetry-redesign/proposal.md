## Why

The telemetry settings in the designer use a rigid 4-slot layout with no way to add/remove widgets, no undo support, and a flat UI that doesn't convey the relationship between configuration and output. Meanwhile, the connection card's telemetry display is hardcoded with placeholder values (`battery=85, speed=42, temp=23`) — the telemetry you configure in the designer never actually appears on the device. This change redesigns the telemetry system end-to-end: a richer inline config experience in the designer, dynamic 0-4 widget support, and wiring the connection card to display real configured telemetry.

## What Changes

- Telemetry widget list becomes variable-length (0-4) instead of always exactly 4
- Empty slots are collapsed in the inspector; users tap [+ Add] to create a new slot
- Each slot shows icon, label, and unit with a compact inline layout
- Undo support added for all telemetry mutations
- Connection card (`_buildActiveLinkTelemetry`) reads from configured telemetry instead of hardcoded values
- Telemetry is automatically disabled when 0 widgets are configured
- Dead code removed: `TelemetryWidgetData` class and `kTelemetryIcons` map
- **BREAKING**: JSON `telemetry` array length is no longer guaranteed to be 4

## Capabilities

### New Capabilities
- `telemetry-config`: Designer-side telemetry configuration with dynamic 0-4 slots, undo support, and inline inspector UI
- `telemetry-display`: Connection card telemetry display showing configured widgets with live values from the device

### Modified Capabilities

## Impact

- `flutter-widgets/lib/src/models/designer_state.dart` — variable-length telemetry, undo support, enable detection
- `radiokit-app/lib/screens/designer/widgets/designer_inspector.dart` — redesigned telemetry section with add/remove
- `radiokit-app/lib/screens/home/models_tab.dart` — wire up `_buildActiveLinkTelemetry` to real data
- `radiokit-app/lib/providers/device_provider.dart` — store telemetry values from VAR_DATA
- `radiokit-app/lib/models/telemetry_widget.dart` — clean up dead code, use real model
- `radiokit-app/lib/screens/designer/codegen/json_arduino_generator.dart` — handle variable-length telemetry
- JSON config schema — `telemetry` array becomes 0-4 elements
