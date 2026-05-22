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

  static const _inputCount = 6;

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);

    return Container(
      width: 80,
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(color: Color(0xFF222222), width: 1),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Text(
            'WIDGETS',
            style: TextStyle(
              color: tokens.primary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildSectionLabel('INPUTS', tokens.primary),
                  ...List.generate(_inputCount, (i) => _buildItem(context, i, tokens)),
                  const SizedBox(height: 8),
                  _buildSectionLabel('OUTPUTS', tokens.primary),
                  ...List.generate(_labels.length - _inputCount,
                      (i) => _buildItem(context, _inputCount + i, tokens)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label, Color primary) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Text(
        label,
        style: TextStyle(
          color: primary.withValues(alpha: 0.6),
          fontSize: 8,
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index, RKTokens tokens) {
    final isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: () => context.go(_routes[index]),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? tokens.primary.withValues(alpha: 0.15) : null,
          border: isSelected
              ? Border(
                  left: BorderSide(color: tokens.primary, width: 2),
                )
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _icons[index],
              color: isSelected ? tokens.primary : const Color(0xFF666666),
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              _labels[index],
              style: TextStyle(
                color: isSelected ? tokens.primary : const Color(0xFF666666),
                fontSize: 8,
                fontFamily: 'monospace',
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

