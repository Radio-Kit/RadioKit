# RadioKit Protocol - v3.0

## Overview

RadioKit uses a compact binary protocol which is transport-agnostic (works for BLE and Serial). The protocol is designed for low-latency, reliable control with minimal overhead.

---

## Packet Structure

```
[START][LENGTH_LO][LENGTH_HI][CMD][PAYLOAD...][CRC_LO][CRC_HI]
  0x55    total      total
```

| Field     | Size | Description                              |
|-----------|------|------------------------------------------|
| `START`   | 1    | Always `0x55`                            |
| `LENGTH`  | 2    | Total packet length including all fields |
| `CMD`     | 1    | Command byte                             |
| `PAYLOAD` | 0–N  | Command-specific payload                 |
| `CRC`     | 2    | CRC-16/CCITT-FALSE over `CMD + PAYLOAD`  |

Minimum packet size: **6 bytes** (no payload).

---

## Command Bytes

| Value  | Name             | Direction     | Description                           |
|--------|------------------|---------------|---------------------------------------|
| `0x01` | `GET_CONF`       | App → Arduino | Request configuration descriptor      |
| `0x02` | `CONF_DATA`      | Arduino → App | Configuration descriptor response     |
| `0x03` | `PING`           | App → Arduino | Connectivity check                    |
| `0x04` | `PONG`           | Arduino → App | Ping response                         |
| `0x05` | `ACK`            | Both          | Acknowledge reliable packet           |
| `0x06` | `GET_VARS`       | App → Arduino | Request current variable state        |
| `0x07` | `VAR_DATA`       | Arduino → App | Variable state response               |
| `0x08` | `VAR_UPDATE`     | Both          | Reliable push of a single widget state|
| `0x09` | `GET_META`       | App → Arduino | Request widget metadata               |
| `0x0A` | `META_DATA`      | Arduino → App | Metadata response                     |
| `0x0B` | `META_UPDATE`    | Both          | Reliable push of widget metadata      |
| `0x0C` | `SET_INPUT`      | Arduino → App | Set state of an input widget from Arduino|
| `0x0D` | `ACTIVE_STATE`   | App → Arduino | Bitmask of active widgets (1 bit/ID)  |
| `0x0E` | `GET_TELEMETRY`  | App → Arduino | Request signal/battery status         |
| `0x0F` | `TELEMETRY_DATA` | Arduino → App | Telemetry values (RSSI, etc.)         |

---

## CONF_DATA (Configuration)

Sent in response to `GET_CONF`. Contains device configuration and widget descriptors.

### Global Header

```
[PROTO_VER][ORIENT][WIDGET_COUNT][NAME_LEN][NAME...][DESC_LEN][DESC...]
[THEME_LEN][THEME...][VERSION_LEN][VERSION...]
```

| Field           | Type      | Description                                            |
|-----------------|-----------|--------------------------------------------------------|
| `PROTO_VER`     | `uint8_t` | Protocol version (current: `0x03`)                     |
| `ORIENT`        | `uint8_t` | `0x00` = Landscape, `0x01` = Portrait                  |
| `WIDGET_COUNT`  | `uint8_t` | Number of widget descriptors that follow               |
| `NAME_LEN`      | `uint8_t` | Length of device name string                           |
| `NAME`          | `char[N]` | Device identity name (UTF-8)                           |
| `DESC_LEN`      | `uint8_t` | Length of description string                           |
| `DESC`          | `char[N]` | Device description (UTF-8)                             |
| `THEME_LEN`     | `uint8_t` | Length of theme identifier string                      |
| `THEME`         | `char[N]` | Theme name (e.g., `"default"`, `"dark"`, `"retro"`)    |
| `VERSION_LEN`   | `uint8_t` | Length of version string                               |
| `VERSION`       | `char[N]` | Firmware version (UTF-8)                               |

### Widget Descriptor

Each widget is described by a fixed header followed by optional string data.

```
[TYPE][ID][X][Y][HEIGHT][WIDTH][ROT_LO][ROT_HI][VARIANT][STR_MASK][STR_DATA...]
```

