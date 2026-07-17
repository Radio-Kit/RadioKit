## Context

RadioKit is an Arduino library + Flutter companion app for building custom RC controllers. The designer lets users arrange widgets on a canvas, generates Arduino code, and communicates widget state over BLE/WiFi. Currently, all widgets exist on a single canvas and are always transmitted, wasting bandwidth and limiting UI complexity.

The system has three main layers:
- **Designer (Flutter)**: Visual canvas for arranging widgets, inspector for properties, codegen for Arduino output
- **Protocol (Binary)**: Frame-based protocol over BLE/WiFi with commands for config, values, metadata
- **Arduino Library**: C++ library that manages widgets, transports, and runtime state

## Goals / Non-Goals

**Goals:**
- Allow users to create multiple pages (screens) in the designer
- Only transmit active page's widgets over the protocol
- Support bidirectional page switching (app and device can switch pages)
- Keep all page data in RAM for instant switching (ESP32-S3 has 512KB)
- Per-page orientation (landscape/portrait)
- Cross-page operations: copy/paste, duplicate page
- Per-page undo/redo

**Non-Goals:**
- Backward compatibility with v1 configs (clean break to v2)
- Shared widgets across pages (each widget is unique to one page)
- Dynamic widget registration/unregistration (all widgets registered at startup)
- Page transitions/animations (instant switch)
- Maximum page limit (let user decide based on their MCU)

## Decisions

### Decision 1: JSON Config Schema v2

**Choice**: New `pages[]` array at top level, replacing flat `widgets[]`.

```json
{
  "version": 2,
  "pages": [
    {
      "name": "Controls",
      "orientation": "landscape",
      "widgets": [...]
    },
    {
      "name": "Telemetry",
      "orientation": "portrait",
      "widgets": [...]
    }
  ]
}
```

**Rationale**: Clean separation of pages. Each page owns its widgets and orientation. No ambiguity about which widgets belong where.

**Alternative considered**: Flat `widgets[]` with a `page` field on each widget. Rejected because it scatters page-related data and makes page operations (rename, reorder, delete) more complex.

### Decision 2: Page-Local Widget IDs with Protocol Prefix

**Choice**: Widget IDs restart at 0 per page. Protocol commands (VAR_UPDATE, SET_INPUT) include a page index prefix byte.

```
VAR_UPDATE: [PAGE(1)] [WIDGET_ID(1)] [SEQ(1)] [VALUES...]
SET_INPUT:  [PAGE(1)] [WIDGET_ID(1)] [VALUES...]
```

**Rationale**: Simple codegen (reset counter per page). Protocol is explicit about which page's data is being updated. No ID space waste.

**Alternative considered**: Global sequential IDs (Page 0: 0-4, Page 1: 5-9). Rejected because it adds complexity to codegen (need global counter) and wastes ID space.

### Decision 3: All Widgets Registered, Gate by Index

**Choice**: All pages' widgets are registered at startup. Active page index gates which ones send/receive values.

```cpp
// All 50 widgets registered
RK_PushButton btn_1(...);  // Page 0
RK_PushButton btn_2(...);  // Page 1
uint8_t activePage = 0;

void loop() {
  RadioKit.update();  // Only active page widgets send data
}
```

**Rationale**: Simple, fast page switch (O(1) index flip), all values persist in RAM. ESP32-S3 has plenty of RAM (50 widgets ≈ 4.2KB, 1.5% of 512KB).

**Alternative considered**: Dynamic register/unregister. Rejected because: (1) static widget definitions still use RAM even when unregistered, (2) page switch has latency from unregister+register, (3) inactive widget values are lost on switch.

### Decision 4: Automatic Protocol Handling + Observable API

**Choice**: Library handles SET_PAGE commands automatically. User can observe `RadioKit.activePage` and call `RadioKit.setActivePage(n)` manually.

```cpp
// Automatic: library handles SET_PAGE internally
// Observable: user can check current page
void loop() {
  RadioKit.update();
  if (RadioKit.activePage != lastPage) {
    // React to page change
  }
}
```

