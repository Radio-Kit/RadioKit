## 1. Build Script

- [x] 1.1 Create `scripts/build-library-zip.sh` that zips `rk-arduino/` into `radiokit-app/assets/rk-arduino.zip`
- [x] 1.2 Add `radiokit-app/assets/rk-arduino.zip` to `.gitignore` (generated artifact, not source)

## 2. Asset Configuration

- [x] 2.1 Add `assets/rk-arduino.zip` to `pubspec.yaml` under `flutter.assets`

## 3. LibraryService

- [x] 3.1 Create `lib/services/library_service.dart` with `LibraryService` class
- [x] 3.2 Implement `initialize()` — extract ZIP to `getApplicationDocumentsDirectory()/rk-arduino/` if not already present
- [x] 3.3 Implement `version` getter — read from extracted `library.json`
- [x] 3.4 Implement `downloadZip()` — return ZIP bytes from asset bundle

## 4. API Endpoints

- [x] 4.1 Add `GET /api/library/version` handler to `RemoteAccessService`
- [x] 4.2 Add `GET /api/library/download` handler to `RemoteAccessService`

## 5. App Integration

- [x] 5.1 Initialize `LibraryService` in app startup (before HTTP server starts)
- [x] 5.2 Follow mode: map `/api/library/*` routes to appropriate screen

## 6. Verification

- [x] 6.1 Run `flutter analyze --fatal-warnings` — no new warnings
- [x] 6.2 Manual test: start app, `curl http://localhost:7007/api/library/version` returns version JSON
- [x] 6.3 Manual test: `curl -o /tmp/rk.zip http://localhost:7007/api/library/download` produces valid ZIP
