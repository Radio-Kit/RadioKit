import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../theme/app_theme.dart';
import '../../widgets/radiokit_app_bar.dart';

class DevToolsTab extends StatelessWidget {
  const DevToolsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    // In landscape mode, don't use Scaffold (parent provides it)
    if (isLandscape) {
      return _buildContent(context);
    }

    return Scaffold(
      appBar: RadioKitAppBar(
        accentColor: context.tokens.primary,
      ),
      body: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DEV TOOLS',
            style: GoogleFonts.changa(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: context.tokens.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          _ToolCard(
            icon: LucideIcons.cable,
            title: 'USB Serial Monitor',
            subtitle: 'Monitor and send serial data over USB',
            onTap: () => context.push('/dev-tools/usb-serial'),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            icon: LucideIcons.hardDrive,
            title: 'Filesystem Explorer',
            subtitle: 'Browse, upload, rename, and format the device partition',
            onTap: () => context.push('/dev-tools/esp32-fs'),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            icon: LucideIcons.zap,
            title: 'Firmware Flasher',
            subtitle: 'Flash firmware to MCU via USB',
            onTap: () => context.push('/dev-tools/firmware-flasher'),
          ),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.tokens.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.tokens.onSurface.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.tokens.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 22, color: context.tokens.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: context.tokens.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: context.tokens.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: context.tokens.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
