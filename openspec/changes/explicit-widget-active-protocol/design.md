## Context

In RadioKit, continuous input widgets (Steering Wheel, Knob, Slider, Joystick) allow users to control hardware actuators (servos, motors, PWM). Previously, the ESP32 firmware inferred `rk.active` solely by tracking when the last packet was received (`_lastInputMs`). If no packet arrived for 200ms (`RK_ACTIVE_RELEASE_MS`), it assumed touch had ended and set `rk.active = false`, causing auto-centering or failsafes to kick in while the user was still holding their finger on the glass.

By establishing an explicit interaction lifecycle with a dedicated `flags` byte in `VAR_UPDATE`, the app explicitly announces touch down, touch hold (via heartbeat), and touch release with zero release latency.

## Goals / Non-Goals

**Goals:**
- Add an explicit `FLAGS` byte (`kVarFlagActive = 0x01`) to `VAR_UPDATE` in the wire protocol.
- Wire interaction callbacks end-to-end in `flutter-widgets` through `WidgetBuildContext`, `CanvasElement`, `WidgetDefinition` instances, and `DesignerState`.
- Implement a ~60ms periodic keepalive stream in `DeviceDesignerBridge` for active widgets.
- Dispatch immediate `FLAGS = 0x00` packets upon touch release for instant auto-centering / release handling.
- Update `RadioKitClass` in `rk-arduino` to directly set `w->setActive(flags & RK_VAR_FLAG_ACTIVE)` and keep a 500ms safety watchdog for disconnects.

**Non-Goals:**
- Backward compatibility with legacy firmware protocols (clean slate approach as agreed).
- Modifying non-interactive display widgets.

## Decisions

### Decision 1: Explicit `FLAGS` Byte in `VAR_UPDATE` Frame
Instead of bitpacking into sequence number or inferring from timing, `VAR_UPDATE` payload is structured as:
`[PAGE_IF_PRESENT] [WIDGET_ID (1B)] [FLAGS (1B)] [VALUES (1..4B)]`
- Bit 0: `kVarFlagActive = 0x01` (1 = touching/active, 0 = released/inactive).
- *Rationale*: Clean, extensible, and self-documenting.

### Decision 2: Centralized Keepalive in `DeviceDesignerBridge`
Instead of duplicating `Timer.periodic` across every individual widget class in `flutter-widgets`, leaf widgets fire `onInteractionChanged(bool)` and `DeviceDesignerBridge` manages the heartbeat timer.
- *Rationale*: Eliminates timer leaks/duplicate code in leaf widgets, centralizes rate-limiting and BLE queue management in one bridge.

### Decision 3: 60ms Keepalive Interval with 500ms Firmware Watchdog
- Flutter streams packets every 60ms during active touch hold.
- Firmware watchdog is relaxed from 200ms to 500ms.
- *Rationale*: 60ms heartbeats comfortably tolerate 1–3 dropped BLE packets before the 500ms watchdog fires, preventing false releases while keeping radio bandwidth minimal (~16 packets/sec).

## Risks / Trade-offs

- **[Risk] Multiple widgets active simultaneously (e.g. dual joystick + button)** → *Mitigation*: `DeviceDesignerBridge` tracks active widget IDs in a set/map and maintains keepalive per active widget.
- **[Risk] BLE congestion during multi-touch** → *Mitigation*: 60ms per active widget is ~16 fps per widget, easily within BLE 4.2+ throughput capabilities.
- **[Risk] App crash or ungraceful exit while active** → *Mitigation*: Firmware 500ms watchdog safely clears `rk.active = false`.
