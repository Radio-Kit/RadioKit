## Why

Users design UIs in the RadioKit Designer and save them as projects. The designer generates a `RADIOKIT.h` file containing widget declarations and config. Currently, users must manually export this file and provide it to an LLM.

With the API server, the LLM fetches `RADIOKIT.h` directly from the device:

**Workflow:**
1. User designs UI in the app, saves the design
2. User enables the API server
3. LLM fetches `http://<ip>:7007/` (llms.txt)
4. LLM discovers `GET /api/designs/<id>/header`
5. LLM fetches the RADIOKIT.h file directly
6. LLM uses the file content in the firmware code

The LLM gets the exact `RADIOKIT.h` file — no copy-paste, no manual export.

## What Changes

- **New endpoint** `GET /api/designs/<id>/json` — returns the designer JSON config for a specific design
- **New endpoint** `GET /api/designs/<id>/header` — generates and returns the Arduino `.h` file content using `JsonArduinoGenerator`
- **Updated** `GET /api/designs` — already returns `jsonContent` but will be verified
- **Updated** `llms.txt` — add design endpoints to the LLM discovery file

## Capabilities

### New Capabilities

(none — extending existing `api-server` capability)

### Modified Capabilities

- `api-server`: Add design content endpoints to the docs API

## Impact

- **Modified file**: `lib/services/remote_access_service.dart` — add 2 new route handlers
- **Modified file**: `assets/skills/llms.txt` — add design endpoint docs
- **No new dependencies**: Uses existing `JsonArduinoGenerator`
