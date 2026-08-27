## 1. WidgetConfig Data Model Updates

- [x] 1.1 Add `final int pageIndex` property (default 0) to `WidgetConfig` in `lib/models/widget_config.dart`.
- [x] 1.2 Include `"pageIndex"` in `WidgetConfig.toDesignerJsonMap()`.

## 2. Converter & Converter Standardization

- [x] 2.1 Update `widgetConfigsToDesignerJson()` in `lib/models/widget_config.dart` to emit `version: 2` JSON with top-level `pages[]` array.
- [x] 2.2 Group incoming `WidgetConfig`s by `pageIndex` into their respective page `widgets[]` arrays.

## 3. Demo Transport & State Sync Fixes

- [x] 3.1 Update `DeviceProvider.sendSetPage()` to update `_activePage` immediately when transport is `DemoTransport` or `DemoFsTransport`.
- [x] 3.2 Ensure `DeviceDesignerBridge` synchronizes `_designerState.setActivePage(deviceActivePage)` upon initialization and widget updates.

## 4. Verification & Testing

- [x] 4.1 Run unit tests `flutter test test/multi_device_test.dart` and `flutter test test/json_arduino_generator_test.dart`.
- [x] 4.2 Rebuild and deploy app APK to tablet via ADB (`flutter build apk --debug`).
- [x] 4.3 Validate Remote Access API endpoints (`POST /api/page` and `GET /api/widgets`) to verify no widget overlap between Page 0 and Page 1.
