## ADDED Requirements

### Requirement: Subsystem Reorganization
The library codebase SHALL be organized into modular subsystems under `src/core/` and `src/handlers/` while maintaining `RadioKitLib.h` as the unified top-level include header.

#### Scenario: Including RadioKitLib.h in an Arduino sketch
- **WHEN** an Arduino sketch includes `<RadioKitLib.h>`
- **THEN** all core structures, widget classes, and transport initializers compile cleanly without header path issues.
