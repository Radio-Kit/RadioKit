## 1. Model: Variable-length telemetry

- [ ] 1.1 Change `_telemetryWidgets` from fixed 4-element list to variable-length `List<Map<String, dynamic>>`
- [ ] 1.2 Add `void addTelemetrySlot()` method (max 4)
- [ ] 1.3 Add `void removeTelemetrySlot(int index)` method (min 0)
- [ ] 1.4 Add `_pushUndo()` calls to `setTelemetryLabel`, `setTelemetryIcon`, `setTelemetryUnit`
- [ ] 1.5 Update `toJson()` to emit variable-length telemetry array
- [ ] 1.6 Update `loadFromJson()` to handle 0-N elements, strip trailing empty slots from legacy 4-element arrays

## 2. Dead code cleanup

- [ ] 2.1 Remove `TelemetryWidgetData` class from `radiokit-app/lib/models/telemetry_widget.dart`
- [ ] 2.2 Remove `kTelemetryIcons` map from `radiokit-app/lib/models/telemetry_widget.dart`
- [ ] 2.3 Remove or update any imports referencing removed code

## 3. Designer inspector UI

- [ ] 3.1 Rewrite `_buildTelemetrySection` to show configured slots with inline icon/label/unit
- [ ] 3.2 Add "[+ Add]" button that calls `addTelemetrySlot()` (hidden when count == 4)
- [ ] 3.3 Add remove button per slot that calls `removeTelemetrySlot(index)`
- [ ] 3.4 Collapse empty trailing slots (only show configured + 1 empty slot)

## 4. DeviceProvider telemetry storage

- [ ] 4.1 Add `_telemetryValues: Map<int, String>` field to `DeviceProvider`
- [ ] 4.2 Add getter `Map<int, String> get telemetryValues`
- [ ] 4.3 Populate `_telemetryValues` from VAR_DATA text values in `_handleVarData`
- [ ] 4.4 Reset `_telemetryValues` on disconnect

## 5. Connection card wiring

- [ ] 5.1 Rewrite `_buildActiveLinkTelemetry` in `models_tab.dart` to read from `deviceProvider.telemetryValues` and config's `telemetryWidgets`
- [ ] 5.2 Show "--" placeholder when no value received yet
- [ ] 5.3 Hide telemetry section when 0 widgets configured

## 6. Codegen

- [ ] 6.1 Update `json_arduino_generator.dart` to handle variable-length telemetry array
- [ ] 6.2 Skip empty slots in code generation

## 7. Tests

- [ ] 7.1 Add unit tests for variable-length telemetry: add, remove, serialization, deserialization
- [ ] 7.2 Add unit tests for undo support on telemetry mutations
- [ ] 7.3 Add unit tests for legacy 4-element array normalization

## 8. Verify

- [ ] 8.1 Run `flutter analyze --fatal-warnings`
- [ ] 8.2 Run `flutter test` — all tests pass
