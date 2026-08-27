# fs-config-repo Design

## Context

The FS manager (`FsTabContent` in `device_config/filesystem_tab.dart`) currently supports manual local-file uploads, downloads, editing, rename, delete, and format. Firmware declares runtime-relevant configuration via `RK_Config` (name, cloud URL/account, WiFi creds), persisted to ESP32 NVS and exposed over the 0xDD settings protocol. The app has no HTTP client dependency today (`http` is only transitive), and the FS tab is gated on the device reporting the filesystem feature bit (`hasFs`).

This change lets firmware declare a config repository (a GitHub repo + subdir). The app reads that declaration over the settings protocol, fetches a manifest of config bundles from the repo, and installs selected bundles onto the device filesystem.

## Goals / Non-Goals

**Goals:**
- One-tap install of config bundles (multiple files, each at a declared target path) from a device-declared GitHub repo into the device LittleFS.
- Device is the single source of truth for the repo (no app-side repo management).
- Reuse existing infrastructure wherever possible: settings protocol framing, `DeviceFsService.writeFileUpload` (CRC32-verified), FS busy locking, themed bottom-sheet/card conventions.
- Design `ConfigRepoService` so the same fetch/parse logic can later back a firmware marketplace (flasher), without committing to that surface now.

**Non-Goals:**
- Flasher firmware marketplace (deferred by the user).
- Installing RadioKit designer UI layouts / reflashing firmware.
- App-side repo editing or multiple saved repos.
- sha256 or signature verification of downloaded content.
- New Remote Access HTTP API endpoints for repo operations.

## Decisions

### D1: Manifest file catalog, not GitHub API listing

A `radiokit.json` manifest lives at the repo subdir root. The app fetches it (plus referenced files) from `raw.githubusercontent.com`.

- Why manifest over the GitHub Contents API (`/repos/{o}/{r}/contents/{path}`): the API returns only name/size (no description, version, icon, or per-file target paths); is GitHub-only; and is rate-limited to 60 req/hr unauthenticated. A manifest is host-agnostic, metadata-rich, and unthrottled.
- Alternative considered: GitHub API listing with file-name conventions (e.g. `{id}.json` + `{id}.meta.json`). Rejected — no metadata without an extra file per item, still GitHub-only.
- Manifest is optional in the sense that the browse flow fails gracefully (error state) if absent; no fallback to API listing is implemented in this change.

**Manifest schema** (fetched from `{subdir}/radiokit.json`):

```json
{
  "version": 1,
  "configs": [
    {
      "id": "sensor-dashboard",
      "name": "Sensor Dashboard",
      "description": "Live sensor readings dashboard",
      "version": "1.2.0",
      "icon": "gauge",
      "files": [
        { "name": "sensors.json",  "path": "/config/sensors.json" },
        { "name": "dashboard.html", "path": "/web/index.html" }
      ]
    }
  ]
}
```

- `files[].name` is relative to the subdir; `files[].path` is the absolute destination on the device. When `path` is omitted, the file lands at `/config/<name>`.
- `icon` maps to the existing `kDesignerIcons` registry when present; otherwise a generic icon is used.

### D2: GitHub URL auto-conversion with HEAD ref

`config.repo_url` holds a normal GitHub URL (e.g. `https://github.com/rambros3d/RadioKit`). `ConfigRepoService.parseGithubUrl()` extracts `owner`, `repo`, and an optional ref from a `/tree/{ref}/` or `/blob/{ref}/` path segment. When no ref is present, `HEAD` is used:

```
manifest: https://raw.githubusercontent.com/{owner}/{repo}/{ref}/{subdir}/radiokit.json
file:     https://raw.githubusercontent.com/{owner}/{repo}/{ref}/{subdir}/{name}
```

- Why `HEAD`: it resolves on `raw.githubusercontent.com` regardless of whether the default branch is `main` or `master`, avoiding a branch-detection API call.
- Why not require a raw URL in firmware: normal GitHub URLs are what firmware authors already know; the app converts.
- Non-GitHub URLs are treated as an invalid repo (error state in the catalog sheet) — out of scope to support arbitrary raw hosts.

### D3: New `GET_REPO_INFO` settings command (0x0F), mirroring cloud-info

Rather than extending `GET_DEVICE_INFO` (which would break payload layout for existing clients), a new request/response pair is added:

```
GET_REPO_INFO    (0x0F, App → MCU)   — no payload
REPO_INFO_DATA   (0x8F, MCU → App)   — [URL_LEN(1)][URL…][SUBDIR_LEN(1)][SUBDIR…]
```