| Field      | Type      | Description                                               |
|------------|-----------|-----------------------------------------------------------|
| `TYPE`     | `uint8_t` | Widget type ID (see table below)                          |
| `ID`       | `uint8_t` | Widget index (0-based, sequential)                        |
| `X`        | `uint8_t` | Center X on virtual canvas (0–200)                        |
| `Y`        | `uint8_t` | Center Y on virtual canvas (0–200)                        |
| `HEIGHT`   | `uint8_t` | Physical height in virtual units (0–200)                  |
| `WIDTH`    | `uint8_t` | Physical width in virtual units (0 = auto-aspect)         |
| `ROTATION` | `int16_t` | Rotation in degrees (clockwise)                           |
| `VARIANT`  | `uint8_t` | Behavioral variation (e.g., spring mode)                  |
| `STR_MASK` | `uint8_t` | String bitmask (determines following string segments)     |

#### Widget Type IDs

| ID  | Widget          | Description                          |
|-----|-----------------|--------------------------------------|
| 1   | PushButton      | Momentary button                     |
| 2   | ToggleButton    | Latching button                      |
| 3   | SlideSwitch     | iOS-style toggle switch              |
| 4   | Slider          | Linear slider (-100 to +100)         |
| 5   | Knob            | Rotary knob (-100 to +100)           |
| 6   | Joystick        | 2-axis joystick                      |
| 7   | LED             | Status indicator                     |
| 8   | Text            | Read-only text display               |
| 9   | MultipleButton  | Radio-style button group             |
| 10  | MultipleSelect  | Checkbox-style group                 |

#### String Bitmask (`STR_MASK`)

Bits indicate which optional strings are included. Each active bit adds a `[LEN][STR]` pair to the `STR_DATA` block.

- **Bit 0 (0x01)**: Label (primary display text)
- **Bit 1 (0x02)**: Icon (standard name string)
- **Bit 2 (0x04)**: OnText (for buttons)
- **Bit 3 (0x08)**: OffText (for buttons)
- **Bit 4 (0x10)**: Content (for Text widget initial value)

Each string is encoded as: `[LENGTH (1 byte)][UTF-8 DATA]`

---

## Runtime Communication

### VAR_DATA (Full State Sync)

Sent in response to `GET_VARS`. Contains the current state of all widgets in ID order.

```
[DATA_W0][DATA_W1][DATA_W2]...
```

Each widget's data is encoded according to its type:

| Type  | Widget          | Data Bytes                              | Description                     |
|-------|-----------------|-----------------------------------------|---------------------------------|
| 1     | PushButton      | 1 byte                                  | Current state (0/1)             |
| 2     | ToggleButton    | 1 byte                                  | Current state (0/1)             |
| 3     | SlideSwitch     | 1 byte                                  | Current state (0/1)             |
| 4     | Slider          | 1 byte                                  | Value (Signed int8, -100 to +100)|
| 5     | Knob            | 1 byte                                  | Value (Signed int8, -100 to +100)|
| 6     | Joystick        | 2 bytes                                 | X, Y values (Signed int8, -100 to +100)|
| 7     | LED             | 5 bytes                                 | State (1), R, G, B, Opacity     |
| 8     | Text            | 32 bytes                                | UTF-8 string (null-padded)      |
| 9     | MultipleButton  | 1 byte                                  | Selected item(s) (Index or Bitmask)|
| 10    | MultipleSelect  | 1 byte                                  | Selected item(s) (Index or Bitmask)|

### SET_INPUT (Arduino → App)

Sent by the Arduino to programmatically set the state of an input widget in the app (e.g., resetting a slider or toggle).

```
[ID][VALUE...]
```

| Field  | Type      | Description                              |
|--------|-----------|------------------------------------------|
| `ID`   | `uint8_t` | Widget index                             |
| `VALUE`| variable  | Type-specific value (see VAR_DATA table) |

The app updates the widget UI immediately. Unlike `VAR_UPDATE`, this is not acknowledged.

### VAR_UPDATE (Reliable Push)

Pushes a change for a single widget. Can be sent by either side:
- **App → Arduino**: When user changes an input.
- **Arduino → App**: When firmware programmatically changes a widget state

```
[ID][SEQ][DATA...]
```

| Field  | Type      | Description                              |
|--------|-----------|------------------------------------------|
| `ID`   | `uint8_t` | Widget index                             |
| `SEQ`  | `uint8_t` | Rolling sequence number (0-255)          |
| `DATA` | variable  | Type-specific value (see VAR_DATA table) |

