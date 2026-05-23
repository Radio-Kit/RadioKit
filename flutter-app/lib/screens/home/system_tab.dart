import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../providers/theme_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/skin_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/radiokit_app_bar.dart';
import '../donate_screen.dart';

class SystemTab extends StatelessWidget {
  Widget _buildProVersionCard(BuildContext context) {
    return Card(
      color: Colors.white.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.brandOrange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.star, color: AppColors.brandOrange, size: 20),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SettingLabel(label: 'GET_PRO_VERSION', value: ''),
                      SizedBox(height: 8),
                      Text(
                        'Support the project to keep development alive.',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandOrange,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  elevation: 0,
                ),
                onPressed: () => DonateBottomSheet.show(context),
                child: Text('GET_PRO_VERSION', style: GoogleFonts.changa(fontWeight: FontWeight.w700, letterSpacing: 1.2, fontSize: 13)),
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
      body: ListView(
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
          _buildSectionTag(context, '03. HARDWARE_METRICS'),
          _buildAboutCard(context),
          
          const SizedBox(height: 48),
          _buildDangerZone(context),
          const SizedBox(height: 32),
        ],
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
    return Card(
      color: Colors.white.withValues(alpha: 0.05),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/skins'),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.brandOrange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.palette_outlined, color: AppColors.brandOrange, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SettingLabel(label: 'ACTIVE_SKIN', value: ''),
                    Text(
                      skinProvider.skinName.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApplicationCard(BuildContext context, ThemeProvider themeProvider) {
    return Card(
      color: Colors.white.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SettingLabel(label: 'INTERFACE_THEME', value: 'Kinetic Dark'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _ThemeToggleOption(
                      label: 'DARK',
                      isActive: themeProvider.isDarkMode,
                      onTap: () => themeProvider.setThemeMode(ThemeMode.dark),
                    ),
                  ),
                  Expanded(
                    child: _ThemeToggleOption(
                      label: 'LIGHT',
                      isActive: !themeProvider.isDarkMode,
                      onTap: () => themeProvider.setThemeMode(ThemeMode.light),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _SettingLabel(label: 'SYSTEM_LANGUAGE', value: 'English (US)'),
                Icon(Icons.language_rounded, color: AppColors.brandOrange.withValues(alpha: 0.7), size: 20),
              ],
            ),
            const Divider(height: 32, color: Colors.white10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: _SettingLabel(label: 'ENABLE_DEMO', value: 'Show Demo examples'),
                ),
                Consumer<SettingsProvider>(
                  builder: (context, settings, _) => Switch(
                    value: settings.showDemo,
                    onChanged: (v) => settings.setShowDemo(v),
                    activeThumbColor: AppColors.brandOrange,
                  ),
                ),
              ],
            ),
            const Divider(height: 32, color: Colors.white10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: _SettingLabel(label: 'USE_FULLSCREEN', value: 'Immersive mode for controller'),
                ),
                Consumer<SettingsProvider>(
                  builder: (context, settings, _) => Switch(
                    value: settings.useFullscreen,
                    onChanged: (v) => settings.setUseFullscreen(v),
                    activeThumbColor: AppColors.brandOrange,
                  ),
                ),
              ],
            ),
            const Divider(height: 32, color: Colors.white10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: _SettingLabel(label: 'ENABLE_DEV_TOOLS', value: 'Show Dev Tools tab'),
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
          ],
        ),
      ),
    );
  }

  Widget _buildAboutCard(BuildContext context) {
    return Card(
      color: Colors.white.withValues(alpha: 0.05),
      child: const Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SettingLabel(label: 'FIRMWARE_VERSION', value: 'v4.2.0-STABLE'),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerZone(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 64, color: Colors.white10),
                  Icon(Icons.priority_high_rounded, size: 24, color: Colors.redAccent),
                ],
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DANGER_ZONE',
                    style: GoogleFonts.exo2(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      color: Colors.redAccent.withValues(alpha: 0.9),
                    ),
                  ),
                  const Text(
                    'This will remove all paired models',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                elevation: 0,
              ),
              onPressed: () => _confirmRemoveModels(context),
              child: Text('REMOVE_MODELS', style: GoogleFonts.changa(fontWeight: FontWeight.w700, letterSpacing: 1.2, fontSize: 13)),
            ),
          ),
        ],
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

class _SettingLabel extends StatelessWidget {
  final String label;
  final String value;
  const _SettingLabel({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 0.5),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _ThemeToggleOption extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ThemeToggleOption({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.changa(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? Colors.white : Colors.white38,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}