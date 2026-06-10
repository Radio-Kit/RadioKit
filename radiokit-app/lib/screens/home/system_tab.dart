import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../providers/theme_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/designs_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/skin_provider.dart';
import '../../providers/remote_access_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/radiokit_app_bar.dart';
import '../../widgets/api_log_view.dart';
import '../donate_screen.dart';
import 'accounts_sheet.dart';

class SystemTab extends StatelessWidget {
  Widget _buildProVersionCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
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
                    color: AppColors.brandOrange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.workspace_premium_rounded, color: AppColors.brandOrange, size: 28),
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
                          color: AppColors.brandOrange,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Support the project to keep development alive.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
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
                  backgroundColor: AppColors.brandOrange,
                  foregroundColor: Colors.black,
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

  const SystemTab({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    // In landscape mode, don't use Scaffold (parent provides it with its own AppBar)
    if (isLandscape) {
      return _buildContent(context, themeProvider);
    }

    return Scaffold(
      appBar: RadioKitAppBar(
        tabIndex: 3,
        actions: [
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brandOrange.withValues(alpha: 0.15),
              foregroundColor: AppColors.brandOrange,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              minimumSize: const Size(0, 34),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: () => AccountsSheet.show(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_rounded, size: 16, color: AppColors.brandOrange),
                const SizedBox(width: 6),
                Text('Accounts',
                    style: GoogleFonts.changa(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        fontSize: 15,
                        color: AppColors.brandOrange)),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildContent(context, themeProvider),
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
            
            _buildSectionTag(context, '01. ENVIRONMENT'),
            _buildApplicationCard(context, themeProvider),
            
            const SizedBox(height: 32),
            _buildSectionTag(context, '02. SKIN_PACKS'),
            _buildSkinPacksCard(context),

            const SizedBox(height: 32),
            _buildSectionTag(context, '03. ADVANCED_OPTIONS'),
            _buildAdvancedOptionsCard(context),

            const SizedBox(height: 32),
            _buildSectionTag(context, '04. VERSION'),
            _buildAboutCard(context),

            const SizedBox(height: 32),
            _buildSectionTag(context, '05. DANGER_ZONE'),
            _buildDangerZone(context),

            const SizedBox(height: 32),
            _buildAccountsButton(context),
            const SizedBox(height: 32),
          ],
        ),
      );
  }

  Widget _buildAccountsButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => AccountsSheet.show(context),
        icon: Icon(Icons.cloud_rounded, size: 20, color: AppColors.brandOrange),
        label: Text(
          'ACCOUNTS',
          style: GoogleFonts.changa(
            color: AppColors.brandOrange,
            fontWeight: FontWeight.w700,
            fontSize: 14,
            letterSpacing: 1.5,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.brandOrange.withValues(alpha: 0.3)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTag(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            color: AppColors.brandOrange,
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.brandOrange,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkinPacksCard(BuildContext context) {
    final skinProvider = context.watch<SkinProvider>();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/skins'),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.brandOrange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.palette_rounded, color: AppColors.brandOrange, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACTIVE_SKIN',
                      style: GoogleFonts.changa(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 1.5,
                        color: AppColors.brandOrange,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      skinProvider.skinName.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.4)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApplicationCard(BuildContext context, ThemeProvider themeProvider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSettingRow(
              Icons.language_rounded,
              'SYSTEM_LANGUAGE',
              'English (US)',
              null,
            ),
            const SizedBox(height: 12),
            _buildSettingRow(
              themeProvider.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              'INTERFACE_THEME',
              themeProvider.isDarkMode ? 'Dark' : 'Light',
              Switch(
                value: themeProvider.isDarkMode,
                onChanged: (v) => themeProvider.setThemeMode(v ? ThemeMode.dark : ThemeMode.light),
                activeThumbColor: AppColors.brandOrange,
              ),
            ),
            const SizedBox(height: 12),
            _buildSettingRow(
              Icons.devices_rounded,
              'ENABLE_DEMO',
              'Show Demo examples',
              Consumer<SettingsProvider>(
                builder: (context, settings, _) => Switch(
                  value: settings.showDemo,
                  onChanged: (v) => settings.setShowDemo(v),
                  activeThumbColor: AppColors.brandOrange,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildSettingRow(
              Icons.fullscreen_rounded,
              'USE_FULLSCREEN',
              'Immersive mode for controller',
              Consumer<SettingsProvider>(
                builder: (context, settings, _) => Switch(
                  value: settings.useFullscreen,
                  onChanged: (v) => settings.setUseFullscreen(v),
                  activeThumbColor: AppColors.brandOrange,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingRow(IconData icon, String label, String value, Widget? trailing) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.brandOrange.withValues(alpha: 0.7)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
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
        color: Colors.white.withValues(alpha: 0.05),
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
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'v1.0.0',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
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
              color: Colors.white.withValues(alpha: 0.1),
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
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'v4.2.0',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
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
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.brandOrange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.code_rounded, color: AppColors.brandOrange, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ENABLE_DEV_TOOLS',
                        style: GoogleFonts.changa(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 1.5,
                          color: AppColors.brandOrange,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Show Dev Tools tab',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Consumer<SettingsProvider>(
                  builder: (context, settings, _) => Switch(
                    value: settings.enableDevTools,
                    onChanged: (v) => settings.setEnableDevTools(v),
                    activeThumbColor: AppColors.brandOrange,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildRemoteAccessCard(context),
      ],
    );
  }

  Widget _buildRemoteAccessCard(BuildContext context) {
    final ra = context.watch<RemoteAccessProvider>();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
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
                    color: AppColors.brandOrange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.wifi_tethering_rounded, color: AppColors.brandOrange, size: 28),
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
                          color: AppColors.brandOrange,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ra.isRunning ? ra.actualUrl : 'HTTP API for automation & testing',
                        style: TextStyle(
                          color: ra.isRunning
                              ? AppColors.connected
                              : Colors.white.withValues(alpha: 0.6),
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
                  activeThumbColor: AppColors.brandOrange,
                ),
              ],
            ),
            if (ra.isRunning) ...[
              const SizedBox(height: 16),
              _buildSettingRow(
                Icons.navigation_rounded,
                'FOLLOW_REMOTE',
                'Live navigation on API calls',
                Consumer<SettingsProvider>(
                  builder: (context, settings, _) => Switch(
                    value: settings.followRemoteAccess,
                    onChanged: (v) => settings.setFollowRemoteAccess(v),
                    activeThumbColor: AppColors.brandOrange,
                  ),
                ),
              ),
            ],
            if (ra.lastError.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 14, color: Colors.redAccent),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        ra.lastError,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 11),
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
                    color: Colors.black.withValues(alpha: 0.3),
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
        color: Colors.redAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.redAccent.withValues(alpha: 0.8)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              color: Colors.redAccent.withValues(alpha: 0.7),
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
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Confirm Reset'),
        content: const Text('Are you sure you want to remove all saved models? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              context.read<HistoryProvider>().deleteAll();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All models removed')),
              );
            },
            child: Text('REMOVE_ALL', style: GoogleFonts.changa(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.0)),
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
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete All Projects'),
        content: Text(
          count == 0
              ? 'No saved projects to delete.'
              : 'Are you sure you want to delete all $count project(s)? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white38)),
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
              child: Text('DELETE_ALL', style: GoogleFonts.changa(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.0)),
            ),
        ],
      ),
    );
  }
}

