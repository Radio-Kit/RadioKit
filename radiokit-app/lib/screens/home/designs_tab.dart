import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';
import '../../models/tab_index.dart';
import '../../widgets/radiokit_app_bar.dart';
import '../../providers/designs_provider.dart';
import '../../theme/app_theme.dart';
import 'starter_templates_section.dart';
import 'responsive_grid.dart';

class DesignsTab extends StatelessWidget {
  const DesignsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DesignsProvider>();
    final designs = provider.activeDesigns;
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    // In landscape mode, don't use Scaffold (parent provides it)
    if (isLandscape) {
      return _buildContent(context, designs);
    }

    return Scaffold(
      appBar: RadioKitAppBar(
        tabIndex: TabIndex.designs,
        onOpen: () => openConfigFile(context),
        onCreate: () => context.push('/designer'),
        accentColor: context.tokens.primary,
      ),
      body: _buildContent(context, designs),
    );
  }

  Widget _buildContent(BuildContext context, List<SavedDesign> designs) {
    final screenWidth = MediaQuery.of(context).size.width;
    final columns = columnCount(screenWidth);
    final provider = context.read<DesignsProvider>();

    // Build the list of design card widgets
    final List<Widget> designCards = designs
        .map((d) => _DesignCard(design: d, provider: provider))
        .toList();

    // Wrap design cards into grid rows
    final List<Widget> designRows = [];
    for (int i = 0; i < designCards.length; i += columns) {
      designRows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int j = 0; j < columns; j++) ...[
                if (j > 0) const SizedBox(width: 12),
                if (i + j < designCards.length)
                  Expanded(child: designCards[i + j])
                else
                  const Expanded(child: SizedBox.shrink()),
              ],
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        // -- Saved Designs header
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [
            Container(width: 8, height: 8, color: context.tokens.primary),
            const SizedBox(width: 12),
            Text('SAVED DESIGNS', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: context.tokens.primary, fontWeight: FontWeight.bold)),
          ]),
        ),
        if (designs.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.palette, size: 64, color: context.tokens.onSurface.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'No designs saved',
                    style: GoogleFonts.inter(
                      color: context.tokens.onSurface.withValues(alpha: 0.5),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...designRows,
        const StarterTemplatesSection(),
      ],
    );
  }

}


/// Opens a .h or .json config file via the system file picker.
Future<void> openConfigFile(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['h', 'json'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final filePath = result.files.first.path;
        if (filePath == null || kIsWeb) {
          throw Exception('File path not available on this platform');
        }

        final content = await File(filePath).readAsString();
        final Map<String, dynamic> decoded;

        if (filePath.endsWith('.json')) {
          // Raw JSON file — parse directly
          decoded = json.decode(content) as Map<String, dynamic>;
        } else {
          // .h file — extract JSON from the comment block
          final match = DesignerState.configPattern.firstMatch(content);
          if (match == null || match.group(1) == null) {
            throw const FormatException('No RadioKit UI Designer block found in file');
          }
          decoded = json.decode(match.group(1)!.trim()) as Map<String, dynamic>;
        }

        if (!context.mounted) return;
        final provider = context.read<DesignsProvider>();
        final name = (decoded['config']?['name'] as String?) ?? result.files.first.name;
        final id = DateTime.now().millisecondsSinceEpoch.toString();
        final appData = decoded['appdata'];
        final lastEdit = appData is Map ? appData['lastEdit'] as int? : null;
        final appVersion = appData is Map ? appData['appVersion'] as String? : null;

        // Save as file-mode entry (no jsonContent — the file is the source of truth)
        await provider.saveDesign(
          id, name, null,
          filePath: filePath,
          lastEdit: lastEdit ?? DateTime.now().millisecondsSinceEpoch,
          appVersion: appVersion,
        );

        if (!context.mounted) return;
        context.push('/designer?id=$id');
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open file: $e')),
      );
    }
  }

class _DesignCard extends StatefulWidget {
  final SavedDesign design;
  final DesignsProvider provider;

  const _DesignCard({required this.design, required this.provider});

  @override
  State<_DesignCard> createState() => _DesignCardState();
}

class _DesignCardState extends State<_DesignCard> {
  DesignerState? _previewState;
  String? _description;
  bool _loaded = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    try {
      String? jsonStr = widget.design.jsonContent;

      // For file-mode entries, read the file to get JSON content
      if (jsonStr == null && widget.design.filePath != null) {
        final file = File(widget.design.filePath!);
        if (file.existsSync()) {
          final content = await file.readAsString();
          // Extract JSON from .h files if needed
          if (widget.design.filePath!.endsWith('.h')) {
            final match = DesignerState.configPattern.firstMatch(content);
            if (match != null && match.group(1) != null) {
              jsonStr = match.group(1)!.trim();
            }
          } else {
            jsonStr = content;
          }
        }
      }

      if (jsonStr != null && !_disposed) {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        final state = DesignerState();
        state.loadFromJson(json);
        if (!state.isPlayMode) state.togglePlayMode();

        // Extract description from config
        final desc = json['config']?['description'] as String?;

        if (!_disposed) {
          setState(() {
            _previewState = state;
            _description = desc;
            _loaded = true;
          });
        } else {
          state.dispose();
        }
        return;
      }
    } catch (e) {
      debugPrint('Failed to load design preview: $e');
    }
    if (!_disposed) {
      setState(() => _loaded = true);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _previewState?.dispose();
    super.dispose();
  }