#### Reliability Logic

- The sender maintains a **pending bitmask** (32-bit) for unacknowledged updates
- Retransmission timeout: **200 ms**
- Maximum retries: **5 attempts**
- After 5 failures, the packet is dropped (fail-soft)
- The receiver sends `ACK` immediately upon receipt

### ACK (Acknowledgment)

Confirms receipt of a reliable packet (`VAR_UPDATE` or `META_UPDATE`).

```
[SEQ]
```

| Field  | Type      | Description                              |
|--------|-----------|------------------------------------------|
| `SEQ`  | `uint8_t` | Sequence number being acknowledged       |

### ACTIVE_STATE (App → Arduino)

Sent whenever the "active" status of one or more widgets changes (e.g., user starts/stops touching a slider).

```
[BITMASK (4 bytes)]
```

- **Payload**: A 32-bit bitmask (Little-Endian).
- **Mapping**: Bit `n` corresponds to Widget ID `n`.
- **Value**: `1` = Active (being manipulated), `0` = Idle.

### META_DATA & META_UPDATE

Same format as VAR_DATA/VAR_UPDATE but for widget metadata (label, icon, etc.). Used when firmware changes widget appearance at runtime.

### TELEMETRY (Arduino → App)

Periodic status updates (optional).

```
[RSSI][LATENCY][RESERVED][RESERVED]
```

| Field      | Type      | Description                               |
|------------|-----------|-------------------------------------------|
| `RSSI`     | `int8_t`  | Signal strength (dBm)                     |
| `LATENCY`  | `uint8_t` | Reserved for latency                      |
| `RESERVED` | `uint8_t` | Reserved                                  |
| `RESERVED` | `uint8_t` | Reserved                                  |

---

## Transports

### BLE (NimBLE)

| Role           | UUID                                     |
|----------------|------------------------------------------|
| **Service**    | `0000FFE0-0000-1000-8000-00805F9B34FB`   |
| **Characteristic** | `0000FFE1-0000-1000-8000-00805F9B34FB`   |

- **Properties**: Write (no response), Notify, Indicate
- **MTU**: 23 bytes (default), negotiated up to 517
- **Packet fragmentation**: Handled by NimBLE for packets > MTU
- **Flow control**: Credit-based (app grants credits for sends)

### USB Serial / UART

- **Baud rate**: 1000000 (recommended), any speed supported
- **Connection timeout**: 3000 ms after last valid packet
- **Recommended PING interval**: 1000 ms
- **Hardware flow control**: Optional (RTS/CTS)

### Web Serial (Chrome/Edge)

- Same as USB Serial
- Browser handles serial port selection
- No baud rate restrictions (virtual port)

---

## Timing & Keepalive

- **PING interval**: 1000–2000 ms (app → Arduino)
- **PONG timeout**: 3000 ms (no response = disconnected)
- **VAR_UPDATE retry**: 200 ms interval, 5 max retries
- **Connection timeout**: 5000 ms (no data from either side)

---

## Error Handling

- **CRC mismatch**: Packet silently discarded
- **Invalid START byte**: Stream resynchronized on next `0x55`
- **Unknown CMD**: Packet ignored (future compatibility)
- **Buffer overflow**: Packet truncated, connection reset
- **Reliable packet timeout**: Retransmit up to 5 times, then drop

---

## Example Session

```
App → Arduino:  GET_CONF
Arduino → App: CONF_DATA (with all widget descriptors)
App → Arduino: GET_VARS
Arduino → App: VAR_DATA (current state of all widgets)
[User taps button]
App → Arduino: VAR_UPDATE with new state
Arduino → App: ACK
[Arduino resets slider to zero]
Arduino → App: SET_INPUT (or VAR_UPDATE) with value 0
[LED state changes programmatically]
Arduino → App: VAR_UPDATE (with LED new state)
App → Arduino: ACK
```

---

## Bulk Filesystem Protocol (0xAA)

A separate, higher-bandwidth protocol runs on the **same physical transport** for filesystem operations (browse, read, write, delete, mkdir, rename, info, ping, format). It uses a different start byte so it can coexist with the widget protocol (0x55) without interfering.

