## Why

AI agents building firmware with RadioKit need to access the library documentation at runtime. Currently, docs live in `SKILLS/` as static markdown files. Agents must either have these files pre-loaded or fetch them externally. Serving documentation through the app's existing REST API (port 7007) lets agents discover and read docs dynamically — no pre-configuration needed.

## What Changes

- **New API endpoint group** `/api/docs/*` serving the SKILLS documentation as structured JSON
- **Doc index** listing all available skill files with metadata
- **Individual doc retrieval** by skill name, returning markdown content
- **Schema endpoint** exposing the full REST API surface as JSON Schema (tool discovery)
- No new protocol, no new dependencies, no new port — just new routes on the existing server

## Capabilities

### New Capabilities

- `docs-api`: REST endpoints serving firmware documentation, API reference, and tool schemas for agent consumption

### Modified Capabilities

(none — purely additive)

## Impact

- **New file**: `lib/services/docs_service.dart` — parses SKILLS/ markdown files and serves them
- **Modified file**: `lib/services/remote_access_service.dart` — register new `/api/docs/*` routes
- **No new dependencies**: Uses existing `shelf` router
- **No breaking changes**: Existing REST API unchanged
