## 1. Firmware Implementation (rk-arduino)

- [x] 1.1 Add `RK_FS_URL` and `RK_OTA_URL` default preprocessor macros to `RadioKitConfig.h` and initialize `RK_Config` fields from them
- [x] 1.2 Add `void enableOTA()` and `bool isOtaReady()` to `RadioKitClass.h` and `RadioKit.cpp`
- [x] 1.3 Update `_handleSettingsGetFeatures()` in `RadioKit.cpp` to set `RK_SETTINGS_FEATURE_OTA` dynamically when `isOtaReady()` is true
- [x] 1.4 Update `_handleSettingsGetLinksInfo()` in `RadioKit.cpp` to stream `config.fs_url` and `config.ota_url` directly from memory
- [x] 1.5 Remove `RK_NVS_KEY_FS_URL`, `RK_NVS_KEY_OTA_URL`, and URL-related NVS read/write logic from `RadioKit.cpp` and `RadioKitNVS.h`
- [x] 1.6 Guard OTA command handlers (`_handleOtaBegin`, `_handleOtaChunk`, etc.) with `isOtaReady()` check

## 2. Designer Codegen & App Updates

- [x] 2.1 Update `JsonArduinoGenerator` in Flutter companion app to emit `#define RK_FS_URL "..."` and `#define RK_OTA_URL "..."` when links are present
- [x] 2.2 Update `JsonArduinoGenerator` to emit `RadioKit.enableOTA();` in `initRadioKit()` when OTA is enabled/configured
- [x] 2.3 Update unit tests for `JsonArduinoGenerator` in `radiokit-app/test/json_arduino_generator_test.dart`

## 3. Documentation & Verification

- [x] 3.1 Update `website/src/content/docs/arduino/protocol.mdx` with `RadioKit.enableOTA()` API and direct link info streaming
- [x] 3.2 Update `RC_brain/src/RADIOKIT.h` to call `RadioKit.enableOTA()`
- [x] 3.3 Build & upload `RC_brain` firmware, connect via companion app, and verify the FIRMWARE / OTA tab appears dynamically
