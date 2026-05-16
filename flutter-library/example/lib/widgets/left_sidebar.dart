import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';

class LeftSidebar extends StatelessWidget {
  const LeftSidebar({super.key, required this.selectedIndex});

  final int selectedIndex;

  static const _labels = [
    'BUTTONS',
    'MULTIPLE',
    'SWITCHES',
    'SLIDERS',
    'KNOBS',
    'JOYSTICKS',
    'DISPLAY',
    'LEDS',
  ];

  static const _routes = [
    '/buttons',
    '/multiple',
    '/switches',
    '/sliders',
    '/knobs',
    '/joysticks',
    '/display',
    '/leds',
  ];

  static const _icons = [
    LucideIcons.squarePower,
    LucideIcons.layoutGrid,
    LucideIcons.toggleRight,
    LucideIcons.settings2,
    LucideIcons.cog,
    LucideIcons.gamepad2,
    LucideIcons.squareTerminal,
    LucideIcons.siren,
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);

    return Container(
      width: 80,
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        border: Border(
          right: BorderSide(color: Color(0xFF222222), width: 1),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Logo area
          Text(
            'WIDGETS',
            style: TextStyle(
              color: tokens.primary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              letterSpacing: 1,
            ),
          ),
          // Navigation icons
          Expanded(
            child: ListView(
              children: [
                _buildSectionHeader(tokens, 'INPUTS'),
                ...List.generate(6, (i) => _buildNavItem(context, i, tokens)),
                const SizedBox(height: 16),
                _buildSectionHeader(tokens, 'OUTPUTS'),
                ...List.generate(2, (i) => _buildNavItem(context, i + 6, tokens)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(RKTokens tokens, String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      alignment: Alignment.center,
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: const Color(0xFF222222))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              title,
              style: TextStyle(
                color: tokens.primary.withValues(alpha: 0.4),
                fontSize: 8,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                letterSpacing: 1.5,
              ),
            ),
          ),
          Expanded(child: Container(height: 1, color: const Color(0xFF222222))),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int i, RKTokens tokens) {
    final isActive = i == selectedIndex;
    return GestureDetector(
      onTap: () => context.go(_routes[i]),
      child: Container(
        width: 80,
        height: 72,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1A1A1A) : null,
          border: Border(
            left: BorderSide(
              color: isActive ? tokens.primary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _icons[i],
              color: isActive ? tokens.primary : const Color(0xFF666666),
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              _labels[i],
              style: TextStyle(
                color: isActive ? tokens.primary : const Color(0xFF666666),
                fontSize: 9,
                fontFamily: 'monospace',
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
