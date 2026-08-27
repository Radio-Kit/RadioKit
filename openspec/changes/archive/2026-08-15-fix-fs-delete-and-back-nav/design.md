# fix-fs-delete-and-back-nav Design

## Context

Two independent bugs, both confirmed on an Android tablet with a real ESP32 device:

1. **Folder delete fails.** The bulk-FS protocol defines `FS_DELETE [PATH, RECURSIVE(1)]` (RadioKitFS.h), and the Flutter app already sends `recursive: true` for directories (`FsTabContent._deleteEntry` passes `recursive: entry.isDirectory`; multi-select always passes `recursive: true`). But `handleDelete` in `rk-arduino/src/connection/RadioKitFsHandlers.cpp` parses the RECURSIVE byte and throws it away: it tries `LittleFS.remove()` (files only), then `LittleFS.rmdir()` (empty directories only). A non-empty folder therefore returns `RK_FS_ERR_NOT_FOUND` and the app shows "Delete failed: NOT_FOUND". The in-memory demo transport (`demo_fs_transport.dart` → `DemoFsState.delete(recursive:)`) implements recursion correctly, so demo-mode works and real-device folder deletion is broken — which is why the existing `demo_fs_test.dart` never caught it.

2. **Back exits the app.** The device-info sheet (INFO/SETTINGS/FILESYSTEM tabs, `FsTabContent`) is a modal bottom sheet shown via `showThemedBottomSheet` → `showModalBottomSheet(useRootNavigator: false)` from the models branch. `StatefulShellRoute.indexedStack` hosts each branch in its own nested Navigator, so the sheet lives on the **branch** Navigator. On real Android 13+ devices Flutter registers `OnBackInvokedCallback` for predictive back (FlutterActivity.setFrameworkHandlesBack → registerOnBackInvokedCallback, no manifest flag needed), and with go_router's per-branch Navigators the back gesture dispatches to the go_router delegate instead of the Navigator owning the sheet — the app exits (flutter/flutter#145290, "Predictive back can close app when navigation stack is not empty"). Works in the emulator and in widget tests; fails on the physical tablet.

## Goals / Non-Goals

**Goals:**
- Deleting a folder from the FS manager removes the folder, its files, and its subfolders (any depth) on real LittleFS hardware.
- The Android system back button dismisses any open modal surface (bottom sheet, dialog) from any shell branch before the app can exit; the go_router delegate is only consulted when no modal is open.
- On-device verification: recursive delete exercised in the firmware FS test example, plus a seed/self-check in `Filesystem_LED`.

**Non-Goals:**
- Changing the wire protocol: `FS_DELETE` and the RECURSIVE flag already exist; no `RadioKitFS.h` constant or frame-layout changes.
- Changing app-side semantics: the app already sends `recursive: true` for directories; no UI text changes.
- Full app-wide navigation redesign, Predictive-back visual animations, or changes to go_router version.
- Deleting non-empty folders with `recursive: false` (kept as current behavior — returns `NOT_FOUND`).

## Decisions

### D1: Implement recursive delete on the firmware

`handleDelete` gains a `deleteRecursive(path)` helper (file-local in `RadioKitFsHandlers.cpp`) that:
1. Opens the path with `LittleFS.open(path, "r")`; if it is not a directory, `LittleFS.remove()` it (a file requested with recursive=1 is still just a file).
2. Iterates with `openNextFile()` (the exact pattern already used by `handleList`):
   - `entry.isDirectory()` → recurse with the joined child path;
   - otherwise `LittleFS.remove(entryPath)`.
3. After children are gone, `rmdir()` the directory.

- Why firmware (not app): the protocol already carries the flag, and app-side recursive delete would require LIST + N×DELETE round trips over BLE (seconds per folder, chatty, failure-prone mid-way).
- Alternative considered: app-side recursion. Rejected for the round-trip cost and because the flag exists precisely to move this onto the device.
- Alternative considered: a separate `FS_DELETE_TREE` command. Rejected — the RECURSIVE flag already defines the contract; a new command would fork the protocol for no gain.

### D2: Depth cap on recursion

