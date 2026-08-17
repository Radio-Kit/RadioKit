## 1. Dependency Changes

- [x] 1.1 Add `phosphoricons_flutter: ^1.0.0` to `flutter-widgets/pubspec.yaml` dependencies (alongside `simple_icons` and `lucide_icons_flutter`)
- [x] 1.2 Remove the unused `cupertino_icons: ^1.0.2` dependency from `radiokit-app/pubspec.yaml`
- [x] 1.3 Run `flutter pub get` in `radiokit-app` and verify `phosphoricons_flutter` appears in `pubspec.lock` (transitive via `radiokit_widgets`) and `cupertino_icons` is gone

## 2. Icon Registry

- [x] 2.1 Add the Phosphor import to `flutter-widgets/lib/src/utils/icon_registry.dart`
- [x] 2.2 Add the 26 Phosphor fill entries (kebab-case keys mapped to `PhosphorIconsFill` constants), replacing the Lucide entries for `bell`, `rewind`, and `fast-forward`

## 3. Verification

- [x] 3.1 Run `flutter analyze --fatal-warnings` in `radiokit-app` (also covers the path dependency) and fix any issues
- [x] 3.2 Run `flutter test` in `radiokit-app` and confirm all tests pass
- [x] 3.3 Verify the icon picker discovers the new keys (no UI code change required) and confirm `iconFromName` resolves a sample of the new names, including the 3 replaced keys

## 4. Lucide Replacement

- [x] 4.1 Swap all remaining Lucide entries in `kDesignerIcons` to Phosphor fill equivalents under the same keys (75 keys; registry becomes Phosphor fill + SimpleIcons)
- [x] 4.2 Remove `lucide_icons_flutter` from `flutter-widgets/pubspec.yaml` and regenerate its lockfile
- [x] 4.3 Update `icon_registry_test.dart` for the Phosphor-only registry and re-run tests (flutter-widgets + app) and analyze

## 5. App Chrome Sweep

- [x] 5.1 Replace all Lucide imports/usages in 10 app files (designer screens, icon_utils, fs_helpers, dev_tools_tab, designs_tab, starter_templates_section) with Phosphor fill equivalents
- [x] 5.2 Fix `test/designer_page_bar_test.dart` (Lucide → Phosphor assertions)
- [x] 5.3 Remove `lucide_icons_flutter` from `radiokit-app/pubspec.yaml`, add `phosphoricons_flutter` as direct dep, run `flutter pub get`
- [x] 5.4 Run `flutter analyze` (back to baseline 324 infos) and `flutter test` (352/352 pass)
