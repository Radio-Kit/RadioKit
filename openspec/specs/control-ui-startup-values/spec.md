# control-ui-startup-values Specification

## Purpose

Input widgets render their spring/centering rest position on boot: pedals rest at min, center-spring widgets at neutral, and the first widget (widgetId 0) is never skipped during value sync. Disabled auto-center survives the wire round-trip, and knob/steering defaults to the center of their value domain before any runtime value arrives.

## Requirements

### Requirement: Boot-time widget rest values

The system SHALL initialize each input widget's value to its spring/centering rest position at construction:

- `RK_SPRING_MIN` (or TOP) → `-100`
- `RK_SPRING_MAX` (or BOTTOM) → `+100`
- `RK_SPRING_CENTER` → `0`
- `RK_SPRING_NONE` → `0`

This applies to `RK_Slider`, `RK_Knob`, `RK_GasPedal`, `RK_SteeringWheel`, and `RK_Joystick`.

#### Scenario: Fresh boot reports pedal at rest

- **WHEN** a gas pedal configured with spring-min boots on the device
- **THEN** the wire VAR_DATA reports `-100` for that pedal (not `0`), so the control UI renders it at the released (min) position

#### Scenario: Center-spring widgets boot at neutral

- **WHEN** a widget with `RK_SPRING_CENTER` or `RK_SPRING_NONE` boots
- **THEN** its wire value is `0`, so the control UI renders it at the neutral/center position

### Requirement: Wire value sync must include widgetId 0

The control UI value sync (`_syncValues` in `DeviceDesignerBridge`) SHALL NOT skip `widgetId == 0`. The first registered widget (e.g. the steering wheel) SHALL receive its wire value like every other widget.

#### Scenario: Steering wheel synced from wire

- **WHEN** a device whose first widget is a steering wheel (widgetId 0) connects and VAR_DATA reports value `0` for it
- **THEN** the control UI renders the wheel at the center (straight ahead) position, not the min position

### Requirement: AutoCenter disabled must survive the wire round-trip

The wire reconstruction (`toDesignerJsonMap`) SHALL emit `autoCenter` explicitly — including the disabled form `[null, 'smooth', 300]` — instead of removing the key when the position is null. This SHALL prevent `DesignerElement.fromJson`'s definition-default seeding from re-enabling auto-center for types whose default is enabled (e.g. steering wheel `['center', 'smooth', 500]`).

#### Scenario: Steering with autoCenter none does not auto-center

- **WHEN** a saved design has `steering_wheel.autoCenter: [null, 'smooth', 500]` and the control UI connects to the flashed device
- **THEN** the steering wheel stays where the user left it on release instead of springing back to center

#### Scenario: Disabled autoCenter appears in reconstructed JSON

- **WHEN** a widget's wire variant encodes centering `NONE` and is converted to designer JSON
- **THEN** the reconstructed JSON contains `autoCenter: [null, 'smooth', 300]` (or the type's disabled form) rather than omitting the key

### Requirement: Knob/steering default value is center

The knob and steering-wheel widget definitions SHALL default to the center of their value domain (`(min + max) / 2`) when no runtime value has been received, instead of a literal `0.5` which is near-min for `[0..100]`.

#### Scenario: Steering renders centered before first VAR_DATA

- **WHEN** a steering wheel with `min: -100, max: 100` renders before any wire value arrives
- **THEN** the wheel points straight ahead (value `0`, not `0.5`)

#### Scenario: Knob default is domain center

- **WHEN** a knob with `min: 0, max: 100` renders without a runtime value
- **THEN** its value defaults to `50`, not `0.5`
