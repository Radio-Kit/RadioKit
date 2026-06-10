import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
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
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final showDevTools = settings.enableDevTools;
    final orientation = MediaQuery.of(context).orientation;

    Widget body;
    if (orientation == Orientation.landscape) {
      body = _buildLandscape(context, showDevTools);
    } else {
      body = _buildPortrait(context, showDevTools);
    }

    return body;
  }

  // ─── Shared data ────────────────────────────────────────────────

  List<_NavItem> _buildNavItems(bool showDevTools) {
    return [
      const _NavItem(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard_rounded,
        label: 'MODELS',
      ),
      const _NavItem(
        icon: Icons.create_new_folder_outlined,
        activeIcon: Icons.create_new_folder_rounded,
        label: 'PROJECTS',
      ),
      if (showDevTools)
        const _NavItem(
          icon: Icons.handyman_outlined,
          activeIcon: Icons.handyman_rounded,
          label: 'DEV_TOOLS',
        ),
      const _NavItem(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings_rounded,
        label: 'SYSTEM',
      ),
    ];
  }

  int _resolvedIndex(bool showDevTools) {
    final branchIdx = widget.navigationShell.currentIndex;
    if (showDevTools) return branchIdx;
    // Without DEV_TOOLS: branch 0→0, 1→1, 2(hidden), 3→2
    if (branchIdx >= 2) return branchIdx - 1;
    return branchIdx;
  }

  int _branchIndex(int visibleIndex) {
    if (visibleIndex < 2) return visibleIndex;
    return visibleIndex + 1;
  }

  void _onTap(int visibleIndex, bool showDevTools) {
    final branchIndex = showDevTools ? visibleIndex : _branchIndex(visibleIndex);
    widget.navigationShell.goBranch(
      branchIndex,
      initialLocation: branchIndex == widget.navigationShell.currentIndex,
    );
  }

  // ─── Portrait: BottomNavigationBar ────────────────────────────

  Widget _buildPortrait(BuildContext context, bool showDevTools) {
    final items = _buildNavItems(showDevTools);
    final currentIdx = _resolvedIndex(showDevTools);

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: currentIdx,
        onTap: (index) => _onTap(index, showDevTools),
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
        items: items
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

  Widget _buildLandscape(BuildContext context, bool showDevTools) {
    final items = _buildNavItems(showDevTools);
    final currentIdx = _resolvedIndex(showDevTools);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: RadioKitAppBar(
        tabIndex: currentIdx,
        onConnect: () => showPairBottomSheet(context),
        onOpen: () => openConfigFile(context),
        onCreate: () => context.push('/designer'),
        onAccounts: () => AccountsSheet.show(context),
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: currentIdx,
            onDestinationSelected: (index) => _onTap(index, showDevTools),
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
            destinations: items
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