# File Editor — Specification

## Overview

Add an in-app code/text file editor to the filesystem explorer screen. Users can open editable files in a near-fullscreen overlay dialog, edit the content, save back to the device with CRC32-verified integrity, and benefit from an in-memory cache for faster re-opening.

---

## 1. Protocol Changes

### 1.1 New FS commands

Add the following to both Flutter (`protocol.dart` + `FsProtocolService`) and Arduino (`RadioKitFsHandlers.h/cpp` + `RadioKitFS.h`):

#### `kFsCmdReplace` (0x0D) — App → MCU

Replaces the content of a single file in one frame (for files ≤ ~16KB). Payload:
```
[PATH_LEN(1)][PATH(N)][CRC32(4 LE)][CONTENT(M)]
```

The device:
1. Validates frame — if malformed (bad path_len, wrong length), replies with `kFsErrInvalidPath`
2. If an upload is active (`s_upload.active`), aborts the pending upload first (cleans up partial file)
3. Opens the file for writing (truncates)
4. Writes CONTENT
5. Computes CRC32 over CONTENT using IEEE 802.3 polynomial (0xEDB88320)
6. Compares with the sent CRC32
7. Replies with `kFsRespReplaceAck` (0x8D) + status byte (`kFsErrOk` or `kFsErrIo`)
8. On CRC mismatch: deletes the file (same as upload protocol), returns `kFsErrIo`

If the file content exceeds `kFsMaxPayload - 5 - pathLen` (~16363 bytes for a typical short path), the app falls back to the existing **UPLOAD_BEGIN/CHUNK/END** protocol automatically.

**Edge case — empty file (0 bytes):** Sends CRC32=0x00000000 (CRC of empty input) with empty content. The device creates a zero-byte file and verifies CRC32 matches — valid operation.

#### `kFsCmdCrc32` (0x0E) — App → MCU

Requests the CRC32 checksum of a file. Payload:
```
[PATH_LEN(1)][PATH(N)]
```Device response: `kFsRespCrc32Data` (0x8E). Payload:
```
[STATUS(1)][CRC32(4 LE)][FILE_SIZE(4 LE)]
```
- **STATUS** = `0x00` if file exists and CRC32 was computed; `0x01` if file not found
- CRC32 is computed over the entire file using IEEE 802.3 polynomial (only valid when STATUS=0x00)
- **File not found (STATUS=0x01):** CRC32 and SIZE fields are zeroed. The app checks STATUS first — if 0x01, treats as cache miss (discard cache if present) and shows "File not found".
- **Performance guard:** If the file is larger than 512 KB, the device returns STATUS=0x01 (same as not-found) to keep BLE response latency predictable. CRC32 of a large file could block the notification handler for seconds.
- **Empty file (0 bytes):** STATUS=0x00, CRC32=0x00000000 (CRC of empty input), SIZE=0. This is now distinguishable from not-found via the STATUS byte.
- No backward compatibility needed (user confirmed). Devices without this command will timeout — the app handles this with a short timeout (3s).

### 1.2 Protocol constants

```dart
// protocol.dart additions
const int kFsCmdReplace     = 0x0D;
const int kFsCmdCrc32       = 0x0E;
const int kFsRespReplaceAck = 0x8D;
const int kFsRespCrc32Data  = 0x8E;
```

### 1.3 FsProtocolService builders

