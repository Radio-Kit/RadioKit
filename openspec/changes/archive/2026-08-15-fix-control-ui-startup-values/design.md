# Design: Control UI Startup Values

## Context

Three related defects make the control UI's startup state wrong:

1. **Firmware boots every input widget at protocol value `0`** (= center of `[-100..100]`). For a gas pedal with spring-min this is the "pressed halfway" position — the app faithfully renders it, so the pedal looks stuck at center until the user touches it (which triggers the app-side spring to min).

2. **`_syncValues` skips `widgetId == 0`** (`device_designer_bridge.dart` line 132: `if (widgetId == 0) continue;`). The steering wheel is the first registered widget → widgetId 0 → its wire value is never applied. The definition fallback `?? 0.5` then kicks in, which is near-min in the `[0..100]` default value domain → wheel renders at min.

3. **Disabled autoCenter is lost in the wire round-trip.** `toDesignerJsonMap` computes `_acListForCentering(variantCentering(variant))` and removes the `autoCenter` key when position is `null`. `DesignerElement.fromJson` then seeds properties from `_defaultProperties(type)`, whose steering-wheel default is `['center', 'smooth', 500]` — so the control UI auto-centers the wheel even though the design says none.

## Decisions

### D1. Firmware owns the boot-time rest value

Each widget constructor sets the initial value to its spring rest position:

| Centering | Initial value |
|-----------|---------------|
| `RK_SPRING_NONE` | 0 |
| `RK_SPRING_CENTER` | 0 |
| `RK_SPRING_MIN` / `RK_SPRING_TOP` | -100 |
| `RK_SPRING_MAX` / `RK_SPRING_BOTTOM` | +100 |

- `RK_Slider`: value 0 (NONE) — unchanged.
- `RK_GasPedal`: `RK_SPRING_CENTER` constructor default is overridden by codegen to `RK_SPRING_MIN`; the pedal's rest value must be `-100`. Set `rk.value = -100` in the GasPedal constructor (codegen sets centering after construction, so the constructor's centering default is CENTER; the value should still be -100 for pedals since their design always springs to min).
- `RK_Knob`: value 0 — unchanged.
- `RK_SteeringWheel`: constructor sets `RK_SPRING_CENTER` → value 0 — unchanged, but codegen typically overrides to `RK_SPRING_NONE` for this design; either way rest is 0.
- `RK_Joystick`: center (0,0) — unchanged.

Only `RK_GasPedal` changes: initial `rk.value = -100`.

> Note: the gas pedal constructor currently defaults `rk.centering = RK_SPRING_CENTER` and the codegen line `gas_pedal.rk.centering = RK_SPRING_MIN` overrides it in `initRadioKit()`. Setting the constructor value to `-100` matches the documented GasPedal default `autoCenter: ['min', 'smooth', 300]` (AGENTS.md §3.3).

### D2. App syncs widgetId 0

Remove the `if (widgetId == 0) continue;` guard in `DeviceDesignerBridge._syncValues`. The subsequent `config.typeId == 0` check already skips elements without a wire config, so removing the widgetId guard is safe. Wire values for the first widget then flow into the designer state like all others.

### D3. Wire reconstruction always emits autoCenter

In `WidgetConfig.toDesignerJsonMap`, replace:

```dart
props['autoCenter'] = _acListForCentering(variantCentering(variant));
if (props['autoCenter'][0] == null) {
  props.remove('autoCenter');
}
```

with:

```dart
props['autoCenter'] = _acListForCentering(variantCentering(variant));
```

so the disabled form `[null, 'smooth', 300]` is always present. `DesignerElement.fromJson` then keeps it disabled instead of re-seeding the type default. This matches the designer's own `toJson`, which emits `autoCenter` whenever present (always, after `_mergeDefaults`).

### D4. Knob/steering definitions default to the value-domain center

In `KnobWidgetDefinition` and `SteeringWheelWidgetDefinition` (`slider_definitions.dart`), change:

```dart
value: ctx.runtimeValue as double? ?? 0.5,
```

to:

```dart
final wMin = (ctx.properties['min'] as num?)?.toDouble() ?? 0;
final wMax = (ctx.properties['max'] as num?)?.toDouble() ?? 100;
value: ctx.runtimeValue as double? ?? ((wMin + wMax) / 2),
```

`RKKnob` and `RKSteeringWheel` interpret the value in `[min..max]` domain, so the fallback must be the domain center — `0.5` is only correct when `min=0, max=1`.

## Out of scope

- Persisting widget values across reboots (NVS per-widget state) — a larger feature; this change only fixes the deterministic boot state.
- The Loco-page-only widgets (page gating) — already handled.
