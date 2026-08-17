## ADDED Requirements

### Requirement: Firmware Item Visibility Masking
The `RadioKit_Multiple` class (and its derived classes `RK_MultipleButton` and `RK_MultipleSelect`) SHALL support an 8-bit item visibility mask (`itemMask`, defaulting to `0xFF`). The library SHALL provide methods to set the entire mask (`setItemMask(uint8_t mask)`) and to toggle or query visibility for individual item indices 0 through 7 (`setItemVisible(uint8_t index, bool visible)`, `setItemHidden(uint8_t index, bool hidden)`, `isItemVisible(uint8_t index)`). Mutating the item mask at runtime SHALL mark the configuration dirty (`RadioKitClass::markConfDirty()`).

#### Scenario: Setting item visibility mask marks configuration dirty
- **WHEN** user code calls `multi.setItemMask(0x0B)` or `multi.setItemHidden(2, true)`
- **THEN** the widget updates its `itemMask` to reflect the change
- **AND** the library marks `CONF_DATA` as dirty to trigger a configuration push to the client

### Requirement: Item Mask Serialization in CONF_DATA
When serializing string descriptors for `RadioKit_Multiple` in `CONF_DATA`, the widget SHALL include `RK_STR_EXTRA` (`1 << 7`) in the string mask byte and append an extra payload containing 1 byte specifying the extra length (`0x01`) followed by 1 byte containing the `itemMask`.

#### Scenario: Serializing Multiple widget with item mask
- **WHEN** `RadioKit_Multiple::serializeStrings()` is invoked on a widget with `itemMask = 0x0B`
- **THEN** bit 7 (`RK_STR_EXTRA`) is set in the string mask byte
- **AND** the trailing binary payload contains `[0x01, 0x0B]`

### Requirement: WidgetConfig Item Mask Parsing
The `WidgetConfig` class in `radiokit-app` SHALL parse `itemMask` when deserializing a `CONF_DATA` descriptor for `kWidgetMultiple` with `kStrMaskExtra` set. If `kStrMaskExtra` is not set, `itemMask` SHALL default to `0xFF`. `WidgetConfig.toDesignerJsonMap()` SHALL emit `properties['itemMask'] = itemMask`.

#### Scenario: Parsing CONF_DATA descriptor with itemMask
- **WHEN** `WidgetConfig.fromDescriptor` parses a `kWidgetMultiple` payload containing an extra block with value `0x0B`
- **THEN** `widgetConfig.itemMask` equals `0x0B`
- **AND** `widgetConfig.toDesignerJsonMap()` contains `'itemMask': 11` in `properties`

### Requirement: Dynamic Item Filtering in Flutter UI
The `RKMultiButton` and `RKMultiSelect` widgets SHALL accept an `itemMask` integer (default `0xFF`). In play mode, only items whose index bit is set in `itemMask` (`(itemMask & (1 << index)) != 0`) SHALL be rendered. The widget width/height SHALL dynamically calculate based on the number of visible items.

#### Scenario: Rendering RKMultiSelect with itemMask 0x0B
- **WHEN** `RKMultiSelect` with 8 items is rendered with `itemMask = 0x0B` (`0b00001011`)
- **THEN** only items at indices 0, 1, and 3 are rendered in the button group
- **AND** the widget width is scaled for 3 buttons instead of 8

#### Scenario: Tapping filtered item maintains bit position contract
- **WHEN** the user taps the 3rd rendered button (which corresponds to original index 3) in `RKMultiSelect`
- **THEN** `onChanged` is called with bit 3 (`1 << 3` / `0x08`) toggled in the resulting bitmask