```dart
/// Max content that fits in a single REPLACE frame for a given path length.
/// Frame max = kFsHeaderSize + kFsMaxPayload = 4 + 16384 = 16388 bytes.
/// Overhead = PATH_LEN(1) + PATH(N) + CRC32(4).
int replaceMaxContent(String path) =>
    kFsMaxPayload - 5 - utf8.encode(path).length;  // 5 = 1(path_len) + 4(crc32)

/// Build a REPLACE frame (single-frame file replace with CRC32).
/// Throws if content exceeds [replaceMaxContent] — caller should fall back
/// to UPLOAD_BEGIN/CHUNK/END.
static Uint8List buildReplace(String path, Uint8List content) {
  final crc = _crc32(content);
  final p = _pathPayload(path);
  p.add(crc & 0xFF);
  p.add((crc >> 8) & 0xFF);
  p.add((crc >> 16) & 0xFF);
  p.add((crc >> 24) & 0xFF);
  p.addAll(content);
  return buildFrame(kFsCmdReplace, p);
}

/// Build a CRC32 request frame.
static Uint8List buildCrc32(String path) =>
    buildFrame(kFsCmdCrc32, _pathPayload(path));

/// Parse CRC32 response: [STATUS(1)][CRC32(4 LE)][SIZE(4 LE)].
/// Returns null on malformed payload.
/// [found] is false when the file doesn't exist or was too large to CRC.
static ({bool found, int crc32, int size})? parseCrc32Data(List<int> payload) {
  if (payload.length < 9) return null;
  final found   = payload[0] == 0x00;
  final crc32   = payload[1] | (payload[2] << 8) | (payload[3] << 16) | (payload[4] << 24);
  final size    = payload[5] | (payload[6] << 8) | (payload[7] << 16) | (payload[8] << 24);
  return (found: found, crc32: crc32, size: size);
}
```

---

## 2. Caching System (In-Memory)

### 2.1 Data structure

```dart
class FileEditorCache {
  /// Path → (content bytes, crc32 at time of fetch)
  final Map<String, ({Uint8List data, int crc32})> _cache = {};

  /// Max entries — prevents unbounded memory growth.
  static const int _maxEntries = 10;
  /// Max total bytes — approximate (sum of data lengths).
  static const int _maxBytes = 50 * 1024 * 1024; // 50 MB

  bool has(String path) => _cache.containsKey(path);
  ({Uint8List data, int crc32})? get(String path) => _cache[path];

  void set(String path, Uint8List data, int crc32) {
    _enforceLimit();
    _cache[path] = (data: data, crc32: crc32);
  }

  void remove(String path) => _cache.remove(path);
  void clear() => _cache.clear();

  /// Evict oldest entry if over limit.
  void _enforceLimit() {
    if (_cache.length >= _maxEntries) {
      final oldest = _cache.keys.first;
      _cache.remove(oldest);
    }
    final total = _cache.values.fold<int>(0, (sum, e) => sum + e.data.length);
    if (total > _maxBytes) {
      // Evict entries until under limit (FIFO)
      while (_cache.isNotEmpty) {
        final oldest = _cache.keys.first;
        final removed = _cache.remove(oldest)!.data.length;
        if (_cache.values.fold<int>(0, (s, e) => s + e.data.length) + removed < _maxBytes) break;
      }
    }
  }
}
```

### 2.2 Cache flow for opening a file

```
User taps Edit on a file tile
  → Show loading spinner on tile + status bar
  → Check cache: does _cache contain this path?
    YES:
      → Send CRC32 request to device (kFsCmdCrc32)
      → Wait up to 3s for response (guard against old firmware)
        → Timeout: skip cache, re-download file
      → Parse response (CRC32 + size)
        → found == false: file doesn't exist or too large to CRC → clear cache entry,
                      show error "File not found on device" (or download fresh if large)
        → found == true && CRC32 matches cache: open editor with cached
          content (instant, no download)
        → found == true && CRC32 differs: discard cache entry,
          download fresh content from device
    NO:
      → Download full file from device (existing readFile with progress)
      → Compute CRC32 on downloaded bytes
      → Store in cache: _cache[path] = (data, crc32)
  → Open editor with content
  → Hide loading spinner
```

### 2.3 Cache invalidation

| Event | Action |
|-------|--------|
| Device disconnects | `clear()` entire cache |
| File deleted via FS explorer | `remove(path)` for deleted path |
| File renamed | `remove(oldPath)` — cache for new path will be populated on first open |
| File saved from editor | Update entry with new content + CRC32 |
| File uploaded via upload button | `remove(path)` — stale data, re-fetch on next edit |
| File replaced via action sheet replace | `remove(path)` |

