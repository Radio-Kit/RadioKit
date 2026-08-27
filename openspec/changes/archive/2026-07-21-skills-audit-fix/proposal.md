## Why

The SKILLS documentation files are out of date with the current codebase. An audit found 20+ discrepancies across firmware, filesystem, OTA, and remote access skills — including wrong JSON config format, incorrect partition tables, missing endpoints, and misleading code samples. Agents relying on these skills will produce incorrect code.

## What Changes

- **radiokit-firmware/SKILL.md**: Update JSON config to v2 format with pages, fix `initRadioKit()` pattern (begin() inside, not outside), add missing examples to table, document `beginFs()` alias, add `startSerial()` to code samples, note vestigial `transport` field
- **radiokit-filesystem/SKILL.md**: Add Replace operation (0x0D) to operations table, fix troubleshooting for ESP32 auto-format behavior, note RP2040 support
- **radiokit-ota/SKILL.md**: Fix partition table values (1.75MB app slots, 384KB FS, add coredump), correct OTA_END verification description (SHA-256, not CRC32), document PROGRESS pacing and 4KB max chunk size
- **radiokit-remote/SKILL.md**: Add ~30 missing endpoints (cloud account management, page management, session, multi-device FS/OTA, device settings, flasher extended, device config extended)
- **llms.txt**: Add missing endpoint groups to match updated radiokit-remote skill

## Capabilities

### New Capabilities

(No new capabilities — these are documentation updates to existing skills)

### Modified Capabilities

(No spec-level requirement changes — these correct documentation to match existing code behavior)

## Impact

- `SKILLS/radiokit-firmware/SKILL.md` — 9 corrections
- `SKILLS/radiokit-filesystem/SKILL.md` — 5 corrections
- `SKILLS/radiokit-ota/SKILL.md` — 6 corrections
- `SKILLS/radiokit-remote/SKILL.md` — ~30 missing endpoints added
- `SKILLS/llms.txt` — matching endpoint updates
