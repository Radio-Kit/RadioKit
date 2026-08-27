# fs-config-repo Design

## Context

The FS manager (`FsTabContent` in `device_config/filesystem_tab.dart`) currently supports manual local-file uploads, downloads, editing, rename, delete, and format. Firmware declares runtime-relevant configuration via `RK_Config` (name, cloud URL/account, WiFi creds), persisted to ESP32 NVS and exposed over the 0xDD settings protocol.

This change introduces multi-link configuration in the visual Designer and firmware (`config.links.fs` and `config.links.ota`), persists them to NVS, exposes them over the settings protocol, and provides an interactive remote repo/folder browser modal directly within the Filesystem tab file browser so users can selectively upload files and folders to the device LittleFS.

## Goals / Non-Goals

**Goals:**
- Configure remote links in the Designer UI (`LINKS` section) with code-generation and NVS persistence:
  - **Filesystem Link (`fs_url`)**: GitHub repo or subfolder URL.
  - **OTA Link (`ota_url`)**: URL placeholder for future OTA firmware updates.
- Provide a remote browser modal launched from the Filesystem tab file browser (via a toolbar/FAB icon and empty-folder menu).
- Allow users to browse remote files and folders, select specific items, and upload them sequentially to the board LittleFS with live progress and CRC32 verification.
- Device is the single source of truth for the links, seeded on first boot or configured via the Designer.
- Support direct URL editing in the modal if the user wants to test or load an alternate repository.

**Non-Goals:**
- Full OTA firmware update execution (the `ota_url` is added as a schema/firmware placeholder now).
- Local zip archive extraction (deferred to keep the scope focused on remote Git repository/subfolder links).
- App-side persistent multi-repo bookmarks database.

## Decisions

### D1: `config.links` in Designer JSON & Codegen

The designer JSON schema introduces `config.links`:

```json
"config": {
  "name": "My Device",
  "transports": { ... },
  "links": {
    "fs": "https://github.com/owner/repo/tree/main/configs",
    "ota": ""
  }
}
```

- **Designer Inspector**: `designer_inspector.dart` adds a `LINKS` section with text inputs:
  - **Filesystem Link**: URL input with hint `https://github.com/owner/repo/tree/main/configs`.
  - **OTA Link**: URL input with helper text indicating OTA support is coming soon.
- **Codegen**: `JsonArduinoGenerator` emits in `initRadioKit()`:
  ```cpp
  RadioKit.config.fs_url  = "https://github.com/owner/repo/tree/main/configs";
  RadioKit.config.ota_url = "";
  ```
  Omitted when empty.

### D2: Firmware & NVS Persistence

- `RK_Config` struct in `RadioKitClass.h` exposes:
  - `const char* fs_url;`
  - `const char* ota_url;`
- Sized by `RADIOKIT_MAX_FS_URL (128)` and `RADIOKIT_MAX_OTA_URL (128)` in `RadioKitConfig.h`.
- Persisted in NVS under keys `rk_fs_url` and `rk_ota_url`.
- Seeded on first boot from `RK_Config` and loaded into RAM buffers (`_nvsFsUrl`, `_nvsOtaUrl`) during `RadioKit.begin()`.

### D3: `GET_LINKS_INFO` Settings Command (0x0F)

The 0xDD settings protocol adds a command pair:

```
GET_LINKS_INFO    (0x0F, App → MCU)   — no payload
LINKS_INFO_DATA   (0x8F, MCU → App)   — [FS_URL_LEN(1)][FS_URL…][OTA_URL_LEN(1)][OTA_URL…]
```

- Wire shape mirrors `CLOUD_INFO_DATA`.
- Handled on MCU by `_handleSettingsGetLinksInfo()`.
- Parsed on the app by `SettingsProtocolService.parseLinksInfoData()` and cached in `DeviceProvider`.

### D4: GitHub URL & Subfolder Parsing

`RepoTreeService.parseGithubUrl(String url)` parses URLs such as:
- `https://github.com/owner/repo`
- `https://github.com/owner/repo/tree/branch/subfolder/path`

Extracts: `owner`, `repo`, `ref` (defaults to `HEAD`), and `subfolder`.

Raw file downloads resolve to:
`https://raw.githubusercontent.com/{owner}/{repo}/{ref}/{subfolder}/{relativeFilePath}`

### D5: Remote Repo Browser Modal in Filesystem Tab

- **Trigger**:
  - A third button in the Filesystem Tab floating action bar (e.g. `Icons.cloud_download_outlined`, tooltip `"Import from Repo"`).
  - An entry in `_showUploadMenu()` ("Download from Repo").
- **Modal View (`RepoBrowserModal`)**:
  - Displays the current repo/subfolder URL with an option to edit.
  - Lists the files and directories fetched from GitHub in an expandable tree.
  - Granular selection via checkboxes: selecting a folder checks all files inside it.
  - Displays the destination path (defaults to current directory in FS browser) and device available storage vs. selected file bytes.
  - Tapping "Upload to Board" iterates through selected files sequentially:
    1. Downloads file bytes over HTTP.
    2. Writes to the board using `DeviceFsService.writeFileUpload` (CRC32-verified).
    3. Displays live progress bar and status.
  - On completion, the modal closes and the Filesystem Tab file list automatically refreshes.

### D6: `package:http` Direct Dependency

Adding `http: ^1.2.0` (or compatible) directly to `radiokit-app/pubspec.yaml` enables cross-platform network fetches across Android, iOS, Linux, macOS, Windows, and Web.

## Risks / Trade-offs

- **GitHub API Rate Limits for Tree Listing**:
  - GitHub unauthenticated API allows 60 requests/hour. A single `git/trees` call fetches the entire repository tree hierarchy.
  - Raw file downloads from `raw.githubusercontent.com` are unthrottled and not subject to API rate limits.
- **Network Errors during Batch Upload**:
  - If a file download or upload fails halfway through a batch, already transferred files remain intact on the board LittleFS. The modal reports the error and allows retrying remaining files.
- **Stale NVS URLs after Flash**:
  - Per the flash erase policy, flashing with erase ensures updated sketch links override previous NVS keys.

## Migration Plan

1. Firmware: add `fs_url` / `ota_url` to `RK_Config`, NVS keys, and `GET_LINKS_INFO` handler.
2. Protocol service + `DeviceProvider` caching of links on connect.
3. Designer state & Inspector: `LINKS` section with FS and OTA inputs.
4. Codegen: emit `RadioKit.config.fs_url` and `RadioKit.config.ota_url`.
5. RepoTreeService & RepoBrowserModal in Flutter app.
6. Filesystem tab trigger integration.
7. Docs sync (protocol.mdx, app features, AGENTS.md).