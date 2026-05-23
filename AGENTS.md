# Guidelines for AI Coding Agents

> [!IMPORTANT]
> Every agent working on this codebase must adhere to these standards.

## 1. Documentation Integrity (Docs-Sync)

- **Rule**: Documentation MUST be updated immediately after any code-level API change.
- **Rule**: Documentation MUST reflect the **current** state of the library only.
- **Rule**: Do not use "transitionary" boxes or alerts (e.g., "Now updated to...") in the reference files. We don't need backward compatibility.
- **Rule**: Avoid "meta-talk" or conversational comments in examples and documentation. Keep comments concise and focused on the code's function.
- **Action**: If you add/remove/update a function, update its corresponding `.md` file in the `docs/` folder. If you change a parameter type, update the signature in the documentation.
- **Goal**: Ensure that the library remains "Plug-and-Play" for human users at all times.

## 2. Using DeepWiki MCP and Github MCP for Research

When working on tasks that require understanding external libraries or codebases, use the **DeepWiki MCP** and **Github MCP** tools before writing or modifying any code.

**When to use DeepWiki MCP:**
- Before integrating or extending support for a third-party library (e.g., NimBLE-Arduino, Flutter packages).
- When the behavior or API of a dependency is unclear or undocumented locally.
- When investigating how a reference implementation works (e.g., `RemoteXY/RemoteXY-Arduino-library`).

**How to use it:**
- Use `read_wiki_structure` to get an overview of a repository's topics.
- Use `read_wiki_contents` to read detailed documentation for a repository.
- Use `ask_question` to ask a targeted question about a specific repo.

> [!TIP]
> Always prefer DeepWiki MCP over assumptions or general knowledge when working with these codebases.

## 3. JSON Config Schema Conventions

The designer serializes/deserializes to a standardized JSON format. All agents must follow these conventions.

### 3.1 Top-level structure

```json
{
  "version": 1,
  "config": { ... },
  "canvas": { ... },
  "widgets": [ ... ]
}
```

### 3.2 Array-based fields (no string encoding)

Use arrays instead of encoded strings wherever possible:

- **Canvas size**: `"size": [200, 100]` (not `"200 x 100"`). Legacy string `"W x H"` is parsed for backward compatibility.
- **Position**: `"position": [x, y, rotation]` (e.g., `[93, 12, 0]`).
- **Size**: `"size": [width, height]` — when a dimension is driven by aspect ratio, emit `null` for that slot (e.g., `[null, 20]` for a square widget where height is primary).
- **AutoCenter**: `"autoCenter": [position, springType, duration]` — see section 3.3.

### 3.3 AutoCenter array format

Auto-center is always stored as a 3-element List:

```
[position, springType, springDuration]
```

- **position**: `null` (disabled) or `"min"` | `"center"` | `"max"` (enabled).
- **springType**: `"smooth"` | `"elastic"` | `"linear"`.
- **springDuration**: integer milliseconds (e.g., `300`, `500`).

Helper functions in `designer_inspector.dart`:
- `_acEnabled(List?)` — returns true when position is not null.
- `_acPosition(List?)` — converts position label to numeric value (0.0, 0.5, 1.0).
- `_acType(List?)` — extracts spring type string.
- `_acDuration(List?, int)` — extracts duration with fallback.
- `_updateACArrayProp(state, id, ac, index, value)` — updates a single slot.

Default values by widget type:
- Slider: `[null, 'smooth', 300]` (disabled)
- GasPedal: `['min', 'smooth', 300]` (enabled, snaps to min)
- Knob: `[null, 'smooth', 500]` (disabled)
- SteeringWheel: `['center', 'smooth', 500]` (enabled, center)
- Joystick: `['center', 'smooth', 300]` (enabled, center)

### 3.4 Label format

In the JSON config, labels use an object format:
```json
"label": { "text": "button_1", "show": true }
```

For display in the code viewer, the `label` object is compacted to a string `"show"`/`"hide"`. The `name` field (C++ identifier) is kept separate and not renamed.

### 3.5 Variant placement

The `variant` field is emitted at the **top level** only for widget types that derive from a base type. It is stripped from `properties` to prevent duplicates:

- **Promoted to top-level** (stripped from properties): `gasPedal`, `steeringWheel`, `multiButton`, `multiSelect`, `rockerSwitch`.
- **Stays in properties** (no top-level variant): `push`/`toggle` (button mode), and any other type-specific variants.

Example output:
```json
{
  "type": "slider",
  "variant": "gasPedal",
  "properties": { "min": 0, "max": 100, ... }
}
```

### 3.6 Widget properties (what goes in `properties` vs top-level)

The `toJson()` method strips these keys from the base properties map before emitting:
- `autoCenter` — serialized separately as an array
- `center`, `springBehavior`, `springDuration` — legacy auto-center keys
- `rotation` — promoted to the `position` array
- `label`, `labelHidden` — promoted to top-level `label` object
- `haptic` — promoted to top-level
- `variant` — conditionally promoted (see 3.5)

