## 1. DesignerState — showPageBar

- [x] 1.1 Add `bool _showPageBar = true` field to `DesignerState`
- [x] 1.2 Add `bool get showPageBar` getter
- [x] 1.3 Add `void togglePageBar()` method that flips `_showPageBar` and calls `notifyListeners()`
- [x] 1.4 Add `showPageBar` to `toJson()` under `canvas.showPageBar`
- [x] 1.5 Add `showPageBar` loading in `loadFromJson()` with fallback to `true`

## 2. DesignerPageBar — Tab UI Rewrite

- [x] 2.1 Replace `_DotIndicator` with `_TabButton` widget showing page name text
- [x] 2.2 Style active tab: filled pill with `tokens.primary` bg, `tokens.onPrimary` text
- [x] 2.3 Style inactive tab: outlined pill with `tokens.surface` bg, `tokens.onSurface` text
- [x] 2.4 Add `SingleChildScrollView` wrapping tabs for horizontal overflow
- [x] 2.5 Wire tab tap to `state.setActivePage(index)`
- [x] 2.6 Wire tab long-press to open context menu (rename, duplicate, delete)
- [x] 2.7 Keep chevron navigation (left/right) with disabled state
- [x] 2.8 Keep "+" add page button
- [x] 2.9 Keep page name tap-to-rename dialog

## 3. Page Bar Visibility Toggle

- [x] 3.1 Add toggle button in page bar (right side, before add button)
- [x] 3.2 Use `LucideIcons.panelTopOpen` when visible, `LucideIcons.panelTopClose` when hidden
- [x] 3.3 Wrap page bar in `AnimatedSize` for smooth collapse/expand transition
- [x] 3.4 Show floating restore button at top-center of canvas when page bar is hidden
- [x] 3.5 Wire toggle button to `state.togglePageBar()`
- [x] 3.6 Wire restore button to `state.togglePageBar()`

## 4. Designer Screen Integration

- [x] 4.1 Conditionally show page bar based on `_state.showPageBar`
- [x] 4.2 Add `AnimatedSize` wrapper around page bar area in layout
- [x] 4.3 Position floating restore button when page bar is hidden

## 5. Testing & Validation

- [x] 5.1 Write widget test for tab rendering with page names
- [x] 5.2 Write widget test for tab tap switches active page
- [x] 5.3 Write widget test for toggle button hides/shows page bar
- [x] 5.4 Write unit test for `showPageBar` serialization in JSON
- [x] 5.5 Run `flutter analyze --fatal-warnings` — all pass
- [x] 5.6 Run `flutter test` — all pass
