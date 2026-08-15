## Why

The legacy `INTERACTIVE_DEMO` section on the Models tab relies on simulated device connection mocks (`WIDGETS_DEMO`, `RC_CONTROLLER`, etc.) that are obsolete and unhelpful. RadioKit already provides rich bundled **Starter Templates** (e.g., Locomotive Remote, RC Car, Drone) that showcase full UI capabilities and let users immediately preview and customize interfaces.

Replacing the legacy interactive demo with Starter Templates when no paired models exist provides a cleaner onboarding experience and allows new users to instantly explore real UI layouts.

## What Changes

- **Models Tab (`models_tab.dart`)**:
  - Remove `_InteractiveDemoSection` and `_DemoTile`.
  - Display `STARTER_TEMPLATES` section when there are no paired models.
  - Tapping a starter template opens its UI in the Designer play mode preview.
- **Settings & Provider Cleanup**:
  - Remove `ENABLE_DEMO` toggle in `system_tab.dart`.
  - Remove `showDemo` property and methods from `SettingsProvider`.
  - Remove `showDemo` endpoints/fields from `RemoteAccessService`.
- **Zero Backward Compatibility**: No fallback flags or transition shims.

## Capabilities

### New Capabilities
- `starter-templates-home`: Displays starter templates on the Models tab when no paired devices exist and navigates to the Designer preview on tap.

### Modified Capabilities
<!-- None -->

## Impact

- `radiokit-app/lib/screens/home/models_tab.dart`
- `radiokit-app/lib/screens/home/system_tab.dart`
- `radiokit-app/lib/providers/settings_provider.dart`
- `radiokit-app/lib/services/remote_access_service.dart`
- `radiokit-app/assets/skills/llms.txt`
