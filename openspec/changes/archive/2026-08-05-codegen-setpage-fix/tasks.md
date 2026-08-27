## 1. Sub-generator Parameter Updates

- [x] 1.1 Add `{int pageIndex = 0}` parameter to `_slider()` method
- [x] 1.2 Add `{int pageIndex = 0}` parameter to `_gasPedal()` method
- [x] 1.3 Add `{int pageIndex = 0}` parameter to `_knob()` method
- [x] 1.4 Add `{int pageIndex = 0}` parameter to `_steeringWheel()` method
- [x] 1.5 Add `{int pageIndex = 0}` parameter to `_buildMultiple()` method

## 2. setPage Emission

- [x] 2.1 Emit `setPage(pageIndex)` in `_slider()` when pageIndex > 0
- [x] 2.2 Emit `setPage(pageIndex)` in `_gasPedal()` when pageIndex > 0
- [x] 2.3 Emit `setPage(pageIndex)` in `_knob()` when pageIndex > 0
- [x] 2.4 Emit `setPage(pageIndex)` in `_steeringWheel()` when pageIndex > 0
- [x] 2.5 Emit `setPage(pageIndex)` in `_buildMultiple()` when pageIndex > 0

## 3. Call Site Updates

- [x] 3.1 Update all `_slider()` call sites to pass `pageIndex: pageIndex`
- [x] 3.2 Update all `_gasPedal()` call sites to pass `pageIndex: pageIndex`
- [x] 3.3 Update all `_knob()` call sites to pass `pageIndex: pageIndex`
- [x] 3.4 Update all `_steeringWheel()` call sites to pass `pageIndex: pageIndex`
- [x] 3.5 Update all `_buildMultiple()` call sites to pass `pageIndex: pageIndex`

## 4. Verification

- [x] 4.1 Run `flutter analyze --fatal-warnings` — no new warnings
- [x] 4.2 Generate code for a multi-page config and verify setPage calls appear for non-zero pages
- [x] 4.3 Generate code for a single-page config and verify no setPage calls appear
