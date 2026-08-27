# fix-fs-delete-and-back-nav Tasks

## 1. Firmware: Recursive Delete

- [x] 1.1 Add a file-local `deleteRecursive(const char* path, int depth)` helper in `rk-arduino/src/connection/RadioKitFsHandlers.cpp` (open with `LittleFS.open(path, "r")`, iterate `openNextFile()`, recurse for subdirs, `LittleFS.remove()` files, `rmdir()` the emptied dir, depth-capped)
- [x] 1.2 Add the depth-cap define (`RK_FS_MAX_DELETE_DEPTH`, file-local constant, value 32) and fail the walk past it
- [x] 1.3 Update `handleDelete` to read the RECURSIVE flag byte into a `bool` and call `deleteRecursive` when set; keep the file-first/`rmdir` fallback for the non-recursive path
- [x] 1.4 Verify `pio run` compiles for the `Filesystem_LED` and `FsCommandTest` examples (venv per AGENTS.md §17.1)

## 2. Firmware: On-Device Tests

- [x] 2.1 Extend `rk-arduino/examples/FsCommandTest` with a `deleteRecursive` test group: seed a nested tree, then `FS_DELETE` with `recursive=1` and assert `OK` + `LittleFS.exists()` false for every node
- [x] 2.2 Add cases: file with `recursive=1` → `OK`; empty dir with `recursive=1` → `OK`; non-empty dir with `recursive=0` → `NOT_FOUND` (unchanged semantics)
- [x] 2.3 Seed a nested tree (`/demo/sub/file.txt`) in `rk-arduino/examples/Filesystem_LED` first-boot so the delete flow is exercisable end-to-end from the app

## 3. App: Back-Button Dispatcher

- [x] 3.1 Add a modal-tracking `NavigatorObserver` (`ModalRouteTracker`) that records/removes `PopupRoute`-subclass routes via `didPush`/`didPop`/`didReplace` and exposes the top modal + its owning navigator
- [x] 3.2 Add `RadioKitBackDispatcher extends RootBackButtonDispatcher` — `didPopRoute()` pops the tracked top modal (if any, on its owning navigator) and returns true; otherwise delegates to `super.didPopRoute()`
- [x] 3.3 Wire both into the app: register the tracker in `createRouter`'s `observers:` and pass `RadioKitBackDispatcher` as `backButtonDispatcher` on `MaterialApp.router` in `app.dart`
- [x] 3.4 Add a widget test: sheet open + `didPopRoute` → sheet dismissed and no delegate call; no modal + `didPopRoute` → delegates

## 4. Verification

- [x] 4.1 `flutter analyze --fatal-warnings` and `flutter test` in `radiokit-app`
- [x] 4.2 Build examples via `pio run` (CI matrix covers all examples)
- [X] 4.3 On the Android tablet with a real device: delete a nested folder from the FS manager and confirm it disappears — verified on ESP32-S3 + tablet: deleted `/demo/sub` (folder containing `file.txt`) and the whole `/demo` tree from the FS manager; root listing went to 0 entries
- [X] 4.4 On the tablet: open the device-info sheet (FILESYSTEM tab) and press back → sheet closes, app stays on models; back on the models root still exits — verified: dispatcher pops the sheet (device-info + FS tab), app stays resumed on models; back at root exits normally
- [X] 4.5 Upload test/example sketches WITH flash erase per AGENTS.md §1.1 (NVS must not mask results) — uploaded `FsCommandTest` and `Filesystem_LED` with erase; all 12 on-device FS tests pass (incl. 4 new recursive-delete cases)

## 5. Documentation Sync

- [x] 5.1 Update FS/protocol docs (`website/src/content/docs/`) noting recursive delete support
- [x] 5.2 Add a note to `AGENTS.md` (section 21/FS conventions) documenting the RECURSIVE flag behavior and the back-dismisses-modals dispatcher
