# Guidelines for AI Coding Agents

> [!IMPORTANT]
> Every agent working on this codebase must adhere to these standards.

## 1. Documentation Integrity (Docs-Sync)

- **Rule**: Documentation MUST be updated immediately after any code-level API change.
- **Rule**: Documentation MUST reflect the **current** state of the library only.
- **Rule**: Do not use "transitionary" boxes or alerts (e.g., "Now updated to...") in the reference files. We don't need backward compatibility.
- **Rule**: Avoid "meta-talk" or conversational comments in examples and documentation. Keep comments concise and focused on the code's function.
- **Action**: If you add/remove/update a function, update its corresponding `.mdx` file in the `website/src/content/docs/` folder. If you change a parameter type, update the signature in the documentation.
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

- **Promoted to top-level** (stripped from properties): `gasPedal`, `steeringWheel`, `multiButton`, `multiSelect`, `rockerSwitch`, `slideSwitch`.
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
- `hidden` — promoted to top-level (see section 21)

### 3.7 Transports config

The `config` object includes a `transports` map (replaces the old `transport` string). Each transport sub-object has an `enabled` boolean and optional config fields:

```json
"transports": {
  "ble": { "enabled": true },
  "wifi": { "enabled": false, "ssid": "", "pass": "" },
  "cloud": { "enabled": false, "account": "", "relay": "" }
}
```

- `ble.enabled` defaults to `true` in `loadFromJson()` fallback.
- `wifi.ssid` / `wifi.pass` are written to NVS as `sta_ssid` / `sta_password` on first boot.
- `cloud.account` / `cloud.relay` are written to NVS as `cloud_account` / `cloud_url` on first boot.
- The old `transport: "BLE"` string field is removed. No backward compatibility.

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

- Generated Arduino code lives in `radiokit-app/lib/screens/designer/codegen/`.
- The `JsonArduinoGenerator.generate(jsonMap)` method produces complete `RADIOKIT.h` content.
- The `.h` file embeds the JSON config in a comment block delimited by:
  ```
  /*__RADIOKIT_Designer_Config__
  ... JSON ...
  RADIOKIT_Designer_Config__*/
  ```
- The C++ code is always derived from the JSON schema (never hand-edited alongside the designer).
- Widget names use `snake_case` identifiers (e.g., `button_1`, `slider_2`).
- Demo JSON files live in `radiokit-app/assets/demos/` and use the same schema.

### 7.1 Transport Toggles and `#define` Directives

The JSON config uses a nested `transports` object (not a flat `transport` string). The codegen emits compile-time `#define` directives at the **top** of the header, before `#include <RadioKitLib.h>`.

**JSON schema (`config.transports`):**
```json
"transports": {
  "ble": { "enabled": true },
  "wifi": { "enabled": false, "ssid": "", "pass": "" },
  "cloud": { "enabled": false, "account": "", "relay": "" }
}
```

**Generated C++ output:**
```cpp
// Transports
#define ENABLE_RK_SERIAL
#define ENABLE_RK_BLE
// #define ENABLE_RK_WIFI
// #define ENABLE_RK_CLOUD

#include <RadioKitLib.h>
// ... widget declarations ...

void setup() {
  RadioKit.begin();
#ifdef ENABLE_RK_SERIAL
  RadioKit.startSerial(Serial);
#endif
#ifdef ENABLE_RK_BLE
  RadioKit.startBLE(RadioKit.config.name);
#endif
}
```

**Rules:**
- Serial is always on (`#define ENABLE_RK_SERIAL` emitted unconditionally). Users manually comment it out to disable.
- `#define` directives are a **codegen-only** pattern — they gate the generated `setup()` code, not the library internals. The Arduino library uses runtime NVS checks (`rk_ble_on`, `rk_wifi_on`, `rk_cloud_on`) independently.
- WiFi/Cloud config fields (`sta_ssid`, `sta_password`, `cloud_url`, `cloud_account`) are emitted only when the respective transport is enabled AND the value is non-empty.
- Start call ordering: Serial -> BLE -> WiFi -> Cloud. Cloud requires WiFi to be started first.
- The old `config.transport = "BLE"` line is no longer emitted (vestigial field in `RK_Config`).
- The JSON `config.transports` object is embedded in the `.h` file comment block for re-import by the header parser.

