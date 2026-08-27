## Why

Multi-page codegen sub-generators (`_slider`, `_gasPedal`, `_knob`, `_steeringWheel`, `_buildMultiple`) were missing `setPage()` emission, causing all widgets to merge onto page 0 regardless of their actual page assignment. This breaks multi-page configs where widgets should be distributed across pages.

## What Changes

- Add `{int pageIndex = 0}` parameter to all sub-generator methods in `json_arduino_generator.dart`
- Emit `setPage(pageIndex)` call in each sub-generator's output when `pageIndex > 0`
- Update all call sites to pass the current page index

## Capabilities

### New Capabilities

### Modified Capabilities

- `multi-page-codegen`: Sub-generators now emit per-widget `setPage()` calls for multi-page configs

## Impact

- **Files modified**: `radiokit-app/lib/screens/designer/codegen/json_arduino_generator.dart`
- **No API changes**: Internal codegen fix only
- **No breaking changes**: Single-page configs unaffected (default `pageIndex = 0` skips emission)
