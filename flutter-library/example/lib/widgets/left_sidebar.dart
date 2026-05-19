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
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(color: Color(0xFF222222), width: 1),
        ),
      ),
      child: NavigationRail(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => context.go(_routes[index]),
        labelType: NavigationRailLabelType.all,
        backgroundColor: const Color(0xFF111111),
        indicatorColor: tokens.primary.withValues(alpha: 0.15),
        minWidth: 80,
        leading: Column(
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
            const SizedBox(height: 20),
          ],
        ),
        selectedIconTheme: IconThemeData(
          color: tokens.primary,
          size: 24,
        ),
        unselectedIconTheme: const IconThemeData(
          color: Color(0xFF666666),
          size: 24,
        ),
        selectedLabelTextStyle: TextStyle(
          color: tokens.primary,
          fontSize: 9,
          fontFamily: 'monospace',
          letterSpacing: 0.5,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: Color(0xFF666666),
          fontSize: 9,
          fontFamily: 'monospace',
          letterSpacing: 0.5,
        ),
        destinations: List.generate(_labels.length, (i) {
          return NavigationRailDestination(
            icon: Icon(_icons[i]),
            label: Text(_labels[i]),
          );
        }),
      ),
    );
  }
}

