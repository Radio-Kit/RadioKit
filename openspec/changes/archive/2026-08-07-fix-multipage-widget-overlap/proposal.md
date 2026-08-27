## Why

When connected to a multi-page device or loading a multi-page configuration, `widgetConfigsToDesignerJson()` flattens all widgets from all pages into a legacy `version: 1` flat JSON schema with a single `"widgets"` array. As a result, `DesignerState` loads all widgets onto a single page ("Page 1"), causing widgets from page 0 and page 1 to stack and overlap on the Control UI canvas.

Additionally, in offline/demo mode, `sendSetPage()` sends a binary command packet but never updates `_activePage` locally because no MCU exists to send back a `PAGE_CHANGED` echo packet.

We need to fix the multi-page data pipeline by embedding `pageIndex` in `WidgetConfig`, outputting standardized `version: 2` JSON with top-level `pages[]`, and ensuring page-aware filtering and seamless page switching in the Control UI without legacy backward compatibility logic.

## What Changes

- Add `pageIndex` property (default 0) to `WidgetConfig` in `lib/models/widget_config.dart`.
- Update `widgetConfigsToDesignerJson()` to output `version: 2` JSON containing top-level `pages[]` array with widgets grouped by `pageIndex`.
- Update `WidgetConfig.toDesignerJsonMap()` to include `"pageIndex"`.
- Update `DeviceProvider.sendSetPage()` to update `_activePage` locally when operating in demo/synthetic transport mode.
- Update `DeviceDesignerBridge` to guarantee that `DesignerState`'s active page is synced with `DeviceProvider.activePage` on initialization and updates.

## Capabilities

### New Capabilities
<!-- None -->

### Modified Capabilities
- `multi-page-app`: Require `widgetConfigsToDesignerJson()` to produce `version: 2` JSON format with `pages[]` so `DesignerState` renders only the active page's widgets without cross-page overlapping.

## Impact

- `lib/models/widget_config.dart`: `WidgetConfig` data model and `widgetConfigsToDesignerJson()` converter.
- `lib/widgets/device_designer_bridge.dart`: Initialization and page syncing bridge.
- `lib/providers/device_provider.dart`: `sendSetPage()` logic in demo transport mode.
- Unit and widget tests across `radiokit-app`.