## 4. State Management Patterns

- **DesignerState** extends `ChangeNotifier` — always call `notifyListeners()` after mutations.
- Every mutation method calls `_pushUndo()` first (saves current state snapshot to undo stack).
- Use `updateElementProperty(id, key, value)` for individual property changes.
- Use `updateElementSize(id, width:, height:)` for dimension changes (clamped to min/max).
- Use `updateElementPosition(id, x, y)` for position changes (clamped within canvas bounds).
- Use `updateElementRotation(id, rotation)` for rotation changes (normalized to -180..180).
- For complex UI updates (like multi-item editors), batch changes into a single method call.

## 5. Inspector Widget Conventions

### 5.1 Field builders

All inspector fields use `InspectorFieldBuilders` static methods:
- `buildTextField(tokens, label, value, onChanged)` — text input
- `buildNumField(tokens, label, value, onChanged, {min, max})` — numeric input with +/- buttons
- `buildCompactNumField(tokens, label, value, onChanged)` — smaller numeric row
- `buildBoolToggle(tokens, label, value, onChanged)` — boolean toggle switch
- `buildOptionSelector(tokens, label, value, options, onChanged, {suffix})` — dropdown selector
- `buildCenterPinnedSelector(tokens, label, value, options, onChanged)` — segmented button group
- `buildButtonGroup(tokens, label, value, options, onChanged, {labels})` — pill-style segmented buttons
- `buildRotationSlider(tokens, value, onChanged, {onReset})` — rotation angle slider
- `buildSection(tokens, title, children)` — wraps fields in a themed section
- `buildReadOnlyField(tokens, label, value)` — non-editable display

### 5.2 Icon selectors

Use `IconFieldBuilder.buildIconSelectorField(context, label, currentIconName, onChanged)` for icon picker fields. The icon registry is in `kDesignerIcons` (a `Map<String, IconData>`).

### 5.3 Multi-item editors

For `multiButton`/`multiSelect` widgets, use `_DesignerMultiItemEditor` (from `designer_inspector.dart`):
- Each item has `onLabel`, `onIcon`, `offLabel`, `offIcon` (all nullable).
- Items are stored as a list of maps in `properties['items']`.
- Always sync `properties['items']` when `properties['itemCount']` changes.
- Default items auto-generate `onLabel` from sequential letters (A, B, C...).

## 6. Canvas Rendering Conventions

### 6.1 renderedGridSize

Widgets with fixed aspect ratios use `renderedGridSize` (a tuple `(int, int)`) instead of raw `width`/`height` for positioning:
- The aspect-ratio-driven dimension is computed from the primary dimension.
- All positioning in `designer_canvas.dart` uses `renderedGridSize` for pixel-perfect handle alignment.
- The `aspectRatio` getter is positive for horizontal layouts (height primary) and negative for vertical (width primary).

### 6.2 Debug overlay

Pass `showDebug: showDebug` to widgets (true only for the selected element in designer mode, always false in play mode). The global `RKDebugOverlay.enabled` is toggled by the designer screen.

## 7. Code Generation Patterns

- Generated Arduino code lives in `flutter-app/lib/screens/designer/codegen/`.
- The `JsonArduinoGenerator.generate(jsonMap)` method produces complete `RadioKit_UI.h` content.
- The `.h` file embeds the JSON config in a comment block delimited by:
  ```
  /*__RadioKit_UI_Designer_Config__
  ... JSON ...
  RadioKit_UI_Designer_Config__*/
  ```
- The C++ code is always derived from the JSON schema (never hand-edited alongside the designer).
- Widget names use `snake_case` identifiers (e.g., `button_1`, `slider_2`).
- Demo JSON files live in `flutter-app/assets/demos/` and use the same schema.

## 8. Demo Screen Conventions

### 8.1 Layout Structure

The demo screen (`demo_screen.dart`) has a horizontal layout with three columns:

```
[LeftSidebar] [Main area (Expanded)] [Tokens panel | InspectorPanel]
```

- **LeftSidebar**: Category navigation with Inputs/Outputs subheadings, scrollable.
- **Main area**: Top bar + Skins bar (`_AestheticCoreBar`) + scrollable card grid.
- **Right panels**: Tokens panel and InspectorPanel are **mutually exclusive** — only one is shown at a time. The Tokens panel auto-closes when switching widgets.

### 8.2 Skin System

Four skins are available: `DRAGON`, `NEON`, `MINIMAL`, `CUSTOM`.

