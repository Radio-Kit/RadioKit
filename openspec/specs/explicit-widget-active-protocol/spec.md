# explicit-widget-active-protocol Specification

## Purpose
TBD - created by archiving change explicit-widget-active-protocol. Update Purpose after archive.
## Requirements
### Requirement: Explicit Active Flag in Protocol
The `VAR_UPDATE` wire packet (command `0x08`) SHALL include an explicit `flags` byte immediately following the `widgetId` byte: `[PAGE_IF_PRESENT] [WIDGET_ID (1B)] [FLAGS (1B)] [VALUES (1..4B)]`. Bit 0 (`0x01`) of `FLAGS` SHALL indicate the active interaction state (`1 = ACTIVE`, `0 = INACTIVE`).

#### Scenario: Active touch update packet
- **WHEN** user interacts with an input widget (e.g. knob, steering wheel, slider, joystick, button)
- **THEN** Flutter app sends `VAR_UPDATE` with `FLAGS` having bit 0 set (`0x01`)

#### Scenario: Inactive touch release packet
- **WHEN** user lifts their finger or ends interaction
- **THEN** Flutter app immediately sends a `VAR_UPDATE` packet with `FLAGS` having bit 0 cleared (`0x00`)

### Requirement: Flutter Interaction Callback Pipeline
The `flutter-widgets` library SHALL propagate interaction lifecycle events (`onInteractionChanged`) from leaf input controls through `WidgetBuildContext`, `CanvasElement`, and `DesignerState` to runtime consumers.

#### Scenario: User touches steering wheel or knob
- **WHEN** user begins dragging a steering wheel or knob
- **THEN** the widget fires `onInteractionChanged(true)`, which triggers `DesignerState.onRuntimeInteractionChanged(elementId, true)`

#### Scenario: User releases steering wheel or knob
- **WHEN** user finishes dragging or cancels gesture
- **THEN** the widget fires `onInteractionChanged(false)`, which triggers `DesignerState.onRuntimeInteractionChanged(elementId, false)`

### Requirement: Bridge Periodic Touch Keepalive Stream
The `DeviceDesignerBridge` in `radiokit-app` SHALL maintain a periodic keepalive timer (~60ms) for any currently active widget to ensure continuous `VAR_UPDATE` transmission while the finger remains stationary.

#### Scenario: Holding stationary touch on continuous widget
- **WHEN** user holds their finger still on an active steering wheel, slider, knob, or joystick
- **THEN** `DeviceDesignerBridge` periodically transmits `VAR_UPDATE` with `flags = 0x01` and the current value every 60ms

#### Scenario: Releasing touch on continuous widget
- **WHEN** user releases their finger
- **THEN** `DeviceDesignerBridge` cancels the keepalive timer and transmits an immediate `VAR_UPDATE` with `flags = 0x00`

### Requirement: Firmware Explicit Active Tracking and Safety Watchdog
The `RadioKitClass` in `rk-arduino` SHALL decode the `flags` byte in `VAR_UPDATE` and directly update the target widget's `setActive(bool)` state without waiting for timeout on release. It SHALL also maintain a 500ms failsafe watchdog to reset `active` to `false` if connection is abruptly lost.

#### Scenario: Receiving active packet on MCU
- **WHEN** `RadioKitClass` receives `VAR_UPDATE` with `FLAGS & 0x01 != 0`
- **THEN** it sets `widget->setActive(true)` and updates `_lastInputMs[widgetId] = millis()`

#### Scenario: Receiving inactive packet on MCU
- **WHEN** `RadioKitClass` receives `VAR_UPDATE` with `FLAGS & 0x01 == 0`
- **THEN** it immediately sets `widget->setActive(false)` and resets `_lastInputMs[widgetId] = 0`

#### Scenario: Failsafe disconnect timeout on MCU
- **WHEN** a widget is active (`w->active() == true`) but no packet is received for > 500ms
- **THEN** `RadioKitClass` clears `widget->setActive(false)` and resets `_lastInputMs[widgetId] = 0`

