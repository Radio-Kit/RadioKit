## 1. JSON Config Schema v2

- [x] 1.1 Add `pages` field to `DesignerState.toJson()` and `loadFromJson()` — replace flat `widgets` array with `pages[]` containing per-page widgets and orientation
- [x] 1.2 Update `DesignerElement.fromJson()` / `toJson()` to work within page context
- [x] 1.3 Add `orientation` field to page data (landscape/portrait) — remove from top-level canvas
- [x] 1.4 Bump JSON version from 1 to 2 in `toJson()` output
- [x] 1.5 Update all demo JSON files in `radiokit-app/assets/demos/` to v2 format
- [x] 1.6 Update `header_file_parser.dart` to handle v2 JSON structure

## 2. Designer State — Pages Model

- [x] 2.1 Create `DesignerPage` class with `name`, `elements`, and `orientation` fields
- [x] 2.2 Refactor `DesignerState` to store `List<DesignerPage>` instead of flat `List<DesignerElement>`
- [x] 2.3 Add `_activePageIndex` field with getter/setter and `notifyListeners()`
- [x] 2.4 Add page management methods: `addPage()`, `removePage()`, `renamePage()`, `reorderPage()`, `duplicatePage()`
- [x] 2.5 Refactor all element operations (`addElement`, `removeSelected`, `updateElement*`) to operate on the active page's elements
- [x] 2.6 Refactor undo/redo to be per-page scoped — each undo entry records which page it belongs to
- [x] 2.7 Refactor `toggleOrientation()` to work per-page instead of globally
- [x] 2.8 Update `toJson()` / `loadFromJson()` to serialize/deserialize the pages structure

## 3. Designer UI — Page Bar

- [x] 3.1 Create `_PageBar` widget with centered chevrons, dot indicators, and page name
- [x] 3.2 Add "+" button for adding new pages
- [x] 3.3 Implement chevron navigation (left/right) with disabled state on first/last page
- [x] 3.4 Implement page name tap-to-rename with inline text field
- [x] 3.5 Implement dot indicator drag-to-reorder
- [x] 3.6 Add long-press context menu on dots for delete/duplicate
- [x] 3.7 Integrate page bar into designer screen layout (below toolbar, above canvas)
- [x] 3.8 Handle canvas resize on page switch (instant, no animation)

## 4. Designer UI — Cross-Page Operations

- [x] 4.1 Implement cross-page copy/paste (copy widget from one page, paste onto another)
- [x] 4.2 Implement duplicate page action (copies all widgets with new unique names)
- [x] 4.3 Update inspector panel to reflect active page context
- [x] 4.4 Update widget sidebar to add widgets to the active page

## 5. Protocol — New Commands

- [x] 5.1 Add protocol constants to `radiokit-app/lib/models/protocol.dart`: `kCmdSetPage` (0x20), `kCmdPageChanged` (0x21), `kCmdGetPages` (0x22), `kCmdPagesData` (0x23), `kCmdPageSwitch` (0x24)
- [x] 5.2 Add protocol constants to `rk-arduino/src/RadioKitProtocol.h`: `RK_CMD_SET_PAGE`, `RK_CMD_PAGE_CHANGED`, `RK_CMD_GET_PAGES`, `RK_CMD_PAGES_DATA`, `RK_CMD_PAGE_SWITCH`
- [x] 5.3 Add page prefix byte to VAR_UPDATE builder/parser in `protocol_service.dart`
- [x] 5.4 Add page prefix byte to SET_INPUT builder/parser in `protocol_service.dart`
- [x] 5.5 Add ACTIVE_PAGE and NUM_PAGES to CONF_DATA header in Arduino `RadioKit.cpp` builder
- [x] 5.6 Update CONF_DATA parser in `protocol_service.dart` to read ACTIVE_PAGE and NUM_PAGES from header
- [x] 5.7 Implement `buildSetPage()`, `buildGetPages()`, `parsePagesData()`, `parsePageChanged()` in `protocol_service.dart`

