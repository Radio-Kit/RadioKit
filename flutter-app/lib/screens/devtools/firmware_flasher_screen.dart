import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../theme/app_theme.dart';

class FirmwareFlasherScreen extends StatelessWidget {
  const FirmwareFlasherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Firmware Flasher',
          style: GoogleFonts.changa(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.zap, size: 64, color: AppColors.brandOrange.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'Firmware Flasher',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Coming soon',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.brandGray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
