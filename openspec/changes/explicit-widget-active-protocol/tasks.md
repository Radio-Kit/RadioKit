## 1. Protocol Definitions

- [x] 1.1 Add `kVarFlagActive` (0x01) and update `buildVarUpdate` in `radiokit-app/lib/services/protocol_service.dart` and `radiokit-app/lib/models/protocol.dart`
- [x] 1.2 Update `RadioKitClass::_handleVarUpdate` in `rk-arduino/src/RadioKit.cpp` and `RadioKitClass.h` to decode `flags` byte and handle `setActive(active)`

## 2. Flutter Widgets Interaction Plumbing

- [x] 2.1 Add `onInteractionChanged` callback to `WidgetBuildContext` in `flutter-widgets/lib/src/models/widget_definition.dart`
- [x] 2.2 Update `CanvasElement` in `flutter-widgets/lib/src/canvas/canvas_element.dart` to pass interaction callback to definitions
- [x] 2.3 Add `onRuntimeInteractionChanged`, `setRuntimeWidgetInteracting`, and tracking in `flutter-widgets/lib/src/models/designer_state.dart`
- [x] 2.4 Wire `onInteractionChanged` in `SteeringWheelWidgetDefinition`, `KnobWidgetDefinition`, `SliderWidgetDefinition`, `JoystickWidgetDefinition`, and `ButtonWidgetDefinition`

## 3. App Bridge Keepalive & Release Dispatch

- [x] 3.1 Update `DeviceDesignerBridge` in `radiokit-app/lib/widgets/device_designer_bridge.dart` to listen to `onRuntimeInteractionChanged`
- [x] 3.2 Implement periodic keepalive timer (~60ms) while active and immediate release packet (`flags = 0x00`) on interaction end
- [x] 3.3 Update `DeviceProvider.setInputValue` to support explicit `active` parameter and forward to `ProtocolService`

## 4. Firmware Safety Watchdog & Testing

- [x] 4.1 Update `RadioKit.cpp` loop to use 500ms safety watchdog for clearing `rk.active` if connection drops
- [x] 4.2 Verify and test compilation across `flutter-widgets`, `radiokit-app`, and `rk-arduino`
