# button-switch-off-icon Specification

## Purpose

Support dual-state icons (`icon` and `offIcon`) for Push/Toggle Buttons and Rocker/Slide Switch widgets across C++ firmware fields, wire protocol serialization, companion app deserialization, and C++ codegen.

## Requirements

### Requirement: C++ Firmware Field Support
The C++ library MUST provide `const char* offIcon = nullptr;` on `RK_ButtonFields` and `RK_SlideSwitchFields`.

### Requirement: Wire Protocol Transmission
When `offIcon` is non-null and non-empty on a Button or SlideSwitch, `serializeStrings()` MUST set `RK_STR_EXTRA` and encode `[1 + len][len][...bytes]`.

### Requirement: App Protocol Deserialization
`ProtocolService` and `WidgetConfig` MUST parse `offIcon` from the `EXTRA` payload of `kWidgetButton`, `kWidgetSwitch`, and `kWidgetSlideSwitch` descriptors and propagate it to `properties['offIcon']`.

### Requirement: Codegen Emission
`JsonArduinoGenerator` and `WidgetTemplates` MUST emit `$name.rk.offIcon = "$offIcon";` whenever `offIcon` is configured.