- Identical wire shape to `CLOUD_INFO_DATA`, reusing the same parsing approach in `SettingsProtocolService`.
- Firmware adds `RK_Config.repo_url` / `repo_subdir`, NVS keys `rk_repo_url` / `rk_repo_subdir` (seeded on first boot from config, loaded by `_syncNvsToBuffers()`), and a handler mirroring `_handleSettingsGetCloudInfo`.
- No new features bitmask flag: an unset repo simply returns empty strings.

### D4: `config.repo` in designer JSON + codegen emission

- `DesignerState` gains a `config.repo` object `{ "url": "", "subdir": "" }`, serialized in `toJson()` and parsed in `loadFromJson()` beside `transports`.
- `JsonArduinoGenerator` emits `config.repo_url = "…";` and `config.repo_subdir = "…";` in the generated `RADIOKIT.h` only when non-empty (same pattern as cloud fields).

### D5: Default install path `/config/<name>`

Manifest entries without an explicit `path` land at `/config/<name>`. Predictable, avoids root clutter and cross-bundle collisions. Explicit paths are authoritative and may point anywhere (e.g. `/web/index.html`).

### D6: No sha256 verification

Downloaded bytes are written via `DeviceFsService.writeFileUpload`, which already verifies integrity end-to-end (CRC32 over the full file, computed on device and checked against the app's reference). The manifest does not carry hashes, keeping catalog publishing trivial.

### D7: Sequential install, no rollback

Install iterates a config's files in order: HTTP fetch → `writeFileUpload` → next. If a file fails, already-written files remain on the device; the sheet reports per-file success/failure and offers retry. No rollback/delete-on-failure.

### D8: Full-screen catalog sheet with capacity bar

`ConfigCatalogSheet` is a full-screen route pushed from the FS tab. It shows:
- Header: repo identity (owner/repo + subdir) and close.
- Capacity bar from `DeviceFsService.getInfo()` (total vs used) so users can judge space before installing.
- Cards per manifest item (name, description, version, file count), tap to install.
- Install progress per file and aggregated; error and empty states with retry.
- After successful install, the FS tab refreshes its listing.

Trigger: a "CONFIGS" action in the FS tab (info strip row). When the device declares no repo, the FS tab shows a compact hint instead.

### D9: `package:http` becomes a direct dependency

`http` is already in the transitive graph (via `shelf`). Adding it directly lets `ConfigRepoService` fetch over HTTP on all platforms (desktop, Android, iOS, web) — `dart:io HttpClient` is not web-compatible.

## Risks / Trade-offs

- **`raw.githubusercontent.com` availability / CORS**: the fetch may fail on restricted networks or from web without CORS headers. `raw.githubusercontent.com` and `api.github.com` send permissive CORS headers, so web is fine. → Catalog sheet surfaces a clean error state with retry; no cached catalog in this change.
- **Rate / size limits**: GitHub hard-caps raw files at ~25 MB. Config bundles are expected to be small (KB–low MB). → The install flow reports size up front from `getInfo()` capacity; oversized files surface as an HTTP error.
- **Stale NVS repo declaration after flash**: NVS persists `rk_repo_url` across reflashes unless erased (see flash-erase-policy). A device may advertise an old repo. → Acceptable; the firmware author's declared value is the source of truth and the sheet displays it so users see what they're browsing.
- **Partial install state on device**: a mid-bundle failure leaves some files installed. → Deliberate (no rollback); the sheet reports exactly which files succeeded/failed.
- **Protocol version skew**: older firmware won't answer `GET_REPO_INFO` (unknown sub-command → no response). → The app treats a timeout/absent response as "no repo declared", which is safe (hint shown).
- **`config.repo` not authored in designer**: firmware authors who write `RADIOKIT.h` by hand can set `config.repo_url` directly; designer authors get the field in the config panel. Low risk.

## Migration Plan

1. Firmware: add fields/NVS/protocol; update `RadioKitConfig.h` size caps; add `GET_REPO_INFO` handler.
2. Protocol service + `DeviceProvider` caching on the app.
3. `ConfigRepoService` + manifest models + `http` dependency.
4. `ConfigCatalogSheet` + FS tab trigger/hint.
5. Designer JSON + codegen emission.
6. Docs sync (protocol.mdx, app features, AGENTS.md schema section).
7. Optional example: point one existing FS example's `RADIOKIT.h` at a public configs repo for end-to-end validation.

Rollback: feature is additive; removing the FS tab trigger and skipping the `GET_REPO_INFO` fetch restores prior behavior without firmware changes.

## Open Questions

- None blocking. Minor: exact placement of the "CONFIGS" trigger in the FS info strip and hint copy will be settled during implementation against the real layout.