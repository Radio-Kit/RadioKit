## Context

ESP32 microcontrollers use a dedicated Non-Volatile Storage (NVS) flash partition to store runtime configuration (BLE device name, WiFi SSID/passwords, custom key/value parameters). Standard firmware uploads only overwrite the application binary partition and leave NVS untouched. When new firmware is uploaded with different runtime defaults (such as a updated BLE device name in `RadioKit.config.name`), `RadioKit.begin()` reads existing NVS parameters first, overriding the code defaults. This results in the device continuing to advertise under its old BLE name or using legacy credentials, confusing users and AI agents.

## Goals / Non-Goals

**Goals:**
- Update all firmware flashing and upload guidance across `SKILLS/`, `radiokit-app/assets/skills/`, `.agents/skills/radiokit-example/`, and `AGENTS.md` to mandate flash erase (`-erase`, `--erase-flash`, `eraseAll: true`) on uploads.
- Explicitly document the NVS flash persistence behavior and rationale so human developers and AI agents understand why flash erase is required by default.
- Provide clear exception rules for when previous settings intentionally need to be preserved (e.g. testing NVS persistence or OTA updates).

**Non-Goals:**
- Changing the underlying Rust relay server or Flutter app flasher binary protocols.
- Modifying C++ library initialization logic in `rk-arduino`.

## Decisions

### Decision 1: Direct Skill & Guidelines Update
Add a standardized **Flash Erase Policy on Firmware Upload** alert and rule section across:
1. `SKILLS/radiokit-firmware/SKILL.md` & `radiokit-app/assets/skills/radiokit-firmware.md`
2. `SKILLS/radiokit-ota/SKILL.md` & `radiokit-app/assets/skills/radiokit-ota.md`
3. `SKILLS/radiokit-remote/SKILL.md` & `radiokit-app/assets/skills/radiokit-remote.md`
4. `.agents/skills/radiokit-example/SKILL.md`
5. `AGENTS.md` (Codebase standards for AI Coding Agents)

*Rationale*: Syncing all active skill locations ensures both local developer agents, remote API consumers, and Flutter asset skills carry identical guidance.

## Risks / Trade-offs

- **Risk**: Flash erase resets stored WiFi credentials or NVS keys on the device.
- **Mitigation**: Document the exception rule clearly: if a user or test explicitly requires preserving NVS settings across a flash, the erase flag is omitted.
