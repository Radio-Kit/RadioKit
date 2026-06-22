# Hide Widget Feature Spec

## Summary

Add a `hidden` boolean property to RadioKit widgets that controls runtime visibility. The Arduino firmware can toggle `rk.hidden` at any time, and the Flutter companion app renders hidden widgets as invisible in play mode and dimmed/ghosted in the designer canvas.

---

## 1. Requirements

| ID | Requirement |
|----|-------------|
| H1 | Every widget type gains a `rk.hidden` bool field (default `false`) |
| H2 | Arduino code can set `widget.rk.hidden = true/false` in `loop()` at runtime |
| H3 | Flutter play/control mode renders hidden widgets as completely invisible |
| H4 | Designer canvas renders hidden widgets as dimmed/ghosted outlines |
| H5 | The `hidden` flag is transmitted over the protocol (widget state is still sent/received) |
| H6 | Generated `RADIOKIT.h` code is normal (widget fully present), hidden flag is just a property |
| H7 | Designer inspector has an eye/eye-off icon toggle to set the initial hidden state |
| H8 | Protocol encoding uses string mask bit `0x04` (bit 2, `RK_STR_WIDGET_HIDDEN`) |

---

## 2. Protocol Changes

### 2.1 String Mask Bit Allocation

The string mask byte is reorganized. `RK_STR_LABEL` is removed since all widgets always have a label — the label string is unconditionally serialized as the first string in the string section.

New layout in `RadioKitConfig.h` (Arduino) and `protocol.dart` (Flutter):

```
Bit 0 (0x01) — (unused — was RK_STR_LABEL, now always present)
Bit 1 (0x02) — RK_STR_LABEL_HIDDEN  — Label visibility flag (moved from 0x40)
Bit 2 (0x04) — RK_STR_WIDGET_HIDDEN — Widget visibility flag (NEW)
Bit 3 (0x08) — RK_STR_ICON          — Icon string present (moved from 0x02)
Bit 4 (0x10) — RK_STR_ONTEXT        — OnText string present (moved from 0x04)
Bit 5 (0x20) — RK_STR_OFFTEXT       — OffText string present (moved from 0x08)
Bit 6 (0x40) — RK_STR_CONTENT       — Content string present (moved from 0x10)
Bit 7 (0x80) — RK_STR_EXTRA         — Widget-specific binary config (moved from 0x20)
```

### 2.2 Encoding Rules

- The label string is **always** serialized as the first string (no mask bit needed)
- When `rk.labelHidden == true`, set bit 1 (`0x02`) in the mask byte
- When `rk.hidden == true`, set bit 2 (`0x04`) in the mask byte
- When `rk.hidden == false`, bit 2 is clear (no change to existing behavior)
- The hidden flag does NOT suppress string serialization — strings are still sent regardless

### 2.3 Wire Format

The string section in CONF_DATA becomes:

```
[STR_MASK(1)] [LABEL_LEN(1)][LABEL...] (always present)
then for each set bit in STR_MASK:
  ICON(3) → ONTEXT(4) → OFFTEXT(5) → CONTENT(6) → EXTRA(7)
```

---

## 3. Arduino Changes

### 3.1 Widget Base Class (`Widget.h`)

Add to `RK_Widget`:

```cpp
// In public section:
bool        hidden() const { return _hidden; }
void setHidden(bool hidden) { _hidden = hidden; }

// In protected section:
bool     _hidden = false;
```

### 3.2 Serialization (`Widget.cpp`)

Label is always serialized (no mask bit). Add `_hidden` to the mask:

```cpp
// Label is always present (no mask bit needed)
mask |= RK_STR_LABEL_HIDDEN;  // only when _labelHidden is true
if (_hidden) mask |= RK_STR_WIDGET_HIDDEN;
```

### 3.3 Config Header (`RadioKitConfig.h`)

Reorganized constants:

