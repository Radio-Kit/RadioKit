# fix-fs-delete-and-back-nav Proposal

## Why

Two user-facing bugs in the filesystem manager on Android tablets:

1. **Folder deletion fails on real devices.** `handleDelete` in the firmware parses the RECURSIVE flag but never uses it — it only calls `LittleFS.remove()` then `LittleFS.rmdir()`, which removes *empty* directories only. Deleting a non-empty folder (files and subfolders) returns `NOT_FOUND`, so the app shows "Delete failed: NOT_FOUND". File deletion works because `LittleFS.remove()` handles files. The in-memory demo transport implements recursive delete correctly, so the bug only reproduces on hardware and escaped existing tests.
2. **Pressing back closes the app instead of dismissing the device-info sheet.** The sheet (INFO/SETTINGS/FILESYSTEM tabs) is a modal bottom sheet pushed on the shell-branch Navigator. On real Android 13+ devices, Flutter registers `OnBackInvokedCallback` for predictive back, and with go_router's per-branch shell Navigators the gesture dispatches to the router delegate instead of the Navigator owning the sheet — the app exits (flutter/flutter#145290). Works on emulator/desktop, fails on the tablet.

## What Changes

- **Firmware**: implement true recursive delete in `handleDelete` — walk the directory (reusing the `handleList` iteration pattern), remove files, recurse into subdirectories, then `rmdir()` the emptied directory, bounded by a depth cap. Honor the existing RECURSIVE flag; the non-recursive path keeps current behavior.
- **App**: add a custom `RootBackButtonDispatcher` on `MaterialApp.router` that calls `maybePop()` across the app's navigators (root + shell branches) before delegating to the go_router delegate, so any open modal/sheet/dialog dismisses on back instead of exiting the app. This fixes the device-info sheet and every other modal surface.
- **Tests**: add a firmware unit test for recursive delete and exercise the feature in the `Filesystem_LED` example sketch. Keep demo parity (`demo_fs_test.dart`) in sync with any error-semantics changes.
- **Docs**: sync protocol/FILESYSTEM docs per the docs-sync rule.

## Capabilities

### New Capabilities
- `fs-recursive-delete`: Firmware FS behavior — `FS_DELETE` with the RECURSIVE flag deletes a directory tree (files + subfolders) on LittleFS; non-recursive delete keeps current semantics; results are ACKed with `RK_FS_ERR_OK` on success.
- `back-dismisses-modals`: App navigation behavior — the Android system back button dismisses open modal surfaces (bottom sheets, dialogs) shown from any shell branch before it can exit the app; the go_router delegate is only consulted when no modal is open.

### Modified Capabilities
<!-- No existing spec-level requirements change; both capabilities are new. -->

## Impact

- **Firmware** (`rk-arduino/src/connection/RadioKitFsHandlers.cpp`): new recursive-delete helper + updated `handleDelete`; no wire-format or `RadioKitFS.h` constant changes (the RECURSIVE flag already exists in the protocol).
- **App** (`radiokit-app/lib/app.dart`): custom `RootBackButtonDispatcher` wired into `MaterialApp.router`'s `backButtonDispatcher`.
- **Tests**: `rk-arduino` unit test for `deleteRecursive`; `Filesystem_LED` example exercise; existing `demo_fs_test.dart` unchanged unless error semantics change (they don't — non-recursive delete of a non-empty dir still returns `NOT_FOUND`).
- **Docs**: `website/src/content/docs/` FS/protocol pages noting recursive delete support.
