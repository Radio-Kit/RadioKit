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
import '../../widgets/model_card.dart';
import 'starter_templates_section.dart';

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
    const breakpoint = 600;
    final useWide = screenWidth > breakpoint;
    final provider = context.read<DesignsProvider>();

    // Build the list of design card widgets
    final List<Widget> designCards = designs
        .map((d) => _DesignCard(design: d, provider: provider))
        .toList();

    // Wrap design cards into rows (2-column on wide, single-column on narrow)
    final List<Widget> designRows = [];
    if (useWide) {
      for (int i = 0; i < designCards.length; i += 2) {
        designRows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: designCards[i]),
                const SizedBox(width: 12),
                if (i + 1 < designCards.length)
                  Expanded(child: designCards[i + 1])
                else
                  const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ),
        );
      }
    } else {
      for (final card in designCards) {
        designRows.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: card,
        ));
      }
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
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

class _DesignCard extends StatelessWidget {
  final SavedDesign design;
  final DesignsProvider provider;

  const _DesignCard({required this.design, required this.provider});

  Future<void> _openDesign(BuildContext context) async {
    if (design.filePath != null) {
      final file = File(design.filePath!);
      if (!file.existsSync()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('File not found: ${design.filePath}')),
          );
          await provider.deleteDesign(design.id);
        }
        return;
      }
    }
    if (context.mounted) {
      context.push('/designer?id=${design.id}');
    }
  }

  Future<void> _deleteDesign(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.tokens.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        icon: Icon(Icons.warning_rounded, color: context.tokens.error, size: 32),
        title: Text('Delete Design?', style: TextStyle(color: context.tokens.onSurface)),
        content: Text('Remove "${design.name}" permanently?',
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
      await provider.deleteDesign(design.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('MMM d, yyyy').format(
      DateTime.fromMillisecondsSinceEpoch(design.timestamp),
    );

    return ModelCard(
      leading: ModelCard.standardLeading(
        context: context,
        icon: LucideIcons.palette,
      ),
      title: ModelCard.standardTitle(design.name),
      subtitle: ModelCard.standardSubtitle(context, formattedDate.toUpperCase()),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (design.appVersion != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: context.tokens.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'v${design.appVersion}',
                style: GoogleFonts.martianMono(
                  color: context.tokens.primary.withValues(alpha: 0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, color: context.tokens.onSurface.withValues(alpha: 0.24), size: 20),
        ],
      ),
      onTap: () => _openDesign(context),
      onLongPress: () => _deleteDesign(context),
    );
  }
}