## 6. Protocol — App State Machine

- [x] 6.1 Add `_PageSwitchState` enum (IDLE, PAGE_PENDING) to `DeviceProvider` or `WebSocketService`
- [x] 6.2 Implement page switch state machine — enter PAGE_PENDING on SET_PAGE, return to IDLE on PAGE_CHANGED
- [x] 6.3 Discard stale VAR_UPDATE/CONF_DATA while in PAGE_PENDING state
- [x] 6.4 Sync active page from CONF_DATA header on reconnect

## 7. Arduino Library — Page Management

- [x] 7.1 Add `activePage`, `numPages`, `pageNames` fields to `RadioKitClass`
- [x] 7.2 Implement `setActivePage(uint8_t page)` with automatic PAGE_CHANGED + CONF_DATA + VAR_DATA emission
- [x] 7.3 Add page index gating in `RadioKit.cpp` — only send/receive data for active page widgets
- [x] 7.4 Handle incoming `CMD_SET_PAGE` in `RadioKit.cpp` command dispatcher
- [x] 7.5 Send `CMD_PAGE_SWITCH` when `setActivePage()` is called from user code (not from protocol)
- [x] 7.6 Handle `CMD_GET_PAGES` by sending `CMD_PAGES_DATA` with page names

## 8. Arduino Codegen

- [x] 8.1 Refactor `JsonArduinoGenerator.generate()` to iterate `pages[]` instead of flat `widgets`
- [x] 8.2 Emit page-grouped widget declarations with comment headers ("// ─── Page N: Name ───")
- [x] 8.3 Assign global sequential widget names across pages (reset not per-page, continue globally)
- [x] 8.4 Emit `#define RK_NUM_PAGES` and `const char* rk_pageNames[]` array
- [x] 8.5 Emit per-page orientation metadata in setup block
- [x] 8.6 Group setup code by page in `initRadioKit()` function
- [x] 8.7 Update demo `.h` files in `rk-arduino/examples/` with regenerated multi-page code

## 9. Flutter App — Page Switcher

- [x] 9.1 Create `PageSwitcher` widget for play/control mode with chevrons, dots, and page name
- [x] 9.2 Integrate `PageSwitcher` into control screen layout
- [x] 9.3 Wire chevron taps to send `CMD_SET_PAGE` via transport
- [x] 9.4 Listen for `CMD_PAGE_SWITCH` / `CMD_PAGE_CHANGED` to update UI
- [x] 9.5 Disable page switcher during OTA updates
- [x] 9.6 Handle page-aware widget rendering — only show active page's widgets in play mode

## 10. Remote Access API

- [x] 10.1 Add `GET /api/page` endpoint returning `{ "page": N, "pages": [...] }`
- [x] 10.2 Add `POST /api/page` endpoint accepting `{ "page": N }` to switch pages
- [x] 10.3 Add `GET /api/pages` endpoint returning page name list
- [x] 10.4 Update follow mode `_followRoute()` to handle page-switch paths
- [x] 10.5 Update `/api/session/route` to include page context

## 11. Testing

- [x] 11.1 Write unit tests for `DesignerPage` model and page management operations
- [x] 11.2 Write unit tests for protocol command builders/parsers with page prefix
- [x] 11.3 Write unit tests for page switch state machine (IDLE → PAGE_PENDING → IDLE)
- [x] 11.4 Write unit tests for codegen output with multi-page configs
- [x] 11.5 Write widget tests for page bar UI (chevrons, dots, rename, delete)
- [x] 11.6 Write widget tests for page switcher in control mode
- [x] 11.7 Update existing tests that assume single-page structure
- [x] 11.8 Run `flutter analyze --fatal-warnings` and `flutter test` — all pass

## 12. Documentation

- [x] 12.1 Update `AGENTS.md` with multi-page conventions (JSON schema, protocol commands, codegen patterns)
- [x] 12.2 Update demo JSON files with multi-page examples
- [x] 12.3 Update codegen documentation with page-grouped output format
