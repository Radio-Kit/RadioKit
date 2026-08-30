## Why

Continuous input widgets (such as Steering Wheel, Knob, Slider, and Joystick) lose their `rk.active = true` state on the ESP32 when the user holds their finger motionless, because Flutter's gesture recognizers emit zero packets when position delta is zero. After 200ms of packet silence, firmware clears `rk.active = false`, causing auto-centering or failsafes to trigger while the user is still touching the screen.

Furthermore, touch state on firmware was previously inferred implicitly from packet frequency rather than being explicitly communicated over the wire protocol. Moving `active` into the protocol creates an explicit, deterministic contract between touch gestures on Flutter and widget state in firmware.

## What Changes

- **Explicit Protocol Flag in `VAR_UPDATE`**: Add an explicit `flags` byte (`0x01 = ACTIVE`) to the `VAR_UPDATE` (0x08) wire protocol payload: `[WIDGET_ID(1B)] [FLAGS(1B)] [VALUES(1..4B)]`.
- **Flutter Widget Tree Interaction Plumbing**: 
  - Add `onInteractionChanged` to `WidgetBuildContext`.
  - Pass `onInteractionChanged` through `CanvasElement` and all continuous/interactive `WidgetDefinition` instances (`SteeringWheel`, `Knob`, `Slider`, `Joystick`, `Button`, `SlideSwitch`, `RockerSwitch`).
  - Wire `DesignerState.onRuntimeInteractionChanged` to propagate interaction state.
- **Bridge-Level Interaction Keepalive & Release Pulse**:
  - In `DeviceDesignerBridge`, when a widget becomes active (`onInteractionChanged(true)`), start a periodic heartbeat timer (~60ms) that streams the current value with `flags = 0x01` (`kVarFlagActive`).
  - When the user lifts their finger (`onInteractionChanged(false)`), immediately cancel the timer and dispatch a single `VAR_UPDATE` with `flags = 0x00` for 0ms release latency.
- **Firmware Direct Active Handling (`rk-arduino`)**:
  - In `RadioKitClass::_handleVarUpdate`, decode `flags` and call `w->setActive(flags & RK_VAR_FLAG_ACTIVE)`.
  - Keep a safety watchdog timeout (500ms) on firmware to reset `rk.active = false` only in the event of dropped Bluetooth connection or app termination.

## Capabilities

### New Capabilities
- `explicit-widget-active-protocol`: Defines the wire protocol frame format, Flutter interaction pipeline, keepalive heartbeats, and firmware active state tracking.

### Modified Capabilities
<!-- None -->

## Impact

- **Wire Protocol**: `VAR_UPDATE` format includes `flags` byte between `widgetId` and values.
- **`flutter-widgets`**: `WidgetBuildContext`, `CanvasElement`, `DesignerState`, and widget definitions updated.
- **`radiokit-app`**: `ProtocolService`, `DeviceDesignerBridge`, and `DeviceProvider` updated.
- **`rk-arduino`**: `RadioKitClass` and `Widget` active handling updated.
