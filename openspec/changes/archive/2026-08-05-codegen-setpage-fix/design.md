## Context

The `JsonArduinoGenerator` in `json_arduino_generator.dart` generates Arduino code from the designer's JSON config. For multi-page configs (version >= 2), widgets are grouped by page. The main generator loop tracks the current page index and passes it to sub-generators.

However, sub-generators (`_slider`, `_gasPedal`, `_knob`, `_steeringWheel`, `_buildMultiple`) lacked a `pageIndex` parameter and didn't emit `setPage()` calls. This caused all widgets to be assigned to page 0 in the generated code, regardless of their actual page in the JSON config.

## Goals / Non-Goals

**Goals:**
- Sub-generators emit `setPage(pageIndex)` when `pageIndex > 0`
- Single-page configs unaffected (default `pageIndex = 0` skips emission)
- All sub-generators consistently handle page assignment

**Non-Goals:**
- Changing the JSON config schema
- Changing the main generator loop structure
- Modifying the `RKMultiButton`/`RKMultiSelect` codegen (already handled by `_buildMultiple`)

## Decisions

### 1. Add optional `pageIndex` parameter to sub-generators

**Decision**: Each sub-generator gets `{int pageIndex = 0}` as an optional parameter.

**Rationale**: Backward compatible — existing call sites without `pageIndex` continue to work. Default of 0 means no `setPage()` emission for single-page configs.

### 2. Emit `setPage()` only when `pageIndex > 0`

**Decision**: The generated code includes `widget_name.rk.page = N;` only when `pageIndex > 0`.

**Rationale**: Page 0 is the default — no need to emit it. This keeps single-page output clean and avoids redundant code.

### 3. Update all call sites in the main generator

**Decision**: The main `generate()` method passes `pageIndex: pageIndex` to each sub-generator call.

**Rationale**: Ensures page assignment flows through the entire codegen pipeline consistently.

## Risks / Trade-offs

- **Low risk**: The change is additive — adding an optional parameter with a safe default.
- **No behavioral change for single-page configs**: `pageIndex` defaults to 0, which skips `setPage()` emission.
