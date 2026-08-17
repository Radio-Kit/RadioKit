# Specification: Dual State offIcon for Button and Switch Widgets

## Requirements

### Requirement 1: C++ Firmware Field Support
The C++ library MUST provide `const char* offIcon = nullptr;` on `RK_ButtonFields` and `RK_SlideSwitchFields`.

### Requirement 2: Wire Protocol Transmission
When `offIcon` is non-null and non-empty on a Button or SlideSwitch, `serializeStrings()` MUST set `RK_STR_EXTRA` and encode `[1 + len][len][...bytes]`.

### Requirement 3: App Protocol Deserialization
`ProtocolService` and `WidgetConfig` MUST parse `offIcon` from the `EXTRA` payload of `kWidgetButton`, `kWidgetSwitch`, and `kWidgetSlideSwitch` descriptors and propagate it to `properties['offIcon']`.

### Requirement 4: Codegen Emission
`JsonArduinoGenerator` and `WidgetTemplates` MUST emit `$name.rk.offIcon = "$offIcon";` whenever `offIcon` is configured.
