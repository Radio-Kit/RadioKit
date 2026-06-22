import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';
import '../../providers/theme_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/designs_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_preset_provider.dart';
import '../../providers/remote_access_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/radiokit_app_bar.dart';
import '../../widgets/api_log_view.dart';
import '../donate_screen.dart';
import 'accounts_sheet.dart';

class SystemTab extends StatefulWidget {
  const SystemTab({super.key});

  @override
  State<SystemTab> createState() => _SystemTabState();
}

class _SystemTabState extends State<SystemTab> {
  bool _sheetOpened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _sheetOpened) return;
      _sheetOpened = true;
      final sheet = GoRouterState.of(context).uri.queryParameters['sheet'];
      if (sheet == 'accounts') {
        AccountsSheet.show(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    if (isLandscape) {
      return _buildContent(context, themeProvider);
    }

    return Scaffold(
      appBar: RadioKitAppBar(
        tabIndex: 3,
        onAccounts: () => AccountsSheet.show(context),
        accentColor: context.tokens.primary,
      ),
      body: _buildContent(context, themeProvider),
    );
  }

  Widget _buildProVersionCard(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: context.tokens.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: tokens.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.workspace_premium_rounded, color: tokens.primary, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'UPGRADE TO PRO',
                        style: GoogleFonts.changa(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 1.5,
                          color: tokens.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Support the project to keep development alive.',
                        style: TextStyle(
                          color: tokens.onSurface.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: tokens.primary,
                  foregroundColor: tokens.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                onPressed: () => DonateBottomSheet.show(context),
                child: Text(
                  'GET PRO VERSION',
                  style: GoogleFonts.changa(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ThemeProvider themeProvider) {
    return NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is OverscrollNotification && notification.overscroll > 50) {
            DonateBottomSheet.show(context);
            return true;
          }
          return false;
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            const SizedBox(height: 8),
            
            _buildProVersionCard(context),
            const SizedBox(height: 16),
            
            _buildSectionTag(context, '01. CLOUD'),
            _buildCloudCard(context),
            
            const SizedBox(height: 32),
            _buildSectionTag(context, '02. ENVIRONMENT'),
            _buildApplicationCard(context, themeProvider),
            
            const SizedBox(height: 32),
            _buildSectionTag(context, '03. CONTROL_UI'),
            _buildControlUiCard(context),

            const SizedBox(height: 32),
            _buildSectionTag(context, '04. ADVANCED_OPTIONS'),
            _buildAdvancedOptionsCard(context),

            const SizedBox(height: 32),
            _buildSectionTag(context, '05. VERSION'),
            _buildAboutCard(context),

            const SizedBox(height: 32),
            _buildSectionTag(context, '06. DANGER_ZONE'),
            _buildDangerZone(context),
            const SizedBox(height: 32),
          ],
        ),
      );
  }

  Widget _buildCloudCard(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: context.tokens.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => AccountsSheet.show(context),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: tokens.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.cloud_rounded, color: tokens.primary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MANAGE_ACCOUNTS',
                      style: GoogleFonts.changa(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 1.5,
                        color: tokens.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create or edit cloud relay accounts',
                      style: TextStyle(
                        color: tokens.onSurface.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: tokens.onSurface.withValues(alpha: 0.3)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTag(BuildContext context, String title) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            color: tokens.primary,
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: tokens.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlUiCard(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: context.tokens.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: tokens.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.gamepad_rounded, color: tokens.primary, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'USE_FULLSCREEN',
                        style: GoogleFonts.changa(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 1.5,
                          color: tokens.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                    Text(
                      'Immersive mode for controller',
                      style: TextStyle(
                        color: tokens.onSurface.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Consumer<SettingsProvider>(
                  builder: (context, settings, _) => Switch(
                    value: settings.useFullscreen,
                    onChanged: (v) => settings.setUseFullscreen(v),
                    activeThumbColor: tokens.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplicationCard(BuildContext context, ThemeProvider themeProvider) {
    final tokens = context.tokens;
    final themePresetProvider = context.watch<ThemePresetProvider>();
    return Container(
      decoration: BoxDecoration(
        color: context.tokens.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSettingRow(context,
              Icons.language_rounded,
              'SYSTEM_LANGUAGE',
              'English (US)',
              null,
            ),
            const SizedBox(height: 12),
            _buildSettingRow(context,
              Icons.palette_rounded,
              'INTERFACE_THEME',
              themePresetProvider.themeName.toUpperCase(),
              DropdownButton<String>(
                value: themePresetProvider.themeName,
                underline: const SizedBox(),
                isDense: true,
                dropdownColor: context.tokens.base300,                          style: TextStyle(
                            color: context.tokens.onSurface,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
                onChanged: (v) {
                  if (v == null) return;
                  themePresetProvider.setTheme(v);
                  final preset = RKTokens.presetsByName[v];
                  themeProvider.setThemeMode(
                    preset?.isDark == true ? ThemeMode.dark : ThemeMode.light,
                  );
                },
                items: themePresetProvider.availableThemes
                    .map((p) => DropdownMenuItem<String>(
                          value: p,
                          child: Text(p.toUpperCase()),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),
            _buildSettingRow(context,
              Icons.devices_rounded,
              'ENABLE_DEMO',
              'Show Demo examples',
              Consumer<SettingsProvider>(
                builder: (context, settings, _) => Switch(
                  value: settings.showDemo,
                  onChanged: (v) => settings.setShowDemo(v),
                  activeThumbColor: tokens.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingRow(BuildContext context, IconData icon, String label, String value, Widget? trailing) {
    return Row(
      children: [
        Icon(icon, size: 18, color: context.tokens.primary.withValues(alpha: 0.7)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: context.tokens.onSurface.withValues(alpha: 0.6),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: context.tokens.onSurface.withValues(alpha: 0.9),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildAboutCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.tokens.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'APP_VERSION',
                    style: TextStyle(
                      color: context.tokens.onSurface.withValues(alpha: 0.5),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'v1.0.0',
                    style: TextStyle(
                      color: context.tokens.onSurface.withValues(alpha: 0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 32,
              color: context.tokens.onSurface.withValues(alpha: 0.1),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Text(
                    'FIRMWARE_VERSION',
                    style: TextStyle(
                      color: context.tokens.onSurface.withValues(alpha: 0.5),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'v4.2.0',
                    style: TextStyle(
                      color: context.tokens.onSurface.withValues(alpha: 0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedOptionsCard(BuildContext context) {
    return Column(
      children: [
        _buildRemoteAccessCard(context),
      ],
    );
  }

  Widget _buildRemoteAccessCard(BuildContext context) {
    final tokens = context.tokens;
    final ra = context.watch<RemoteAccessProvider>();

    return Container(
      decoration: BoxDecoration(
        color: context.tokens.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: tokens.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.wifi_tethering_rounded, color: tokens.primary, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'REMOTE_ACCESS',
                        style: GoogleFonts.changa(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 1.5,
                          color: tokens.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ra.isRunning ? ra.actualUrl : 'HTTP API for automation & testing',
                        style: TextStyle(
                          color: ra.isRunning
                              ? tokens.success
                              : tokens.onSurface.withValues(alpha: 0.6),
                          fontSize: ra.isRunning ? 12 : 11,
                          fontFamily: ra.isRunning ? 'monospace' : null,
                          fontWeight: ra.isRunning ? FontWeight.w600 : null,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: ra.isRunning,
                  onChanged: (_) => ra.toggle(),
                  activeThumbColor: tokens.primary,
                ),
              ],
            ),
            if (ra.isRunning) ...[
              const SizedBox(height: 16),
              _buildSettingRow(context,
                Icons.navigation_rounded,
                'FOLLOW_REMOTE',
                'Live navigation on API calls',
                Consumer<SettingsProvider>(
                  builder: (context, settings, _) => Switch(
                    value: settings.followRemoteAccess,
                    onChanged: (v) => settings.setFollowRemoteAccess(v),
                    activeThumbColor: tokens.primary,
                  ),
                ),
              ),
            ],
            if (ra.lastError.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.tokens.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 14, color: context.tokens.error),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        ra.lastError,
                        style: TextStyle(color: context.tokens.error, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (ra.isRunning && ra.logs.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    color: context.tokens.base200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ApiLogView(height: 160),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDangerZone(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDangerAction(
          context,
          icon: Icons.devices_other_rounded,
          label: 'REMOVE_MODELS',
          subtitle: 'Remove all paired models',
          onPressed: () => _confirmRemoveModels(context),
        ),
        const SizedBox(height: 12),
        _buildDangerAction(
          context,
          icon: Icons.folder_delete_rounded,
          label: 'DELETE_PROJECTS',
          subtitle: 'Delete all saved designs',
          onPressed: () => _confirmDeleteProjects(context),
        ),
      ],
    );
  }

  Widget _buildDangerAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.tokens.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: context.tokens.error.withValues(alpha: 0.8)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: context.tokens.onSurface.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: context.tokens.onSurface.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              color: context.tokens.error.withValues(alpha: 0.7),
              onPressed: onPressed,
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemoveModels(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.tokens.base300,
        title: const Text('Confirm Reset'),
        content: const Text('Are you sure you want to remove all saved models? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL', style: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.38))),
          ),
          TextButton(
            onPressed: () {
              context.read<HistoryProvider>().deleteAll();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All models removed')),
              );
            },
            child: Text('REMOVE_ALL', style: GoogleFonts.changa(color: context.tokens.error, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.0)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteProjects(BuildContext context) {
    final designs = context.read<DesignsProvider>().designs;
    final count = designs.length;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.tokens.base300,
        title: const Text('Delete All Projects'),
        content: Text(
          count == 0
              ? 'No saved projects to delete.'
              : 'Are you sure you want to delete all $count project(s)? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL', style: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.38))),
          ),
          if (count > 0)
            TextButton(
              onPressed: () {
                context.read<DesignsProvider>().deleteAll();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All projects deleted')),
                );
              },
              child: Text('DELETE_ALL', style: GoogleFonts.changa(color: context.tokens.error, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.0)),
            ),
        ],
      ),
    );
  }
}