The FS protocol is suitable for transferring multi-kilobyte files without bloating the 0x55 widget state machine.

### FS Frame Structure

```
[START][SUB_CMD][LEN_LO][LEN_HI][PAYLOAD...]
  0xAA   uint8     uint8   uint8   0..16380 bytes
```

| Field     | Size     | Description                                       |
|-----------|----------|---------------------------------------------------|
| `START`   | 1        | Always `0xAA`                                     |
| `SUB_CMD` | 1        | FS sub-command (see table)                        |
| `LEN`     | 2 (LE)   | **Total frame length** (header(4) + payload)      |
| `PAYLOAD` | 0..16380 | Sub-command-specific payload                      |
| **CRC**   | **none** | No checksum — rely on transport reliability       |

Maximum payload size: **16 380 bytes** (16 384 − 4-byte header).

### Sub-Commands (App → Arduino)

| Value  | Name              | Payload                                              | Description                            |
|--------|-------------------|------------------------------------------------------|----------------------------------------|
| `0x01` | `FS_LIST`         | `[u8 path_len][path...]`                              | List entries in a directory            |
| `0x02` | `FS_READ`         | `[u8 path_len][path...][u32 offset][u16 max_bytes]`   | Read up to 65 535 bytes from offset    |
| `0x03` | `FS_WRITE`        | `[u8 path_len][path...][u32 offset][bytes...]`         | Write a file chunk (offset 0 truncates) |
| `0x04` | `FS_DELETE`       | `[u8 path_len][path...][u8 recursive]`                | Delete a file or directory             |
| `0x05` | `FS_INFO`         | (empty)                                              | Get FS usage / free space              |
| `0x06` | `FS_MKDIR`        | `[u8 path_len][path...]`                              | Create a directory                     |
| `0x07` | `FS_RENAME`       | `[u8 old_len][old...][u8 new_len][new...]`            | Rename / move a file or directory      |
| `0x08` | `FS_UPLOAD_BEGIN` | `[u8 path_len][path...][u32 size]`                    | Begin a multi-frame write              |
| `0x09` | `FS_UPLOAD_CHUNK` | `[u8 path_len][path...][u32 offset][bytes...]`         | Write a chunk of an upload             |
| `0x0A` | `FS_UPLOAD_END`   | `[u8 path_len][path...][u32 size]`                    | Finalize a multi-frame write           |
| `0x0B` | `FS_PING`         | (empty)                                              | Capability probe — replies `FS_PING_ACK` |
| `0x0C` | `FS_FORMAT`       | (empty)                                              | Re-format the default FS (destructive) |

### Sub-Commands (Arduino → App)

| Value  | Name                  | Payload                                                              | Description                                |
|--------|-----------------------|----------------------------------------------------------------------|--------------------------------------------|
| `0x81` | `FS_LIST_DATA`        | `[u16 count]` then per entry `[u8 is_dir][u32 size][u8 name_len][name...]` | Directory listing result                   |
| `0x82` | `FS_READ_DATA`        | `[u32 total_size][u32 offset][bytes...]`                              | File chunk (offset + length tell client position) |
| `0x83` | `FS_WRITE_ACK`        | `[u8 err]`                                                            | Write ack                                  |
| `0x84` | `FS_DELETE_ACK`       | `[u8 err]`                                                            | Delete ack                                 |
| `0x85` | `FS_INFO_DATA`        | `[u32 total][u32 used][u16 block_size][u8 fs_type]`                   | FS usage / metadata                        |
| `0x86` | `FS_MKDIR_ACK`        | `[u8 err]`                                                            | Mkdir ack                                  |
| `0x87` | `FS_RENAME_ACK`       | `[u8 err]`                                                            | Rename ack                                 |
| `0x88` | `FS_UPLOAD_BEGIN_ACK` | `[u8 err]`                                                            | Upload begin ack                           |
| `0x89` | `FS_UPLOAD_CHUNK_ACK` | `[u8 err]`                                                            | Upload chunk ack                           |
| `0x8A` | `FS_UPLOAD_END_ACK`   | `[u8 err]`                                                            | Upload end ack                             |
| `0x8B` | `FS_PING_ACK`         | `[u8 status]`                                                         | Mount status (0 = mounted, 0x03 = NO_FS)  |
| `0x8C` | `FS_FORMAT_ACK`       | `[u8 err]`                                                            | Format ack                                 |

