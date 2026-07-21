## 1. radiokit-firmware/SKILL.md

- [x] 1.1 Update JSON config example from v1 to v2 format with pages array
- [x] 1.2 Fix initRadioKit() pattern: show begin() and transport starts inside initRadioKit(), not in setup()
- [x] 1.3 Fix code sample: config fields set inside initRadioKit(), not in setup() before it
- [x] 1.4 Add startSerial(Serial) to BLE code sample
- [x] 1.5 Fix BasicSwitch label: note it's Serial-primary, not BLE-only
- [x] 1.6 Add missing examples to table: FsCommandTest, SerialSimple, MultiPageController
- [x] 1.7 Document beginFs() as alias for enableFS()
- [x] 1.8 Note that transport config field is vestigial
- [x] 1.9 Add architecture and libversion read-only fields to RK_Config table

## 2. radiokit-filesystem/SKILL.md

- [x] 2.1 Add Replace operation (0x0D) to operations table with CRC32 verification note
- [x] 2.2 Fix troubleshooting: ESP32 auto-formats on begin(), enableFS() won't return false for unformatted flash
- [x] 2.3 Update platform support: note RP2040 has working code path
- [x] 2.4 Add CRC32 sub-command code (0x0E) to operations table

## 3. radiokit-ota/SKILL.md

- [x] 3.1 Fix partition table: app slots 0x1C0000 (1.75MB), spiffs 0x60000 (384KB), add coredump partition
- [x] 3.2 Fix partition description: ~1.75MB per app slot, ~384KB for filesystem
- [x] 3.3 Correct OTA_END: device uses SHA-256 via Update.end(), CRC32 is logged but not compared
- [x] 3.4 Document PROGRESS frame pacing: sent every ~5% or every 50 chunks, not after every chunk
- [x] 3.5 Document RK_OTA_MAX_PAYLOAD = 4096 bytes max chunk size
- [x] 3.6 Note board is ESP32-S3 in partition table example

## 4. radiokit-remote/SKILL.md

- [x] 4.1 Add cloud account management endpoints: GET/POST /api/cloud/accounts, PUT/DELETE /api/cloud/accounts/<id>, GET/POST /api/cloud/account
- [x] 4.2 Add page management endpoints: GET/POST /api/page, GET /api/pages
- [x] 4.3 Add session endpoints: GET /api/session/route, GET /api/session/state, GET /api/session/sheets
- [x] 4.4 Add multi-device FS/OTA endpoints (~20 endpoints under /api/devices/<id>/)
- [x] 4.5 Add device settings endpoints: /api/devices/<id>/settings/nvs/*
- [x] 4.6 Add flasher extended endpoints: disconnect, log, select-firmware, clear-firmware, erase-all
- [x] 4.7 Add device config extended endpoints: GET/PUT /api/settings, raw NVS read/write, cloud-info

## 5. llms.txt

- [x] 5.1 Add cloud account management endpoints
- [x] 5.2 Add page management endpoints
- [x] 5.3 Add session endpoints
- [x] 5.4 Add multi-device endpoints
- [x] 5.5 Add device settings endpoints
- [x] 5.6 Add flasher extended endpoints

## 6. Verify

- [x] 6.1 Review all updated files for consistency
- [x] 6.2 Verify endpoint counts match between radiokit-remote and llms.txt
