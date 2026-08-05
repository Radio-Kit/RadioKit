## Why

Adding new widgets, screens, or features currently requires modifying multiple centralized, monolithic files across both `flutter-widgets` and `radiokit-app` (e.g. `DesignerElementType` enum, `canvas_element.dart`, `designer_inspector.dart`, `json_arduino_generator.dart`, and `router.dart`). This violates the Open-Closed Principle and makes codebase maintenance fragile and error-prone as the library grows. Refactoring to a modular plugin architecture allows new widgets and screens to be added by dropping in self-contained definition modules without touching existing core code.

## What Changes

- Introduce a `WidgetDefinition` interface and `WidgetRegistry` in `flutter-widgets` to decouple widget rendering, sizing, property schema, and code generation from hardcoded enums and switch statements.
- Replace the 82.5 KB monolithic `designer_inspector.dart` with a schema-driven inspector engine that auto-renders property controls from widget definition schemas.
- Refactor `CanvasElement` to resolve and render widgets dynamically via `WidgetRegistry`.
- Refactor `JsonArduinoGenerator` to delegate C++ code snippet generation to individual widget definitions.
- Introduce a `FeatureModule` registry for `radiokit-app` to allow self-registering screens, navigation items, and dev-tool tabs.

## Capabilities

### New Capabilities

- `widget-registry`: Plugin architecture and self-contained widget definitions for visual designer and runtime canvas.
- `schema-driven-inspector`: Schema-driven property descriptors for auto-generating designer property inspector UI controls.
- `modular-codegen`: Modular C++ code generation delegated to widget definitions instead of centralized switch cases.
- `feature-modules`: Modular screen and tab registration system for app navigation and devtools.

### Modified Capabilities

<!-- No requirement level changes to existing user-facing features -->

## Impact

- `flutter-widgets`:
  - `lib/src/models/designer_element.dart`: Refactored to work with dynamic widget definitions alongside legacy enum fallback.
  - `lib/src/canvas/canvas_element.dart`: Uses `WidgetRegistry` lookups.
  - `lib/src/widgets/`: Widget definitions co-located with widget UI implementations.
- `radiokit-app`:
  - `lib/screens/designer/widgets/designer_inspector.dart`: Refactored into schema-driven inspector panel.
  - `lib/screens/designer/codegen/json_arduino_generator.dart`: Delegates codegen to registered widget definitions.
  - `lib/router.dart` and `lib/screens/home_screen.dart`: Configured to dynamically load registered `FeatureModule` routes and tabs.
