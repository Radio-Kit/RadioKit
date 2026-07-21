# Design: Firmware-Controlled Widget Visibility + Per-Page Wire Protocol

## Architecture

### Wire Protocol Change

**Before:**
```
CONF_DATA: [orientation][numWidgets=ALL][activePage][numPages][theme][w0][w1]...[wN]
VAR_DATA:  [all widget values]
```

**After:**
```
CONF_DATA: [orientation][numWidgets=ACTIVE_PAGE_VISIBLE][activePage][numPages][theme][w0][w1]...
VAR_DATA:  [active page visible values only]
```

`numWidgets` in the header is now the count of non-hidden widgets on the active page. The app already reads this count and iterates — no parser change needed.

### Hidden Widget Exclusion

Hidden widgets are completely excluded from:
- `CONF_DATA` — app never creates a WidgetConfig
- `VAR_DATA` — no value updates sent or received
- `META_DATA` — no metadata sent
- `update()` change detection — no shadow comparison
- `_handleSetInput` — no incoming value deserialization

### Auto-Rebuild on Visibility Change

When `setHidden()` or `setLabelHidden()` is called:
1. Widget's `_hidden` / `_labelHidden` flag is set
2. `_confDirty = true` is set on the RadioKitClass
3. On next `update()` cycle, `_confDirty` triggers:
   - `_handleGetConf()` — sends fresh CONF_DATA (widget excluded/included)
   - `_handleGetVars()` — sends fresh VAR_DATA (widget excluded/included)
   - `_confDirty = false`

### App-Side Rendering

- `CanvasElement`: `if (element.hidden) return SizedBox.shrink();` — both play and designer mode
- `DesignerState`: new `setElementHidden(String id, bool hidden)` — no undo push (firmware-driven)
- `DeviceDesignerBridge._syncValues()`: sync `WidgetConfig.hidden` → `DesignerElement.hidden`

## Firmware Changes

### RadioKitClass.h

```cpp
// New field
bool _confDirty = false;

// setActivePage clears _confDirty (it sends its own CONF_DATA)
void setActivePage(uint8_t page) {
    // ... existing code ...
    _confDirty = false;  // page switch sends fresh CONF_DATA
}
```

### Widget.h — setHidden / setLabelHidden

```cpp
void setHidden(bool h) {
    _hidden = h;
    // Access _confDirty via RadioKit instance (friend or global)
    // Implementation: set a bit in a dirty mask, or direct flag
}
```

Note: Widget needs access to RadioKitClass's `_confDirty`. Options:
- Make Widget a friend of RadioKitClass
- Use a static/global flag (simpler, single-instance architecture)
- Pass RadioKitClass pointer to Widget (already has `_init()` with context)

Best approach: Widget already calls `_registerSelf()` which pushes to RadioKitClass. Add a `_confDirty` setter call there, or use a static pointer.

### RadioKit.cpp — _buildConfPayload

```cpp
uint16_t RadioKitClass::_buildConfPayload(uint8_t* buf, uint16_t bufSize) {
    uint16_t out = 0;

    // Count visible widgets on active page
    uint8_t visibleCount = 0;
    for (uint8_t i = 0; i < _widgetCount; i++) {
        RadioKit_Widget* w = _widgets[i];
        if (w->page() != _activePage) continue;
        if (w->hidden()) continue;
        visibleCount++;
    }

    // Header (v5 with pages or v4 without)
    const char* themeStr = config.theme ? config.theme : "dragon";
    uint8_t themeLen = (uint8_t)strnlen(themeStr, 64);

    if (_numPages > 1) {
        if (out + 5 + themeLen > bufSize) return 0;
        buf[out++] = config.orientation;
        buf[out++] = visibleCount;
        buf[out++] = _activePage;
        buf[out++] = _numPages;
        buf[out++] = themeLen;
    } else {
        if (out + 3 + themeLen > bufSize) return 0;
        buf[out++] = config.orientation;
        buf[out++] = visibleCount;
        buf[out++] = themeLen;
    }
    memcpy(&buf[out], themeStr, themeLen); out += themeLen;

    // Per-widget (active page, visible only)
    for (uint8_t i = 0; i < _widgetCount; i++) {
        RadioKit_Widget* w = _widgets[i];
        if (w->page() != _activePage) continue;
        if (w->hidden()) continue;
        // ... serialize 10-byte header + strings (unchanged)
    }
    return out;
}
```

### RadioKit.cpp — _buildVarPayload

```cpp
uint16_t RadioKitClass::_buildVarPayload(uint8_t* buf, uint16_t bufSize) {
    uint16_t out = 0;
    for (uint8_t i = 0; i < _widgetCount; i++) {
        RadioKit_Widget* w = _widgets[i];
        if (w->page() != _activePage) continue;
        if (w->hidden()) continue;
        uint8_t inSz = w->inputSize();
        uint8_t outSz = w->outputSize();
        uint8_t sz = (outSz > 0) ? outSz : inSz;
        if (sz == 0) continue;
        if (out + sz > bufSize) break;
        if (outSz > 0) w->serializeOutput(&buf[out]);
        else w->serializeInput(&buf[out]);
        out += sz;
    }
    return out;
}
```