- Built-in skins (`RKTokens.dragon`, `RKTokens.neon`, `RKTokens.minimal`) are `static const` singletons.
- CUSTOM skin (`_customTokens`) must be initialized as a **distinct instance** — use `RKTokens.dragon.copyWith()` (not `RKTokens.dragon`) to avoid identity collisions with the const singleton.
- The `_AestheticCoreBar` detects CUSTOM via an `isCustom` check: `tokens != RKTokens.dragon && tokens != RKTokens.neon && tokens != RKTokens.minimal`. This uses Dart's default `==` (identity for const objects), so CUSTOM must be a different instance.

### 8.3 Token Editing

- Only CUSTOM skin is editable. Built-in skins show read-only values.
- All six color fields (Primary, OnPrimary, Surface, OnSurface, Track, Glow) are editable in CUSTOM mode.
- Radius and Elevation sliders are also editable for CUSTOM.
- Use `_updateCustom(RKTokens Function(RKTokens) update)` for all token edits. This helper:
  1. Captures `wasCustom = themeNotifier.value == _customTokens` **before** reassignment
  2. Applies the update via `_customTokens = update(_customTokens)`
  3. If CUSTOM was active, re-assigns `themeNotifier.value = _customTokens` to notify `ValueListenableBuilder` listeners

### 8.4 Tokens Panel

- Shown/hidden via `_showTokensPanel` bool toggled by the COLORS button.
- Styled identically to `InspectorPanel`: `width: 320`, `Color(0xFF181818)` background, left `BorderSide(color: Color(0xFF222222))`.
- Header uses `LucideIcons.palette` + "TOKENS" title + close button (same padding/typography as config panel).
- Content is inline (no card sub-container). Uses section headers (skin name, "NUMBERS") styled in `tokens.primary` color (12px monospace, letter-spacing: 1).
- Color rows show a 36×36 swatch + label + hex value. Editable rows have underlined hex, chevron hint, and tap-to-edit via `showColorPickerDialog`.
- Slider rows show label + value + `Slider` widget with `activeColor: _customTokens.primary`.

### 8.5 Color Picker

Use `flex_color_picker` package (`showColorPickerDialog` function):

```dart
final newColor = await showColorPickerDialog(
  context,
  current,
  width: 40,
  height: 40,
  borderRadius: 6,
  wheelDiameter: 180,
  showColorCode: true,
  colorCodeHasColor: true,
  pickersEnabled: const <ColorPickerType, bool>{
    ColorPickerType.wheel: true,
    ColorPickerType.primary: true,
    ColorPickerType.accent: true,
    ColorPickerType.bw: false,
    ColorPickerType.custom: false,
  },
  actionButtons: ColorPickerActionButtons(
    okButton: true,
    closeButton: true,
    dialogActionButtons: false,
  ),
  constraints: BoxConstraints(minHeight: 460, minWidth: 320, maxWidth: 340),
);
if (newColor != current) {
  onPicked(newColor);
}
```

- Keep `enableOpacity` off (avoids web asset loading issue with `opacity.png`).
- Don't forget to add `flex_color_picker: ^3.8.0` to `pubspec.yaml` when using this in a new project.

### 8.6 Color Row Widget

The `_colorRow` method renders each token color as a row with:
- 36×36 swatch with rounded corners (6px), subtle glow shadow, and border (white24 for editable, #444444 for read-only).
- Editable swatches show a `touch_app` icon overlay.
- Hex value displayed as `#RRGGBB` in 12px bold monospace.
- Editable rows have underlined hex and a `chevron_right` icon.

### 8.7 Inspector Panel

- `InspectorPanel` uses sections via `InspectorFieldBuilders.buildSection(tokens, title, children)`.
- Fields use `InspectorFieldBuilders` static methods with 20px horizontal padding and `vertical: 6`.
- The panel header uses `padding: const EdgeInsets.all(20)` with icon + title + optional close button pattern.

## 9. No need for Backward Compatibility

- **Rule**: Only work on the current request, it's okay if it breaks backward compatibility. We can break the API whenever needed.
- **Rule**: We don't need to support old versions of the library. We can drop support for old versions whenever needed.

## 10. PlatformIO (Arduino Build)

PlatformIO is installed globally via `uv tool install platformio` (v6.1.19). It is available as the `pio` command from anywhere.

### 10.1 Build commands

```bash
pio run                          # builds default env (SerialTest)
pio run -e BasicSwitch           # builds a specific example
pio run -e SerialTest -t upload  # flash to board
pio run -e SliderServo           # builds SliderServo (includes ESP32Servo dep)
```

### 10.2 Available environments

Defined in `platformio.ini`:
- `SerialTest` — default, no BLE needed
- `BasicSwitch` — BLE basic switch
- `JoystickMotor` — BLE joystick motor
- `SliderServo` — servo slider (adds ESP32Servo)
- `BLE_RC_Truck` — BLE RC truck

### 10.3 Reinstallation

If `pio` is ever missing or broken:

```bash
uv tool install platformio
```
