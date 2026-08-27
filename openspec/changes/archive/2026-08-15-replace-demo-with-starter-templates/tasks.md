## 1. Provider & Service Cleanup

- [x] 1.1 Remove `showDemo` state and `setShowDemo` method from `SettingsProvider`
- [x] 1.2 Remove `ENABLE_DEMO` switch from `SystemTab`
- [x] 1.3 Remove `showDemo` serialization from `RemoteAccessService`
- [x] 1.4 Clean up references in `llms.txt` or assets

## 2. Models Tab Overhaul

- [x] 2.1 Remove `_InteractiveDemoSection` and `_DemoTile` from `models_tab.dart`
- [x] 2.2 Update `StarterTemplatesSection` or create a variant with header `STARTER_TEMPLATES`
- [x] 2.3 Render starter templates section on `models_tab.dart` when `pairedDevices` is empty in both portrait and landscape modes
- [x] 2.4 Verify tapping a starter template navigates to Designer preview

## 3. Verification & Validation

- [x] 3.1 Run Flutter tests to verify all tests pass and compile cleanly
- [x] 3.2 Verify no broken imports or dead references
