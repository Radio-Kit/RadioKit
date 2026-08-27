## 1. Model: showControlPageBar config

- [x] 1.1 Add `bool _showControlPageBar = true` field to `DesignerState`
- [x] 1.2 Add getter `bool get showControlPageBar => _showControlPageBar`
- [x] 1.3 Add `void toggleControlPageBar()` method with `_pushUndo()` + `notifyListeners()`
- [x] 1.4 Serialize `showControlPageBar` in `toJson()` under `canvas.showControlPageBar`
- [x] 1.5 Deserialize `showControlPageBar` in `loadFromJson()` from `canvas.showControlPageBar`, default `true`

## 2. Designer inspector toggle

- [x] 2.1 Add "Show Page Bar in Control UI" `buildBoolToggle` in the CONTROL UI section of `designer_inspector.dart`

## 3. Control UI PageSwitcher rewrite

- [x] 3.1 Rewrite `PageSwitcher` build method: replace dot indicators with horizontally scrollable tab buttons
- [x] 3.2 Tab styling: active tab gets primary background + onPrimary text, inactive gets surface background + outlined border
- [x] 3.3 Gate visibility on `showControlPageBar` from `DesignerState` (read via the device config JSON)
- [x] 3.4 Keep existing logic: hidden when `numPages <= 1` or OTA in progress
- [x] 3.5 Keep existing `sendSetPage()` wiring and haptic feedback on tap

## 4. Control screen integration

- [x] 4.1 Pass `showControlPageBar` config to `PageSwitcher` (or have it read from device config JSON)

## 5. Tests

- [x] 5.1 Add unit tests for `showControlPageBar` toggle, serialization, and default value
- [x] 5.2 Widget tests covered by existing integration tests + manual verification

## 6. Verify

- [x] 6.1 Run `flutter analyze --fatal-warnings`
- [x] 6.2 Run `flutter test` — all tests pass
