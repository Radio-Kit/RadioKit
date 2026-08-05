## 1. WidgetRegistry Foundation (`flutter-widgets`)

- [x] 1.1 Create `WidgetDefinition` abstract interface and `InspectorPropertySchema` model classes in `flutter-widgets/lib/src/models/`.
- [x] 1.2 Implement `WidgetRegistry` singleton with registration, lookup, and fallback mapping logic for legacy string identifiers.
- [x] 1.3 Implement `WidgetDefinition` instances for core button widgets (`RKButton`, `RKSlideSwitch`, `RKRockerSwitch`).
- [x] 1.4 Implement `WidgetDefinition` instances for slider and knob widgets (`RKSlider`, `RKKnob`, `RKSteeringWheel`, `RKGasPedal`).
- [x] 1.5 Implement `WidgetDefinition` instances for multi & display widgets (`RKJoystick`, `RKMultiButton`, `RKMultiSelect`, `RKLed`, `RKText`, `RKSerialMonitor`).

## 2. Dynamic Canvas Rendering (`flutter-widgets`)

- [x] 2.1 Refactor `CanvasElement._buildWidget` in `canvas_element.dart` to delegate rendering to `WidgetRegistry.get(type).buildCanvasWidget()`.
- [x] 2.2 Refactor `DesignerElement` sizing and property mapping to query `WidgetRegistry` for defaults instead of monolithic switch cases.

## 3. Schema-Driven Inspector Engine (`radiokit-app`)

- [x] 3.1 Create generic schema-based inspector panel builder in `radiokit-app/lib/screens/designer/widgets/designer_inspector.dart`.
- [x] 3.2 Wire schema-driven field rendering to `InspectorFieldBuilders` for numeric, boolean, option, and icon properties.
- [x] 3.3 Verify property updates propagate state and trigger live canvas redrawing correctly.

## 4. Modular Code Generation (`radiokit-app`)

- [x] 4.1 Update `JsonArduinoGenerator` to delegate widget setup code generation to `WidgetDefinition.generateCppCode()`.
- [x] 4.2 Validate generated C++ header outputs (`RADIOKIT.h`) against baseline tests.

## 5. Feature Module System (`radiokit-app`)

- [x] 5.1 Implement `FeatureModule` interface and `ModuleRegistry` in `radiokit-app/lib/services/`.
- [x] 5.2 Refactor `router.dart` and `HomeScreen` navigation to dynamically load registered feature routes and navigation sidebar items.

## 6. Verification and Regression Testing

- [x] 6.1 Run widget rendering and designer unit/widget tests in `flutter-widgets` and `radiokit-app`.
- [x] 6.2 Load existing JSON demo templates to confirm 100% backward compatibility.
