import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';
import '../../models/starter_template.dart';
import '../../providers/designs_provider.dart';
import '../../widgets/model_card.dart';


/// Section that loads bundled starter-template JSON files and displays them
/// as tappable cards below the user's saved designs.
class StarterTemplatesSection extends StatefulWidget {
  const StarterTemplatesSection({super.key});

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

  Future<void> _openTemplate(BuildContext context, StarterTemplate template) async {
    final provider = context.read<DesignsProvider>();
    final id = template.id;

    // Save as a new design entry so the designer can load it by ID.
    await provider.saveDesign(
      id,
      template.name,
      template.jsonContent,
    );

    if (context.mounted) {
      context.push('/designer?id=$id');
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
        // -- Section header
        Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 12),
          child: Row(children: [
            Container(width: 8, height: 8, color: tokens.primary),
            const SizedBox(width: 12),
            Text('STARTER TEMPLATES', style: GoogleFonts.martianMono(color: tokens.onSurface.withValues(alpha: 0.45), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
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
    const breakpoint = 600;
    final useWide = screenWidth > breakpoint;

    if (!useWide) {
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: templates.length,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _TemplateCard(
            template: templates[i],
            previewState: previewStates[templates[i].assetPath],
            onTap: () => onTap(templates[i]),
          ),
        ),
      );
    }

    // Wide: 2-column grid
    final rows = <Widget>[];
    for (int i = 0; i < templates.length; i += 2) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _TemplateCard(
                  template: templates[i],
                  previewState: previewStates[templates[i].assetPath],
                  onTap: () => onTap(templates[i]),
                ),
              ),
              const SizedBox(width: 12),
              if (i + 1 < templates.length)
                Expanded(
                  child: _TemplateCard(
                    template: templates[i + 1],
                    previewState: previewStates[templates[i + 1].assetPath],
                    onTap: () => onTap(templates[i + 1]),
                  ),
                )
              else
                const Expanded(child: SizedBox.shrink()),
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

    return ModelCard(
      leading: _buildPreview(context, tokens),
      title: ModelCard.standardTitle(template.name),
      subtitle: ModelCard.standardSubtitle(
        context,
        [typeLabel, transportLabel].where((s) => s != null).join(' \u2022 '),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: tokens.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${template.widgetCount} w',
              style: GoogleFonts.martianMono(
                color: tokens.primary.withValues(alpha: 0.8),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded,
              color: tokens.onSurface.withValues(alpha: 0.24), size: 20),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildPreview(BuildContext context, RKTokens tokens) {
    if (previewState == null) {
      return ModelCard.standardLeading(
        context: context,
        icon: LucideIcons.layoutTemplate,
      );
    }

    final previewTokens =
        RKTokens.presetsByName[previewState!.activeSkin] ?? RKTokens.dragon;

    return RepaintBoundary(
      child: SizedBox(
        width: 56,
        height: 40,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: tokens.effectiveOutline, width: 0.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: RKTheme(
              tokens: previewTokens,
              child: AbsorbPointer(
                child: DesignerCanvas(state: previewState!),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
