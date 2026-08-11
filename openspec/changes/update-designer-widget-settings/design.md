## Context

The RadioKit Designer (`radiokit-app`) and Widget Library (`flutter-widgets`) allow users to visually compose hardware control surfaces for Arduino microcontrollers. Three widget options are currently missing or broken in the designer inspector:

1. **Slider AutoCenter Position**: Sliders support auto-centering spring physics, but the Inspector UI only shows a boolean toggle without clear selection between `none` (disabled), `min`, `center`, and `max`.
2. **MultiButton Item Text & Icons**: `_DesignerMultiItemEditor` in `designer_inspector.dart` uses a condition `final showOn = onLabel != null || onIconName != null;` which evaluates to false for newly created items with empty string/null values, concealing item state text fields and icon selectors.
3. **MultiButton Button Mode (`push` vs `toggle`)**: Single buttons support momentary (`push`) and latching (`toggle`) variants. MultiButtons omit this selection in their schema and inspector UI.

## Goals / Non-Goals

**Goals:**
- Provide clear `['none', 'min', 'center', 'max']` centering control for slider-based widgets.
- Fix `_DesignerMultiItemEditor` so ON and OFF text inputs and icon pickers are reliably editable for all items in a multi-button / multi-select.
- Add `variant` (`push` vs `toggle`) to `multiButton` and `multiSelect` widgets across JSON schema, inspector UI, and C++ code generator.

**Non-Goals:**
- Changing existing C++ firmware headers without designer JSON update.
- Altering physical spring animation duration defaults.

## Decisions

### 1. Slider Centering Control Format
- **Decision**: Update `AutoCenter` position dropdown options to `['none', 'min', 'center', 'max']` in `designer_inspector.dart`.
- **Rationale**: If `'none'` is chosen, `_updateACArrayProp` sets index 0 to `null` (disabling auto-centering). If `'min'`, `'center'`, or `'max'` is chosen, index 0 is updated accordingly and autoCenter becomes active.
- **Alternatives Considered**: Keeping a separate boolean checkbox + dropdown. Combined dropdown is cleaner and matches standard hardware control UX.

### 2. MultiItem Inspector Editor Fix
- **Decision**: Remove the restrictive `if (!showOn && !showOff)` suppression check in `_DesignerMultiItemEditor`. Always display the `ON` state inputs for every item, and display `OFF` state inputs when `showOffState` is true.
- **Rationale**: Users need to edit item labels/icons even when they start empty.

### 3. MultiButton Variant (`push` vs `toggle`)
- **Decision**: Expose `variant` property in `MultiButtonWidgetDefinition` schema and inspector UI, defaulting to `toggle`. In `json_arduino_generator.dart`, emit `multiButton.setMode(RK_BUTTON_PUSH)` or `RK_BUTTON_TOGGLE`.
- **Rationale**: Matches standard `button` widget architecture and standard `AGENTS.md` JSON schema conventions (section 3.5 variant promotion).

## Risks / Trade-offs

- **[Risk]**: Legacy multi-button JSON configs without a `variant` property.
  - **Mitigation**: Fallback default to `toggle` when `variant` key is null or missing.
