# fs-config-repo Proposal

## Why

The filesystem manager only supports manual local-file uploads, making the installation of configuration bundles, web assets, or device assets onto an ESP32 LittleFS tedious and error-prone. Users must hand-craft files and upload them one at a time. By enabling firmware and the visual Designer to configure remote links (Filesystem Link and an OTA Link placeholder), users can easily browse remote repository/subfolder contents directly from the Filesystem tab and select specific files or folders to upload to the board in one go.

## What Changes

- **Designer UI Configuration**:
  - The Designer Inspector gains a `LINKS` section to configure **Filesystem Link** (URL to a GitHub repo or subfolder) and an **OTA Link** (placeholder for future OTA updates).
  - Serialized in Designer JSON schema under `config.links` (`{ "fs": "...", "ota": "..." }`).
  - `JsonArduinoGenerator` emits `RadioKit.config.fs_url` and `RadioKit.config.ota_url` in the generated `RADIOKIT.h`.
- **Firmware & NVS Persistence**:
  - `RK_Config` struct exposes `fs_url` and `ota_url`, persisted to NVS under keys `rk_fs_url` and `rk_ota_url`.
  - Settings protocol command `GET_LINKS_INFO` (0x0F / 0x8F) returns the configured link URLs to the app upon connection.
- **Filesystem Tab File Browser Integration**:
  - Adds a remote repo browse action icon (e.g. `Icons.cloud_download_outlined`) to the Filesystem tab toolbar/FAB and empty-folder menu.
  - Tapping opens a modal window displaying the contents (files and directories) of the configured repo/subfolder URL.
  - Supports selecting individual files or entire folders with cascading checkboxes.
  - Displays device free storage capacity vs. selected file sizes.
  - Tapping "Upload to Board" downloads the selected files via HTTP and uploads them sequentially to the device filesystem using the CRC32-verified upload protocol (`DeviceFsService.writeFileUpload`).
- **Dependencies & Docs**:
  - Adds direct `package:http` dependency (already transitive via `shelf`).
  - Documentation and schema guides updated per the docs-sync rule.

## Capabilities

### New Capabilities

- `fs-config-repo`: Filesystem tab remote repository browser modal — browse remote folders/files, granular selection, capacity check, and sequential batch upload to board LittleFS.
- `repo-info-protocol`: Multi-link configuration across Designer UI, codegen, firmware `RK_Config` (`fs_url`, `ota_url`), NVS persistence, and the 0xDD settings protocol exchange.

### Modified Capabilities

<!-- No existing spec-level requirements break; all additions are backward-compatible. -->

## Impact

- **Designer & Codegen** (`flutter-widgets`, `radiokit-app`):
  - `designer_state.dart`: `config.links` (`fs`, `ota`) getters, setters, serialization (`toJson` / `loadFromJson`).
  - `designer_inspector.dart`: New `LINKS` section with text inputs for Filesystem Link and OTA Link.
  - `json_arduino_generator.dart`: Emission of `RadioKit.config.fs_url` and `RadioKit.config.ota_url`.
- **Firmware** (`rk-arduino/src`):
  - `RadioKitClass.h`: `RK_Config` fields (`fs_url`, `ota_url`), internal buffers (`_nvsFsUrl`, `_nvsOtaUrl`).
  - `RadioKitConfig.h`: Buffer caps (`RADIOKIT_MAX_FS_URL 128`, `RADIOKIT_MAX_OTA_URL 128`).
  - `RadioKitNVS.h`: NVS keys `rk_fs_url`, `rk_ota_url`.
  - `RadioKit.cpp`: First-boot seeding, `_syncNvsToBuffers()`, `_handleSettingsGetLinksInfo()`.
  - `RadioKitProtocol.h` / `RadioKitSettings.h`: Command codes `0x0F` / `0x8F`.
- **Protocol & State** (`radiokit-app/lib`):
  - `protocol.dart` & `settings_protocol_service.dart`: `kSettingsCmdGetLinksInfo = 0x0F`, parser & builder.
  - `device_provider.dart`: Caching of `fsUrl` and `otaUrl` on connect.
- **Filesystem UI & Services** (`radiokit-app/lib`):
  - `RepoTreeService`: GitHub URL parsing and tree fetcher.
  - `RepoBrowserModal`: Interactive folder/file tree browser, selection state, and batch upload flow.
  - `filesystem_tab.dart`: Remote browse trigger in toolbar/FAB and upload menu.