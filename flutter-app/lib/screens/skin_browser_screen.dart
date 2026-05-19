import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';
import '../widgets/radiokit_app_bar.dart';
import '../providers/skin_provider.dart';
import '../theme/app_theme.dart';

/// Theme picker screen showing available RKTokens presets.
class SkinBrowserScreen extends StatelessWidget {
  const SkinBrowserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final skinProvider = context.watch<SkinProvider>();
    final activeName = skinProvider.skinName;
    final presets = skinProvider.availablePresets;

    return Scaffold(
      appBar: RadioKitAppBar(),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: presets.length,
        itemBuilder: (context, index) {
          final name = presets[index];
          final tokens = kTokenPresets[name]!;
          final isActive = name == activeName;
          return _ThemeCard(
            name: name,
            tokens: tokens,
            isActive: isActive,
            onApply: () => skinProvider.setSkin(name),
          );
        },
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final String name;
  final RKTokens tokens;
  final bool isActive;
  final VoidCallback onApply;

  const _ThemeCard({
    required this.name,
    required this.tokens,
    required this.isActive,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    // Build a preview swatch from the token colors
    final previewColors = [
      tokens.primary,
      tokens.surface,
      tokens.trackColor,
      tokens.onSurface,
    ];

    final description = _presetDescription(name);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isActive
          ? AppColors.brandOrange.withValues(alpha: 0.1)
          : Colors.white.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActive
              ? AppColors.brandOrange.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.08),
          width: isActive ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Color palette preview
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.black.withValues(alpha: 0.3),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Column(
                  children: [
                    for (final c in previewColors)
                      Expanded(child: Container(color: c)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Metadata
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name.toUpperCase(),
                        style: GoogleFonts.exo2(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (isActive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.brandOrange,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'ACTIVE',
                            style: GoogleFonts.changa(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Apply button
            if (!isActive)
              TextButton(
                onPressed: onApply,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.brandOrange,
                ),
                child: Text(
                  'APPLY',
                  style: GoogleFonts.changa(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _presetDescription(String name) {
    switch (name) {
      case 'rambros':
        return 'Industrial orange theme with mechanical aesthetics';
      case 'neon':
        return 'Cyberpunk cyan glow with dark surface';
      case 'minimal':
        return 'Monochrome wireframe with zero-decoration';
      case 'debug':
        return 'High-visibility green-on-black for development';
      default:
        return '';
    }
  }
}
