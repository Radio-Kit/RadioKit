import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const HomeScreen({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final showDevTools = context.watch<SettingsProvider>().enableDevTools;

    final items = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(
        icon: Icon(Icons.dashboard_outlined, size: 18),
        activeIcon: Icon(Icons.dashboard_rounded, size: 22),
        label: 'MODELS',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.add_circle_outline_rounded, size: 18),
        activeIcon: Icon(Icons.add_circle_rounded, size: 22),
        label: 'PAIR',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.create_new_folder_outlined, size: 18),
        activeIcon: Icon(Icons.create_new_folder_rounded, size: 22),
        label: 'PROJECTS',
      ),
      if (showDevTools)
        const BottomNavigationBarItem(
          icon: Icon(Icons.handyman_outlined, size: 18),
          activeIcon: Icon(Icons.handyman_rounded, size: 22),
          label: 'DEV_TOOLS',
        ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.settings_outlined, size: 18),
        activeIcon: Icon(Icons.settings_rounded, size: 22),
        label: 'SYSTEM',
      ),
    ];

    final rawIndex = navigationShell.currentIndex;
    final currentIdx = showDevTools
        ? rawIndex
        : (rawIndex >= 3 ? 3 : rawIndex);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: currentIdx,
        onTap: (index) {
          final branchIndex = showDevTools ? index : _branchIndex(index);
          navigationShell.goBranch(
            branchIndex,
            initialLocation: branchIndex == navigationShell.currentIndex,
          );
        },
        selectedItemColor: AppColors.brandOrange,
        unselectedItemColor:
            Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
        selectedLabelStyle: GoogleFonts.changa(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
        unselectedLabelStyle: GoogleFonts.changa(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.0,
        ),
        items: items,
      ),
    );
  }

  int _branchIndex(int visibleIndex) {
    if (visibleIndex < 3) return visibleIndex;
    return visibleIndex + 1;
  }
}