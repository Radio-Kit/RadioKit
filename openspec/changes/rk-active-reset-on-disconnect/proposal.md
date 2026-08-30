# Proposal: Reset rk.active on disconnect

## Problem

`rk.active` and `_lastInputMs` are never cleared when all transports disconnect.
If a client disconnects mid-touch, `rk.active` stays `true` indefinitely until a
new client connects and sends input. Firmware code reading `rk.active` (e.g.
steering wheel dynamic centering) would incorrectly think the user is still
interacting.

## Scope

Single file change: `rk-arduino/src/RadioKit.cpp`

## Change

In the `s_lastConnected` transition block (disconnect edge), clear all per-widget
active states:

```cpp
if (s_lastConnected && !nowConnected) {
    _deviceAuthenticated = (_nvsPwd[0] == '\0');
    _userAuthenticated = _deviceAuthenticated;
    // Reset all rk.active flags — no client is touching widgets anymore
    for (uint8_t i = 0; i < _widgetCount; i++) {
        _widgets[i]->setActive(false);
        _lastInputMs[i] = 0;
    }
}
```

## Verification

- Set `rk.active = true` on a widget via simulated VAR_UPDATE
- Disconnect transport
- Confirm `rk.active` is `false` and `_lastInputMs` is `0` for all widgets
