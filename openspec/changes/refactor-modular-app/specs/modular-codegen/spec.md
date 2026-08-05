## ADDED Requirements

### Requirement: Delegated C++ Code Generation
The Arduino code generator SHALL delegate widget initialization and setup code generation to the `WidgetDefinition.generateCppCode()` implementation for each widget.

#### Scenario: Exporting Arduino RADIOKIT.h header
- **WHEN** the user generates Arduino C++ header output for a design configuration
- **THEN** `JsonArduinoGenerator` iterates over design elements and invokes `WidgetDefinition.generateCppCode()` for each element, producing complete C++ setup code.
