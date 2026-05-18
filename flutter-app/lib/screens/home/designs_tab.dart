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
import '../../providers/designs_provider.dart';
import '../../theme/app_theme.dart';
import 'package:intl/intl.dart';

class DesignsTab extends StatelessWidget {
  const DesignsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DesignsProvider>();
    final designs = provider.designs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PROJECTS'),
      ),
      body: Column(
        children: [
          Expanded(
            child: designs.isEmpty
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
                            child: const Icon(LucideIcons.fileCode, color: AppColors.brandOrange),
                          ),
                          title: Text(
                            design.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            formattedDate,
                            style: const TextStyle(color: AppColors.brandGray, fontSize: 12),
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
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF111111),
              border: Border(top: BorderSide(color: Color(0xFF222222), width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      foregroundColor: const Color(0xFF90CAF9),
                    ),
                    icon: const Icon(LucideIcons.folderOpen, size: 16),
                    label: const Text('OPEN CONFIG FILE'),
                    onPressed: () => _openConfigFile(context),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(LucideIcons.plus, size: 16),
                    label: const Text('CREATE NEW'),
                    onPressed: () => context.push('/designer'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openConfigFile(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['h'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final bytes = result.files.first.bytes;
        String content = '';
        if (bytes != null) {
          content = utf8.decode(bytes);
        } else {
          final path = result.files.first.path;
          if (path != null && !kIsWeb) {
            content = await File(path).readAsString();
          } else {
            throw Exception('Could not read file data');
          }
        }
        
        final match = DesignerState.configPattern.firstMatch(content);
        if (match == null || match.group(1) == null) {
          throw const FormatException('No RadioKit UI Designer block found in file');
        }
        final jsonStr = (match.group(1) as String).trim();
        final decoded = json.decode(jsonStr) as Map<String, dynamic>;
        
        if (!context.mounted) return;
        final provider = context.read<DesignsProvider>();
        final name = (decoded['config']?['name'] as String?) ?? result.files.first.name;
        final id = DateTime.now().millisecondsSinceEpoch.toString();
        
        await provider.saveDesign(id, name, jsonStr);
        
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
