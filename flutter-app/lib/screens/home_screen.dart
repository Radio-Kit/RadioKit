import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const HomeScreen({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: navigationShell.currentIndex,
        onTap: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined, size: 18),
            activeIcon: Icon(Icons.dashboard_rounded, size: 22),
            label: 'MODELS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline_rounded, size: 18),
            activeIcon: Icon(Icons.add_circle_rounded, size: 22),
            label: 'PAIR',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.create_new_folder_outlined, size: 18),
            activeIcon: Icon(Icons.create_new_folder_rounded, size: 22),
            label: 'PROJECTS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined, size: 18),
            activeIcon: Icon(Icons.settings_rounded, size: 22),
            label: 'SYSTEM',
          ),
        ],
      ),
    );
  }
}