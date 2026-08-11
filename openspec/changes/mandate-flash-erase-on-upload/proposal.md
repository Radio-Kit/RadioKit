## Why

When uploading new Arduino firmware to ESP32 microcontrollers, persistent settings (such as advertised BLE device name, WiFi credentials, and passwords) stored in Non-Volatile Storage (NVS) flash persist across standard flashes if the flash sector is not erased. This causes the device to boot up using stale NVS settings from previous firmware—advertising under an outdated name or attempting old connections—which confuses developers and users. Updating skill documentation, project guidelines, and code examples to mandate the flash erase option (`-erase` / `--erase` / `eraseAll: true`) on uploads ensures devices always boot cleanly with current configuration settings.

## What Changes

- Update skill documentation across `SKILLS/` and `radiokit-app/assets/skills/` (`radiokit-firmware`, `radiokit-ota`, `radiokit-remote`) to mandate flash erase during code upload unless previous settings must be explicitly preserved.
- Update agent guidelines in `AGENTS.md` and `.agents/skills/radiokit-example/SKILL.md` to establish the flash erase rule for all AI coding agents and human developers building firmware.
- Clarify the rationale: ESP32 NVS persistence overrides runtime sketch defaults at boot, causing outdated BLE names or stale transport parameters to persist unless erased.

## Capabilities

### New Capabilities
- `flash-erase-policy`: Mandates flash erase (`-erase`, `--erase-flash`, `eraseAll: true`) on all firmware upload commands and documentation unless settings preservation is explicitly requested.

### Modified Capabilities

## Impact

- **Documentation & Agent Skills**: `SKILLS/radiokit-firmware/SKILL.md`, `SKILLS/radiokit-ota/SKILL.md`, `SKILLS/radiokit-remote/SKILL.md`, `radiokit-app/assets/skills/*`, `.agents/skills/radiokit-example/SKILL.md`, `AGENTS.md`.
- **Workflow & Testing**: All future code uploads, PlatformIO upload commands, OTA updates, and flasher API calls will include flash erase by default during development.