`deleteRecursive` takes a depth parameter starting at 0 and fails (returns false) past `RK_FS_MAX_DELETE_DEPTH` (new `#define`, value 32). Rationale: LittleFS path length is bounded (128 chars in `readString`'s buffer), so realistic trees are shallow; 32 is generous headroom. Prevents stack overflow from pathological/malicious payloads, since `handleDelete` runs in the main loop's stack.

### D3: Error semantics for the non-recursive path stay unchanged

When `recursive: false` targets a non-empty directory, `handleDelete` keeps returning `RK_FS_ERR_NOT_FOUND` (current behavior). The app never sends `recursive: false` for directories, so this path is only reachable by direct protocol clients; no spec/behavior change and no demo-parity change.

### D4: Custom `RootBackButtonDispatcher` (global fix)

Wire a custom dispatcher into `MaterialApp.router(backButtonDispatcher: ...)`:

```dart
class RadioKitBackDispatcher extends RootBackButtonDispatcher {
  final NavigatorObserver modalTracker;
  @override
  Future<bool> didPopRoute() async {
    // 1) If a modal route is open on any navigator, pop it ourselves.
    final top = modalTracker.topModal;
    if (top != null && top.navigator != null) {
      top.navigator!.pop();
      return true;
    }
    // 2) Otherwise delegate to go_router (pages, and exit when on a root page).
    return super.didPopRoute();
  }
}
```

`modalTracker` is a `NavigatorObserver` registered in go_router's `observers:` list. It maintains a stack of routes pushed via `didPush` and removes them on `didPop`/`didReplace`, tracking only **pageless** routes — `PopupRoute` subclasses (bottom sheets, dialogs) — which are never part of go_router's `currentConfiguration`. Page routes (go_router's own navigations) are ignored, so `didPopRoute` only intercepts modals and delegates everything else to go_router.

- Why the dispatcher over `PopScope`: PopScope on the sheet would fix one surface; the app shows many modals from shell branches (device-info sheet, pair sheet, accounts sheet, auth dialog, FS action sheet, file editor, settings dialog, donate sheet, designer sheets). The dispatcher fixes the whole class in one place and mirrors the workaround verified in flutter/flutter#145290.
- Why a navigator observer + stack rather than tracking contexts: branch Navigators are created internally by go_router (`StatefulShellRoute.indexedStack`); we can't enumerate them. Observing pushes gives us the `Route` objects, and `route.navigator` points at whichever navigator (root or branch) owns the modal, so `navigator.pop()` pops the correct stack.
- Why `useRootNavigator: true` for sheets is not the fix: the #145290 repro used it and still failed; the defect is in the delegate's route discovery, not which navigator hosts the modal.
- Alternative considered: upgrading go_router / waiting for the framework fix. Rejected for this change — #145290 is open (P2) with no release target; the dispatcher is small, local, and removable later.

### D5: On-device tests in the existing test example

The repo's established FS command test is `rk-arduino/examples/FsCommandTest` (builds frames, calls `RKFs::dispatch`, captures the ACK via a custom sender). Recursive-delete cases go there:

- `FS_DELETE /tree recursive=1` on a seeded tree (2 files + 1 subfolder with a file) → `OK`, and `LittleFS.exists()` checks confirm the whole tree is gone.
- `FS_DELETE /file recursive=1` → `OK` (files are handled by the same path).
- `FS_DELETE /tree recursive=0` on a non-empty tree → `NOT_FOUND` (unchanged semantics).
- `FS_DELETE /empty_dir recursive=1` → `OK`.

`Filesystem_LED` seeds a small nested tree (`/demo/sub/file.txt`) on first boot alongside the existing README, so the flow can be exercised end-to-end from the app (delete `/demo` from the FS manager, verify it disappears).

### D6: Flash-erase on test uploads

Per AGENTS.md §1.1 (firmware flash erase policy), every upload of the test/example sketches during verification MUST include `--erase` (or `eraseAll: true`) so stale NVS cannot mask results.

## Risks / Trade-offs

- **Recursive delete is destructive and unbounded in files touched** → the walk is depth-capped (D2), each `FS_DELETE` still goes through the same ACK path, and the app already requires a confirmation dialog for folder delete ("This will delete the folder ... and ALL files inside it").
- **Dispatcher pops a modal the user didn't expect** (e.g., a system dialog) → tracker only records `PopupRoute` subclasses pushed by the app's own navigators; behavior matches what a correct Navigator `maybePop` would do anyway.
- **go_router future changes could break the observer contract** → the dispatcher is a thin, removable layer; if go_router ships a fix for #145290 the dispatcher can be deleted without touching navigation code.
- **Depth cap could reject an extreme tree** → 32 levels far exceeds LittleFS's practical nesting; the app surfaces the ACK error if it ever happens.
- **`FsCommandTest`/`Filesystem_LED` need a real device** → CI (pioarduino-ci) builds examples; the on-device assertions run manually per the established pattern for that example.

## Migration Plan

1. Firmware: add `deleteRecursive` + depth cap in `RadioKitFsHandlers.cpp`; wire the RECURSIVE flag in `handleDelete`.
2. On-device tests: extend `FsCommandTest` with recursive-delete cases; seed the nested tree in `Filesystem_LED`.
3. App: add the modal-tracking observer + `RadioKitBackDispatcher`; wire `backButtonDispatcher` in `app.dart`.
4. Widget test for the dispatcher (modal open → `didPopRoute` pops it and returns true; no modal → delegates) using a `Navigator` + fake `GoRouter`-style page stack.
5. Verify on the tablet: FS delete of a nested folder; back dismisses the sheet; back on the models root still exits.
6. Docs sync: FS/protocol docs note recursive delete; `AGENTS.md` back-button behavior note.

Rollback: revert the two small diffs (firmware handler + dispatcher wiring); no protocol or schema changes, so nothing else needs undoing.

## Open Questions

- None blocking. Minor: exact placement of the depth-cap define (`RadioKitConfig.h` vs file-local) is settled during implementation (file-local constant, since it is not user-configurable).
