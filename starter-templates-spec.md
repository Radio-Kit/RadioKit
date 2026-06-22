# Starter Templates — Feature Spec

## Overview

Add a "Starter Templates" section to the designs screen (`/designs`) that displays pre-built UI layouts from bundled JSON files. Users can tap a template to open it directly in the designer, giving them a head start instead of building from scratch.

---

## 1. Data Source

### 1.1 Template files

- Location: `starter-templates/*.json` (e.g. `Locomotive_Remote.json`)
- Format: Standard RadioKit Designer JSON (same schema as designs saved in-app)
- Key fields used for display:
  - `config.name` — template display name (e.g. "Locomotive-Remote")
  - `config.type` — template type/category (e.g. "Locomotive")
  - `config.transport` — transport type (e.g. "BLE", "WiFi")
  - `canvas.size` — canvas dimensions `[width, height]`
  - `widgets` — array of widget definitions (used for preview rendering and widget count)
  - `canvas.skin` — default skin (e.g. "dragon")

### 1.2 Bundling

- Bundle `starter-templates/*.json` as Flutter assets via `pubspec.yaml`:
  ```yaml
  flutter:
    assets:
      - starter-templates/
  ```
- Load at runtime using `rootBundle.loadString('starter-templates/Locomotive_Remote.json')`
- Parse JSON into `SavedDesign` objects with a synthetic `id` (e.g. `"template_locomotive_remote"`)

### 1.3 Metadata

- No additional metadata files. Use the JSON fields directly:
  - Display name from `config.name`
  - Subtitle from `config.type` (if non-empty)
  - Widget count from `widgets.length`
  - Transport badge from `config.transport`

---

## 2. UI Design

### 2.1 Section placement

- Appears **below** the saved designs list on the designs screen
- Separated by a section header: "STARTER TEMPLATES" (monospace, uppercase, same style as other section headers in the app)
- If there are no saved designs, show the empty state ("No designs saved") as before, then the starter templates section below it

### 2.2 Template cards

- Use `ModelCard` (same component as saved design cards) for consistency
- Visual preview: Each card renders a **live preview** of the template's canvas
  - Parse the template JSON and render a small scaled-down canvas using `DesignerCanvas` (or a lightweight subset)
  - Preview size: ~120×80px container, scaled to fit the canvas aspect ratio
  - Use the template's `canvas.skin` for the preview theme
- Card layout:
  - **Leading**: Small canvas preview (replaces the icon used in saved design cards)
  - **Title**: `config.name` (e.g. "Locomotive-Remote")
  - **Subtitle**: `config.type` + transport badge (e.g. "Locomotive • BLE")
  - **Trailing**: Widget count badge (e.g. "3 widgets") + chevron
- No delete action on template cards (templates are immutable)

### 2.3 Grid layout

- Same responsive layout as saved designs:
  - Narrow screen (< 600px): Single column ListView
  - Wide screen (≥ 600px): 2-column grid using Row + Expanded
- Templates appear in the order they are defined in the assets directory

---

## 3. Interaction

### 3.1 Tap behavior

- Tapping a template card opens the designer with the template's JSON loaded
- Implementation:
  1. Parse the template JSON from the asset
  2. Create a new `SavedDesign` entry in `DesignsProvider` with:
     - `id`: generated timestamp-based ID (e.g. `"template_1719000000000"`)
     - `name`: `config.name` from JSON
     - `jsonContent`: the full JSON string
     - `filePath`: `null` (app-mode, not file-mode)
  3. Navigate to `/designer?id=<new_id>`
- The template becomes a saved design that the user can edit and save independently
- The original template remains unchanged (templates are read-only source)

### 3.2 No delete/long-press

- Template cards do not support long-press delete
- Templates are immutable and always available

---

## 4. Implementation Details

### 4.1 New files

- `radiokit-app/lib/screens/home/starter_templates_section.dart` — Widget that loads and displays the templates section
- `radiokit-app/lib/models/starter_template.dart` — Model class for template metadata (parsed from JSON)

