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
import '../../widgets/radiokit_app_bar.dart';
import '../../providers/designs_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/model_card.dart';

class DesignsTab extends StatelessWidget {
  const DesignsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DesignsProvider>();
    final designs = provider.activeDesigns;

    return Scaffold(
      appBar: RadioKitAppBar(
        actions: [
          _PillButton(
            icon: LucideIcons.folderOpen,
            label: 'Open',
            onTap: () => _openConfigFile(context),
          ),
          const SizedBox(width: 6),
          _PillButton(
            icon: LucideIcons.plus,
            label: 'Create',
            onTap: () => context.push('/designer'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: designs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.palette, size: 64, color: AppColors.brandGray.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'No designs saved',
                    style: GoogleFonts.inter(
                      color: AppColors.brandGray,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          : _DesignsGrid(
              designs: designs,
              provider: provider,
            ),
    );
  }

  Future<void> _openConfigFile(BuildContext context) async {
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
}

class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: Colors.white54),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.changa(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    fontSize: 11,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// ── Designs Grid ─────────────────────────────────────────────────────────────

class _DesignsGrid extends StatelessWidget {
  final List<SavedDesign> designs;
  final DesignsProvider provider;

  const _DesignsGrid({
    required this.designs,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const breakpoint = 600;
    final useWide = screenWidth > breakpoint;

    if (!useWide) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: designs.map((d) => _DesignCard(design: d, provider: provider)).toList(),
      );
    }

    // Landscape: 2-column grid using Row + Expanded
    final rows = <Widget>[];
    for (int i = 0; i < designs.length; i += 2) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _DesignCard(design: designs[i], provider: provider)),
              const SizedBox(width: 12),
              if (i + 1 < designs.length)
                Expanded(child: _DesignCard(design: designs[i + 1], provider: provider))
              else
                const Expanded(child: SizedBox.shrink()),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: rows,
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
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        icon: const Icon(Icons.warning_rounded, color: Colors.redAccent, size: 32),
        title: const Text('Delete Design?', style: TextStyle(color: Colors.white)),
        content: Text('Remove "${design.name}" permanently?',
            style: const TextStyle(color: Colors.white54, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
              foregroundColor: Colors.redAccent,
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
      leading: Container(
        padding: const EdgeInsets.all(4),
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Icon(LucideIcons.palette, color: AppColors.brandOrange, size: 36),
        ),
      ),
      title: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          design.name.toUpperCase(),
          style: GoogleFonts.exo2(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
      ),
      subtitle: Text(
        formattedDate.toUpperCase(),
        style: TextStyle(
          color: AppColors.brandOrange.withValues(alpha: 0.7),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (design.appVersion != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.brandOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'v${design.appVersion}',
                style: GoogleFonts.jetBrainsMono(
                  color: AppColors.brandOrange.withValues(alpha: 0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 20),
        ],
      ),
      onTap: () => _openDesign(context),
      onLongPress: () => _deleteDesign(context),
    );
  }
}
