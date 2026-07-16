import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';

/// Page bar shown below the top toolbar in the designer.
///
/// Displays centered chevron navigation (< Page Name >), dot indicators,
/// and an add button. Supports tap-to-rename, long-press context menu
/// for delete/duplicate, and drag-to-reorder on dots.
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
        return Container(
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
              // Dot indicators (scrollable if many pages)
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0; i < numPages; i++)
                          _DotIndicator(
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
                            onAcceptReorder: (oldIndex) {
                              state.reorderPage(oldIndex, i);
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              // Page name (tap to rename)
              _PageNameLabel(
                name: state.activePage.name,
                tokens: tokens,
                onTap: () => _renamePage(context, tokens, activeIndex),
              ),
              const SizedBox(width: 4),
              // Right chevron
              _ChevronButton(
                icon: LucideIcons.chevronRight,
                onPressed: activeIndex < numPages - 1
                    ? () => state.setActivePage(activeIndex + 1)
                    : null,
                tokens: tokens,
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
        );
      },
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

class _DotIndicator extends StatefulWidget {
  final int index;
  final bool isActive;
  final DesignerPage page;
  final RKTokens tokens;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final void Function(int oldIndex) onAcceptReorder;

  const _DotIndicator({
    required this.index,
    required this.isActive,
    required this.page,
    required this.tokens,
    required this.onTap,
    required this.onLongPress,
    required this.onAcceptReorder,
  });

  @override
  State<_DotIndicator> createState() => _DotIndicatorState();
}

class _DotIndicatorState extends State<_DotIndicator> {
  @override
  Widget build(BuildContext context) {
    return Draggable<int>(
      data: widget.index,
      feedback: _Dot(
        isActive: true,
        tokens: widget.tokens,
        label: '${widget.index + 1}',
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _Dot(
          isActive: widget.isActive,
          tokens: widget.tokens,
          label: '${widget.index + 1}',
        ),
      ),
      child: DragTarget<int>(
        onAcceptWithDetails: (details) {
          widget.onAcceptReorder(details.data);
        },
        builder: (context, candidateData, rejectedData) {
          return GestureDetector(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _Dot(
                isActive: widget.isActive,
                tokens: widget.tokens,
                label: '${widget.index + 1}',
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final bool isActive;
  final RKTokens tokens;
  final String label;

  const _Dot({
    required this.isActive,
    required this.tokens,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isActive ? 24 : 10,
      height: 10,
      decoration: BoxDecoration(
        color: isActive ? tokens.primary : tokens.effectiveOutline,
        borderRadius: BorderRadius.circular(5),
      ),
      alignment: Alignment.center,
      child: isActive
          ? Text(
              label,
              style: TextStyle(
                color: tokens.onPrimary,
                fontSize: 8,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }
}

class _PageNameLabel extends StatelessWidget {
  final String name;
  final RKTokens tokens;
  final VoidCallback onTap;

  const _PageNameLabel({
    required this.name,
    required this.tokens,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 120),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: tokens.primary.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
        ),
        child: Text(
          name,
          style: TextStyle(
            color: tokens.onSurface.withValues(alpha: 0.88),
            fontSize: 11,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
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
