## Context

The designer icon system funnels through a single registry, `kDesignerIcons` in `flutter-widgets/lib/src/utils/icon_registry.dart` — a `Map<String, IconData>` of 144 icons drawn from Lucide (78) and SimpleIcons (66). Icon names travel as strings through the JSON config and device info; the registry resolves them to `IconData` at render time via `iconFromName()`. The icon picker dialog iterates `kDesignerIcons.keys` with substring search, so registry additions are automatically discoverable with no UI changes.

The project runs Flutter 3.44.2. In this SDK, `IconData` is declared `final class IconData`, which makes the official `phosphor_flutter` package uncompilable: its `PhosphorIconData extends IconData`.

## Goals / Non-Goals

**Goals:**
- Add a third icon source (Phosphor, fill weight) to `kDesignerIcons` with 26 requested glyphs.
- Make Phosphor icons available to the app and widget library exactly like SimpleIcons — declared in `flutter-widgets`, consumed via the shared registry.
- Remove the unused `cupertino_icons` dependency from the app.

**Non-Goals:**
- No JSON schema, protocol, or codegen changes — icon names stay strings resolved client-side.
- No icon picker UI changes — discovery is automatic.
- No changes to the Arduino firmware or wire format.

## Decisions

### 1. Use `phosphoricons_flutter` over `phosphor_flutter`
- **Decision**: Add `phosphoricons_flutter: ^1.0.0`.
- **Rationale**: `phosphor_flutter`'s `PhosphorIconData extends IconData`, and `IconData` is `final` in Flutter 3.44.2 — verified in the installed SDK source (`final class IconData`). The official package (2.1.0, 2 years old) is incompatible and unmaintained. `phosphoricons_flutter` (1.0.0) aliases `IconData` instead of subclassing (`typedef PhosphorIconData = IconData`), ships the full 1530+ icon core, and its flat weights are plain `IconData` — exactly what the registry needs.
- **Alternative considered**: Vendoring the Phosphor TTF and constructing `IconData(codePoint, fontFamily: 'Phosphor')` manually — zero dependency risk but significant maintenance burden (code points, font asset wiring). Rejected as overkill; the package is a thin wrapper over exactly this.

### 2. Declare the dependency in `flutter-widgets`, mirroring `simple_icons`
- **Decision**: Add to `flutter-widgets/pubspec.yaml` only; the app consumes it transitively through `kDesignerIcons`.
- **Rationale**: The registry lives in the widget library. The app accesses Phosphor icons the same way it accesses SimpleIcons today — by name string through the registry — so no direct app import is needed.
- **Alternative considered**: Declaring in `radiokit-app` too, for direct `PhosphorIconsFill` use in app chrome. Deferred; trivially added later if app-side direct imports are wanted.

### 3. Fill weight for the new entries
- **Decision**: All 26 new entries use `PhosphorIconsFill`.
- **Rationale**: User requirement; fill glyphs read better for device/signal icons at small canvas sizes. One weight = one font file bundled (smallest Phosphor footprint).

### 4. Collision resolution: Phosphor takes over `bell`, `rewind`, `fast-forward`
- **Decision**: Replace the 3 Lucide entries with Phosphor fill versions under the same keys.
- **Rationale**: Map keys are unique; these 3 names were requested. Verified zero references to the keys in `assets/demos/`, `assets/starter-templates/`, app `lib/`, and widget-library `lib/` — so the swap is invisible to existing configs. Matches the project's no-backward-compatibility stance (AGENTS.md section 16).
- **Alternative considered**: `-fill` suffixed keys (`bell-fill` etc.) — rejected, pollutes the name-string schema for no real benefit.

### 5. Registry keys are Phosphor kebab-case names
- **Decision**: Keys match the Phosphor icon names (`caret-left`, `arrow-fat-right`, `lightbulb-filament`, ...), consistent with the existing registry's `zap`, `battery-charging`, `trash-2` convention. `warning` stays plain (no collision; the Lucide hazard key is `alert-triangle`).

### 6. Full Lucide → Phosphor replacement
- **Decision**: Every remaining Lucide entry in `kDesignerIcons` was swapped to a Phosphor fill equivalent **under the same key** (e.g. `zap` → `PhosphorIconsFill.lightning`, `settings` → `gearSix`, `home` → `house`, `search` → `magnifyingGlass`), and `lucide_icons_flutter` was removed from `flutter-widgets` dependencies (the registry was its only consumer in the package).
- **Rationale**: A single stroke-weight family (Phosphor fill) across the whole registry gives visual consistency and drops a dependency. Keys are unchanged, so existing JSON configs and wire-format icon names keep resolving — the swap is purely a glyph change.
- **Mapping notes** (Lucide → Phosphor, no exact counterpart): `battery` → `batteryFull`, `music` → `musicNote`, `volume`/`speaker` → `speakerLow`/`speakerHigh`, `chevron-up`/`chevron-down` → `caretUp`/`caretDown`, `maximize-2`/`minimize-2` → `arrowsOut`/`arrowsIn`, `droplets` → `drop`, `alert-triangle` → `warning` (Phosphor's triangle glyph is `warning`; `warningTriangle` does not exist), `navigation`/`navigation-2` → `navigationArrow`, `refresh-ccw` → `arrowsCounterClockwise`.
- **Alternative considered**: Renaming keys to Phosphor names (`zap` → `lightning`) — rejected; it would break stored icon-name strings for zero functional gain.

## Risks / Trade-offs

- **Young dependency**: `phosphoricons_flutter` is 1.0.0, ~2 months old, single maintainer → Mitigation: it's a thin generated wrapper over the official Phosphor core (MIT); if it stalls, the vendored-TTF approach is the escape hatch. Only the fill weight is consumed.
- **App size**: Bundling the fill weight adds a font file to app and widget-library consumers → Mitigation: single weight only; tree-shaking-friendly `@staticIconProvider` annotations per package claims.
- **Visual change for 3 icons**: `bell`/`rewind`/`fast-forward` switch from Lucide stroke to Phosphor fill → Mitigation: verified zero usages in shipped configs and code; cosmetic difference only.

## Migration Plan

1. Add dependency to `flutter-widgets/pubspec.yaml`; delete `cupertino_icons` from `radiokit-app/pubspec.yaml`.
2. `flutter pub get` in `radiokit-app` (regenerates both lockfiles, pulls the new transitive dep).
3. Add registry entries; run `flutter analyze --fatal-warnings` and `flutter test`.
4. Rollback: revert the pubspec + registry edits and re-run `flutter pub get`; no data migration involved (icon names are additive strings).
