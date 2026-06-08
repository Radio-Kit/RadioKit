# Device Info & Button Group Redesign — Spec

> **Status:** Final  
> **Last updated:** 2026-06-08 (answers to open questions incorporated)  
> **Target files:** `flutter-app/lib/screens/home/models_tab.dart`  
> **Protocol changes:** `RadioKitProtocol.h`, `RadioKit.cpp`, `protocol.dart`, `device_provider.dart`  
> **New files needed:** None (changes land in existing files)  

---

## 1. Overview

Replace the current `_ActiveLinkSection` button layout (separate full-width buttons stacked vertically) with a **Material3 segmented button group** (three buttons in a single row). Add a **Device Info bottom sheet** triggered by the config icon button, displaying ESP32 chip information with quick-action buttons.

---

## 2. Active Link Section Redesign

### 2.1 Current state

The `_ActiveLinkSection` widget (in `models_tab.dart`) currently renders:

```
┌─────────────────────────────────────┐
│ [icon] TELEMETRY_LIVE ●             │
│        DEVICE_NAME                  │
│        [tag] [tag2]                 │
│ ─────────────────────────────────── │
│ LATENCY: XXms    SIGNAL: X dBm      │
│ ┌─────────────────────────────────┐ │
│ │         OPEN_CONTROLLER         │ │  ← full-width ElevatedButton
│ └─────────────────────────────────┘ │
│ ┌─────────────────────────────────┐ │
│ │ 📁 FILESYSTEM              │ │  ← full-width OutlinedButton (conditional)
│ └─────────────────────────────────┘ │
│ ┌─────────────────────────────────┐ │
│ │ 📥 UPDATE FIRMWARE         │ │  ← full-width OutlinedButton (conditional)
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

### 2.2 Target state

```
┌─────────────────────────────────────┐
│ [icon] TELEMETRY_LIVE ●             │
│        DEVICE_NAME                  │
│        [tag] [tag2]                 │
│ ─────────────────────────────────── │
│ LATENCY: XXms    SIGNAL: X dBm      │
│ ─────────────────────────────────── │
│ [⚙]  [   OPEN_CONTROLLER   ]  [🔗]│  ← M3 button group (custom Row)
└─────────────────────────────────────┘
```

- **Telemetry items** (LATENCY, SIGNAL) stay in the card as today.
- **Three buttons** in a single **Material3 SegmentedButton** row:
  1. **Config button** — icon only (`Icons.tune_rounded`), opens device info bottom sheet
  2. **Open Controller** — text label `OPEN_CONTROLLER`, navigates to `/control`
  3. **Disconnect button** — icon only (`Icons.link_off_rounded`), disconnects device

### 2.3 Button group implementation (custom Row, M3 button group style)

Use a **custom styled `Row`** that replicates the M3 button group look — connected segments with shared borders, no selection state:

```dart
Widget _buildActionRow() {
  return Container(
    decoration: BoxDecoration(
      border: Border.all(color: borderColor),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Row(
      children: [
        // Config (icon only)
        _buildGroupButton(
          icon: Icons.tune_rounded,
          onTap: () => _showDeviceInfo(context),
          isFirst: true,
        ),
        // Open Controller (text)
        Expanded(
          child: _buildGroupButton(
            label: 'OPEN_CONTROLLER',
            onTap: () => context.go('/control'),
          ),
        ),
        // Disconnect (icon only)
        _buildGroupButton(
          icon: Icons.link_off_rounded,
          onTap: () => deviceProvider.disconnect(),
          isLast: true,
        ),
      ],
    ),
  );
}
```

Where `_buildGroupButton` is a helper that renders each segment as a clickable widget with:
- Equal-height segments (52px)
- Internal dividers (1px vertical lines between segments)
- Hover/press states via `InkWell` or `TextButton` styling
- Dark background (`#2A2A2A`), orange accent on hover, white text/icons
- Square aspect for icon-only buttons (config, disconnect), flexible width for text button (Open Controller)
- First/last segments get rounded outer corners

### 2.4 Action handling

| Segment | Action | Icon | Behavior |
|---------|--------|------|----------|
| Config | Open device info | `Icons.tune_rounded` | Opens the Device Info bottom sheet |
| Open Controller | Navigate to control | None (text only) | `context.go('/control')` |
| Disconnect | Disconnect device | `Icons.link_off_rounded` | Calls `deviceProvider.disconnect()` |

---

## 3. Device Info Bottom Sheet

### 3.1 Trigger

Tapping the Config (⚙) segment in the Active Link button group opens a **Material3 bottom sheet** via `showModalBottomSheet`.

### 3.2 Contents

The bottom sheet has three sections, stacked vertically:

```
┌─ Device Info ──────────────────────┐
│ ┌─────────────────────────────┐    │
│ │   DEVICE NAME               │    │
│ │   device_type ● BLE         │    │  ← Header section
│ │   Connection: 48ms | MTU: 498    │
│ └─────────────────────────────┘    │
│                                     │
│  CHIP INFO                          │  ← Section label (orange, monospace)
│ ┌─────────────────────────────┐    │
│ │ Chip Model     ESP32-S3     │    │
│ │ Revision       v0.2         │    │
│ │ Cores          2            │    │
│ │ Flash Size     4 MB         │    │
│ │ PSRAM Size     2 MB         │    │
│ │ SDK Version    v5.1.4       │    │
│ │ Chip ID (MAC)  10:20:ba:... │    │
│ └─────────────────────────────┘    │
│                                     │
│  QUICK ACTIONS                      │  ← Section label (orange, monospace)
│ ┌─────────────────────────────┐    │
│ │ [FILESYSTEM] [UPDATE_FW]    │    │  ← SegmentedButton row
│ └─────────────────────────────┘    │
└─────────────────────────────────────┘
```

### 3.3 Header section

- **Device name**: from `connectedDevice.displayName`, large bold
- **Type badge**: `BLE` or `SERIAL` with dot indicator
- **Connection params**: latency ms, negotiated MTU, RSSI (from `sendGetBleInfo()` or cached `_bleInfoCompleter` result)

### 3.4 Chip info section

#### Data shown

| Field | Key in response | Format |
|-------|----------------|--------|
| Chip Model | `chipModel` | String, e.g. "ESP32-S3" |
| Revision | `chipRevision` | String, e.g. "v0.2" |
| Cores | `chipCores` | Numeric, e.g. 2 |
| Flash Size | `flashSize` | Formatted as "X MB" or "X KB" |
| PSRAM Size | `psramSize` | Formatted as "X MB" or "None" |
| SDK Version | `sdkVersion` | String, e.g. "v5.1.4" |
| Chip ID (MAC) | `chipId` | Hex string "XX:XX:XX:XX:XX:XX" |

#### Data source

A **new protocol command pair** is required on the Arduino side:

- **App → MCU**: `RK_CMD_GET_CHIP_INFO` (0x17)
- **MCU → App**: `RK_CMD_CHIP_INFO_DATA` (0x18)

The ESP32 firmware builds the response using:
- `esp_chip_info()` — chip model, revision, cores
- `ESP.getFlashChipSize()` — flash size
- `ESP.getPsramSize()` — PSRAM size
- `ESP.getSdkVersion()` — IDF SDK version string
- `esp_efuse_mac_get_default()` — 6-byte MAC address

#### Wire format (CHIP_INFO_DATA payload)

```
[modelLen(1)][modelChars(N)][revision(1)][cores(1)][flashSize(4 LE)][psramSize(4 LE)][sdkLen(1)][sdkChars(N)][mac(6)]
```

| Offset | Size | Field |
|--------|------|-------|
| 0 | 1 | `modelLen` — length of model string (N) |
| 1 | N | `model` — chip model string (e.g. "ESP32-S3") |
| 1+N | 1 | `revision` — chip revision number |
| 2+N | 1 | `cores` — number of cores |
| 3+N | 4 | `flashSize` — flash size in bytes (uint32 LE) |
| 7+N | 4 | `psramSize` — PSRAM size in bytes (uint32 LE, 0 if none) |
| 11+N | 1 | `sdkLen` — length of SDK version string (M) |
| 12+N | M | `sdkVersion` — IDF SDK version string |
| 12+N+M | 6 | `mac` — MAC address bytes |

Max payload: ~100 bytes (model ~20 chars + sdk ~20 chars + fixed fields 17 bytes).

#### Request flow

1. `DeviceProvider` sends `GET_CHIP_INFO` after connection (fire-and-forget, on first features data)
2. Device responds with `CHIP_INFO_DATA`
3. `DeviceProvider._handleChipInfoData()` parses and stores in `_chipInfo` field
4. Bottom sheet reads `_chipInfo` when opened; if null, fetches with a `Completer`
5. **Loading state**: while waiting, show spinner + "Fetching chip info..." in the chip info rows
6. **Error / timeout**: show dashes `--` for each field, with a small "Failed to fetch" note
7. **Demo mode**: all chip fields show `--`, connection params show demo defaults

### 3.5 Quick actions section

A segmented button row at the bottom with conditional buttons:

| Button | Condition | Action |
|--------|-----------|--------|
| FILESYSTEM | `device.hasFs == true` | Sheet **stays open**; navigates to `/dev-tools/esp32-fs` (FS screen renders on top of sheet) |
| UPDATE FIRMWARE | `deviceProvider.hasOta == true` | Sheet **stays open**; triggers file picker → OTA upload dialog (overlays sheet) |

Quick actions also use the **button group style** (custom `Row` of connected segments), not individual buttons.

### 3.6 Bottom sheet styling

- **Background**: `Color(0xFF1A1A1A)` (matching existing dialogs)
- **Shape**: rounded top corners (12px radius)
- **Drag handle**: `showDragHandle: true`
- **Dismissible**: tap outside to dismiss
- **Insets**: left/right padding 24px, top 20px, bottom 32px
- **Section labels**: orange (#FF8C00) 12px monospace, letter-spacing 1, uppercase
- **Header text**: device name in white 22px bold, connection params in gray 11px
- **Chip info rows**: label left-aligned (gray, 12px), value right-aligned (white, 12px monospace)

---

## 4. Protocol Constants to Add

### 4.1 Flutter side (`protocol.dart`)

```dart
const int kCmdGetChipInfo = 0x17;     // App → MCU: request chip info
const int kCmdChipInfoData = 0x18;    // MCU → App: chip info response
```

### 4.2 Arduino side (`RadioKitProtocol.h`)

```c
#define RK_CMD_GET_CHIP_INFO     0x17  // App → Arduino: request chip info
#define RK_CMD_CHIP_INFO_DATA    0x18  // Arduino → App: chip info [payload]
```

### 4.3 Arduino side (`RadioKit.h` / `RadioKit.cpp`)

- New handler: `_handleGetChipInfo()` — builds response from ESP32 APIs
- Dispatch in `_onPacket()` switch-case
- Tx buffer builder similar to `_handleGetFeatures()`

---

## 5. State Management

### 5.1 `DeviceProvider` changes

New fields:

```dart
Map<String, dynamic>? _chipInfo;
Completer<void>? _chipInfoCompleter;

Map<String, dynamic>? get chipInfo => _chipInfo;
```

New methods:

```dart
Future<void> _requestChipInfo();    // Send GET_CHIP_INFO, await response
void _handleChipInfoData(List<int> payload);  // Parse CHIP_INFO_DATA
```

### 5.2 Fetch timing

- `_requestChipInfo()` is called fire-and-forget after features request completes
- Cached in `_chipInfo` for the lifetime of the connection
- Cleared on disconnect

---

## 6. Resolved Decisions (from user interviews)

1. **Button group style**: Custom styled `Row` of connected segments (M3 button group style), NOT Flutter's `SegmentedButton` (which requires selection state). First/last segments have rounded outer corners; internal vertical dividers separate them.

2. **Sheet behavior on FILESYSTEM/UPDATE_FW**: Sheet **stays open**. When FILESYSTEM is tapped, the FS explorer screen renders on top (navigation push). When UPDATE_FIRMWARE is tapped, the file picker + OTA dialog overlay the sheet. The sheet remains in the widget tree underneath.

3. **Icons**:
   - Config (device info): `Icons.tune_rounded`
   - Open Controller: Text only (no icon)
   - Disconnect: `Icons.link_off_rounded`

4. **Chip info protocol command numbers**: `0x17` for GET_CHIP_INFO, `0x18` for CHIP_INFO_DATA. Confirmed no conflict with existing commands.

---

## 7. Implementation Plan (future)

1. Wire protocol
   - Add `RK_CMD_GET_CHIP_INFO`/`RK_CMD_CHIP_INFO_DATA` constants
   - Implement `_handleGetChipInfo()` in `RadioKit.cpp`
   - Build and flash firmware

2. Flutter state
   - Add `_chipInfo`, `_chipInfoCompleter` to `DeviceProvider`
   - Add `_requestChipInfo()`, `_handleChipInfoData()`
   - Wire into packet dispatch

3. UI: Active Link section
   - Replace current button stack with M3 segmented button row
   - Wire Config → bottom sheet, Open Controller → `/control`, Disconnect → `disconnect()`

4. UI: Device Info bottom sheet
   - Build `_DeviceInfoSheet` widget
   - Chip info section with loading/error/demo states
   - Quick actions section (FILESYSTEM, UPDATE_FIRMWARE)
