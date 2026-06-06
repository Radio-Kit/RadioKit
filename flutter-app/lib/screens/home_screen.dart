import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/remote_access_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/logo_icon.dart';

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
    final ra = context.read<RemoteAccessProvider>();
    ra.followNavigationTarget.addListener(_onFollow);
  }

  @override
  void dispose() {
    context.read<RemoteAccessProvider>().followNavigationTarget
        .removeListener(_onFollow);
    super.dispose();
  }

  static const _allTabRoutes = ['/models', '/pair', '/designs', '/dev-tools', '/system'];

  int _resolveFollowIndex(String route, bool showDevTools) {
    final raw = _allTabRoutes.indexOf(route);
    if (raw < 0) return -1;
    if (showDevTools) return raw;
    if (raw == 3) return -1;
    return raw > 3 ? raw - 1 : raw;
  }

  void _onFollow() {
    final ra = context.read<RemoteAccessProvider>();
    final settings = context.read<SettingsProvider>();
    if (!settings.followRemoteAccess) return;
    final route = ra.consumeFollowTarget();
    if (route == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final idx = _resolveFollowIndex(route, settings.enableDevTools);
      if (idx >= 0) {
        widget.navigationShell.goBranch(idx,
            initialLocation: idx == widget.navigationShell.currentIndex);
      } else {
        try {
          GoRouter.of(context).go(route);
        } catch (e) {
          debugPrint('FollowRemote: go($route) failed: $e');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final showDevTools = settings.enableDevTools;
    final orientation = MediaQuery.of(context).orientation;
    final follow = settings.followRemoteAccess;

    Widget body;
    if (orientation == Orientation.landscape) {
      body = _buildLandscape(context, showDevTools);
    } else {
      body = _buildPortrait(context, showDevTools);
    }

    if (follow) {
      final ra = context.watch<RemoteAccessProvider>();
      body = Stack(
        children: [
          AbsorbPointer(child: body),
          // Edge glow that pulses blue on navigation
          Positioned.fill(
            child: IgnorePointer(
              child: ValueListenableBuilder<Color>(
                valueListenable: ra.glowColor,
                builder: (_, color, __) => Stack(
                  children: [
                    Positioned(top: 0, left: 0, right: 0, height: 20,
                      child: Container(decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [color.withValues(alpha: 0.25), Colors.transparent],
                        ),
                      )),
                    ),
                    Positioned(bottom: 0, left: 0, right: 0, height: 20,
                      child: Container(decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter, end: Alignment.topCenter,
                          colors: [color.withValues(alpha: 0.25), Colors.transparent],
                        ),
                      )),
                    ),
                    Positioned(top: 0, bottom: 0, left: 0, width: 20,
                      child: Container(decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft, end: Alignment.centerRight,
                          colors: [color.withValues(alpha: 0.25), Colors.transparent],
                        ),
                      )),
                    ),
                    Positioned(top: 0, bottom: 0, right: 0, width: 20,
                      child: Container(decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerRight, end: Alignment.centerLeft,
                          colors: [color.withValues(alpha: 0.25), Colors.transparent],
                        ),
                      )),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Red STOP button
          Positioned(
            right: 20,
            bottom: 20,
            child: FloatingActionButton(
              heroTag: 'follow_stop',
              backgroundColor: Colors.redAccent,
              onPressed: () => settings.setFollowRemoteAccess(false),
              child: const Icon(Icons.stop_rounded, color: Colors.white),
            ),
          ),
        ],
      );
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
        icon: Icons.add_circle_outline_rounded,
        activeIcon: Icons.add_circle_rounded,
        label: 'PAIR',
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
    final raw = widget.navigationShell.currentIndex;
    return showDevTools ? raw : (raw >= 3 ? raw : raw);
  }

  int _branchIndex(int visibleIndex) {
    if (visibleIndex < 3) return visibleIndex;
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
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: currentIdx,
            onDestinationSelected: (index) => _onTap(index, showDevTools),
            labelType: NavigationRailLabelType.all,
            backgroundColor: theme.colorScheme.surface,
            indicatorColor: Colors.transparent,
            minWidth: 80,
            leading: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              child: Transform.scale(
                scale: 2.0,
                child: const LogoIcon(),
              ),
            ),
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