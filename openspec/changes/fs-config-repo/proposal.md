# fs-config-repo Proposal

## Why

The filesystem manager only supports manual local-file uploads, so installing configuration bundles (e.g. sensor calibration JSON, web assets, device data files) onto an ESP32 is tedious and error-prone. Users must hand-craft files and upload them one at a time. By letting firmware declare a config repository URL and subdirectory, the app can list and install ready-made config bundles directly into the device filesystem with one tap.

## What Changes

- Firmware gains two new configurable fields: `config.repo_url` (a normal GitHub URL) and `config.repo_subdir`, persisted to NVS (`rk_repo_url`, `rk_repo_subdir`).
- A new settings protocol command `GET_REPO_INFO` (0x0F) returns `[URL_LEN(1)][URL][SUBDIR_LEN(1)][SUBDIR]`, mirroring the existing cloud-info command.
- The Flutter app fetches repo info on connect and caches it in `DeviceProvider`.
- A new `ConfigRepoService` fetches a manifest file (`radiokit.json`) from the device-declared GitHub repo subdir (GitHub URLs auto-converted to `raw.githubusercontent.com`), plus the config file bytes referenced by the manifest.
- The FS manager gains a full-screen config catalog sheet: cards with name/description/version/file count, a live FS capacity bar, and tap-to-install. Install writes each file to its declared target path (default `/config/<name>`) via the existing CRC32-verified upload protocol.
- When a connected device declares no repo, the FS manager shows a hint.
- Designer JSON schema and codegen emit `config.repo_url` / `config.repo_subdir` so generated `RADIOKIT.h` files can declare a repo.
- Add `package:http` as a direct Flutter dependency (already transitive).
- Documentation updated per the docs-sync rule (protocol, app features, AGENTS.md).

## Capabilities

### New Capabilities

- `fs-config-repo`: App-side FS manager feature — manifest-based config catalog fetched from a device-declared GitHub repo, full-screen catalog sheet, install-to-device flow, and hint when no repo is declared.
- `repo-info-protocol`: Device-declared config repo support across the stack — `RK_Config` fields, NVS persistence, `GET_REPO_INFO` settings command, `DeviceProvider` caching, designer JSON `config.repo`, and codegen emission.

### Modified Capabilities

<!-- No existing spec-level requirements change; all additions are new capabilities. -->

## Impact

- **Firmware** (`rk-arduino/src`): `RadioKitClass.h` (RK_Config struct), `RadioKitConfig.h` (size caps), `RadioKitNVS.h` (keys), `RadioKit.cpp` (first-boot seeding, `_syncNvsToBuffers`, new `_handleSettingsGetRepoInfo`), `RadioKitProtocol.h` (command codes), `RadioKitSettings.h` (command constants).
- **Protocol** (`radiokit-app/lib/models/protocol.dart`, `settings_protocol_service.dart`): new `kSettingsCmdGetRepoInfo = 0x0F`, `kSettingsRespRepoInfoData = 0x8F`, builder + parser.
- **Flutter app** (`radiokit-app/lib`): new `ConfigRepoService`, manifest models, `DeviceProvider` repo fields, new `ConfigCatalogSheet`, FS tab trigger + hint, `pubspec.yaml` (http dependency).
- **Designer / codegen**: `flutter-widgets/lib/src/models/designer_state.dart` (`config.repo` load/toJson), `json_arduino_generator.dart` (emit `config.repo_url` / `config.repo_subdir`).
- **Docs**: `website/src/content/docs/arduino/protocol.mdx`, app features docs, `AGENTS.md` (schema section for `config.repo`).
- **Dependencies**: add `http` to `radiokit-app/pubspec.yaml` (already present in the transitive dependency graph).