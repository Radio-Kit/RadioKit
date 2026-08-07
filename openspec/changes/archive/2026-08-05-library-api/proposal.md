## Why

AI agents and new users need the `rk-arduino` library to compile RadioKit projects, but currently must manually clone it from GitHub. The Flutter app already runs an HTTP server (80+ endpoints) — it should serve the library directly so agents can download and update it programmatically via the remote access API.

## What Changes

- Bundle `rk-arduino/` as a ZIP asset inside the Flutter app
- Add a build script that creates `assets/rk-arduino.zip` from the sibling `rk-arduino/` directory
- Add `LibraryService` to extract and index the library at runtime
- Add two HTTP API endpoints:
  - `GET /api/library/version` — returns the library version (read from bundled `library.json`)
  - `GET /api/library/download` — serves the ZIP archive for download
- Agent workflow: query version → compare with local → download if stale → ready to compile

## Capabilities

### New Capabilities
- `library-api`: HTTP API for serving the Arduino library ZIP and version metadata to agents and users

### Modified Capabilities

## Impact

- **Files added**: `radiokit-app/assets/rk-arduino.zip`, `radiokit-app/lib/services/library_service.dart`
- **Files modified**: `radiokit-app/lib/services/remote_access_service.dart` (2 new routes)
- **Build process**: New pre-build step to zip `rk-arduino/` into `assets/rk-arduino.zip`
- **Asset bundle**: ~500KB addition to app bundle
- **Dependencies**: None new — uses existing `shelf`, `archive` packages
