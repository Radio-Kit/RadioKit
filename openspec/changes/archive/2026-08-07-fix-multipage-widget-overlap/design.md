## Context

In the RadioKit companion app, multi-page support was added to allow grouping widgets into separate pages (e.g. "Control", "Settings"). The Visual Designer exports a `version: 2` JSON configuration with a top-level `pages: [...]` array.

However, when a device sends its widget layout over the wire (or when demo mode initializes), `widgetConfigsToDesignerJson()` maps all received `WidgetConfig` items into a legacy `version: 1` flat JSON schema (`widgets: [...]`). As a result, `DesignerState.loadFromJson()` puts all widgets onto a single page ("Page 1"), causing widgets from different pages to overlap on top of each other.

Furthermore, no backward compatibility or transitionary support is needed (per project rules). All widget configuration conversion must standardize directly on `version: 2` JSON.

## Goals / Non-Goals

**Goals:**
- Add `pageIndex` property to `WidgetConfig` model and map it in wire decoding.
- Update `widgetConfigsToDesignerJson()` to output `version: 2` JSON format with top-level `pages: [...]`, grouping widgets by `pageIndex`.
- Synchronize `DesignerState.activePageIndex` with `DeviceProvider.activePage` on init and page changes.
- Ensure `DeviceProvider.sendSetPage()` updates `_activePage` immediately when running on demo/synthetic transports without waiting for a hardware packet echo.

**Non-Goals:**
- Backward compatibility for legacy `version: 1` output in `widgetConfigsToDesignerJson()`.
- Modifying binary frame protocol header structures.

## Decisions

### 1. `WidgetConfig` Page Index Property
- **Decision**: Add `final int pageIndex;` (default 0) to `WidgetConfig`.
- **Rationale**: Keeps `WidgetConfig` immutable while preserving the page placement assigned by the firmware or designer.

### 2. Standardize `widgetConfigsToDesignerJson()` on `version: 2`
- **Decision**: Group all `WidgetConfig` items by their `pageIndex` property and output a `pages: [...]` array instead of a flat `widgets: [...]` array.
- **Rationale**: Aligns `widgetConfigsToDesignerJson()` directly with the `version: 2` schema expected by `DesignerState`. Eliminates widget overlap on the Control UI canvas without needing ad-hoc UI filtering.

```dart
final pagesJson = <Map<String, dynamic>>[];
for (int i = 0; i < pageNames.length; i++) {
  final pageWidgets = widgets.where((w) => w.pageIndex == i).toList();
  pagesJson.add({
    'name': pageNames[i],
    'orientation': 'landscape',
    'widgets': pageWidgets.map((w) => w.toDesignerJsonMap(canvasW, canvasH)).toList(),
  });
}
```

### 3. Immediate Local Page Switch for Demo Transports
- **Decision**: In `DeviceProvider.sendSetPage()`, if the transport is `DemoTransport` or `DemoFsTransport`, update `_activePage = pageIndex` and notify listeners immediately.
- **Rationale**: Offline / synthetic transports do not send back `CMD_PAGE_CHANGED` packets. Immediate local state update ensures page switching works seamlessly in demo mode and via the Remote Access API.

## Risks / Trade-offs

- **[Widget ID Collisions]** → Ensure widget IDs remain globally unique across all pages in `version: 2` (covered by existing codegen and designer rules).
- **[Orientation Transitions]** → Switching pages with different orientations triggers a instant canvas resize pass (already handled by `ControlScreen._applyCanvasOrientation()`).

## Migration Plan

1. Update `WidgetConfig` model and `widgetConfigsToDesignerJson()` in `radiokit-app`.
2. Update `DeviceProvider.sendSetPage()` for demo transport mode.
3. Verify with unit tests (`multi_device_test.dart`, `json_arduino_generator_test.dart`) and live Remote API verification.
