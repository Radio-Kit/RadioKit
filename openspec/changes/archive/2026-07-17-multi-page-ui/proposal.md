## Why

Currently, all widgets in a RadioKit design exist on a single canvas and are always transmitted over BLE/WiFi, regardless of which are visible. This wastes bandwidth on resource-constrained devices and limits UI complexity — users can't organize controls into logical groups (e.g., "Controls", "Telemetry", "Settings") without packing everything onto one screen.

Multi-page UI solves this by allowing users to create multiple pages (screens) in the designer, where only the active page's widgets are communicated. Inactive widgets persist in RAM but are silent on the wire.

## What Changes

- **Designer gains a page bar** with centered chevrons (< Page 1 >), dot indicators, and page name. Users can add, remove, rename, reorder, and duplicate pages.
- **Each page has its own canvas** with independent widget layout and per-page orientation (landscape/portrait).
- **JSON config schema upgrades to v2** with a `pages[]` array containing per-page widgets and orientation. No backward compatibility with v1.
- **Protocol adds 5 new commands** for page switching (SET_PAGE, PAGE_CHANGED, GET_PAGES, PAGES_DATA, PAGE_SWITCH). VAR_UPDATE and SET_INPUT gain a page index prefix byte.
- **Arduino codegen outputs page-grouped widget declarations** with global sequential names and page metadata (RK_NUM_PAGES, page names array).
- **Arduino library gains `RadioKit.setActivePage(n)` API** with automatic protocol handling and observable `activePage` getter.
- **Flutter app gains a page switcher widget** in play/control mode, page-aware rendering, and page sync on reconnect via ACTIVE_PAGE in CONF_DATA header.
- **Remote Access API gains page endpoints** (/api/page, /api/pages) and follow mode syncs page switches.
- **Undo/redo is per-page scoped.** Cross-page copy/paste and page duplication are supported.

## Capabilities

### New Capabilities
- `multi-page-designer`: Page management UI in the designer — page bar, add/remove/rename/reorder/duplicate pages, per-page canvas with orientation, per-page undo/redo, cross-page copy/paste.
- `multi-page-protocol`: Protocol extensions for page switching — new commands (SET_PAGE, PAGE_CHANGED, GET_PAGES, PAGES_DATA, PAGE_SWITCH), page prefix in VAR_UPDATE/SET_INPUT, ACTIVE_PAGE in CONF_DATA header.
- `multi-page-codegen`: Arduino codegen for multi-page configs — page-grouped widget declarations, global sequential names, page metadata (RK_NUM_PAGES, pageNames[]), page-aware setup block.
- `multi-page-firmware`: Arduino library page management — `RadioKit.setActivePage(n)` API, activePage getter, page index gating for widget send/receive, page names storage.
- `multi-page-app`: Flutter app page switcher — chevron+dot+name UI, page-aware widget rendering, page sync on reconnect, page endpoints in Remote Access API.

### Modified Capabilities
- `api-server`: New endpoints for page management (/api/page, /api/pages) and page switch in follow mode.

## Impact

- **JSON config**: v1 → v2 breaking change. All existing demo configs and user sketches must be updated.
- **Protocol**: VAR_UPDATE and SET_INPUT packet format changes (added page index byte). Old firmware won't understand new packets.
- **Arduino library**: New API surface (setActivePage, activePage, pageNames). All widget registration logic changes.
- **Flutter app**: DesignerState refactored to support pages. New page switcher widget. CONF_DATA parser updated.
- **Codegen**: JsonArduinoGenerator rewritten for page-grouped output. All 7 example RADIOKIT.h files must be regenerated.
- **Remote Access**: New endpoints added. Follow mode extended for page sync.
- **Breaking**: No backward compatibility with v1 configs or old firmware.
