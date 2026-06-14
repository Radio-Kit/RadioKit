import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../widgets/radiokit_app_bar.dart';
import 'home/designs_tab.dart';
import 'home/pair_sheet.dart';
import 'home/accounts_sheet.dart';

class HomeScreen extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const HomeScreen({super.key, required this.navigationShell});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;

    if (orientation == Orientation.landscape) {
      return _buildLandscape(context);
    }
    return _buildPortrait(context);
  }

  // ─── Shared data ────────────────────────────────────────────────

  static const _navItems = [
    _NavItem(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
      label: 'MODELS',
    ),
    _NavItem(
      icon: Icons.create_new_folder_outlined,
      activeIcon: Icons.create_new_folder_rounded,
      label: 'PROJECTS',
    ),
    _NavItem(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
      label: 'SYSTEM',
    ),
  ];

  void _onTap(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  // ─── Portrait: BottomNavigationBar ────────────────────────────

  Widget _buildPortrait(BuildContext context) {
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: widget.navigationShell.currentIndex,
        onTap: _onTap,
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
        items: _navItems
            .map((e) => BottomNavigationBarItem(
                  icon: Icon(e.icon, size: 18),
                  activeIcon: Icon(e.activeIcon, size: 22),
                  label: e.label,
                ))
            .toList(),
      ),
    );
  }

  // ─── Landscape: NavigationRail ─────────────────────────────────

  Widget _buildLandscape(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(        appBar: RadioKitAppBar(
        tabIndex: widget.navigationShell.currentIndex,
        onConnect: () => showPairBottomSheet(context),
        onOpen: () => openConfigFile(context),
        onCreate: () => context.push('/designer'),
        onAccounts: () => AccountsSheet.show(context),
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: widget.navigationShell.currentIndex,
            onDestinationSelected: _onTap,
            labelType: NavigationRailLabelType.all,
            backgroundColor: theme.colorScheme.surface,
            indicatorColor: Colors.transparent,
            minWidth: 60,
            selectedIconTheme: const IconThemeData(
              color: AppColors.brandOrange,
              size: 22,
            ),
            unselectedIconTheme: IconThemeData(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.38),
              size: 18,
            ),
            selectedLabelTextStyle: GoogleFonts.changa(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: AppColors.brandOrange,
            ),
            unselectedLabelTextStyle: GoogleFonts.changa(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.0,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.38),
            ),
            destinations: _navItems
                .map((e) => NavigationRailDestination(
                      icon: Icon(e.icon),
                      selectedIcon: Icon(e.activeIcon),
                      label: Text(e.label),
                    ))
                .toList(),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: widget.navigationShell),
        ],
      ),
    );
  }
}

// ─── Helper ─────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}