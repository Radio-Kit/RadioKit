## Context

Currently, `radiokit-app` and `flutter-widgets` rely on centralized switch statements and a closed `DesignerElementType` enum. Adding a single new widget requires editing 9 different locations across both packages (`designer_element.dart`, `canvas_element.dart`, `designer_inspector.dart`, `json_arduino_generator.dart`, palette dialogs, etc.). `designer_inspector.dart` has grown into an 82.5 KB monolith file.

This refactoring introduces a plugin-oriented architecture using a central `WidgetRegistry` and `FeatureModuleRegistry` to make widget creation, inspector rendering, code generation, and screen routing modular and self-contained.

## Goals / Non-Goals

**Goals:**
- Enable plug-and-play widget registration via a `WidgetDefinition` interface in `flutter-widgets`.
- Refactor `CanvasElement` to render widgets dynamically using `WidgetRegistry`.
- Replace manual inspector field logic in `designer_inspector.dart` with a schema-driven inspector builder.
- Refactor C++ code generation in `json_arduino_generator.dart` to delegate code snippet creation to `WidgetDefinition`.
- Introduce a modular `FeatureModule` registry for `radiokit-app` routing and sidebar tab navigation.
- Ensure 100% backward compatibility with existing saved JSON design configs and C++ codegen headers.

**Non-Goals:**
- Changing existing widget visual aesthetics or UI design system tokens (`RKTokens`).
- Changing the protocol frame format (0xAA frame specification).
- Re-architecting Arduino C++ library runtime logic.

## Decisions

### 1. `WidgetDefinition` Registry Pattern
- **Decision**: Create an abstract `WidgetDefinition` class in `flutter-widgets/lib/src/models/widget_definition.dart` and a singleton `WidgetRegistry`. Each widget implements its own definition class co-located with its UI component.
- **Alternatives Considered**:
  - *Keep enum + extension methods*: Still requires modifying core enum files for every new widget.
  - *Dynamic JSON-only schema definitions*: Harder to provide rich custom Flutter UI rendering for complex widgets (like SteeringWheel or Joystick).
- **Rationale**: `WidgetDefinition` provides maximum flexibility by combining static schema properties (for inspector controls) with custom Flutter widget builders (for live canvas).

### 2. Schema-Driven Inspector Engine
- **Decision**: Define `InspectorPropertySchema` types (`NumPropertySchema`, `BoolPropertySchema`, `OptionPropertySchema`, `IconPropertySchema`, `ListPropertySchema`). `designer_inspector.dart` will iterate over `definition.propertiesSchema` and render standard `InspectorFieldBuilders`.
- **Rationale**: Reduces `designer_inspector.dart` from an 82.5 KB monolith to a ~5 KB generic property editor shell.

### 3. Modular Code Generation
- **Decision**: Each `WidgetDefinition` exposes `String generateCppCode(CodegenContext ctx)` that returns the initialization and property assignments for C++ code output.
- **Rationale**: Keeps C++ code output logic next to the widget definition rather than inside a centralized 20 KB generator switch statement.

### 4. `FeatureModule` Navigation Registry
- **Decision**: `radiokit-app` will use a `ModuleRegistry` containing `FeatureModule` definitions. `router.dart` and `HomeScreen` build `GoRoute` entries and navigation sidebar items dynamically from the registry.

## Risks / Trade-offs

- **[Risk] Backward Compatibility with Legacy JSON Configs** → *Mitigation*: Ensure `WidgetRegistry` resolves legacy string/enum keys (e.g. `'button'`, `'slideSwitch'`) seamlessly and falls back to default definitions.
- **[Risk] Performance of Dynamic Inspector Schema Rendering** → *Mitigation*: Memoize property schema lists on widget definition instances.

## Migration Plan

1. Create `WidgetDefinition` & `WidgetRegistry` in `flutter-widgets`.
2. Wrap existing 13 widget types in self-contained `WidgetDefinition` classes.
3. Update `CanvasElement` to use `WidgetRegistry`.
4. Refactor `designer_inspector.dart` to consume `propertiesSchema`.
5. Refactor `json_arduino_generator.dart` to delegate to `WidgetDefinition.generateCppCode()`.
6. Implement `FeatureModule` registry in `radiokit-app`.
7. Verify all tests and existing demo configs load, display, edit, and export correctly.
