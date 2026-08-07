## MODIFIED Requirements

### Requirement: Page-aware setup block
The codegen SHALL emit setup code grouped by page in the initRadioKit() function. Each sub-generator SHALL emit a `setPage(pageIndex)` call when the widget belongs to a page other than page 0.

#### Scenario: Setup block is page-grouped
- **WHEN** the codegen generates the setup block
- **THEN** widget setup code (labels, icons, hidden flags) is grouped under page comment headers
- **AND** page config (numPages, pageNames) is set before widget setup

#### Scenario: Sub-generators emit setPage for non-zero pages
- **WHEN** a widget is on page 1 or higher
- **THEN** the generated setup code includes `widget_name.rk.page = pageIndex;`
- **AND** the emission is skipped when pageIndex is 0 (default page)