**Rationale**: Matches existing pattern (library handles SET_INPUT, VAR_UPDATE, etc. automatically). Eliminates boilerplate. Device-initiated switches (physical button) work the same way.

**Alternative considered**: Manual protocol handling. Rejected because every sketch would need the same page-switch boilerplate.

### Decision 5: Bidirectional Page Switching Protocol

**Choice**: 5 new commands for page management.

| Command | ID | Direction | Payload |
|---------|-----|-----------|---------|
| CMD_SET_PAGE | 0x20 | App → MCU | [PAGE_INDEX(1)] |
| CMD_PAGE_CHANGED | 0x21 | MCU → App | [PAGE_INDEX(1)] |
| CMD_GET_PAGES | 0x22 | App → MCU | (empty) |
| CMD_PAGES_DATA | 0x23 | MCU → App | [NUM_PAGES(1)] + per-page: [NAME_LEN(1)][NAME...] |
| CMD_PAGE_SWITCH | 0x24 | MCU → App | [PAGE_INDEX(1)] |

**Rationale**: Symmetric design. SET_PAGE is app-initiated, PAGE_SWITCH is device-initiated. PAGE_CHANGED is the acknowledgment. GET_PAGES/PAGES_DATA provide page metadata.

### Decision 6: ACTIVE_PAGE in CONF_DATA Header

**Choice**: Add ACTIVE_PAGE and NUM_PAGES to CONF_DATA global header for reconnection sync.

```
CONF_DATA header (v2):
[ORIENTATION(1)] [NUM_WIDGETS(1)] [ACTIVE_PAGE(1)] [NUM_PAGES(1)]
[THEME_LEN(1)] [THEME(THEME_LEN)]
```

**Rationale**: On BLE reconnection, app needs to know which page the MCU is on. Including it in CONF_DATA ensures automatic sync.

### Decision 7: Per-Page Orientation

**Choice**: Each page stores its own orientation (landscape/portrait). Canvas resizes instantly on page switch.

**Rationale**: Maximum flexibility — users can have landscape control pages and portrait telemetry pages. Instant switch (no animation) keeps it simple.

**Alternative considered**: Fixed orientation per device. Rejected because it limits UI flexibility.

### Decision 8: Codegen with Comment-Separated Blocks

**Choice**: Widgets grouped by page with comment headers. Global sequential names (no page prefix).

```cpp
// ─── Page 0: Controls ───
RK_PushButton btn_1(10, 20, 20, 20, 0);
RK_Slider slider_1(50, 20, 30, 10, 0);

// ─── Page 1: Telemetry ───
RK_LED led_2(10, 20, 15, 15, 0);
RK_Text text_3(50, 20, 60, 20);
```

**Rationale**: Clean, readable output. Global names avoid collision. Comment headers make page boundaries clear.

### Decision 9: Page State Machine for App

**Choice**: App uses a state machine to handle page switch timing.

```
States: IDLE → PAGE_PENDING → IDLE
- On SET_PAGE sent: enter PAGE_PENDING
- Discard VAR_UPDATE/CONF_DATA while PENDING
- On PAGE_CHANGED received: return to IDLE, apply new data
```

**Rationale**: Prevents stale data from old page being applied after page switch. Simple state machine, easy to reason about.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| BLE bandwidth during page switch (CONF_DATA + VAR_DATA burst) | CONF_DATA is small (~100 bytes per page). VAR_DATA is only active page values. Burst is acceptable. |
| RAM usage with many pages | 50 widgets ≈ 4.2KB. ESP32-S3 has 512KB. Can fit 200+ widgets comfortably. |
| Page switch during OTA | App disables page switcher during OTA. MCU ignores SET_PAGE during flash. |
| VAR_UPDATE arrives during page switch | App state machine discards stale data until PAGE_CHANGED received. |
| BLE reconnection loses page context | ACTIVE_PAGE in CONF_DATA header ensures automatic sync. |
| No backward compatibility with v1 | Clean break. All demos and user sketches must be updated. Documented as breaking change. |