### 4.2 Modified files

- `radiokit-app/pubspec.yaml` — Add `starter-templates/` to flutter assets
- `radiokit-app/lib/screens/home/designs_tab.dart` — Import and render `StarterTemplatesSection` below the saved designs grid
- `starter-templates/` — Move JSON files here (currently at project root)

### 4.3 Data flow

```
starter-templates/*.json (assets)
    ↓ rootBundle.loadString()
StarterTemplate.fromJson()
    ↓
StarterTemplatesSection (StatefulWidget)
    ↓ loads on initState
List<StarterTemplate> templates
    ↓
ModelCard per template (with live preview)
    ↓ onTap
DesignsProvider.saveDesign() → context.push('/designer?id=...')
```

### 4.4 Live preview rendering — detailed approach

#### How DesignerCanvas scales

The existing `DesignerCanvas` already handles arbitrary-scale rendering. Key constants from the codebase:

- `canvasPixelW = 600.0` (fixed virtual canvas width in pixels)
- `canvasPixelH = 600.0 * ch / cw` (derived from canvas grid aspect ratio)
- Each element is positioned via: `(el.x - halfW) / cw * canvasPixelW`
- `CanvasElement._cellSize = 600.0 / designerState.canvasWidth`
- The entire canvas is wrapped in `FittedBox(fit: BoxFit.fill)` inside a `ClipRect`

This means `DesignerCanvas` already renders at a fixed 600px virtual width and scales to fit any container. We can reuse this directly.

#### Preview widget architecture

Create a `TemplatePreview` StatelessWidget:

```dart
class TemplatePreview extends StatelessWidget {
  final DesignerState state;  // pre-loaded, read-only
  final double width;          // e.g. 120
  final double height;         // e.g. 80

  const TemplatePreview({
    required this.state,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = RKTokens.presetsByName[state.activeSkin] ?? RKTokens.dragon;
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: RKTheme(
          tokens: tokens,
          child: DesignerCanvas(state: state),
        ),
      ),
    );
  }
}
```

`DesignerCanvas` uses `LayoutBuilder` internally — given the `SizedBox` constraints (120×80), it computes:
- `availableW = 120`, `availableH = 80`
- `scaleX = 120 / 600 = 0.2`, `scaleY = 80 / canvasPixelH`
- `scale = min(scaleX, scaleY)` → fits the canvas while preserving aspect ratio
- The `FittedBox` inside does the final render scaling

No manual scaling math needed — the existing canvas handles it all.

#### DesignerState setup per template

Each template card needs its own `DesignerState` instance. Create it lazily:

```dart
// In StarterTemplatesSection (StatefulWidget)
final Map<String, DesignerState> _previewStates = {};

@override
void initState() {
  super.initState();
  _loadTemplates();
}

Future<void> _loadTemplates() async {
  for (final asset in _templateAssets) {
    final jsonStr = await rootBundle.loadString(asset);
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    final state = DesignerState();
    state.loadFromJson(json);
    // Force play mode — disables handles, selection, drag targets
    if (!state.isPlayMode) state.togglePlayMode();
    _previewStates[asset] = state;
  }
  setState(() {});
}
```

Key: `togglePlayMode()` sets `_isPlayMode = true`, `_selectedElementId = null`, `_isInspectorVisible = false`. This causes:
- `DesignerCanvas` to skip rendering resize/rotate handles
- `CanvasElement` to skip `IgnorePointer` wrappers (widgets are interactive in play mode, but the preview is inside a `GestureDetector` that absorbs taps)
- `_MovableElement` to use `FittedBox(fit: BoxFit.contain)` without the `GestureDetector` wrapper

#### Preventing interaction in preview

The preview must NOT be interactive (no widget toggling, no dragging). Wrap the `DesignerCanvas` in an `AbsorbPointer`:

