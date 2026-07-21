# Proposal: Firmware-Controlled Widget Visibility + Per-Page Wire Protocol

## Summary

Enable firmware to show/hide widgets at runtime via `setHidden()` / `setLabelHidden()`, and optimize the wire protocol to send only the active page's visible widgets in CONF_DATA and VAR_DATA.

## Motivation

1. **Firmware control**: The `hidden` field exists on widgets but the app never syncs it from protocol to rendering. Firmware cannot dynamically adapt the UI.
2. **Bandwidth waste**: CONF_DATA and VAR_DATA currently send ALL widgets from ALL pages. Over BLE, this is wasteful. Per-page filtering reduces payload by ~70%.
3. **Hidden widgets on wire**: Hidden widgets still consume protocol bandwidth and app-side resources.

## Scope

- Firmware: filter CONF_DATA, VAR_DATA, META_DATA by active page + hidden flag
- Firmware: auto-rebuild CONF_DATA when hidden set changes
- App: render hidden widgets as invisible in both play and designer mode
- App: sync hidden state from WidgetConfig to DesignerElement on META_UPDATE
- No new protocol commands, no schema changes, no backward compatibility

## Success Criteria

- `rk.setHidden(true)` hides a widget from the app UI within one `update()` cycle
- `rk.setHidden(false)` shows it again, with current value restored
- CONF_DATA contains only active page widgets (visible count in header)
- VAR_DATA contains only active page values
- Hidden widgets are excluded from all wire payloads
- All existing tests pass, new tests cover hide/unhide flows
