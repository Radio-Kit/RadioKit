## Context

The RadioKit monorepo contains two tightly coupled components: the Flutter app (`radiokit-app/`) and the Arduino C++ library (`rk-arduino/`). Today, the library is distributed via GitHub — users must manually clone or install it. The app already runs a full HTTP server (`shelf_router`) with 80+ endpoints for device control, OTA, filesystem, designs, etc.

The goal is to make the app a self-contained distribution point for the library, so AI agents (and users) can fetch it directly via the remote access API without touching GitHub.

## Goals / Non-Goals

**Goals:**
- Agent can query library version via HTTP and download the full library as a ZIP
- Agent can detect staleness by comparing version strings
- Build process automates ZIP creation from the sibling `rk-arduino/` directory
- Minimal surface area: two endpoints, one service class

**Non-Goals:**
- Individual file download endpoints (ZIP is sufficient for 496KB)
- PlatformIO registry integration
- Over-the-air library updates to ESP32 devices
- Version negotiation or compatibility checking between app and library

## Decisions

### 1. ZIP as the transport format

**Decision**: Serve a single ZIP archive via `GET /api/library/download`.

**Rationale**: The library is 63 files / 496KB. A ZIP is atomic — one download, one extract, done. Individual file endpoints add complexity for no benefit at this scale.

**Alternatives considered**:
- Individual file endpoints: rejected — too many roundtrips for no gain
- Tar.gz: rejected — ZIP is universally supported, no extra dependencies
- Serving from Flutter asset bundle directly: possible but extraction to documents dir is simpler for serving via shelf

### 2. Version string comparison (not checksum-based)

**Decision**: Agent compares `version` field from `GET /api/library/version` against local `library.json` version.

**Rationale**: Simple, fast, no need to hash every file. Version bump in `library.json` is the signal for "something changed." For a 496KB library, full re-download on version mismatch is fine.

**Alternatives considered**:
- SHA-256 checksums per file: rejected — overkill for this scale
- ETag / Last-Modified: rejected — adds HTTP complexity, version string is clearer

### 3. Asset bundling via build script

**Decision**: A shell script zips `rk-arduino/` into `radiokit-app/assets/rk-arduino.zip` as a pre-build step.

**Rationale**: Flutter assets must live within the project directory. A build script keeps the source of truth in `rk-arduino/` and avoids duplication.

**Alternatives considered**:
- Symlink to `../rk-arduino/`: rejected — unreliable across platforms and Flutter build systems
- Embedding file contents as Dart constants: rejected — brittle, requires codegen on every library change
- Reading from `../rk-arduino/` at runtime: rejected — won't work in release builds on mobile

### 4. LibraryService extracts to app documents directory

**Decision**: On first access, `LibraryService` extracts the ZIP to `getApplicationDocumentsDirectory()/rk-arduino/`. Serves version from the extracted `library.json`.

**Rationale**: Clean separation between bundled asset (ZIP) and runtime state (extracted files). Documents directory persists across app restarts.

**Alternatives considered**:
- Serving directly from asset bundle without extraction: possible but `rootBundle` doesn't support streaming bytes for HTTP responses easily
- Temp directory: rejected — would re-extract every app launch

## Risks / Trade-offs

- **Asset staleness** → Library version in the ZIP is frozen at app build time. Users must update the app to get a newer library. This is acceptable for the current distribution model.
- **500KB bundle increase** → Trivial. The ZIP is smaller than the existing `assets/demos/` directory.
- **Version drift** → If someone edits `rk-arduino/` without running the build script, the served ZIP won't reflect changes. Mitigated by documenting the build step.