---

## 3. UI Changes

### 3.1 Edit button on file tile (`FsFileTile`)

- Add a trailing `IconButton` with `Icons.edit_rounded` (pencil icon) for editable file types
- Editable types (determined by `fileExtension()`):
  - Plain text: `.txt`, `.md`, `.log`, `.csv`, `.tsv`, `.xml`, `.json`, `.yaml`, `.yml`, `.toml`, `.cfg`, `.conf`, `.ini`, `.env`, `.gitignore`, `.gitkeep`
  - Code: `.cpp`, `.h`, `.hpp`, `.c`, `.cc`, `.cxx`, `.py`, `.js`, `.ts`, `.dart`, `.html`, `.css`, `.scss`, `.sass`, `.less`, `.ino`, `.java`, `.kt`, `.swift`, `.go`, `.rs`, `.rb`, `.php`, `.sh`, `.bash`, `.zsh`, `.pl`, `.lua`
- The existing `more_vert` icon remains for all files (accesses the full action sheet)
- Layout: trailing area shows `[edit icon] [more_vert icon]` for editable files, or just `[more_vert icon]` for non-editable files
- Edit icon styling: subdued (38% opacity, 18px), same accent color as the file type icon
- **Multi-select mode**: Edit icon is hidden (only checkboxes shown during multi-select)
- Tapping the edit icon triggers the **editor open flow** directly

### 3.2 Loading indicator

- While downloading for editor open:
  - **File tile**: Replace the size text with a small `CircularProgressIndicator` (strokeWidth: 2, 14x14)
  - **Status bar**: Show "Loading /path/to/file…" with `LinearProgressIndicator`
- On cache hit + CRC32 match: no loading indicator (instant open)
- On cache hit + CRC32 mismatch: show "Checking /path…" in status bar, then download progress
- On CRC32 timeout: show "Device not responding — downloading fresh…"

### 3.3 Near-fullscreen overlay dialog

Opened via `showDialog()` as a near-fullscreen overlay (barrierDismissible: false).

#### Layout

```
┌─────────────────────────────────────────────┐
│ [← Back]     filename.txt         [💾 Save] │  ← Top bar
├─────────────────────────────────────────────┤
│                                             │
│  [Editor content area — re_editor widget]   │
│  (with line numbers, syntax highlighting)   │
│                                             │
│                                             │
├─────────────────────────────────────────────┤
│  [Status: "Modified" / "Saved ✔" / Err]     │  ← Optional bottom strip
└─────────────────────────────────────────────┘
```

- **Top bar** (`Color(0xFF1A1A1A)` background, 48px height):
  - `IconButton(Icons.arrow_back_rounded)` — Close. If modified: show "Discard changes?" confirmation
  - `SizedBox(12)`
  - `Text(basename(path))` — monospace, ellipsis, white, 14px
  - `Spacer()`
  - `IconButton(Icons.save_rounded)` — Save. Disabled while saving
- **Editor area** — Recessed within padding `EdgeInsets.all(16)`. Uses the chosen code editor package.
- **Bottom strip** (optional, 32px): Shows "Saved ✔" for 2s after success, "Saving…" during save, or error messages.

#### Dialog properties

| Property | Value |
|----------|-------|
| `barrierDismissible` | `false` |
| `backgroundColor` | `Colors.transparent` |
| Transition | `SizeTransition` or `FadeTransition` (brief, <200ms) |
| Width | `MediaQuery.of(context).size.width - (platform == tablet ? 40 : 16)` |
| Height | `MediaQuery.of(context).size.height - (platform == tablet ? 60 : 16)` |

The dialog is **near-fullscreen** — a small margin (8-20px) provides visual separation from the background.

#### Back button behavior

- If content modified since last save: show `AlertDialog` — "Discard changes?" with [Cancel, Discard]
- If unmodified: close immediately

