# Tasks: Firmware-Controlled Widget Visibility + Per-Page Wire Protocol

## 1. Firmware: Widget visibility flag integration

- [x] 1.1 Add `_confDirty` field to `RadioKitClass` in `RadioKitClass.h`
- [x] 1.2 Clear `_confDirty` in `setActivePage()` (page switch sends its own CONF_DATA)
- [x] 1.3 Add `_confDirty = true` to `RadioKit_Widget::setHidden()` — Widget needs access to RadioKitClass flag (use static pointer or friend)
- [x] 1.4 Add `_confDirty = true` to `RadioKit_Widget::setLabelHidden()` — same mechanism

## 2. Firmware: Per-page + hidden filtering in payload builders

- [x] 2.1 Rewrite `_buildConfPayload` — count visible widgets on active page for header, skip hidden + wrong page in serialization loop
- [x] 2.2 Rewrite `_buildVarPayload` — add page + hidden filtering (currently has no page gating)
- [x] 2.3 Rewrite `_buildMetaPayload` — add page + hidden filtering

## 3. Firmware: update() loop and input handling

- [x] 3.1 Add `if (w->hidden()) continue;` to `update()` change detection loop (after page check)
- [x] 3.2 Add `_confDirty` handler at end of `update()` — sends CONF_DATA + VAR_DATA when flag is set
- [x] 3.3 Add `if (w->hidden()) { offset += sz; continue; }` to `_handleSetInput` (after page check)

## 4. App: Canvas rendering

- [x] 4.1 Change `CanvasElement` to return `SizedBox.shrink()` for hidden widgets in both play AND designer mode (remove 15% opacity ghosting)

## 5. App: Designer state

- [x] 5.1 Add `setElementHidden(String id, bool hidden)` method to `DesignerState` — no undo push, sets hidden flag directly
- [x] 5.2 Add hidden sync to `DeviceDesignerBridge._syncValues()` — detect `config.hidden != el.hidden` and call `setElementHidden`

## 6. Tests

- [x] 6.1 Add test: firmware setHidden(true) excludes widget from CONF_DATA
- [x] 6.2 Add test: firmware setHidden(false) includes widget in CONF_DATA
- [x] 6.3 Add test: hidden widget excluded from VAR_DATA
- [x] 6.4 Add test: page switch + hidden interaction (hidden on page 0, visible on page 1)
- [x] 6.5 Add test: app CanvasElement returns SizedBox.shrink for hidden
- [x] 6.6 Add test: DesignerState.setElementHidden sets flag without undo
- [x] 6.7 Add test: DeviceDesignerBridge syncs hidden from WidgetConfig to element

## 7. Verify

- [x] 7.1 Run flutter test — all tests pass
- [x] 7.2 Verify Arduino code compiles (platformio build)
- [x] 7.3 Update SKILLS/radiokit-firmware/SKILL.md — document setHidden/setLabelHidden API