```cpp
#define RK_STR_LABEL_HIDDEN  (1 << 1) ///< Label visibility flag (hidden when set)
#define RK_STR_WIDGET_HIDDEN (1 << 2) ///< Widget visibility flag (hidden when set)
#define RK_STR_ICON          (1 << 3) ///< Icon string present
#define RK_STR_ONTEXT        (1 << 4) ///< OnText string present
#define RK_STR_OFFTEXT       (1 << 5) ///< OffText string present
#define RK_STR_CONTENT       (1 << 6) ///< Content string present
#define RK_STR_EXTRA         (1 << 7) ///< Widget-specific binary config
```

### 3.4 Usage Pattern

```cpp
// In loop():
button_1.rk.hidden = true;   // Hide the button
slider_1.rk.hidden = false;  // Show the slider
```

### 3.5 Shadow Comparison

The shadow comparison in `RadioKit.cpp` uses `memcmp()` on the encoded buffer. Since `_hidden` affects the string mask byte, changes to `rk.hidden` will trigger a re-encode and push the update to connected transports — same as any other field.

---

## 4. Flutter Changes

### 4.1 Protocol Layer

**File: `radiokit-app/lib/models/protocol.dart`**

Reorganized constants:

```dart
const int kStrMaskLabelHidden  = 0x02;  // moved from 0x40
const int kStrMaskWidgetHidden = 0x04;  // NEW
const int kStrMaskIcon         = 0x08;  // moved from 0x02
const int kStrMaskOnText       = 0x10;  // moved from 0x04
const int kStrMaskOffText      = 0x20;  // moved from 0x08
const int kStrMaskContent      = 0x40;  // moved from 0x10
const int kStrMaskExtra        = 0x80;  // moved from 0x20
```

Note: `kStrMaskLabel` (0x01) is removed — label is always present.

### 4.2 Widget Config Model

**File: `radiokit-app/lib/models/widget_config.dart`**

Add field:

```dart
/// Whether the widget is hidden in the UI (set via kStrMaskWidgetHidden bit).
final bool hidden;
```

Update constructor and `copyWith()` to include `hidden`.

### 4.3 Protocol Parser

**File: `radiokit-app/lib/services/protocol_service.dart`**

In the widget parsing logic (around line 471):

```dart
final hidden = (strMask & kStrMaskWidgetHidden) != 0;
```

Pass `hidden` to the `WidgetConfig` constructor.

### 4.4 Widget Renderer

**File: `flutter-widgets/lib/src/widgets/widget_renderer.dart`** (or equivalent)

Wrap widget rendering in an opacity layer when hidden:

```dart
if (widgetConfig.hidden && !isDesignerMode) {
  return const SizedBox.shrink(); // Invisible in play mode
}
```

### 4.5 Designer Element

**File: `flutter-widgets/lib/src/models/designer_element.dart`**

Add field:

```dart
bool hidden;
```

Update constructor, `copyWith()`, `toJson()`, and `fromJson()`.

Serialize to JSON as:

```json
{
  "label": { "text": "button_1", "show": true },
  "hidden": true
}
```

### 4.6 Designer Canvas

**File: `flutter-widgets/lib/src/canvas/canvas_element.dart`**

When `element.hidden == true`, wrap the widget in a dimmed/ghosted wrapper:

```dart
Widget child = _buildWidget(context);

if (element.hidden) {
  child = Opacity(
    opacity: 0.15,
    child: child,
  );
}
```

### 4.7 Designer Inspector

**File: `radiokit-app/lib/screens/designer/widgets/designer_inspector.dart`**

Add an eye/eye-off icon toggle in the inspector panel, similar to the existing `labelHidden` toggle:

- Use `LucideIcons.eye` when visible, `LucideIcons.eyeOff` when hidden
- Place in the same section as the label toggle
- Toggle calls `designerState.updateElementProperty(id, 'hidden', !element.hidden)`

### 4.8 Code Generation

**File: `radiokit-app/lib/screens/designer/codegen/json_arduino_generator.dart`**

Generate the hidden flag in the setup block when the initial state is hidden:

