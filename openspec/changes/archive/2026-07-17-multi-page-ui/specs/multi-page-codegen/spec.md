## ADDED Requirements

### Requirement: Page-grouped widget declarations
The codegen SHALL group widget declarations by page with comment headers indicating page index and name.

#### Scenario: Codegen outputs page-grouped widgets
- **WHEN** the codegen processes a 3-page config
- **THEN** the output contains comment blocks: "// ─── Page 0: Controls ───", "// ─── Page 1: Telemetry ───", etc.
- **AND** each page's widgets are listed under its comment header

### Requirement: Global sequential widget names
The codegen SHALL assign global sequential names to widgets across all pages (btn_1, btn_2, led_3, etc.) without page prefixes.

#### Scenario: Widgets get unique global names
- **WHEN** Page 0 has btn_1 and slider_1, Page 1 has led_1
- **THEN** the generated names are btn_1, slider_2, led_3 (globally unique)

### Requirement: Page metadata defines
The codegen SHALL emit RK_NUM_PAGES define and rk_pageNames[] string array with all page names.

#### Scenario: Page metadata is emitted
- **WHEN** the codegen processes a config with 3 pages named "Controls", "Telemetry", "Settings"
- **THEN** the output contains "#define RK_NUM_PAGES 3" and "const char* rk_pageNames[] = { \"Controls\", \"Telemetry\", \"Settings\" };"

### Requirement: Page-aware setup block
The codegen SHALL emit setup code grouped by page in the initRadioKit() function.

#### Scenario: Setup block is page-grouped
- **WHEN** the codegen generates the setup block
- **THEN** widget setup code (labels, icons, hidden flags) is grouped under page comment headers
- **AND** page config (numPages, pageNames) is set before widget setup

### Requirement: Per-page orientation in codegen
The codegen SHALL emit orientation configuration per page when pages have different orientations.

#### Scenario: Mixed orientation pages
- **WHEN** Page 0 is landscape and Page 1 is portrait
- **THEN** the generated code includes orientation metadata for each page
