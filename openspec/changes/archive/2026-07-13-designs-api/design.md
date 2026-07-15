## Context

The RadioKit app has a Designer screen where users create widget layouts visually. Designs are saved as JSON configs and can be exported as Arduino `.h` files. The existing REST API (`GET /api/designs`) lists all saved designs with their JSON content, but doesn't provide a way to:
1. Fetch just the JSON for a specific design by ID
2. Generate the Arduino `.h` file on demand

Adding these endpoints lets an LLM read a design and generate firmware code in one step.

## Goals / Non-Goals

**Goals:**
- Add `GET /api/designs/<id>/json` to fetch designer JSON by ID
- Add `GET /api/designs/<id>/header` to generate Arduino `.h` file on demand
- Update `llms.txt` with design endpoints
- Keep implementation minimal — reuse existing codegen

**Non-Goals:**
- Modifying the design data model
- Adding new save/export flows
- Caching generated headers

## Decisions

### D1: Generate .h on demand, not cached

**Choice**: Call `JsonArduinoGenerator.generate()` on each request.

**Rationale**: Designs change frequently. Caching would require invalidation logic. Generation is fast (<10ms) and the endpoint is called infrequently (by agents, not UI).

### D2: Return raw text for .h, JSON for json

**Choice**: `/json` returns `application/json`, `/header` returns `text/plain`.

**Rationale**: Agents process both formats natively. JSON for programmatic access, plain text for code generation.

### D3: Reuse existing `JsonArduinoGenerator`

**Choice**: Import and call the existing codegen from `lib/screens/designer/codegen/json_arduino_generator.dart`.

**Rationale**: No duplication. The generator already handles all widget types and produces correct Arduino code.

## Risks / Trade-offs

**[Risk] Import path from service to screen code** → The generator lives in `lib/screens/designer/codegen/`. Importing from a service into a screen package is unconventional. Mitigation: Acceptable for codegen utility; could be moved to `lib/services/` later if needed.

## Migration Plan

1. Add 2 new routes to the router
2. Add 2 handler methods
3. Update `llms.txt`
4. Test with curl

No migration needed — purely additive.