```cpp
button_1.rk.hidden = true;
```

This is generated alongside `labelHidden` assignments.

---

## 5. JSON Config Schema

### 5.1 Widget Entry Format

```json
{
  "type": "button",
  "name": "button_1",
  "label": { "text": "button_1", "show": true },
  "hidden": true,
  "position": [20, 30, 0],
  "size": [40, 40],
  "haptic": true,
  "properties": {
    "variant": "push",
    "onText": "ON",
    "offText": "OFF"
  }
}
```

### 5.2 Backward Compatibility

- Old configs without `"hidden"` field default to `false` (visible)
- Old firmware ignores the unknown bit 2 — widgets remain visible
- No explicit backward compatibility mechanism required (per user preference)

### 5.3 Designer Interaction Rules

Hidden widgets in the designer canvas:
- **Can** be selected by tapping
- **Can** be dragged to reposition
- **Can** be resized via handles
- **Can** be deleted via the inspector
- **Can** be toggled visible again via the eye icon

The ghosted/dimmed rendering (0.15 opacity) is purely visual — all interaction is preserved so the designer remains a functional editing tool.

### 5.4 `toJson()` Property Stripping

The `hidden` field is promoted to top-level (like `label`, `labelHidden`, `haptic`). In `toJson()`, add `hidden` to the list of keys stripped from `baseProps`:

```dart
..remove('hidden')
```

### 5.5 `fromJson()` Parsing

In `fromJson()`, read `hidden` from the top-level JSON key, defaulting to `false` for old configs:

```dart
final bool hiddenVal = (json['hidden'] as bool?) ?? false;
```

### 5.6 Demo JSON Files

Demo configs in `radiokit-app/assets/demos/` do NOT need updating — the `hidden` field defaults to `false`, so existing demos render identically. No changes required.

---

## 6. Remote Access API

The Remote Access API (`/api/widgets`) already transmits widget state as JSON. The `hidden` field will be included in the JSON representation of each widget, so follow mode and remote debugging automatically respect the hidden flag.

---

## 7. Testing

### 7.1 Unit Tests

- `widget_config_test.dart`: Verify `hidden` field defaults to `false`, serialization/deserialization
- `protocol_service_test.dart`: Verify bit 2 parsing in string mask
- `designer_element_test.dart`: Verify `toJson()`/`fromJson()` round-trip with hidden field
- `codegen_test.dart`: Verify generated code includes `rk.hidden = true` when set

### 7.2 Widget Tests

- `designer_canvas_test.dart`: Verify hidden widgets render with reduced opacity
- `designer_inspector_test.dart`: Verify eye toggle works

### 7.3 Integration Test

- Connect to a device with hidden widgets
- Verify hidden widgets are invisible in play mode
- Toggle hidden flag via API and verify UI updates

---

## 8. File Change Summary

| File | Change |
|------|--------|
| `rk-arduino/src/RadioKitConfig.h` | Add `RK_STR_WIDGET_HIDDEN` constant |
| `rk-arduino/src/widgets/Widget.h` | Add `_hidden` field and accessors |
| `rk-arduino/src/widgets/Widget.cpp` | Set bit 2 (`RK_STR_WIDGET_HIDDEN`) in `serializeStrings()` |
| `radiokit-app/lib/models/protocol.dart` | Add `kStrMaskWidgetHidden` constant |
| `radiokit-app/lib/models/widget_config.dart` | Add `hidden` field |
| `radiokit-app/lib/services/protocol_service.dart` | Parse bit 2 in string mask |
| `flutter-widgets/lib/src/models/designer_element.dart` | Add `hidden` field, JSON support |
| `flutter-widgets/lib/src/canvas/canvas_element.dart` | Dimmed rendering for hidden widgets |
| `radiokit-app/lib/screens/designer/widgets/designer_inspector.dart` | Eye toggle UI |
| `radiokit-app/lib/screens/designer/codegen/json_arduino_generator.dart` | Generate `rk.hidden` assignment |
