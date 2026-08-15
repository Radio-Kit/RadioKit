## Context

The Models tab currently contains a legacy `_InteractiveDemoSection` with placeholder mock devices (`WIDGETS_DEMO`, `RC_CONTROLLER`, `IOT_DASHBOARD`, `MULTI_PAGE`). This section was guarded by an `ENABLE_DEMO` toggle in `SystemTab` and `SettingsProvider.showDemo`. 

RadioKit already includes a rich set of starter templates loaded via `StarterTemplate` from `assets/starter-templates/` and rendered in `DesignsTab` with `StarterTemplatesSection`. We want to leverage these starter templates on the `ModelsTab` as onboarding content when no paired devices are present, allowing immediate exploration and interactive preview in the Designer.

## Goals / Non-Goals

**Goals:**
- Display `STARTER_TEMPLATES` section on the Models tab when the user has no paired devices.
- On tapping any template card, open the Designer with the template loaded in play mode.
- Completely remove `_InteractiveDemoSection`, `_DemoTile`, and related `connectDemo` UI calls from `models_tab.dart`.
- Remove the `ENABLE_DEMO` switch from `system_tab.dart` and `showDemo` state from `SettingsProvider` and `RemoteAccessService`.

**Non-Goals:**
- Changing how starter templates are parsed or edited in `DesignsTab` or `StarterTemplatesSection`.
- Changing how actual paired hardware models connect or operate.

## Decisions

1. **Section Header**: Use `STARTER_TEMPLATES` as the section header tag on the Models tab.
2. **Conditional Rendering**: In `models_tab.dart`, evaluate whether paired models exist. If `pairedDevices.isEmpty`, render `StarterTemplatesSection`.
3. **Card Tap Navigation**: Use existing `StarterTemplatesSection` routing logic (`context.push('/designer', extra: {...})`) to open the design in interactive play mode.
4. **Clean Removal**: Delete `showDemo` completely from `SettingsProvider` without deprecated aliases or fallback toggles.

## Risks / Trade-offs

- [Risk] Missing paired devices if device list filter state is slow to hydrate.
  → Mitigation: `HistoryProvider.pairedDevices` is synchronously loaded from SharedPreferences at startup.