### Error Codes (returned in all `*_ACK` payloads and `FS_PING_ACK`/`FS_READ_DATA`)

| Value | Name              | Meaning                                |
|-------|-------------------|----------------------------------------|
| `0x00`| `OK`              | Success                                |
| `0x01`| `NOT_FOUND`       | File or directory does not exist       |
| `0x02`| `IO`              | Read/write error                       |
| `0x03`| `NO_FS`           | LittleFS not compiled in or not mounted |
| `0x04`| `ACCESS_DENIED`   | Permission denied                      |
| `0x05`| `INVALID_PATH`    | Malformed path or argument             |
| `0x06`| `OUT_OF_SPACE`    | Filesystem full                        |
| `0x07`| `INVALID_STATE`   | Operation not valid in current state   |

### Notes

- The FS protocol is optional. Sketches that don't use it can simply not call `RadioKit.beginFs()`.
- Sketches may override the default `LittleFS` backend by re-implementing the `RKFs::listDir`, `RKFs::readFile`, `RKFs::writeFile`, `RKFs::delFile`, `RKFs::getInfo`, `RKFs::mkdir`, `RKFs::rename` functions (weak symbols).
- The two state machines (0x55 widget + 0xAA FS) are fed from the same byte stream and demuxed by the start byte. There is no contention.
- `FS_PING` is the recommended way to detect FS support on a freshly-connected device. The app sends a few probes; if any reply is `OK`, set `hasFs = true`.

### Example: Capability detection (PING)

```
App  → Arduino: FS_PING
  0xAA 0x0B 0x04 0x00          // header only, no payload (LEN=4)

Arduino → App: FS_PING_ACK (mounted)
  0xAA 0x8B 0x05 0x00 0x00     // LEN=5, status=OK
```

### Example: Listing a directory

```
App → Arduino: FS_LIST ("/")
  0xAA 0x01 0x05 0x00 0x01 0x2F     // path_len=1, "/"

Arduino → App: FS_LIST_DATA (2 entries)
  0xAA 0x81 0x14 0x00                  // LEN=20
  0x02 0x00                            // count=2
  0x01 0x00 0x00 0x00 0x00 0x04 'd' 'e' 'm' 'o'      // dir, 0 bytes, "demo"
  0x00 0x57 0x00 0x00 0x00 0x04 'R' 'E' 'A' 'D' 'M' 'E'  // file, 87 bytes, "README"
```

### Example: Reading a file in chunks

```
App → Arduino: FS_READ ("/README", offset=0, max=512)
  0xAA 0x02 ...
  // path_len=7, "README", 4-byte offset=0, 2-byte max=512

Arduino → App: FS_READ_DATA (87 bytes total, sent 87 in this chunk)
  0xAA 0x82 ...
  // 4-byte total_size=87, 4-byte offset=0, then 87 data bytes

App → Arduino: FS_READ ("/README", offset=512, max=512)
  // (offset past EOF — server returns 0 data bytes)
Arduino → App: FS_READ_DATA (87 total, 0 bytes at offset 512)
  // → client knows EOF, no more reads needed
```

### Example: Upload a small file

```
App → Arduino: FS_WRITE ("/hello.txt", offset=0, "Hello, world!")
  // 12 bytes of payload after path + offset

Arduino → App: FS_WRITE_ACK
  0xAA 0x83 0x05 0x00 0x00       // LEN=5, err=0 (OK)
```

---

## Version History

| Version | Changes |
|---------|---------|
| v0.01   | Initial protocol (GET_CONF, CONF_DATA only) |
| v0.02   | Added VAR_DATA, SET_INPUT |
| v0.03   | Added reliability (ACK, VAR_UPDATE) |
| v2.0    | Added META_DATA, TELEMETRY, expanded to 256 widgets, aspect ratio support |
| v3.0    | Current version — Absolute Height/Width layout, META_UPDATE, enhanced reliability |
| v3.1    | Added bulk Filesystem protocol (0xAA start byte, 16 KB max payload, no CRC) |
| v3.2    | Added FS_PING (0x0B) and FS_FORMAT (0x0C) sub-commands for capability detection and partition formatting |