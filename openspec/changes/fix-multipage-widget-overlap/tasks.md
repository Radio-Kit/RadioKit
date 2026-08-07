## 1. WidgetConfig Data Model Updates

- [ ] 1.1 Add `final int pageIndex` property (default 0) to `WidgetConfig` in `lib/models/widget_config.dart`.
- [ ] 1.2 Include `"pageIndex"` in `WidgetConfig.toDesignerJsonMap()`.

## 2. Converter & Converter Standardization

- [ ] 2.1 Update `widgetConfigsToDesignerJson()` in `lib/models/widget_config.dart` to emit `version: 2` JSON with top-level `pages[]` array.
- [ ] 2.2 Group incoming `WidgetConfig`s by `pageIndex` into their respective page `widgets[]` arrays.

## 3. Demo Transport & State Sync Fixes

- [ ] 3.1 Update `DeviceProvider.sendSetPage()` to update `_activePage` immediately when transport is `DemoTransport` or `DemoFsTransport`.
- [ ] 3.2 Ensure `DeviceDesignerBridge` synchronizes `_designerState.setActivePage(deviceActivePage)` upon initialization and widget updates.

## 4. Verification & Testing

- [ ] 4.1 Run unit tests `flutter test test/multi_device_test.dart` and `flutter test test/json_arduino_generator_test.dart`.
- [ ] 4.2 Rebuild and deploy app APK to tablet via ADB (`flutter build apk --debug`).
- [ ] 4.3 Validate Remote Access API endpoints (`POST /api/page` and `GET /api/widgets`) to verify no widget overlap between Page 0 and Page 1.
