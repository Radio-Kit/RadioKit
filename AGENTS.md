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

## 9. Filesystem Explorer (M3)

The bulk-FS protocol is exposed in the Flutter app through a Material 3 file explorer screen at `lib/screens/devtools/filesystem/`. New files in this domain MUST follow these conventions:

### 9.1 Sub-directory layout

```
lib/screens/devtools/filesystem/
  filesystem_explorer_screen.dart   # Main screen state + body
  fs_drawer.dart                    # NavigationDrawer (jump-to + format)
  fs_breadcrumbs.dart               # ActionChip row per path segment
  fs_info_strip.dart                # Card.filled + LinearProgressIndicator
  fs_file_tile.dart                 # ListTile wrapper (normal + multi-select)
  fs_action_sheet.dart              # showModalBottomSheet (per-file actions)
  fs_helpers.dart                   # Pure functions: path utils, icon map, formatBytes
```

### 9.2 M3 component rules

- Use `Scaffold` with `AppBar` (M3 surface tint, no custom `Container` chrome).
- Use `ListView` of `ListTile` inside a wrapping `Card` (filled or outlined) — never hand-roll row chrome.
- Use `FloatingActionButton.extended` for primary create action.
- Use `showModalBottomSheet(showDragHandle: true, isScrollControlled: true)` for per-file actions.
- Use `RefreshIndicator` (with `AlwaysScrollableScrollPhysics()`) to allow pull-to-refresh on empty and populated states.
- Use `NavigationDrawer` for jump-to-root / format actions, with a `LinearProgressIndicator` in the header showing storage usage.
- Use `Chip` / `ActionChip` for breadcrumbs (M3 segmented chip look) — never raw text with `Icon`.
- Use `LinearProgressIndicator` for in-progress file operations (upload/download) — not custom progress bars.
- Pull colors from `Theme.of(context).colorScheme` (`primary`, `onSurface`, `onSurfaceVariant`, `primaryContainer`, `errorContainer`, etc.). Avoid `withValues(alpha: ...)` on hard-coded colors when a semantic role exists.
- For destructive actions, use `scheme.error` for icons and `FilledButton.tonal(backgroundColor: scheme.errorContainer, foregroundColor: scheme.onErrorContainer)`.
- For Info / format-confirmation dialogs, use `AlertDialog` with an `icon:` parameter and a `ValueListenableBuilder` to enable the confirm button only when the typed value matches.

### 9.3 Multi-select pattern

