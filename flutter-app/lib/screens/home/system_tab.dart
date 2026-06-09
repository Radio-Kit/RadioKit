import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../providers/theme_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/skin_provider.dart';
import '../../providers/remote_access_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/radiokit_app_bar.dart';
import '../../widgets/api_log_view.dart';
import '../donate_screen.dart';

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
    
    return Scaffold(
      appBar: RadioKitAppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.sensors_rounded, size: 20),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: NotificationListener<ScrollNotification>(
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
            _buildSectionTag(context, '04. HARDWARE_METRICS'),
            _buildAboutCard(context),

            const SizedBox(height: 48),
            _buildDangerZone(context),
            const SizedBox(height: 32),
          ],
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
              themeProvider.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              'INTERFACE_THEME',
              themeProvider.isDarkMode ? 'Dark' : 'Light',
              Switch(
                value: themeProvider.isDarkMode,
                onChanged: (v) => themeProvider.setThemeMode(v ? ThemeMode.dark : ThemeMode.light),
                activeThumbColor: AppColors.brandOrange,
              ),
            ),
            const SizedBox(height: 20),
            _buildSettingRow(
              Icons.language_rounded,
              'SYSTEM_LANGUAGE',
              'English (US)',
              null,
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
              child: const Icon(Icons.info_outline_rounded, color: AppColors.brandOrange, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FIRMWARE_VERSION',
                    style: GoogleFonts.changa(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 1.5,
                      color: AppColors.brandOrange,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'v4.2.0-STABLE',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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
            if (!ra.isRunning && ra.lastError.isEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.pause_circle_outline, size: 14, color: Colors.white.withValues(alpha: 0.4)),
                  const SizedBox(width: 8),
                  Text(
                    'Server stopped',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                  ),
                ],
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.redAccent.withValues(alpha: 0.2),
          width: 1,
        ),
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
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DANGER_ZONE',
                        style: GoogleFonts.changa(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 1.5,
                          color: Colors.redAccent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This will remove all paired models',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 11,
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
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                onPressed: () => _confirmRemoveModels(context),
                child: Text(
                  'REMOVE_MODELS',
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
}

