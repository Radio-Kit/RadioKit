# Technical Design: Dual State offIcon Support

## 1. Overview

This design defines how `offIcon` is represented in C++ structs, serialized into the `EXTRA` section of `CONF_DATA`, parsed by `radiokit-app`, and emitted by `JsonArduinoGenerator`.

## 2. Wire Protocol Serialization

In RadioKit descriptor frames (`CONF_DATA`), each widget descriptor begins with a bitmask byte.
- `RK_STR_ICON` (`1 << 3`): Transmits the primary icon (`onIcon`).
- `RK_STR_EXTRA` (`1 << 7`): Widget-specific extra binary payload.

### Extra Block Format for Button and Switch Widgets:
```
[total_extra_len: 1 byte]
  [off_icon_len: 1 byte]
  [off_icon_bytes: off_icon_len bytes]
```
- `total_extra_len` = `1 + off_icon_len`.
- If `offIcon` is null or empty, `RK_STR_EXTRA` is not set for `offIcon`.

## 3. C++ Firmware Structs

### `RK_ButtonFields` (`Button.h`):
```cpp
struct RK_ButtonFields {
    uint8_t     x = 0, y = 0;
    uint8_t     height = 10;
    uint8_t     width = 0;
    int16_t     rotation = 0;

    const char* icon    = nullptr; // onIcon
    const char* offIcon = nullptr; // offIcon
    const char* onText  = nullptr;
    const char* offText = nullptr;
    const char* label   = nullptr;

    bool        active = false;
    bool        state  = false;
};
```

### `RK_SlideSwitchFields` (`SlideSwitch.h`):
```cpp
struct RK_SlideSwitchFields {
    uint8_t     x = 0, y = 0;
    uint8_t     height = 10;
    uint8_t     width = 0;
    int16_t     rotation = 0;
    const char* icon    = nullptr; // onIcon
    const char* offIcon = nullptr; // offIcon
    uint8_t     variant = 0;
    const char* onText  = nullptr;
    const char* offText = nullptr;
    const char* label   = nullptr;
    bool        labelHidden = false;
    bool        active = false;
    bool        state = false;
};
```

## 4. Codegen Rules

In `JsonArduinoGenerator`:
- When `props['onIcon']` or `props['icon']` is non-empty: emit `$name.rk.icon = "$onIcon";`.
- When `props['offIcon']` is non-empty: emit `$name.rk.offIcon = "$offIcon";`.
