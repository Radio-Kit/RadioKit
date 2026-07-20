import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';

/// Page bar shown below the top toolbar in the designer.
///
/// Displays tab-style buttons with page names, chevron navigation,
/// and an add button. Supports tap-to-switch, long-press context menu
/// for rename/duplicate/delete, and horizontal scrolling.
class DesignerPageBar extends StatelessWidget {
  final DesignerState state;

  const DesignerPageBar({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);
    final numPages = state.numPages;
    final activeIndex = state.activePageIndex;

    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        return AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: state.showPageBar
              ? Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: tokens.base300,
                    border: Border(
                      bottom: BorderSide(color: tokens.effectiveOutline, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      // Left chevron
                      _ChevronButton(
                        icon: LucideIcons.chevronLeft,
                        onPressed: activeIndex > 0
                            ? () => state.setActivePage(activeIndex - 1)
                            : null,
                        tokens: tokens,
                      ),
                      const SizedBox(width: 4),
                      // Tab buttons (scrollable if many pages)
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (int i = 0; i < numPages; i++)
                                  _TabButton(
                                    index: i,
                                    isActive: i == activeIndex,
                                    page: state.pages[i],
                                    tokens: tokens,
                                    onTap: () => state.setActivePage(i),
                                    onLongPress: () => _showContextMenu(
                                      context,
                                      tokens,
                                      i,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Toggle button (hide page bar)
                      _ToggleButton(
                        tokens: tokens,
                        onPressed: () => state.togglePageBar(),
                      ),
                      const SizedBox(width: 4),
                      // Add page button
                      _AddPageButton(
                        tokens: tokens,
                        onPressed: () => state.addPage(),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        );
      },
    );
  }

  void _showContextMenu(
    BuildContext context,
    RKTokens tokens,
    int pageIndex,
  ) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                LucideIcons.pencil,
                color: tokens.onSurface.withValues(alpha: 0.7),
              ),
              title: Text(
                'Rename Page',
                style: TextStyle(
                  color: tokens.onSurface.withValues(alpha: 0.88),
                  fontFamily: 'monospace',
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _renamePage(context, tokens, pageIndex);
              },
            ),
            ListTile(
              leading: Icon(
                LucideIcons.copy,
                color: tokens.onSurface.withValues(alpha: 0.7),
              ),
              title: Text(
                'Duplicate Page',
                style: TextStyle(
                  color: tokens.onSurface.withValues(alpha: 0.88),
                  fontFamily: 'monospace',
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                state.duplicatePage(pageIndex);
              },
            ),
            if (state.numPages > 1)
              ListTile(
                leading: Icon(
                  LucideIcons.trash2,
                  color: tokens.error,
                ),
                title: Text(
                  'Delete Page',
                  style: TextStyle(
                    color: tokens.error,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeletePage(context, tokens, pageIndex);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _renamePage(BuildContext context, RKTokens tokens, int index) {
    final controller = TextEditingController(text: state.pages[index].name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.base300,
        title: Text(
          'Rename Page',
          style: TextStyle(
            color: tokens.onSurface.withValues(alpha: 0.88),
            fontFamily: 'monospace',
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(
            color: tokens.onSurface.withValues(alpha: 0.88),
            fontFamily: 'monospace',
          ),
          decoration: InputDecoration(
            hintText: 'Page Name',
            hintStyle: TextStyle(
              color: tokens.onSurface.withValues(alpha: 0.53),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: tokens.effectiveOutline),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: tokens.primary.withValues(alpha: 0.6),
              ),
            ),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              state.renamePage(index, value.trim());
            }
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'CANCEL',
              style: TextStyle(
                color: tokens.onSurface.withValues(alpha: 0.67),
                fontFamily: 'monospace',
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                state.renamePage(index, controller.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: Text(
              'SAVE',
              style: TextStyle(
                color: tokens.primary.withValues(alpha: 0.6),
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePage(
    BuildContext context,
    RKTokens tokens,
    int pageIndex,
  ) {
    final pageName = state.pages[pageIndex].name;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.base300,
        title: Text(
          'Delete Page',
          style: TextStyle(
            color: tokens.onSurface.withValues(alpha: 0.88),
            fontFamily: 'monospace',
          ),
        ),
        content: Text(
          'Delete "$pageName" and all its widgets?',
          style: TextStyle(
            color: tokens.onSurface.withValues(alpha: 0.67),
            fontFamily: 'monospace',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'CANCEL',
              style: TextStyle(
                color: tokens.onSurface.withValues(alpha: 0.67),
                fontFamily: 'monospace',
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              state.removePage(pageIndex);
            },
            child: Text(
              'DELETE',
              style: TextStyle(
                color: tokens.error,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tab button showing page name. Active = filled primary, inactive = outlined.
class _TabButton extends StatelessWidget {
  final int index;
  final bool isActive;
  final DesignerPage page;
  final RKTokens tokens;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _TabButton({
    required this.index,
    required this.isActive,
    required this.page,
    required this.tokens,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final hasOrientationOverride = page.orientationOverride != null &&
        page.orientationOverride != 'global';

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        constraints: const BoxConstraints(minWidth: 48, maxWidth: 120),
        decoration: BoxDecoration(
          color: isActive ? tokens.primary : tokens.surface,
          border: Border.all(
            color: isActive
                ? tokens.primary
                : tokens.effectiveOutline,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Text(
                page.name,
                style: TextStyle(
                  color: isActive
                      ? tokens.onPrimary
                      : tokens.onSurface.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            if (hasOrientationOverride)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: tokens.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.rotateCw,
                    size: 8,
                    color: tokens.onPrimary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChevronButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final RKTokens tokens;

  const _ChevronButton({
    required this.icon,
    required this.onPressed,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isDisabled ? tokens.base200 : tokens.surface,
          border: Border.all(
            color: tokens.effectiveOutline,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          icon,
          size: 14,
          color: isDisabled
              ? tokens.effectiveOutline
              : tokens.primary,
        ),
      ),
    );
  }
}

/// Toggle button to show/hide the page bar.
class _ToggleButton extends StatelessWidget {
  final RKTokens tokens;
  final VoidCallback onPressed;

  const _ToggleButton({
    required this.tokens,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: tokens.surface,
          border: Border.all(
            color: tokens.primary.withValues(alpha: 0.5),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          LucideIcons.panelTopOpen,
          size: 14,
          color: tokens.primary,
        ),
      ),
    );
  }
}

class _AddPageButton extends StatelessWidget {
  final RKTokens tokens;
  final VoidCallback onPressed;

  const _AddPageButton({
    required this.tokens,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: tokens.surface,
          border: Border.all(
            color: tokens.primary.withValues(alpha: 0.5),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          LucideIcons.plus,
          size: 14,
          color: tokens.primary,
        ),
      ),
    );
  }
}
