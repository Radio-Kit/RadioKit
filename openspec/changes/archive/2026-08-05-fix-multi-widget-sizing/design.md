## Context

The designer canvas renders each widget inside a `SizedBox` matching its `renderedGridSize` (in pixels), wrapped in a `FittedBox(BoxFit.contain)`. The widget's `buildCanvasWidget()` method creates the actual Flutter widget.

For most widgets (slider, gasPedal, button, etc.), `buildCanvasWidget()` correctly computes sizing from `ctx.width`, `ctx.height`, and `ctx.cellSize`. But `MultiButtonWidgetDefinition` and `MultiSelectWidgetDefinition` don't — they create `RKMultiButton` / `RKMultiSelect` with default parameters, causing a size mismatch.

The old rendering path in `canvas_element.dart:120-162` (`_buildMultiButton` / `_buildMultiSelect`) already does this correctly. The fix is to port that logic into the `WidgetDefinition.buildCanvasWidget()` methods.

## Goals / Non-Goals

**Goals:**
- Multi widget fills its grid cell in the designer canvas
- Orientation flips correctly when width/height cross during resize
- Button size scales proportionally with the grid cell

**Non-Goals:**
- Changing the `RKMultiButton` / `RKMultiSelect` widget API
- Changing the aspect ratio or `renderedGridSize` logic
- Affecting play mode rendering (only designer canvas)

## Decisions

### 1. Port sizing logic from `_buildMultiButton` into `buildCanvasWidget`

**Decision**: Compute `buttonSize`, `orientation`, and `gap` in `buildCanvasWidget` using the same formulas as `canvas_element.dart:_buildMultiButton`.

**Rationale**: The existing logic in `_buildMultiButton` already works correctly. Reusing the same approach ensures consistency and avoids introducing new bugs.

**Formula** (from `canvas_element.dart:127-131`):
```dart
final cs = ctx.cellSize;
final pixelW = ctx.width.toDouble() * cs;
final pixelH = ctx.height.toDouble() * cs;
final horizontal = ctx.width >= ctx.height;
final spacing = 6.0;
final padding = 8.0;
final buttonSize = horizontal
    ? ((pixelW - padding*2 - spacing*(count-1)) / count).clamp(10.0, pixelH - padding*2)
    : ((pixelH - padding*2 - spacing*(count-1)) / count).clamp(10.0, pixelW - padding*2);
```

### 2. Use `WidgetBuildContext` properties

**Decision**: The `WidgetBuildContext` already exposes `width`, `height`, and `cellSize`. No changes needed to the context model.

## Risks / Trade-offs

- **Low risk**: The parameters being passed (`buttonSize`, `orientation`, `gap`) are already supported by `RKMultiButton` / `RKMultiSelect`. We're just finally passing them.
- **Visual change**: Widgets will appear larger in the designer (filling their cells instead of being scaled down). This is the intended fix.