### RadioKit.cpp — _buildMetaPayload

```cpp
uint16_t RadioKitClass::_buildMetaPayload(uint8_t* buf, uint16_t bufSize) {
    uint16_t out = 0;
    for (uint8_t i = 0; i < _widgetCount; i++) {
        RadioKit_Widget* w = _widgets[i];
        if (w->page() != _activePage) continue;
        if (w->hidden()) continue;
        uint16_t strLen = w->serializeStrings(&buf[out]);
        if (out + strLen <= bufSize) {
            out += strLen;
        } else {
            break;
        }
    }
    return out;
}
```

### RadioKit.cpp — update() loop

```cpp
if (isConnected()) {
    for (uint8_t i = 0; i < _widgetCount; i++) {
        RadioKit_Widget* w = _widgets[i];
        if (w->page() != _activePage) continue;
        if (w->hidden()) continue;  // NEW
        // ... existing change detection ...
    }
}
```

### RadioKit.cpp — update() end (after meta batch)

```cpp
// Rebuild CONF_DATA if widget visibility changed
if (_confDirty && isConnected()) {
    _handleGetConf();
    _handleGetVars();
    _confDirty = false;
}
```

### RadioKit.cpp — _handleSetInput

```cpp
void RadioKitClass::_handleSetInput(const uint8_t* payload, uint16_t len) {
    uint16_t offset = 0;
    for (uint8_t i = 0; i < _widgetCount; i++) {
        RadioKit_Widget* w = _widgets[i];
        uint8_t sz = w->inputSize();
        if (w->page() != _activePage) { offset += sz; continue; }
        if (w->hidden()) { offset += sz; continue; }  // NEW
        if (sz == 0) continue;
        if (offset + sz > len) break;
        w->deserializeInput(payload + offset);
        // ...
    }
}
```

## App Changes

### canvas_element.dart

```dart
// Before:
if (isPlayMode && element.hidden) {
    return const SizedBox.shrink();
}
if (!isPlayMode && element.hidden) {
    child = Opacity(opacity: 0.15, child: child);
}

// After:
if (element.hidden) {
    return const SizedBox.shrink();
}
```

### designer_state.dart — new method

```dart
void setElementHidden(String id, bool hidden) {
    final index = elements.indexWhere((e) => e.id == id);
    if (index == -1) return;
    activePage.elements = [
        for (int i = 0; i < elements.length; i++)
            if (i == index) elements[i].copyWith(hidden: hidden)
            else elements[i],
    ];
    notifyListeners();
}
```

No `_pushUndo()` — firmware-driven change, not user-initiated.

### device_designer_bridge.dart — _syncValues()

Add after existing value sync loop:

```dart
// Sync hidden state from WidgetConfig → DesignerElement
for (final el in _designerState.elements) {
    final config = _widgetConfigForElement(el);
    if (config.typeId == 0) continue;
    if (config.hidden != el.hidden) {
        _designerState.setElementHidden(el.id, config.hidden);
    }
}
```

## Data Flows

### Hide (firmware-initiated)

```
Firmware: led.setHidden(true)
  → _confDirty = true
  → update() → _confDirty detected
  → _handleGetConf() → CONF_DATA (led excluded, visibleCount decremented)
  → _handleGetVars() → VAR_DATA (led excluded)
  → App: _deviceConfigJson rebuilt (no led)
  → Bridge: JSON changed → _syncElementsFromJson() → led element removed
  → Widget invisible ✓
```

### Unhide

```
Firmware: led.setHidden(false)
  → _confDirty = true
  → update() → _confDirty detected
  → _handleGetConf() → CONF_DATA (led included, visibleCount incremented)
  → _handleGetVars() → VAR_DATA (led included)
  → App: _deviceConfigJson rebuilt (led present)
  → Bridge: JSON changed → _syncElementsFromJson() → led element created
  → _syncValues() pushes current value
  → Widget visible ✓
```

### Page Switch

```
setActivePage(2)
  → PAGE_SWITCH sent
  → _handleGetConf() → CONF_DATA (page 2 widgets, hidden excluded)
  → _handleGetVars() → VAR_DATA (page 2 values, hidden excluded)
  → App: _deviceConfigJson rebuilt
  → Bridge: JSON changed → _syncElementsFromJson()
  → Widget list replaced with page 2 widgets ✓
```

### Shadow Recovery on Unhide

When a hidden widget is unhidden:
- Shadow arrays were zero (never populated while hidden)
- Next `update()` detects shadow mismatch (current value != 0)
- Pushes VAR_UPDATE with current value
- App receives value and displays correctly ✓