#### Keyboard shortcuts

- `Ctrl+S` / `Cmd+S` — Save (native `Shortcuts` widget or `HardwareKeyboard` handler)
- `Ctrl+Z` / `Cmd+Z` — Undo (provided by re_editor natively)
- `Ctrl+Shift+Z` / `Cmd+Shift+Z` — Redo (provided by re_editor natively)

### 3.4 Integration with device info sheet's FS tab

The file editor should also work from the FS tab inside the device info bottom sheet (`_FsTabContent` in `models_tab.dart`). Both the standalone `FilesystemExplorerScreen` and the inline `_FsTabContent` share the same `DeviceFsService` and should share the same `FileEditorCache` instance. Approach:

- Make `FileEditorCache` a shared singleton (or pass it through the widget tree)
- Both screens wire their file tiles the same way: edit icon → editor open flow
- The `FileEditorDialog` is the same widget regardless of which screen opens it

---

## 4. Save Flow

```
User taps Save
  → Disable save button (prevent double-save)
  → Show "Saving…" in bottom strip
  → Read current content from editor
  → Determine save method:
     IF content fits in one REPLACE frame (≤ replaceMaxContent(path)):
       → Send REPLACE command with CRC32
       → Timeout (10s): show error "Save failed — device unreachable"
       → CRC error (kFsErrIo): show "Save failed — data corrupted, retry"
       → Other error: show "Save failed — {errorName}"
     ELSE (larger files > ~16KB):
       → Use UPLOAD_BEGIN/CHUNK/END protocol (existing writeFileUpload)
       → Show progress in status bar (per-chunk)
  → On success:
     → Update cache: _cache[path] = (newData, newCrc32)
     → Show "Saved ✔" for 2s (auto-dismiss)
     → Trigger auto-refresh of the parent explorer's file list
     → Re-enable save button
  → On failure:
     → Show error persistently in bottom strip (not snackbar)
     → Re-enable save button so user can retry or copy content
```

---

## 5. Files Affected

### Protocol layer
- `flutter-app/lib/models/protocol.dart` — add `kFsCmdReplace` (0x0D), `kFsCmdCrc32` (0x0E), `kFsRespReplaceAck` (0x8D), `kFsRespCrc32Data` (0x8E)
- `flutter-app/lib/services/fs_protocol_service.dart` — add `buildReplace()`, `buildCrc32()`, `parseCrc32Data()`, `replaceMaxContent()`
- `flutter-app/lib/services/device_fs_service.dart` — add `replaceFile(path, content)` and `getFileCrc32(path)` methods

### Arduino firmware
- `arduino-library/src/connection/RadioKitFS.h` — add `RK_FS_CMD_REPLACE` (0x0D), `RK_FS_CMD_CRC32` (0x0E), response sub-commands
- `arduino-library/src/connection/RadioKitFsHandlers.cpp` — add `handleReplace()`, `handleCrc32()` handlers and dispatch entries
  - `handleReplace`: validate frame, abort active upload if any, write content, verify CRC32, clean up on mismatch
  - `handleCrc32`: check file size > 512KB → return size=0 (skip), else compute CRC32 over entire file, return CRC32 + size

### UI layer
- New: `flutter-app/lib/screens/devtools/filesystem/file_editor_cache.dart` — in-memory cache with size limits
- New: `flutter-app/lib/screens/devtools/filesystem/file_editor_dialog.dart` — near-fullscreen editor overlay
- `flutter-app/lib/screens/devtools/filesystem/fs_file_tile.dart` — add trailing edit icon for editable file types
- `flutter-app/lib/screens/devtools/filesystem/filesystem_explorer_screen.dart` — wire edit icon to editor flow, add per-tile loading state, auto-refresh after save, evict cache on external upload/delete
- `flutter-app/lib/screens/home/models_tab.dart` (`_FsTabContent`) — same edit icon + editor flow for the inline FS tab

### Package dependency