- Long-press a `ListTile` to enter selection mode (haptic feedback via `HapticFeedback.mediumImpact()`).
- The AppBar swaps title to `"N selected"` and replaces actions with `select_all` / `delete` icons.
- The FAB is hidden during selection.
- The `ListTile.leading` swaps to a `Checkbox` while in selection mode.
- Add a `Set<String> _selectedPaths` storing the full path (so duplicate basenames in different dirs don't collide).
- A close (`Icons.close_rounded`) leading icon exits selection.

### 9.4 File operations

- All file operations go through `DeviceFsService` (in `lib/services/`). Never call `DeviceProvider.sendFs()` directly from a screen.
- For every long operation, set a `_progress` double (0..1) and render it in a status bar with a `LinearProgressIndicator` + status text.
- After any mutation (upload, delete, mkdir, rename), call `_refresh()` to re-list the current directory.
- `formatFs()` is a destructive action — always wrap in a typed-name confirmation dialog (the device name from `DeviceProvider.connectedDevice`).

### 9.5 Path utilities

- Path manipulation lives in `fs_helpers.dart` (`joinPath`, `parentPath`, `baseName`, `pathSegments`).
- `joinPath('/', 'foo')` returns `/foo` (not `//foo`).
- `parentPath('/')` returns `/` (no-op for root).
- Screens should not compute paths inline — use the helpers.

## 10. Filesystem Demo Mode (No MCU)

The widgets_demo / RC_CONTROLLER / IOT_DASHBOARD connections can be exercised against an in-memory simulated FS, with no Arduino, no serial port, and no second device.

**File layout**:

- `lib/services/demo_fs_state.dart` — pure-Dart in-memory `FsDemoNode` tree (file/dir nodes, recursive delete, quota check). `DemoFsState.seeded()` ships with `/demo/README.txt`, `/demo/sensors.json`, and an empty `/scripts/`. `FsDemoResult` exposes `errOk`/`errNotFound`/`errIo`/`errNoFs`/`errAccessDenied`/`errInvalidPath`/`errOutOfSpace`/`errInvalidState` as static int constants (named to avoid the `const FsDemoResult.ok()` constructor shadowing).
- `lib/services/demo_fs_transport.dart` — `DemoFsTransport` extends `DemoTransport`, intercepts `writePacket` for 0xAA frames, dispatches to `DemoFsState`, fires `onFsPacketReceived` on the next microtask. Default `responseDelay: Duration.zero` (instant); can be raised for visible progress bars.

**Device gating**:

- `lib/models/device_info.dart` — `final bool hasFs` field (default `false`). Demos pass `hasFs: true`; real devices default `false` (real-device detection deferred — no probing on connect).
- `lib/providers/device_provider.dart` — `loadDemo(...)` constructs a `DemoFsTransport` (not the plain `DemoTransport`) and sets `hasFs: true` in the resulting `DeviceInfo`.
- Visibility rule: any UI that exposes FS features must gate the trigger on `device.hasFs`. The canonical example is `_ActiveLinkSection` in `models_tab.dart`, which renders a FILESYSTEM outlined button below OPEN_CONTROLLER only when `device.hasFs` is true. Hidden on real-device connections (for now).

**Payload-size validation gotcha** (caught by unit tests):

- READ handler in `demo_fs_transport.dart` requires `payload.length >= 1 + pathLen + 6` (path_len byte + path + 4-byte offset + 2-byte length). An off-by-2 (`+8`) check rejected every real read. WRITE's `+4` is correct (no trailing length field).
- Sub-command byte positions for 0xAA: byte 1 = subCmd, bytes 2-3 = length. The header strip is `kFsHeaderSize = 4`.

**Adding a new demo connection with FS support**:

1. Pass `hasFs: true` to `DeviceInfo` in `device_provider.dart`.
2. `setTransport(DemoFsTransport())` instead of `setTransport(DemoTransport())`.
3. The `FilesystemExplorerScreen` (`/dev-tools/esp32-fs` route) just checks `isConnected` — works transparently for both real and demo transports.

## 11. Flatpak / Flathub Packaging

### 11.0 Tag convention

Push a tag ending in `-flatpak` (e.g. `test-flatpak`, `v1.0.0-flatpak`) to trigger only the Flatpak build job. The `release` job (Android + iOS) is skipped for these tags. A regular `v*` tag triggers both Android/iOS and (previously) Flatpak — now `*-flatpak` is the dedicated Flatpak-only trigger.

### 11.1 Toolchain

- **flatpak-flutter** is the de facto standard for publishing Flutter apps on Flathub. It pre-processes the manifest to pin all pub.dev dependencies for offline (sandboxed) builds.
- Source: `https://github.com/TheAppgineer/flatpak-flutter`
- Usage pattern:
  ```
  python3 flatpak-flutter.py \
    --app-pubspec flutter-app \
    --extra-pubspecs flutter-library \
    flatpak/flatpak-flutter.yml
  ```

### 11.2 File Structure

```
flatpak/
  flatpak-flutter.yml                    # Input template (committed, hand-written)
  com.rambros3d.radiokit.yml             # Generated output (gitignored, pinned deps)
  com.rambros3d.radiokit.desktop         # Desktop entry
  com.rambros3d.radiokit.metainfo.xml    # AppStream metadata (required by Flathub)
  flathub.json                           # Flathub submission metadata
```

### 11.3 Key details

- **App ID**: `com.rambros3d.radiokit`
- **Runtime**: `org.freedesktop.Platform//24.08`
- **SDK extension**: `org.freedesktop.Sdk.Extension.llvm18` — required for C++ compiler (CMake)
- **Flutter SDK tag**: must match the latest stable Flutter (check `git ls-remote --tags https://github.com/flutter/flutter.git`)
- **Monorepo path dep**: `radiokit_widgets` (`path: ../flutter-library`) is handled via `--extra-pubspecs flutter-library` — the code is already in the git checkout, only its transitive hosted/git deps need pinning
- **`libserialport`**: no separate Flatpak module needed — `flutter_libserialport` bundles and self-builds the C library from `third_party/libserialport/`
- **CMakeLists.txt**: must be tracked in git (add `!**/CMakeLists.txt` to `.gitignore` to override `*.txt` pattern)
- **Icon**: must be ≤512x512px (Flathub limit)
- **Bundle layout**: `flutter build linux --release` produces `bundle/radiokit` + `bundle/lib/*.so` + `bundle/data/`. The binary uses rpath `$ORIGIN/lib`. Install everything under `/app/share/radiokit/` and symlink into `/app/bin/`.
- **Build options**: `append-path: /usr/lib/sdk/llvm18/bin:/run/build/radiokit/flutter/bin` with `CC: clang` and `CXX: clang++` env vars

### 11.4 Permissions (finish-args)

```yaml
finish-args:
  - --socket=wayland
  - --socket=fallback-x11
  - --device=all              # serial ports (/dev/ttyACM*, /dev/ttyUSB*)
  - --socket=system-bus       # BlueZ D-Bus for BLE
  - --talk-name=org.bluez
  - --share=network
  - --filesystem=host         # file picker access
```

### 11.5 Build & verification

```bash
# Pre-process
python3 flatpak-flutter.py --app-pubspec flutter-app --extra-pubspecs flutter-library flatpak/flatpak-flutter.yml

# Build in sandbox (no network)
flatpak-builder --repo=repo --force-clean --sandbox --user --install \
  --install-deps-from=flathub \
  build flatpak/com.rambros3d.radiokit.yml

# Run
flatpak run com.rambros3d.radiokit
```

### 11.6 CI

The `.github/workflows/release.yml` has a `flatpak` job that runs after the Android/iOS release job. It:
1. Installs flatpak-builder, flatpak-flutter, runtimes, and `org.freedesktop.Sdk.Extension.llvm18` (C++ compiler)
2. Pre-processes the manifest with `--extra-pubspecs flutter-library`
3. Builds with flatpak-builder (no `--sandbox` for CI stability)
4. Exports `.flatpak` bundle
5. Uploads to the existing GitHub Release

### 11.7 Flathub submission

- Fork `https://github.com/flathub/flathub`
- Place the **generated** `com.rambros3d.radiokit.yml`, `.desktop`, `metainfo.xml`, and `flathub.json` at `flatpak/applications/com.rambros3d.radiokit/`
- Open a PR — Flathub bot builds and verifies

## 12. No need for Backward Compatibility

- **Rule**: Only work on the current request, it's okay if it breaks backward compatibility. We can break the API whenever needed.
- **Rule**: We don't need to support old versions of the library. We can drop support for old versions whenever needed.

## 13. PlatformIO (Arduino Build)

PlatformIO is installed globally via `uv tool install platformio` (v6.1.19). It is available as the `pio` command from anywhere.

### 13.1 Build commands

Each example has its own `platformio.ini` in its directory. Build from that directory:

```bash
pio run                      # builds the example (default env)
pio run -t upload            # flash to board
```

### 13.2 Available examples

Each directory under `arduino-library/examples/` has a self-contained `platformio.ini`:
- `SerialTest` — Serial transport demo
- `BasicSwitch` — BLE basic switch
- `JoystickMotor` — BLE joystick motor
- `SliderServo` — servo slider (adds ESP32Servo)
- `BLE_RC_Truck` — BLE RC truck
- `Filesystem_LED` — bulk-FS demo with LittleFS

### 13.3 Reinstallation

If `pio` is ever missing or broken:

```bash
uv tool install platformio
```
