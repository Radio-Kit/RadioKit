## Why

The designer's icon registry (`kDesignerIcons`) needs more expressive, fill-style glyphs for widgets (sirens, headlights, steering wheels, hazard symbols, vehicles). The official `phosphor_flutter` package is unusable on this project's Flutter SDK (`IconData` is `final` and the package subclasses it), so the compatible `phosphoricons_flutter` community package is the way in. Separately, `cupertino_icons` is declared in the app's pubspec but never imported anywhere — dead weight.

## What Changes

- Add `phosphoricons_flutter: ^1.0.0` as a dependency of `flutter-widgets` (declared alongside `simple_icons`, exposed to the app through the shared icon registry).
- Extend `kDesignerIcons` with 26 new icons from the Phosphor **fill** weight, keyed by their kebab-case names (e.g. `caret-left`, `siren`, `steering-wheel`, `biohazard`).
- Replace all remaining Lucide entries in `kDesignerIcons` with equivalent Phosphor **fill** glyphs under the same keys (e.g. `zap` → `lightning`, `settings` → `gearSix`, `home` → `house`), so the registry is entirely Phosphor fill + SimpleIcons. Stored icon-name strings keep resolving unchanged.
- Replace all Lucide imports in the app's own UI chrome (10 files: designer screens, icon_utils, fs_helpers, dev_tools_tab, designs_tab, starter_templates_section, and 1 test) with Phosphor fill equivalents, then remove `lucide_icons_flutter` from `radiokit-app/pubspec.yaml` — eliminating Lucide from the entire app.
- Remove the vestigial `cupertino_icons` dependency from `radiokit-app/pubspec.yaml`. Verified: zero imports in `lib/`.
- No JSON schema or wire-protocol changes — icon names remain strings resolved client-side via `kDesignerIcons`; unknown names continue to fall back to a default icon.

## Capabilities

### New Capabilities
- `designer-icons`: The shared icon registry (`kDesignerIcons`) in `flutter-widgets`, covering multi-pack resolution (Lucide, SimpleIcons, Phosphor), additive name-string keys, unknown-name fallback, and automatic discovery by the icon picker.

### Modified Capabilities
- (none — no existing spec covers the icon registry)

## Impact

- `flutter-widgets/pubspec.yaml` — new dependency `phosphoricons_flutter: ^1.0.0`.
- `flutter-widgets/lib/src/utils/icon_registry.dart` — Lucide section fully replaced by Phosphor fill equivalents (104 Phosphor entries total); registry is now Phosphor fill + SimpleIcons.
- `flutter-widgets/pubspec.yaml` — remove `lucide_icons_flutter` (was only used by the registry).
- `radiokit-app/pubspec.yaml` — remove `cupertino_icons: ^1.0.2`, remove `lucide_icons_flutter`, add `phosphoricons_flutter: ^1.0.0` (now used directly by app chrome).
- `radiokit-app/lib/` — 10 files sweeped from Lucide to Phosphor fill (designer screens, icon_utils, fs_helpers, dev_tools_tab, designs_tab, starter_templates_section).
- `radiokit-app/test/designer_page_bar_test.dart` — Lucide assertions replaced with Phosphor equivalents.
- Lockfiles regenerate via `flutter pub get` in `radiokit-app` (resolves the path dependency transitively).
- App size: one additional icon font weight (Phosphor fill) bundled into the widget library consumers.
- Consumers: designer icon picker, canvas rendering, device icon selection — all read `kDesignerIcons` and pick up new keys automatically.