Add a code editor package. Primary choice: **re_editor** (latest: `0.9.0`, June 2025). Alternative: **flutter_code_editor** (more actively maintained, 100+ languages, code folding support). Verify package compatibility with the project's Flutter version at implementation time.

If neither package works (e.g., breaking API changes), fallback to a styled `TextField`:
- `maxLines: null` with `expands: true`
- `GoogleFonts.jetBrainsMono()` for monospace font
- No syntax highlighting
- `Shortcuts` widget for Ctrl+S save binding

### Demo FS
- `flutter-app/lib/services/demo_fs_state.dart` — implement `replace()` (reuse existing `writeFile` with CRC32 check) and `crc32()` (compute CRC32 over in-memory data, skip if > 512KB)
- `flutter-app/lib/services/demo_fs_transport.dart` — dispatch `kFsCmdReplace` and `kFsCmdCrc32` to `DemoFsState`

---

## 6. Edge Cases & Constraints

| Scenario | Behavior |
|----------|----------|
| **Empty file (0 bytes)** | REPLACE with CRC32=0x00000000 + empty content. CRC32 command returns STATUS=0x00, CRC32=0x00000000, SIZE=0. Distinguishable from not-found via the STATUS byte. Cache hit handled normally. |
| **File too large for REPLACE** | Fall back to UPLOAD_BEGIN/CHUNK/END protocol (existing `writeFileUpload`). |
| **Device without CRC32 command** | Timeout after 3s → skip cache, re-download file (defensive, since backward compat isn't needed). |
| **Device without REPLACE command** | Fall back to existing WRITE at offset 0 (no CRC32) then upload protocol. |
| **Large file CRC32 (>512 KB)** | Device returns size=0 (skip CRC on large files). App treats as cache miss, re-downloads. |
| **CRC32 command timeout** | 3s timeout → treat as cache miss, download fresh content. |
| **User closes without saving** | Show "Discard changes?" confirmation if content modified since last save. |
| **Cache hit (CRC32 matches)** | Open editor instantly with cached content — no network round trip. |
| **Cache hit (CRC32 mismatch)** | Discard cache, download fresh content, update cache, then open editor. |
| **Disconnect during edit** | Show "Connection lost" message in bottom strip. Save button disabled. Editor stays open with content intact. |
| **Reconnection** | Cache preserved across disconnect/reconnect. Next edit tap triggers CRC32 check. |
| **File deleted while editor open** | Save will fail with NOT_FOUND. Show "File was deleted on device — close editor?" |
| **File renamed while editor open** | Save will fail (path no longer exists). Show "File was renamed — close editor?" |
| **Binary file** | No edit icon shown. Existing action sheet (Download, Rename, Info, Delete) unchanged. |
| **Very large file (>500 KB)** | Show warning dialog before opening: "This file is large (X MB). Editing may be slow. Open anyway?" |
| **Multiple rapid saves** | Save button disabled during save. Subsequent taps are ignored until current save completes. |
| **UTF-8 malformed content** | Display with replacement characters (�). Content is sent as raw bytes to device — no transformation on save. |
| **Cache stale from external upload** | Any upload/delete/rename operation via the FS explorer evicts the affected path from cache. |
| **No syntax highlighting (fallback)** | Plain monospace TextField with keyboard shortcut bindings. |

---

## 7. Package Recommendation: `re_editor`

Based on research (pub.dev, June 2025):

| Package | Latest | Notes |
|---------|--------|-------|
| **re_editor** | 0.9.0 | Modern, high-performance code editor built from scratch (not wrapping TextField). Part of the Reqable project. 40+ languages syntax highlighting, code folding, line numbers, auto-indent, undo/redo, find/replace. |
| **flutter_code_editor** | Active | 100+ languages, code folding, pluggable analyzers. More features but heavier. |
| **code_text_field** | Stale | Last published ~3 years ago. Avoid. |

**Recommendation:** Use `re_editor` (v0.9.0). At implementation time, verify Flutter SDK compatibility by running `flutter pub add re_editor`. If that fails, fall back to `flutter_code_editor`.

### Language detection

Map file extensions to re_editor language modes:
- `.cpp`, `.h`, `.hpp`, `.c`, `.cc`, `.cxx`, `.ino` → `cpp`
- `.py` → `python`
- `.js` → `javascript`
- `.ts` → `typescript`
- `.dart` → `dart`
- `.html`, `.htm` → `html`
- `.css`, `.scss`, `.sass`, `.less` → `css`
- `.json` → `json`
- `.xml` → `xml`
- `.md` → `markdown`
- `.yaml`, `.yml` → `yaml`
- `.sh`, `.bash`, `.zsh` → `shell`
- `.go` → `go`
- `.rs` → `rust`
- `.java` → `java`
- `.kt` → `kotlin`
- `.swift` → `swift`
- `.rb` → `ruby`
- `.php` → `php`
- `.lua` → `lua`
- `.pl` → `perl`
- `.txt`, `.log`, `.csv`, `.tsv`, `.cfg`, `.conf`, `.ini`, `.env`, `.gitignore` → `text` (no highlighting)

---

## 8. Implementation Order

1. **Protocol constants** (5 min) — Add 4 constants to `protocol.dart`
2. **FsProtocolService builders** (10 min) — Add `buildReplace`, `buildCrc32`, `parseCrc32Data`, `replaceMaxContent`
3. **DeviceFsService methods** (10 min) — Add `replaceFile()` and `getFileCrc32()` thin wrappers
4. **Arduino firmware** (30 min) — Add `handleReplace` + `handleCrc32` handlers and dispatch in `RadioKitFsHandlers.cpp`. Add sub-command constants in `RadioKitFS.h`
5. **Demo FS** (15 min) — Add `replace` and `crc32` to `DemoFsState`. Wire dispatch in `DemoFsTransport`
6. **FileEditorCache** (10 min) — Implement cache class with size limits
7. **FileEditorDialog** (45 min) — Build the near-fullscreen editor overlay with re_editor, top bar, save logic, keyboard shortcuts, confirm-dismiss
8. **FsFileTile edit icon** (15 min) — Add trailing pencil icon for editable file types, hide during multi-select
9. **Explorer screen integration** (30 min) — Wire tile edit tap → cache check → download → editor open → save → list refresh. Evict cache on upload/delete/rename
10. **Device info tab integration** (10 min) — Same wiring for `_FsTabContent` in `models_tab.dart`
11. **Testing** (30 min) — Unit tests for CRC32 parsing, cache logic (match/mismatch/not-found), integration test with demo FS transport
12. **Real device test** (30 min) — Test with BLE and Serial transports, verify save + CRC32 verification

---

## 9. Testing Plan

### Unit tests
- `FsProtocolService.parseCrc32Data` — valid payload, short payload (null), edge values
- `FileEditorCache` — set/get/remove, clear on disconnect, eviction at max entries, eviction at max bytes
- `replaceMaxContent` — correct size calculation for various path lengths
- CRC32 consistency — ensure Dart CRC32 matches Arduino CRC32 for known test vectors

### Integration tests (demo FS)
1. Open editor on a file → verify content displayed
2. Edit content → save → verify file content changed on device
3. Open same file again → verify cache hit (CRC32 match) → instant open
4. Modify file externally (via demo FS write) → open editor → verify cache miss (CRC32 mismatch) → re-download
5. Delete file while editor open → try save → verify error message
6. Open non-editable file (.bin) → verify no edit icon

### Manual device tests
1. Connect to device (BLE) → open file → edit → save → disconnect → reconnect → open same file → verify instant open (cache hit)
2. Connect to device (Serial) → same flow
3. Upload a new version of the file via upload button → open editor → verify cache miss (CRC32 changed)
4. Edit a large file (>16KB) → verify fallback to upload protocol
5. Rapid save taps → verify no double-save
