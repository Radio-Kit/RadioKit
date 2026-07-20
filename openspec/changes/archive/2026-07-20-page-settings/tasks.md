## 1. DesignerPage Model

- [x] 1.1 Add `String? orientationOverride` field to `DesignerPage`
- [x] 1.2 Add `bool effectiveIsLandscape(bool globalIsLandscape)` computed method
- [x] 1.3 Update `toJson()` to emit `"orientation": "global" | "landscape" | "portrait"` (null defaults to "global")
- [x] 1.4 Update `fromJson()` to read orientation override, defaulting to "global" when missing
- [x] 1.5 Update `copyWith()` to accept `orientationOverride` parameter

## 2. DesignerState

- [x] 2.1 Add `setPageOrientationOverride(String value)` method
- [x] 2.2 Update `toggleOrientation()` to set override to opposite of global (not flip `isLandscape`)
- [x] 2.3 Update `addPage()` to default `orientationOverride` to `'global'`
- [x] 2.4 Update canvas width/height getters to use `effectiveIsLandscape(globalIsLandscape)`
- [x] 2.5 Add `bool get globalIsLandscape` getter (from CONTROL UI orientation setting)

## 3. Inspector — PAGE SETTINGS Section

- [x] 3.1 Add `_buildPageSettingsSection()` method to `DesignerInspector`
- [x] 3.2 Add page name live-editing text field using `buildTextField()`
- [x] 3.3 Add 3-way orientation selector using `buildCenterPinnedSelector()` with options: Global, Landscape, Portrait
- [x] 3.4 Insert section above MODEL in `_buildGeneralProperties()` (only when `numPages > 1`)
- [x] 3.5 Wire page name field to `state.renamePage()`
- [x] 3.6 Wire orientation selector to `state.setPageOrientationOverride()`

## 4. Page Bar Tab Indicator

- [x] 4.1 Add orientation badge to `_TabButton` (small rotation icon when override != 'global')
- [x] 4.2 Position badge at top-right of tab pill
- [x] 4.3 Use `LucideIcons.rotateCw` or similar icon for the badge

## 5. Control Screen Orientation Re-lock

- [x] 5.1 Update `DeviceProvider` to compute effective orientation per page on page switch
- [x] 5.2 Update `ControlScreen` to re-apply `SystemChrome.setPreferredOrientations()` on page change
- [x] 5.3 Ensure page switch in control mode updates `_orientation` field

## 6. Testing & Validation

- [x] 6.1 Write unit test for `effectiveIsLandscape()` with all override values
- [x] 6.2 Write unit test for JSON serialization/deserialization of orientation override
- [x] 6.3 Write widget test for PAGE SETTINGS section visibility (multi-page vs single-page)
- [x] 6.4 Write widget test for orientation selector updates page override
- [x] 6.5 Write widget test for tab indicator visibility
- [x] 6.6 Run `flutter analyze --fatal-warnings` — all pass
- [x] 6.7 Run `flutter test` — all pass
