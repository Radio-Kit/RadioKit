## Context

In `designer_widget_dialog.dart`, grid items render widget previews inside `_SheetGridItem._buildCell()`. Previously, individual widget preview cases hardcoded pixel parameters or used `.clamp()` ranges that distorted non-square elements (like 3:1 linear sliders or 1:2 gas pedals).

## Goals / Non-Goals

**Goals:**
- Query `(defW, defH) = DesignerElement.defaultSize(variant.type)` for each preview variant.
- Wrap preview widgets in `FittedBox(fit: BoxFit.contain)` with a `SizedBox` sized proportionally to `(defW, defH)`.
- Ensure all 14 widget variants display with accurate aspect ratios inside the sheet grid.

**Non-Goals:**
- Modifying canvas drag-and-drop scaling or inspector property logic.

## Decisions

### Decision 1: Proportional `FittedBox` Preview Container
Instead of hardcoding custom clamps per widget, wrap `_buildPreview()` in a `FittedBox(fit: BoxFit.contain)` and `SizedBox(width: defW * scale, height: defH * scale)`.

*Rationale*: Guarantees that every widget renders at its exact design-system aspect ratio `(defW : defH)` while filling available grid cell space without clipping or distortion.

## Risks / Trade-offs

- **Risk**: Extremely wide or tall widgets could render small inside a square grid cell.
- **Mitigation**: `BoxFit.contain` ensures full visibility; padding is tuned so label text remains legible underneath.
