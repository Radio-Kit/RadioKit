## Context

The RadioKit Flutter app runs a REST API on port 7007. AI agents building firmware need access to the rk-arduino documentation at runtime. The `SKILLS/` directory contains comprehensive markdown docs (firmware, widgets, transports, filesystem, OTA, remote access). Serving these through the existing API lets agents fetch documentation on-demand without pre-configuration.

## Goals / Non-Goals

**Goals:**
- Serve SKILLS/ documentation as JSON API responses
- Provide a docs index listing all available skill files
- Expose the REST API surface as JSON Schema for tool discovery
- Use the existing port 7007 and shelf router
- Keep implementation minimal — just routes + file serving

**Non-Goals:**
- MCP protocol implementation
- Authentication/authorization
- Documentation generation or transformation
- Real-time documentation updates

## Decisions

### D1: Serve markdown as-is, not HTML

**Choice**: Return raw markdown content in JSON responses.

**Rationale**: Agents process markdown natively. Converting to HTML adds complexity with no benefit for AI consumers.

### D2: Embed docs at build time, not runtime file serving

**Choice**: Read SKILLS/ files at server startup, cache in memory, serve from cache.

**Rationale**: Avoids filesystem access at runtime (web builds don't have `dart:io`). Ensures docs are always available even if files change. Startup cost is negligible (~50KB).

**Alternatives considered**:
- Runtime file reading: Fails on web builds, adds FS dependency
- Network fetch: Circular dependency

### D3: JSON Schema for API surface

**Choice**: Add a `/api/docs/api-schema` endpoint that returns the full REST API surface as JSON Schema, derived from the existing route definitions.

**Rationale**: Lets agents auto-discover what tools are available and their parameter formats without reading markdown docs.

### D4: Flat route structure

**Choice**: Three endpoints under `/api/docs/`:
- `GET /api/docs` — index of all available docs
- `GET /api/docs/<skill>` — individual skill content
- `GET /api/docs/api-schema` — JSON Schema of all API endpoints

**Rationale**: Simple, consistent with existing flat route pattern.

## Risks / Trade-offs

**[Risk] Doc content drift** → If SKILLS/ files change but server cache doesn't. Mitigation: Cache is rebuilt on server restart (which happens on app restart). Acceptable for development workflow.

**[Risk] Large payloads** → Some skill files are 10-15KB. Mitigation: Return on-demand, not streamed. MCP/REST clients handle this fine.

## Migration Plan

1. Add `DocsService` class that reads and caches SKILLS/ files
2. Add three routes to the existing router
3. Register `DocsService` in `RemoteAccessProvider`
4. Test with `curl http://127.0.0.1:7007/api/docs`

No migration needed — purely additive.