### 7.2 Page-Grouped Output Format

For multi-page configs (version >= 2), the generated code groups widgets by page:

```cpp
// Transports
#define ENABLE_RK_SERIAL
#define ENABLE_RK_BLE

// Page definitions
#define RK_NUM_PAGES 2
const char* rk_pageNames[] = {"Control", "Settings"};

// --- Page 0: Control ---
Button button_1;
Slider slider_1;

// --- Page 1: Settings ---
Switch switch_1;

void setup() {
  RadioKit.setNumPages(RK_NUM_PAGES);
  RadioKit.begin();
  // ... widget init ...
  button_1.rk.label = "Forward";
  slider_1.rk.page = 1;  // only emitted for page > 0
}
```

Key rules:
- Widget names are globally sequential across pages (button_1, slider_1, switch_1).
- `rk.page = N;` is emitted only when pageIndex > 0 (page 0 is the default).
- `#define RK_NUM_PAGES` and `rk_pageNames[]` are emitted only for multi-page configs.
- `RadioKit.setNumPages(RK_NUM_PAGES)` is called before `RadioKit.begin()` in setup.
- For single-page configs (v1 format), no page-related code is emitted.

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
- Color rows show a 36x36 swatch + label + hex value. Editable rows have underlined hex, chevron hint, and tap-to-edit via `showColorPickerDialog`.
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
- 36x36 swatch with rounded corners (6px), subtle glow shadow, and border (white24 for editable, #444444 for read-only).
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
    --app-pubspec radiokit-app \
    --extra-pubspecs flutter-widgets \
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
- **Monorepo path dep**: `radiokit_widgets` (`path: ../flutter-widgets`) is handled via `--extra-pubspecs flutter-widgets` — the code is already in the git checkout, only its transitive hosted/git deps need pinning
- **`libserialport`**: no separate Flatpak module needed — `flutter_libserialport` bundles and self-builds the C library from `third_party/libserialport/`
- **CMakeLists.txt**: must be tracked in git (add `!**/CMakeLists.txt` to `.gitignore` to override `*.txt` pattern)
- **Icon**: must be <=512x512px (Flathub limit)
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
python3 flatpak-flutter.py --app-pubspec radiokit-app --extra-pubspecs flutter-widgets flatpak/flatpak-flutter.yml

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
2. Pre-processes the manifest with `--extra-pubspecs flutter-widgets`
3. Builds with flatpak-builder (no `--sandbox` for CI stability)
4. Exports `.flatpak` bundle
5. Uploads to the existing GitHub Release

### 11.7 Flathub submission

- Fork `https://github.com/flathub/flathub`
- Place the **generated** `com.rambros3d.radiokit.yml`, `.desktop`, `metainfo.xml`, and `flathub.json` at `flatpak/applications/com.rambros3d.radiokit/`
- Open a PR — Flathub bot builds and verifies

## 12. Follow Mode (Remote Access Navigation)

### 12.1 App-level wrapper (`_FollowModeWrapper`)

- **Location**: `radiokit-app/lib/app.dart` — wraps all routes above the Navigator.
- **Constructor param**: Takes `GoRouter router` as a required parameter (NOT `GoRouter.of(context)` — that fails from `MaterialApp.router` builder context because the GoRouter InheritedWidget is inside the Navigator).
- **Route change tracking**: Uses `router.routerDelegate.addListener(_onRouteChanged)` — `RouterDelegate` extends `Listenable` so `addListener`/`removeListener` work directly.
- **Initialization**: Register the listener in a `addPostFrameCallback` so the router delegate is fully initialized before we try to read `currentConfiguration`.
- **Location sync**: `_syncLocation()` reads `widget.router.routerDelegate.currentConfiguration.uri.toString()` with null-safe checks (`if (config == null) return;`).
- **Skip re-navigation**: The `_onFollow` handler checks `if (_currentLocation == route) return;` before calling `widget.router.go(route)`. This prevents recreating screens (and triggering redundant FS operations) when the target route is already active.
- **AbsorbPointer**: `AbsorbPointer` wraps all routes EXCEPT `/control` (the control screen must remain interactive during follow mode).

### 12.2 Route mapping (`_followRoute`)

- **Location**: `radiokit-app/lib/services/remote_access_service.dart` — `static String? _followRoute(String path)`.
- **Mapping**: API request path prefixes -> follow-mode route targets (uses `startsWith` internally):
  ```
  path.startsWith('/api/pair/')        -> /pair
  path.startsWith('/api/connection/connect') -> /control
  path.startsWith('/api/connection/disconnect') -> /models
  path == '/api/widgets' || startsWith('/api/widgets/') -> /control
  path.startsWith('/api/fs/')          -> /dev-tools/esp32-fs
  path.startsWith('/api/designs')      -> /designs
  path.startsWith('/api/transport/')   -> /debug
  path.startsWith('/api/settings')     -> /system
  path.startsWith('/api/console')     -> /system
  path.startsWith('/api/log')         -> /system
  path.startsWith('/api/models')      -> /models
  ```
- **Testing**: Use `RemoteAccessService.testOnlyFollowRoute(path)` (annotated `@visibleForTesting`) for unit tests.
- **Path matching nuance**: For routes registered as both bare (`/api/widgets`) and parameterized (`/api/widgets/<id>`), the `startsWith` check MUST handle both: `path == '/api/widgets' || path.startsWith('/api/widgets/')`.

### 12.3 `/api/session/route` endpoint

- **Purpose**: Returns the current GoRouter location so automated tests can verify follow mode navigation.
- **Response**: `{"route": "/dev-tools/esp32-fs"}` — returns `''` if no route has been synced yet.
- **Implementation**: `RemoteAccessProvider._currentRoute` field updated by `_FollowModeWrapper._syncLocation()`. Passed as `String Function()` getter to `RemoteAccessService` constructor via `currentRouteGetter` parameter.

### 12.4 FS screen interference defer

- **Problem**: When follow mode navigates to `/dev-tools/esp32-fs` during an ongoing FS operation (e.g., an HTTP API write), the screen's `initState` -> `_initialRefresh` -> `_refresh()` starts its own `listDir()` and `getInfo()` calls that collide with the ongoing transfer.
- **Fix**: `FilesystemExplorerScreen._initialRefresh()` checks `DeviceProvider.isFsBusy` and defers with a 600ms retry if the transport is busy. The `_initTriggered` flag is NOT set during retries, so the chain keeps trying until the FS is idle.
- **Getter**: `DeviceProvider.isFsBusy` exposes the private `_fsBusy` flag (set by `_ProviderAdapter` around every `sendFs` call).

## 13. BLE Filesystem Write Reliability

### 13.1 Re-entrant send packet queue

- **Problem**: `RadioKitBLE::sendPacket()` has a `_sending` re-entrancy guard to prevent interleaving data from different BLE streams. During file transfers, an incoming BLE write (from the phone) could arrive during a `delay()` call in `sendPacket()` (used for retry backoff and inter-chunk pacing). The incoming write triggers `_onWrite()` -> `handleWrite()` -> `sendPacket()`, which sees `_sending = true` and **drops** the outgoing ACK. The phone times out waiting for the ACK, stalling transfers at ~156KB.
- **Fix**: Instead of dropping the re-entrant call, queue the outgoing frame in `_pendingBuf[16388]` (FS header + max payload) and set `_pendingLen`. After the current send completes (`_sending = false`), drain the pending buffer via recursion: `sendPacket(_pendingBuf, qLen)`.
- **Buffer size**: `kPendingBufSize = 16388` — large enough for any FS frame (4-byte header + 16384-byte max payload).
- **Memory impact**: ~16KB static allocation on the singleton `RadioKitBLE` instance (~3% of ESP32-S3 512KB RAM).
- **Disconnect safety**: `_sending` is `volatile bool` — correct for cross-task access (NimBLE host task vs main loop).

### 13.2 Notify chunk size and pacing

- **Chunk size**: `_negotiatedMtu - 3` (MTU minus 3 bytes for ATT notification overhead).
- **Retry**: 10 retries with linear backoff from 10ms to 250ms.
- **Pacing**: `delay(_connIntervalMs * 5)` between multi-notification chunks.
- **Timeout**: 30s hard timeout per `sendPacket()` call.

## 14. Filesystem Explorer Speed Indicator

- **Location**: The transfer speed indicator lives in `FsInfoStrip` (the Capacity Usage card), not the AppBar.
- **Placement**: Right side of the card header row, after the "X used of Y" usage text (both visible simultaneously). Separated by an 8px gap.
- **Parameters**: `FsInfoStrip` accepts `double? speedBytesPerSec`. When non-null, the `_SpeedChip` widget (compact pill with spinning `CircularProgressIndicator` + formatted speed text) is rendered in the header row.
- **Speed formatting**: `_SpeedChip._format()` handles B/s, KB/s, MB/s formats. Tabular figures (`FontFeature.tabularFigures()`) for stable width during updates.
- **Updates**: The parent screen computes `_currentTransferBytes / elapsed` on each `setState()` from progress callbacks.

## 15. Testing Patterns

### 15.1 Testing private static methods

- Use `@visibleForTesting` annotation from `package:flutter/foundation.dart`:
  ```dart
  @visibleForTesting
  static String? testOnlyFollowRoute(String path) => _followRoute(path);
  ```
- Tests import the production class and call the `testOnly*` method directly.

### 15.2 Unit tests for shelf HTTP handlers

- Use `shelf` and `shelf_router` directly in tests to create standalone `Router` instances with the same handler logic. This validates the response format and status codes.
- For testing the actual production `_followRoute` mapping logic, use `RemoteAccessService.testOnlyFollowRoute()` (see 15.1).
- Example:
  ```dart
  final router = Router();
  router.get('/api/session/route', (request) async {
    return Response.ok(
      jsonEncode({'route': currentRoute}),
      headers: {'content-type': 'application/json'},
    );
  });
  final request = Request('GET', Uri.parse('http://test/api/session/route'));
  final response = await router(request);
  ```

## 16. No need for Backward Compatibility

- **Rule**: Only work on the current request, it's okay if it breaks backward compatibility. We can break the API whenever needed.
- **Rule**: We don't need to support old versions of the library. We can drop support for old versions whenever needed.

## 17. Build Tools & Processes

### 17.1 PlatformIO (Arduino Build)

PlatformIO must be installed inside a **`uv` venv** — do NOT install it globally.

```bash
# First-time setup (from project root)
uv venv .venv
source .venv/bin/activate
uv pip install platformio
```

**Build commands** — each example has its own `platformio.ini`. Build from the example directory:

```bash
# Activate venv first
source .venv/bin/activate

# Then build from the example directory
cd rk-arduino/examples/BasicSwitch
pio run                      # builds the example (default env)
pio run -t upload            # flash to board
```

**Available examples** (`rk-arduino/examples/`):
- `BasicSwitch` — BLE basic switch
- `BLE_RC_Truck` — BLE RC truck
- `Filesystem_LED` — bulk-FS demo with LittleFS
- `FsCommandTest` — FS command test
- `JoystickMotor` — BLE joystick motor
- `SliderServo` — servo slider (adds ESP32Servo)
- `WiFiCloudSwitch` — WiFi cloud switch

**Reinstallation** — if `pio` is missing or broken after venv reset:

```bash
uv venv .venv && source .venv/bin/activate && uv pip install platformio
```

**CI**: `.github/workflows/pioarduino-ci.yml` builds all examples via a matrix. Uses `pip install platformio` in CI (no venv needed there).

### 17.2 Flutter App

**Prerequisites**: Flutter 3.44.2+, Dart 3.12.2+

```bash
cd radiokit-app

# Get dependencies (also fetches flutter-widgets path dep)
flutter pub get

# Run analyzer (CI enforces --fatal-warnings)
flutter analyze --fatal-warnings

# Run tests
flutter test

# Build debug APK
flutter build apk --debug

# Build release APK
flutter build apk --release

# Build for web
flutter build web

# Build for Linux desktop
flutter build linux
```

**Monorepo note**: `radiokit-widgets` (`flutter-widgets/`) is a path dependency. Run `flutter pub get` in `radiokit-app/` — it resolves `flutter-widgets` automatically.

**Dependency override**: `flserial` uses a git override (`rambros3d/flserial` fork). Do not remove from `pubspec.yaml` dependency_overrides.

**CI**: `.github/workflows/flutter-ci.yml` runs `flutter analyze` and `flutter test` on every push.

### 17.3 Rust Relay (radiokit-relay)

**Prerequisites**: Rust 1.95.0+ (rustc/cargo)

```bash
cd radiokit-relay

# Build
cargo build

# Build release
cargo build --release

# Run tests
cargo test

# Run locally
cargo run

# Build Docker image
docker build -t radiokit-relay .

# Run in Docker
./run.sh
```

**CI**: Docker build is triggered by the relay CI workflow.

## 18. Models Tab Auth Dialog Flow

The models tab (`models_tab.dart`) uses an auto-popup auth dialog pattern. No gate card is shown when authentication is needed.

### 18.1 Connection auth flow

1. Device connects with a password set (`hasPassword: true`)
2. `_ActiveLinkSection` (StatefulWidget) detects `needAuth = hasPassword && !isAuthenticated`
3. An auth dialog automatically opens as a modal popup via `addPostFrameCallback`
4. If auth succeeds (`isAuthenticated: true`), the connected device card is shown in ACTIVE_LINKS
5. If the user cancels the dialog, the device is disconnected
6. If the auth timeout (60s) fires, the device is disconnected automatically

The `_authDialogShown` flag prevents the dialog from being shown multiple times. It is reset when the device disconnects.

### 18.2 Shared auth dialog (`_showAuthDialog`)

- **Location**: Top-level function in `models_tab.dart`
- **Signature**: `Future<bool> _showAuthDialog(BuildContext context, DeviceInfo device, {bool isAdminAuth = false})`
- **Returns**: `true` if auth succeeded, `false` if cancelled
- **Barrier dismissible**: `false` (user must either auth or cancel)
- **Remember password**: Checkbox saves to `SecureStorageService.savePassword()` or `saveAdminPassword()`
- **Saved passwords**: Auto-loaded into the password field on dialog open
- **Countdown**: `_AuthCountdown` widget shown in dialog title during connection auth (not admin auth)

### 18.3 Admin auth

The `_AdminAccessButton` (shown in the info bottom sheet when user mode is active) calls `_showAuthDialog(context, device, isAdminAuth: true)`. The same dialog handles both connection auth and admin auth, differentiated by the `isAdminAuth` parameter.

### 18.4 Widget dependencies

- `_ActiveLinkSection` — `StatefulWidget` replacing the previous `StatelessWidget` gate card pattern
- `_AuthCountdown` — `StatefulWidget` with `Timer.periodic(1s)` to display remaining auth time
- `_AdminAccessButton` — Opens the shared dialog in admin mode
- `_showAuthDialog` — Shared dialog function, returns `Future<bool>`
- `DeviceProvider.authenticate()` — Connection auth (falls back to admin auth on mismatch)
- `DeviceProvider.authenticateAdmin()` — Admin-only auth with admin flag byte

## 19. Documentation -- No Emojis

- **Rule**: Do not use emoji characters (e.g. checkmarks, rockets, spinning arrows, hourglasses) in any documentation files.
- **Rationale**: Emojis render inconsistently across terminals, editors, and CI output. Use plain-text markers instead (e.g., `[X]` for complete, `[~]` for in progress, `[ ]` for pending, `[-]` for blocked/failed).
- **Action**: If you find emoji characters in a doc file, replace them with the corresponding plain-text marker.
- **Note**: This rule applies to ALL markdown files in the project, including `website/src/content/docs/`, `llm-docs/`, `llm-docs/plans/`, and any other documentation.

## 20. Cloud Relay Ed25519 Auth

The cloud relay system uses Ed25519 challenge-response authentication between the Flutter app and the Rust relay server.

### 20.1 Key components

- **`radiokit-app/lib/services/websocket_service.dart`** — WebSocket transport that manages the Ed25519 auth state machine (`unauth` -> `challenged` -> `authenticated`). Sends `auth_request` on connect, signs the challenge nonce, handles `auth_ok`/`auth_failed`.
- **`radiokit-app/lib/services/cloud_identity.dart`** — `CloudIdentityService` class wrapping Ed25519 keypair generation (`cryptography` package), secure storage via `flutter_secure_storage`, and nonce signing.
- **`radiokit-app/lib/providers/cloud_identity_provider.dart`** — ChangeNotifier wrapper that initializes identity on first launch (generates keypair, persists to secure storage).
- **`radiokit-relay/src/relay.rs`** — `verify_auth()` function validates Ed25519 signatures against the hex-encoded public key (account).
- **`radiokit-relay/src/main.rs`** — Auth state machine: `auth_request` -> `auth_challenge` -> `auth_response` -> `auth_ok`/`auth_failed`.
- **`radiokit-relay/src/session.rs`** — `list_devices` and `join` are gated behind `authenticated = true`.

### 20.2 Auth flow

```
App (WebSocketService)        Relay                     Device
 |                            |                          |
 |-- auth_request ----------->|                          |
 |   { type, account }       |                          |
 |                            |                          |
 |<---- auth_challenge -------|                          |
 |   { type, nonce_b64 }     |                          |
 |                            |                          |
 |-- auth_response ---------->|                          |
 |   { type, signature_b64 } |                          |
 |   (sign(nonce, Ed25519)   |                          |
 |                            |                          |
 |<---- auth_ok --------------|                          |
 |   { type }                |                          |
 |                            |                          |
 |-- list_devices ----------->|                          |
 |<---- [device_names] -------|                          |
 |                            |                          |
 |-- join Device ------------>|------- forward --------->|
 |                            |                          |
 |   (widget frames rout     |                          |
 |    through relay)         |                          |
```

### 20.3 WebSocketService auth state machine

- **`_authState`**: `_AuthState.unauth`, `_AuthState.challenged`, `_AuthState.authenticated`
- On `connect()`: sets `_authState = unauth`, sends `auth_request` with the account (public key hex)
- On receiving `auth_challenge`: decodes nonce from base64, signs it with `_identity.sign(nonce)`, sends `auth_response`
- On `auth_ok`: sets `_authState = authenticated`, fires `onAuthSuccess`
- On `auth_failed`: sets `_authState = unauth`, fires `onAuthFailed`
- On disconnect: resets `_authState = unauth`
- **Re-entrant connect guard**: If `connect()` is called while already connected, it sends the join message through the existing authenticated session instead of creating a new WebSocket.

### 20.4 CloudIdentityService

```dart
class CloudIdentityService {
  Future<void> initialize();           // Load from storage or generate new
  Future<List<int>> sign(List<int> data); // Sign with private key
  Future<void> importKeyPair(String privHex, String pubHex); // For testing
  bool get hasIdentity;
  String? get publicKeyHex;
}
```

- Keys are stored in `flutter_secure_storage` under keys `cloud_private_key` and `cloud_public_key`
- On first launch, a new Ed25519 keypair is generated via `cryptography` package
- The public key hex is the "account" — set this on the ESP32 firmware's `cloud_account` config

### 20.5 Remote Access API endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/cloud/connect` | Connect to relay, auth, list devices |
| GET | `/api/cloud/devices` | Cached connection state + device list |
| POST | `/api/cloud/join` | Join a device through the relay |
| POST | `/api/cloud/disconnect` | Disconnect from relay |
| GET | `/api/cloud/account` | Get current Ed25519 identity (public key) |
| POST | `/api/cloud/account` | Generate new Ed25519 identity (resets account) |
| GET | `/api/cloud/accounts` | List all stored cloud accounts |
| POST | `/api/cloud/accounts` | Create a named account with relay URL |
| PUT | `/api/cloud/accounts/<id>` | Update account name or relay URL |
| DELETE | `/api/cloud/accounts/<id>` | Delete a cloud account |

See `llm-docs/API.md` section 15 (Cloud Relay) and section 16 (Cloud Account Management) for full request/response schemas.

### 20.6 ESP32 firmware setup

In the `RADIOKIT.h` config, set:
```cpp
RadioKit.config.cloud_url     = "wss://relay.example.com:443";
RadioKit.config.cloud_account = "<64-char-hex-public-key>";
RadioKit.startCloud();  // After startWiFi()
```

The device registers with the relay on boot using the public key as its identity.

### 20.7 Testing

See `llm-docs/AGENT-TEST.md` for the full cloud relay auth test procedure via the Remote Access API.

Key test command:
```bash
curl -X POST http://127.0.0.1:7007/api/cloud/connect \
  -H 'Content-Type: application/json' \
  -d '{"host":"10.0.0.17","port":9000,"account":"<pubkey>","privateKey":"<privkey>"}'
curl -X POST http://127.0.0.1:7007/api/cloud/join \
  -H 'Content-Type: application/json' \
  -d '{"device":"WiFi_Cloud_Switch"}'
```

## 21. Binary Protocol String Mask Layout

The CONF_DATA widget descriptor uses a string mask byte to indicate which optional strings follow the always-present label. Agents working on transport, serialization, or codegen MUST follow this layout.

### 21.1 Bit allocation (current)

```
Bit 0 (0x01) -- (reserved, label always present)
Bit 1 (0x02) -- RK_STR_LABEL_HIDDEN  -- Label hidden when set
Bit 2 (0x04) -- RK_STR_WIDGET_HIDDEN -- Widget hidden when set
Bit 3 (0x08) -- RK_STR_ICON          -- Icon string present
Bit 4 (0x10) -- RK_STR_ONTEXT        -- OnText string present
Bit 5 (0x20) -- RK_STR_OFFTEXT       -- OffText string present
Bit 6 (0x40) -- RK_STR_CONTENT       -- Content string present
Bit 7 (0x80) -- RK_STR_EXTRA         -- Widget-specific binary config
```

### 21.2 Rules

- The label string is **always** serialized as the first string (no mask bit needed).
- When a bit is set, the corresponding string is serialized immediately after the label.
- String order in the wire format: `LABEL` (always) -> `ICON`(3) -> `ONTEXT`(4) -> `OFFTEXT`(5) -> `CONTENT`(6) -> `EXTRA`(7).
- Arduino constants: `RK_STR_*` in `RadioKitConfig.h`.
- Flutter constants: `kStrMask*` in `protocol.dart`.
- Both sides must stay in sync — any change requires updating both files.

### 21.3 Wire format per widget

```
[STR_MASK(1)]
[LABEL_LEN(1)][LABEL...]                          -- always present
[ICON_LEN(1)][ICON...]                             -- if bit 3 set
[ONTEXT_LEN(1)][ONTEXT...]                         -- if bit 4 set
[OFFTEXT_LEN(1)][OFFTEXT...]                       -- if bit 5 set
[CONTENT_LEN(1)][CONTENT...]                       -- if bit 6 set
[EXTRA_LEN(1)][EXTRA_BYTES...]                     -- if bit 7 set
```

### 21.4 Usage in codegen

Generated Arduino code sets `rk.labelHidden` and `rk.hidden` in the `setup()` block:
```cpp
button_1.rk.labelHidden = true;  // bit 1
slider_1.rk.hidden = true;       // bit 2
```

### 21.5 Designer JSON

The `hidden` field is promoted to top-level in the JSON config (like `label`, `haptic`):
```json
{
  "type": "button",
  "name": "button_1",
  "label": { "text": "button_1", "show": true },
  "hidden": true,
  "position": [20, 30, 0],
  "size": [40, 40]
}
```

## 22. Multi-Page UI

### 22.1 JSON Config Schema v2

The designer uses a v2 JSON format with a `pages` array instead of a flat `widgets` array:

```json
{
  "version": 2,
  "config": { ... },
  "canvas": { ... },
  "pages": [
    {
      "name": "Page 1",
      "orientation": "landscape",
      "widgets": [ ... ]
    },
    {
      "name": "Page 2",
      "orientation": "portrait",
      "widgets": [ ... ]
    }
  ]
}
```

- `version`: Must be `2` for multi-page configs.
- `pages[]`: Array of page objects, each with `name`, `orientation`, and `widgets`.
- `widgets`: Array of widget objects (same format as v1 flat list).
- Backward compat: v1 flat `widgets` array is still supported.

### 22.2 Protocol Commands

New commands for page management (see `protocol.dart` and `RadioKitProtocol.h`):

| Command | Code | Direction | Description |
|---------|------|-----------|-------------|
| `SET_PAGE` | 0x20 | App -> MCU | Switch to page N |
| `PAGE_CHANGED` | 0x21 | MCU -> App | Page switch acknowledged |
| `GET_PAGES` | 0x22 | App -> MCU | Request page list |
| `PAGES_DATA` | 0x23 | MCU -> App | Page names list |
| `PAGE_SWITCH` | 0x24 | MCU -> App | Device-initiated page switch |

### 22.3 App State Machine

The `DeviceProvider` tracks page switch state:

- `_PageSwitchState.idle` - no pending page switch
- `_PageSwitchState.pagePending` - SET_PAGE sent, waiting for PAGE_CHANGED

Rules:
- On `sendSetPage()`: enter `pagePending`, start timer.
- On `PAGE_CHANGED` or `PAGE_SWITCH`: return to `idle`, update `_activePage`.
- While in `pagePending`: discard stale `VAR_UPDATE` and `CONF_DATA` packets.
- Timeout (60s): return to `idle` if no response.

### 22.4 Arduino Library

Widgets have a `page` field (`uint8_t _page`) set during codegen `_init()`:

- `RadioKit.setActivePage(page)` - switches active page, sends PAGE_SWITCH + CONF_DATA + VAR_DATA.
- `RadioKit.setNumPages(n)` - sets total page count (called in `setup()`).
- Page gating: `update()` loop and `_handleSetInput()` skip widgets where `w->page() != _activePage`.
- `_buildConfPayload` emits v5 header with `ACTIVE_PAGE` + `NUM_PAGES` when `_numPages > 1`.

### 22.5 Codegen Output

Generated code includes:

```cpp
#define RK_NUM_PAGES 3
const char* rk_pageNames[] = {"Control", "Settings", "Monitor"};

// --- Page 0: Control ---
Button button_1;  // page=0
Slider slider_1;   // page=0

// --- Page 1: Settings ---
Switch switch_1;   // page=1

void setup() {
  RadioKit.setNumPages(RK_NUM_PAGES);
  RadioKit.begin();
  // ... widget init with page param ...
}
```

### 22.6 Remote Access API

New endpoints for page management:

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/page` | Returns `{ activePage, numPages, pages }` |
| POST | `/api/page` | Switch page: `{ page: N }` |
| GET | `/api/pages` | Returns `{ pages, numPages, activePage }` |

Follow mode: `/api/page` and `/api/pages` map to `/control` route.

### 22.7 Designer State

`DesignerState` manages pages via:

- `List<DesignerPage> pages` - page list with name, elements, orientation.
- `activePageIndex` getter / `setActivePage(index)` setter.
- Element operations (`addElement`, `removeSelected`, etc.) operate on active page.
- Undo/redo is per-page scoped.
- `toJson()` / `loadFromJson()` serialize/deserialize the pages structure.
