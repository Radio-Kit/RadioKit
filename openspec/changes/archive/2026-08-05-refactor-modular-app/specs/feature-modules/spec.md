## ADDED Requirements

### Requirement: Modular Screen and Feature Module Registration
The application router and main shell SHALL build routes and sidebar navigation items dynamically from registered `FeatureModule` instances.

#### Scenario: Registering a new application feature module
- **WHEN** a `FeatureModule` is registered in `ModuleRegistry`
- **THEN** its route is added to `GoRouter` and its tab icon and label are rendered in `HomeScreen` navigation controls.