  Future<void> _openDesign() async {
    final context = this.context;
    if (widget.design.filePath != null) {
      final file = File(widget.design.filePath!);
      if (!file.existsSync()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('File not found: ${widget.design.filePath}')),
          );
          await widget.provider.deleteDesign(widget.design.id);
        }
        return;
      }
    }
    if (context.mounted) {
      context.push('/designer?id=${widget.design.id}');
    }
  }

  Future<void> _renameDesign() async {
    final context = this.context;
    final tokens = context.tokens;
    final controller = TextEditingController(text: widget.design.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Rename Design', style: TextStyle(color: tokens.onSurface)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: tokens.onSurface),
          decoration: InputDecoration(
            hintText: 'Design name',
            hintStyle: TextStyle(color: tokens.onSurface.withValues(alpha: 0.4)),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: tokens.effectiveOutline)),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: tokens.primary)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('CANCEL', style: TextStyle(color: tokens.onSurface.withValues(alpha: 0.54))),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(controller.text.trim()),
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty && newName != widget.design.name && context.mounted) {
      final provider = context.read<DesignsProvider>();
      await provider.saveDesign(
        widget.design.id,
        newName,
        widget.design.jsonContent,
        filePath: widget.design.filePath,
        appVersion: widget.design.appVersion,
      );
    }
  }

  Future<void> _deleteDesign() async {
    final context = this.context;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.tokens.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        icon: Icon(Icons.warning_rounded, color: context.tokens.error, size: 32),
        title: Text('Delete Design?', style: TextStyle(color: context.tokens.onSurface)),
        content: Text('Remove "${widget.design.name}" permanently?',
            style: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.54), fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('CANCEL', style: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.54))),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: context.tokens.error.withValues(alpha: 0.2),
              foregroundColor: context.tokens.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await widget.provider.deleteDesign(widget.design.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final design = widget.design;
    final formattedDate = DateFormat('MMM d, yyyy').format(
      DateTime.fromMillisecondsSinceEpoch(design.timestamp),
    );

    return GestureDetector(
      onTap: _openDesign,
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
            // -- Thumbnail preview
            AspectRatio(
              aspectRatio: 16 / 10,
              child: _loaded && _previewState != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(tokens.borderRadius.clamp(4, 16)),
                      ),
                      child: Container(
                        color: tokens.base300,
                        child: RKTheme(
                          tokens: RKTokens.presetsByName[_previewState!.activeSkin] ?? tokens,
                          child: AbsorbPointer(
                            child: DesignerCanvas(state: _previewState!),
                          ),
                        ),
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
                        child: _loaded
                            ? Icon(LucideIcons.palette, size: 32, color: tokens.onSurface.withValues(alpha: 0.2))
                            : SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: tokens.onSurface.withValues(alpha: 0.3)),
                              ),
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
                    design.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.exo2(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: tokens.onSurface,
                    ),
                  ),
                  if (_description != null && _description!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      _description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: tokens.onSurface.withValues(alpha: 0.54),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        formattedDate.toUpperCase(),
                        style: GoogleFonts.martianMono(
                          fontSize: 9,
                          color: tokens.onSurface.withValues(alpha: 0.38),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        splashRadius: 16,
                        iconSize: 16,
                        icon: Icon(
                          LucideIcons.ellipsisVertical,
                          size: 16,
                          color: tokens.onSurface.withValues(alpha: 0.38),
                        ),
                        color: tokens.surface,
                        onSelected: (value) {
                          if (value == 'open') _openDesign();
                          if (value == 'rename') _renameDesign();
                          if (value == 'delete') _deleteDesign();
                        },
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            value: 'open',
                            child: Row(
                              children: [
                                Icon(LucideIcons.folderOpen, size: 14, color: tokens.onSurface.withValues(alpha: 0.7)),
                                const SizedBox(width: 10),
                                Text('Open', style: TextStyle(fontSize: 13, color: tokens.onSurface)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'rename',
                            child: Row(
                              children: [
                                Icon(LucideIcons.pencil, size: 14, color: tokens.onSurface.withValues(alpha: 0.7)),
                                const SizedBox(width: 10),
                                Text('Rename', style: TextStyle(fontSize: 13, color: tokens.onSurface)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(LucideIcons.trash2, size: 14, color: tokens.error),
                                const SizedBox(width: 10),
                                Text('Delete', style: TextStyle(fontSize: 13, color: tokens.error)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
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
