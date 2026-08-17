import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';
import '../../models/starter_template.dart';
import 'design_preview.dart';
import 'responsive_grid.dart';



/// Section that loads bundled starter-template JSON files and displays them
/// as tappable cards below the user's saved designs.
class StarterTemplatesSection extends StatefulWidget {
  final bool showHeader;
  final String? headerLabel;
  final bool openInPreview;

  const StarterTemplatesSection({
    super.key,
    this.showHeader = true,
    this.headerLabel,
    this.openInPreview = false,
  });

  @override
  State<StarterTemplatesSection> createState() =>
      _StarterTemplatesSectionState();
}

class _StarterTemplatesSectionState extends State<StarterTemplatesSection> {
  final List<StarterTemplate> _templates = [];
  final Map<String, DesignerState> _previewStates = {};
  bool _loaded = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    try {
      // Discover template assets from the asset manifest.
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final templatePaths = manifest.listAssets()
          .where((k) =>
              k.contains('starter-templates/') && k.endsWith('.json'))
          .toList()
        ..sort();

      for (final path in templatePaths) {
        if (_disposed) return;
        try {
          final jsonStr = await rootBundle.loadString(path);
          if (_disposed) return;
          final json = jsonDecode(jsonStr) as Map<String, dynamic>;
          final template = StarterTemplate.fromParsed(
            assetPath: path,
            json: json,
            jsonContent: jsonStr,
          );
          _templates.add(template);

          // Build a read-only DesignerState for the live preview.
          final state = DesignerState();
          state.loadFromJson(json);
          if (!state.isPlayMode) state.togglePlayMode();
          _previewStates[path] = state;
        } catch (e) {
          debugPrint('Skipping malformed starter template $path: $e');
        }
      }
    } catch (e) {
      debugPrint('Failed to load starter templates: $e');
    }

    if (mounted && !_disposed) {
      setState(() => _loaded = true);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final state in _previewStates.values) {
      state.dispose();
    }
    super.dispose();
  }

  void _openTemplate(BuildContext context, StarterTemplate template) {
    // Generate a random 3-digit suffix for the design name.
    final suffix = (100 + (DateTime.now().microsecondsSinceEpoch % 900));
    final name = '${template.name}-$suffix';

    if (context.mounted) {
      // Pass template JSON via extra — designer saves only on explicit Save.
      context.push('/designer', extra: {
        'templateJson': template.jsonContent,
        'templateName': name,
        'initialPlayMode': widget.openInPreview,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const SizedBox.shrink();
    }
    if (_templates.isEmpty) {
      return const SizedBox.shrink();
    }

    final tokens = RKTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showHeader)
          Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 12),
            child: Row(children: [
              Container(width: 8, height: 8, color: tokens.primary),
              const SizedBox(width: 12),
              Text(widget.headerLabel ?? 'STARTER TEMPLATES', style: GoogleFonts.martianMono(color: tokens.onSurface.withValues(alpha: 0.45), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
            ]),
          ),
        // ── Template cards ──────────────────────────────────────────────
        _TemplateGrid(
          templates: _templates,
          previewStates: _previewStates,
          onTap: (t) => _openTemplate(context, t),
        ),
      ],
    );
  }
}

// ── Grid layout (mirrors _DesignsGrid) ────────────────────────────────────

class _TemplateGrid extends StatelessWidget {
  final List<StarterTemplate> templates;
  final Map<String, DesignerState> previewStates;
  final ValueChanged<StarterTemplate> onTap;

  const _TemplateGrid({
    required this.templates,
    required this.previewStates,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final columns = columnCount(screenWidth);

    final rows = <Widget>[];
    for (int i = 0; i < templates.length; i += columns) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int j = 0; j < columns; j++) ...[
                if (j > 0) const SizedBox(width: 12),
                if (i + j < templates.length)
                  Expanded(
                    child: _TemplateCard(
                      template: templates[i + j],
                      previewState: previewStates[templates[i + j].assetPath],
                      onTap: () => onTap(templates[i + j]),
                    ),
                  )
                else
                  const Expanded(child: SizedBox.shrink()),
              ],
            ],
          ),
        ),
      );
    }

    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

// ── Template card ─────────────────────────────────────────────────────────

class _TemplateCard extends StatelessWidget {
  final StarterTemplate template;
  final DesignerState? previewState;
  final VoidCallback onTap;

  const _TemplateCard({
    required this.template,
    this.previewState,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);
    final transportLabel = template.transport.isNotEmpty
        ? template.transport.toUpperCase()
        : null;
    final typeLabel =
        template.type.isNotEmpty ? template.type : null;

    return GestureDetector(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.borderRadius.clamp(4, 16)),
          side: BorderSide(color: tokens.effectiveOutline.withValues(alpha: 0.5), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // -- Thumbnail preview (rendered directly from JSON)
            AspectRatio(
              aspectRatio: 16 / 10,
              child: previewState != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(tokens.borderRadius.clamp(4, 16)),
                      ),
                      child: DesignPreview(
                              state: previewState!,
                              fallbackTokens: tokens,
                            ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: tokens.base300,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(tokens.borderRadius.clamp(4, 16)),
                        ),
                      ),
                      child: Center(
                        child: Icon(PhosphorIconsFill.squaresFour, size: 32, color: tokens.onSurface.withValues(alpha: 0.2)),
                      ),
                    ),
            ),
            // -- Name + metadata
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.exo2(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: tokens.onSurface,
                    ),
                  ),
                  if (typeLabel != null || transportLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      [typeLabel, transportLabel].where((s) => s != null).join(' \u2022 '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: tokens.onSurface.withValues(alpha: 0.54),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: tokens.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        '${template.widgetCount} w',
                        style: GoogleFonts.martianMono(
                          color: tokens.primary.withValues(alpha: 0.8),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