```dart
child: AbsorbPointer(
  child: DesignerCanvas(state: state),
),
```

This absorbs all tap/drag events so widgets in the preview don't respond to touches.

#### Caching strategy

**Problem**: If every card creates a `DesignerState` + `DesignerCanvas` in the widget tree, scrolling the list causes continuous rebuilds and re-layouts.

**Solution**: Use `RepaintBoundary` to isolate each preview's paint:

```dart
child: RepaintBoundary(
  child: TemplatePreview(
    state: previewState,
    width: 120,
    height: 80,
  ),
),
```

`RepaintBoundary` creates a separate `Layer` — when sibling cards repaint (e.g. on scroll), the cached preview bitmap is reused unless the state changes.

**Additional optimization**: Since templates are static (never change), the `RepaintBoundary` effectively caches the preview permanently. No `shouldRepaint` invalidation will occur because `DesignerState` is never mutated after initial load.

#### Lazy loading / deferred rendering

**Problem**: Loading all templates on `initState` blocks the first frame if there are many templates.

**Solution**: Two-phase loading:

1. **Phase 1** (initState): Load JSON strings from assets asynchronously. Display placeholder cards (skeleton with loading indicator).
2. **Phase 2** (post-frame): Parse JSON, create `DesignerState`, call `loadFromJson()`. Build preview widgets on next frame.

```dart
Future<void> _loadTemplates() async {
  final manifestContent = await rootBundle.loadString('AssetManifest.json');
  final Map<String, dynamic> manifest = jsonDecode(manifestContent);
  final templatePaths = manifest.keys
      .where((k) => k.startsWith('starter-templates/') && k.endsWith('.json'))
      .toList()
    ..sort();

  // Phase 1: load JSON strings
  final jsonStrings = <String, String>{};
  for (final path in templatePaths) {
    jsonStrings[path] = await rootBundle.loadString(path);
  }

  // Phase 2: parse and create states
  for (final entry in jsonStrings.entries) {
    final json = jsonDecode(entry.value) as Map<String, dynamic>;
    final state = DesignerState();
    state.loadFromJson(json);
    if (!state.isPlayMode) state.togglePlayMode();
    _previewStates[entry.key] = state;
  }
  if (mounted) setState(() {});
}
```

#### Performance budget

| Metric | Target |
|--------|--------|
| Preview render time per card | < 16ms (one frame) |
| Memory per preview | ~50KB (DesignerState + element tree) |
| Total for 10 templates | < 1MB memory, < 200ms total load |
| Scroll FPS | 60fps (RepaintBoundary isolates paint) |

#### Disposal

`DesignerState` extends `ChangeNotifier`. Dispose all preview states when the section is removed:

```dart
@override
void dispose() {
  for (final state in _previewStates.values) {
    state.dispose();
  }
  super.dispose();
}
```

#### Edge: Canvas aspect ratio vs card size

Templates may have different canvas sizes (e.g. `200x100` landscape vs `100x200` portrait). The preview container is fixed at `120×80`. `DesignerCanvas` + `FittedBox` handles the aspect ratio mismatch:
- Landscape (200×100): fits width-first, centered vertically
- Portrait (100×200): fits height-first, centered horizontally
- Square (100×100): fits to the smaller dimension

The `ClipRRect` ensures nothing overflows the rounded-rect preview bounds.

---

## 5. Edge Cases

- **Empty templates directory**: Hide the section entirely (don't show an empty "Starter Templates" header)
- **Malformed JSON**: Skip the template, log a warning, don't crash
- **Large templates**: Preview container clips overflow; the actual designer handles full rendering
- **Theme/skin mismatch**: Preview uses the template's specified skin, not the user's current theme
- **Offline/cold start**: Assets are bundled, no network needed; loading is synchronous from `rootBundle`

---

## 6. Future Considerations (out of scope)

- User-created templates (save a design as a template)
- Template categories/filters
- Template marketplace (download from server)
- Template versioning
