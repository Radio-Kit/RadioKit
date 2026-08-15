# fs-config-repo Tasks

## 1. Firmware: Config Fields and NVS

- [ ] 1.1 Add `RADIOKIT_MAX_REPO_URL` (128) and `RADIOKIT_MAX_REPO_SUBDIR` (64) caps to `rk-arduino/src/RadioKitConfig.h`
- [ ] 1.2 Add `const char* repo_url` and `const char* repo_subdir` to `RK_Config` in `rk-arduino/src/RadioKitClass.h`
- [ ] 1.3 Add `RK_NVS_KEY_REPO_URL` ("rk_repo_url") and `RK_NVS_KEY_REPO_SUBDIR` ("rk_repo_subdir") to `rk-arduino/src/connection/RadioKitNVS.h`
- [ ] 1.4 Add `_nvsRepoUrl` / `_nvsRepoSubdir` buffers to `RadioKitClass` (RadioKitClass.h) and memset them in the constructor (RadioKit.cpp)
- [ ] 1.5 Seed NVS from config on first boot and add `RKNvs::readString` loads to `_syncNvsToBuffers()` (RadioKit.cpp begin())

## 2. Firmware: GET_REPO_INFO Settings Command

- [ ] 2.1 Add `RK_SETTINGS_CMD_GET_REPO_INFO 0x0F` and `RK_SETTINGS_RESP_REPO_INFO_DATA 0x8F` to `rk-arduino/src/connection/RadioKitSettings.h` and `RadioKitProtocol.h`
- [ ] 2.2 Add `_handleSettingsGetRepoInfo()` to RadioKitClass and wire it in the settings dispatcher (RadioKit.cpp), mirroring `_handleSettingsGetCloudInfo` with `[URL_LEN(1)][URL][SUBDIR_LEN(1)][SUBDIR]` payload

## 3. App: Protocol and DeviceProvider Caching

- [ ] 3.1 Add `kSettingsCmdGetRepoInfo = 0x0F` and `kSettingsRespRepoInfoData = 0x8F` to `radiokit-app/lib/models/protocol.dart`
- [ ] 3.2 Add `buildGetRepoInfo()` and `parseRepoInfoData()` to `radiokit-app/lib/services/settings_protocol_service.dart`
- [ ] 3.3 Add `_repoUrl` / `_repoSubdir` fields, getters, fetch-on-connect (fire-and-forget after features), and `_handleSettingsRepoInfoData` dispatch in `radiokit-app/lib/providers/device_provider.dart`

## 4. App: ConfigRepoService and Manifest Models

- [ ] 4.1 Add `http` as a direct dependency in `radiokit-app/pubspec.yaml`
- [ ] 4.2 Create manifest models (`ConfigManifest`, `ConfigItem`, `ConfigFile`) in `radiokit-app/lib/models/`
- [ ] 4.3 Create `ConfigRepoService` in `radiokit-app/lib/services/` with `parseGithubUrl()` (owner/repo/ref, HEAD default), `fetchManifest()`, and `fetchFile()` via raw.githubusercontent.com
- [ ] 4.4 Add unit tests for URL parsing (plain, branch-qualified, non-GitHub) and manifest parsing (valid, missing, malformed)

## 5. App: Catalog Sheet and FS Tab Integration

- [ ] 5.1 Create `ConfigCatalogSheet` full-screen route in `radiokit-app/lib/screens/filesystem/` with repo header, capacity bar (`DeviceFsService.getInfo()`), config cards, install progress, and error/empty states with retry
- [ ] 5.2 Implement install flow: per-file HTTP fetch -> `writeFileUpload` to `path ?? '/config/<name>'`, reporting per-file success/failure and a final summary with retry
- [ ] 5.3 Add the CONFIGS trigger (info strip row) and the no-repo hint to `radiokit-app/lib/screens/device_config/filesystem_tab.dart`
- [ ] 5.4 Refresh the FS listing after a successful install

## 6. Designer JSON Schema and Codegen

- [ ] 6.1 Add `config.repo` (`{ url, subdir }`) load/save to `flutter-widgets/lib/src/models/designer_state.dart` beside `transports`
- [ ] 6.2 Emit `config.repo_url = "...";` / `config.repo_subdir = "...";` only when non-empty in `radiokit-app/lib/screens/designer/codegen/json_arduino_generator.dart`
- [ ] 6.3 Add the repo field editor to the designer config panel (inspector) with `buildTextField` builders

## 7. Example and End-to-End Validation

- [ ] 7.1 Update one existing FS example (`Filesystem_LED` or a demo) to declare `config.repo_url` / `config.repo_subdir` pointing at a public configs repo
- [ ] 7.2 Add a manifest (`radiokit.json`) to the referenced repo subdir with at least one multi-file config
- [ ] 7.3 Verify end-to-end: connect -> GET_REPO_INFO -> catalog sheet -> install -> files land on device FS (with flash erase per firmware flash policy)

## 8. Documentation Sync

- [ ] 8.1 Update `website/src/content/docs/arduino/protocol.mdx` with the GET_REPO_INFO command table entries
- [ ] 8.2 Update the app filesystem/features docs with the config-repo browse flow and manifest format
- [ ] 8.3 Update `AGENTS.md` JSON config conventions (section 3) with the `config.repo` schema
- [ ] 8.4 Update relevant skill file (`radiokit-filesystem` or a new section) describing the feature