## 1. DesignerState — showPageBar

- [ ] 1.1 Add `bool _showPageBar = true` field to `DesignerState`
- [ ] 1.2 Add `bool get showPageBar` getter
- [ ] 1.3 Add `void togglePageBar()` method that flips `_showPageBar` and calls `notifyListeners()`
- [ ] 1.4 Add `showPageBar` to `toJson()` under `canvas.showPageBar`
- [ ] 1.5 Add `showPageBar` loading in `loadFromJson()` with fallback to `true`

## 2. DesignerPageBar — Tab UI Rewrite

- [ ] 2.1 Replace `_DotIndicator` with `_TabButton` widget showing page name text
- [ ] 2.2 Style active tab: filled pill with `tokens.primary` bg, `tokens.onPrimary` text
- [ ] 2.3 Style inactive tab: outlined pill with `tokens.surface` bg, `tokens.onSurface` text
- [ ] 2.4 Add `SingleChildScrollView` wrapping tabs for horizontal overflow
- [ ] 2.5 Wire tab tap to `state.setActivePage(index)`
- [ ] 2.6 Wire tab long-press to open context menu (rename, duplicate, delete)
- [ ] 2.7 Keep chevron navigation (left/right) with disabled state
- [ ] 2.8 Keep "+" add page button
- [ ] 2.9 Keep page name tap-to-rename dialog

## 3. Page Bar Visibility Toggle

- [ ] 3.1 Add toggle button in page bar (right side, before add button)
- [ ] 3.2 Use `LucideIcons.panelTopOpen` when visible, `LucideIcons.panelTopClose` when hidden
- [ ] 3.3 Wrap page bar in `AnimatedSize` for smooth collapse/expand transition
- [ ] 3.4 Show floating restore button at top-center of canvas when page bar is hidden
- [ ] 3.5 Wire toggle button to `state.togglePageBar()`
- [ ] 3.6 Wire restore button to `state.togglePageBar()`

## 4. Designer Screen Integration

- [ ] 4.1 Conditionally show page bar based on `_state.showPageBar`
- [ ] 4.2 Add `AnimatedSize` wrapper around page bar area in layout
- [ ] 4.3 Position floating restore button when page bar is hidden

## 5. Testing & Validation

- [ ] 5.1 Write widget test for tab rendering with page names
- [ ] 5.2 Write widget test for tab tap switches active page
- [ ] 5.3 Write widget test for toggle button hides/shows page bar
- [ ] 5.4 Write unit test for `showPageBar` serialization in JSON
- [ ] 5.5 Run `flutter analyze --fatal-warnings` — all pass
- [ ] 5.6 Run `flutter test` — all pass
