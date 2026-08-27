## Context

`RKMultiButton` and `RKMultiSelect` widgets rendering on the designer canvas have two issues:
1. `itemCount` discrepancy: `buildCanvasWidget()` only maps `properties['items']`. If `items` list length is less than `itemCount` (e.g. 3 vs 5), only 3 buttons render.
2. Orientation lock: `aspectRatio` returns `count * 0.67` (or negative). When dragging resize handle, `_handleResize()` forces `width = height * AR` (keeping `width >= height`), preventing the user from ever dragging the handle to flip orientation from horizontal to vertical.

## Goals / Non-Goals

**Goals:**
- `buildCanvasWidget()` generates/pads items up to `itemCount` so N buttons render on canvas.
- Free-form resizing for multiButton and multiSelect so orientation flips between horizontal (`width >= height`) and vertical (`height > width`) automatically like `Slider`.

**Non-Goals:**
- Modifying `RKMultiButton` runtime widget class in `flutter-widgets`.
- Modifying C++ codegen (already supports page/multi-item codegen).

## Decisions

### 1. Generate/pad items up to `itemCount` in `buildCanvasWidget()`

Read `itemCount` from properties, generate missing items up to `itemCount` with `onLabel: String.fromCharCode(65 + i)` (A, B, C, D...).

### 2. Remove rigid `aspectRatio` lock on `multiButton` / `multiSelect`

Return `null` for `aspectRatio` in `MultiButtonWidgetDefinition`, `MultiSelectWidgetDefinition`, and `DesignerElement.aspectRatio` so the canvas drag handle allows free-form width/height resizing. `buildCanvasWidget()` dynamically computes `orientation: horizontal ? RKAxis.horizontal : RKAxis.vertical` based on `width >= height`.

## Risks / Trade-offs

- **Low risk**: `RKMultiButton` and `RKMultiSelect` already support `RKAxis.horizontal` and `RKAxis.vertical` and flexible `buttonSize`.
