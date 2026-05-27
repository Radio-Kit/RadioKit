import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';
import 'package:intl/intl.dart';
import '../../widgets/radiokit_app_bar.dart';
import '../../providers/designs_provider.dart';
import '../../theme/app_theme.dart';

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
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: designs.length,
              itemBuilder: (context, index) {
                final design = designs[index];
                final date = DateTime.fromMillisecondsSinceEpoch(design.timestamp);
                final formattedDate = DateFormat.yMMMd().add_jm().format(date);

                final isFileMode = design.filePath != null;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.brandCharcoal,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isFileMode ? LucideIcons.fileCode : LucideIcons.archive,
                        color: AppColors.brandOrange,
                      ),
                    ),
                    title: Text(
                      design.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formattedDate,
                          style: const TextStyle(color: AppColors.brandGray, fontSize: 12),
                        ),
                        if (isFileMode)
                          Text(
                            design.filePath!,
                            style: const TextStyle(color: AppColors.brandOrange, fontSize: 10),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(LucideIcons.trash2, size: 20, color: AppColors.brandRed),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Project?'),
                                content: Text('Are you sure you want to delete "${design.name}"?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('CANCEL'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      provider.deleteDesign(design.id);
                                      Navigator.pop(ctx);
                                    },
                                    child: const Text('DELETE', style: TextStyle(color: AppColors.brandRed)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    onTap: () {
                      context.push('/designer?id=${design.id}');
                    },
                  ),
                );
              },
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
    );
  }
}
