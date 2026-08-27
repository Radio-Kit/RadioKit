# fs-config-repo Tasks

## 1. Firmware: Config Fields and NVS

- [x] 1.1 Add `RADIOKIT_MAX_FS_URL` (128) and `RADIOKIT_MAX_OTA_URL` (128) caps to `rk-arduino/src/RadioKitConfig.h`
- [x] 1.2 Add `const char* fs_url` and `const char* ota_url` to `RK_Config` in `rk-arduino/src/RadioKitClass.h`
- [x] 1.3 Add `RK_NVS_KEY_FS_URL` ("rk_fs_url") and `RK_NVS_KEY_OTA_URL` ("rk_ota_url") to `rk-arduino/src/connection/RadioKitNVS.h`
- [x] 1.4 Add `_nvsFsUrl` / `_nvsOtaUrl` buffers to `RadioKitClass` (RadioKitClass.h) and initialize them in constructor
- [x] 1.5 Seed NVS from config on first boot and load string values into buffers in `_syncNvsToBuffers()` (RadioKit.cpp begin())

## 2. Firmware: GET_LINKS_INFO Settings Command

- [x] 2.1 Add `RK_SETTINGS_CMD_GET_LINKS_INFO 0x0F` and `RK_SETTINGS_RESP_LINKS_INFO_DATA 0x8F` to `rk-arduino/src/connection/RadioKitSettings.h` and `RadioKitProtocol.h`
- [x] 2.2 Implement `_handleSettingsGetLinksInfo()` in RadioKitClass and dispatch in `RadioKit.cpp` settings handler (`[FS_LEN(1)][FS_URL][OTA_LEN(1)][OTA_URL]`)

## 3. App: Protocol and DeviceProvider Caching

- [x] 3.1 Add `kSettingsCmdGetLinksInfo = 0x0F` and `kSettingsRespLinksInfoData = 0x8F` to `radiokit-app/lib/models/protocol.dart`
- [x] 3.2 Add `buildGetLinksInfo()` and `parseLinksInfoData()` to `radiokit-app/lib/services/settings_protocol_service.dart`
- [x] 3.3 Add `_fsUrl` and `_otaUrl` fields, getters, fetch-on-connect, and `_handleSettingsLinksInfoData` in `radiokit-app/lib/providers/device_provider.dart`

## 4. App: RepoTreeService and URL Parsing

- [x] 4.1 Ensure `http` dependency in `radiokit-app/pubspec.yaml`
- [x] 4.2 Create `RepoTreeService` in `radiokit-app/lib/services/` with GitHub URL/subfolder parsing, tree fetching via GitHub Trees API, and raw file downloading
- [x] 4.3 Add unit tests for URL parsing (repo, tree branch, subfolder) and tree responses

## 5. App: Filesystem Tab Repo Browser Modal

- [x] 5.1 Create `RepoBrowserModal` bottom sheet / dialog with editable URL header, folder tree view, cascading file/directory selection checkboxes, and storage capacity bar
- [x] 5.2 Implement batch upload flow using `DeviceFsService.writeFileUpload` with per-file progress reporting and error retry handling
- [x] 5.3 Add the "Import from Repo" action icon to the Filesystem tab floating action bar and `_showUploadMenu`
- [x] 5.4 Automatically refresh the file list in `filesystem_tab.dart` after upload completion

## 6. Designer UI and Codegen

- [x] 6.1 Add `config.links` (`{ fs, ota }`) getters, setters, and `toJson()` / `loadFromJson()` to `flutter-widgets/lib/src/models/designer_state.dart`
- [x] 6.2 Add the `LINKS` section to `radiokit-app/lib/screens/designer/widgets/designer_inspector.dart` with text inputs for Filesystem Link and OTA Link
- [x] 6.3 Emit `RadioKit.config.fs_url = "...";` and `RadioKit.config.ota_url = "...";` in `radiokit-app/lib/screens/designer/codegen/json_arduino_generator.dart`

## 7. Example and End-to-End Validation

- [x] 7.1 Update an FS example sketch to configure `RadioKit.config.fs_url` pointing to a sample repository subfolder
- [x] 7.2 Verify end-to-end: connect -> receive links info -> open repo modal in FS tab -> select files/folders -> batch upload to LittleFS -> verify on device (with flash erase per policy)

## 8. Documentation Sync

- [x] 8.1 Update `website/src/content/docs/arduino/protocol.mdx` with `GET_LINKS_INFO` (0x0F / 0x8F)
- [x] 8.2 Update app filesystem documentation with the repo browser modal flow
- [x] 8.3 Update `AGENTS.md` JSON config conventions (section 3) with `config.links`