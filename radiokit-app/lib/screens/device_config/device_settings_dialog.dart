import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/device_provider.dart';
import '../../services/ble_service_impl.dart';
import '../../services/serial_service_native.dart';
import '../../services/websocket_service.dart';
import '../../theme/app_theme.dart';

/// Full-screen dialog for editing device settings (name, description,
/// passwords) and performing a factory reset.
///
/// Each field tracks its original value and shows a per-field save
/// button only when the value has been changed by the user.
class DeviceSettingsDialog extends StatefulWidget {
  const DeviceSettingsDialog({super.key});

  /// Show the dialog as a full-screen modal bottom sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.tokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => const DeviceSettingsDialog(),
    );
  }

  @override
  State<DeviceSettingsDialog> createState() => _DeviceSettingsDialogState();
}

class _DeviceSettingsDialogState extends State<DeviceSettingsDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _pwdCtrl;
  late TextEditingController _adminPwdCtrl;

  // Track original values to detect changes
  String _originalName = '';
  String _originalDesc = '';
  bool _pwdVisible = false;
  bool _adminPwdVisible = false;
  bool _savingName = false;
  bool _savingDesc = false;
  bool _savingPwd = false;
  bool _savingAdminPwd = false;

  // Transport toggles (UI only — functionality added later)
  bool _bleEnabled = true;
  bool _wifiEnabled = false;
  bool _cloudEnabled = false;

  @override
  void initState() {
    super.initState();
    final dp = context.read<DeviceProvider>();
    _originalName = dp.configName ?? '';
    _originalDesc = dp.description ?? '';
    _nameCtrl = TextEditingController(text: _originalName);
    _descCtrl = TextEditingController(text: _originalDesc);
    _pwdCtrl = TextEditingController();
    _adminPwdCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _pwdCtrl.dispose();
    _adminPwdCtrl.dispose();
    super.dispose();
  }

  bool get _nameChanged => _nameCtrl.text.trim() != _originalName;
  bool get _descChanged => _descCtrl.text.trim() != _originalDesc;
  bool get _pwdChanged => _pwdCtrl.text.trim().isNotEmpty;
  bool get _adminPwdChanged => _adminPwdCtrl.text.trim().isNotEmpty;

  /// Returns the transport type name if connected, null otherwise.
  String? _connectedTransportName(DeviceProvider dp) {
    if (!dp.isConnected) return null;
    final t = dp.currentTransport;
    if (t is BleService) return 'BLE';
    if (t is WebSocketService) return 'WIFI';
    if (t is SerialService) return 'Serial';
    return null;
  }

  /// Shows confirmation if disabling the currently connected transport.
  Future<bool> _confirmDisableTransport(DeviceProvider dp, String transport) async {
    final connectedVia = _connectedTransportName(dp);
    if (connectedVia != transport) return true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.warning_rounded, color: context.tokens.warning, size: 32),
        title: const Text('Disconnect Device?'),
        content: Text(
          'Connected via $transport. Disabling this will cause the device to disconnect.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: context.tokens.warning.withValues(alpha: 0.2),
              foregroundColor: context.tokens.warning,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('DISABLE'),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DeviceProvider>();
    final deviceName = dp.configName ?? 'Device';

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Transform.translate(
        offset: const Offset(0, -18),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.tokens.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.tune_rounded,
                      color: context.tokens.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(deviceName.toUpperCase(),
                          style: GoogleFonts.exo2(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                              color: context.tokens.onSurface)),
                      Text('DEVICE SETTINGS',
                          style: TextStyle(
                              color: context.tokens.onSurface.withValues(alpha: 0.38),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1)),
                    ],
                  ),
                ),
              ]),
              SizedBox(height: 24),
              Divider(height: 1, color: context.tokens.onSurface.withValues(alpha: 0.12)),
              const SizedBox(height: 24),

              // ── MODEL_INFO section ─────────────────────────
              _buildSectionTag('MODEL_INFO'),
              const SizedBox(height: 16),

              _buildSaveField(
                label: 'NAME',
                ctrl: _nameCtrl,
                isChanged: _nameChanged,
                saving: _savingName,
                onSave: () => _saveField(dp, 'name'),
              ),
              const SizedBox(height: 16),

              _buildSaveField(
                label: 'DESCRIPTION',
                ctrl: _descCtrl,
                isChanged: _descChanged,
                saving: _savingDesc,
                onSave: () => _saveField(dp, 'description'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              _buildSaveField(
                label: 'CONNECTION PASSWORD (leave empty to clear)',
                ctrl: _pwdCtrl,
                isChanged: _pwdChanged,
                saving: _savingPwd,
                onSave: () => _saveField(dp, 'password'),
                isPassword: true,
                pwdVisible: _pwdVisible,
                onTogglePwd: () => setState(() => _pwdVisible = !_pwdVisible),
              ),
              const SizedBox(height: 16),

              _buildSaveField(
                label: 'ADMIN PASSWORD (leave empty to clear)',
                ctrl: _adminPwdCtrl,
                isChanged: _adminPwdChanged,
                saving: _savingAdminPwd,
                onSave: () => _saveField(dp, 'adminPassword'),
                isPassword: true,
                pwdVisible: _adminPwdVisible,
                onTogglePwd: () =>
                    setState(() => _adminPwdVisible = !_adminPwdVisible),
                isAdmin: true,
              ),
              const SizedBox(height: 32),

              // ── CONNECTION section ──────────────────────────
              _buildSectionTag('CONNECTION'),
              const SizedBox(height: 16),

              _buildTransportRow(
                icon: Icons.bluetooth_rounded,
                label: 'BLE',
                subtitle: 'Bluetooth Low Energy',
                enabled: _bleEnabled,
                onChanged: (v) async {
                  if (!v) {
                    final ok = await _confirmDisableTransport(dp, 'BLE');
                    if (!ok) return;
                  }
                  setState(() => _bleEnabled = v);
                },
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: context.tokens.onSurface.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.wifi_rounded, size: 20, color: _wifiEnabled ? context.tokens.primary : context.tokens.onSurface.withValues(alpha: 0.38)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('WIFI',
                                  style: TextStyle(
                                      color: _wifiEnabled ? context.tokens.onSurface : context.tokens.onSurface.withValues(alpha: 0.54),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text('Wireless network',
                                  style: TextStyle(
                                      color: context.tokens.onSurface.withValues(alpha: 0.4),
                                      fontSize: 11)),
                            ],
                          ),
                        ),
                        Switch(
                          value: _wifiEnabled,
                          onChanged: (v) async {
                            if (!v) {
                              final ok = await _confirmDisableTransport(dp, 'WIFI');
                              if (!ok) return;
                            }
                            setState(() {
                              _wifiEnabled = v;
                              if (!v) _cloudEnabled = false;
                            });
                          },
                          activeThumbColor: context.tokens.primary,
                        ),
                      ],
                    ),
                    if (_wifiEnabled) ...[
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1, color: context.tokens.onSurface.withValues(alpha: 0.1)),
                      ),
                      _buildSettingRow(
                        Icons.cloud_rounded,
                        'CLOUD',
                        'Remote access over internet',
                        Switch(
                          value: _cloudEnabled,
                          onChanged: (v) => setState(() => _cloudEnabled = v),
                          activeThumbColor: context.tokens.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── Factory Reset ────────────────────────────────
              _buildSectionTag('FACTORY_RESET'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.tokens.error,
                    side: BorderSide(
                        color: context.tokens.error.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                  ),
                  icon: const Icon(Icons.restart_alt_rounded, size: 20),
                  label: Text('FACTORY RESET',
                      style: GoogleFonts.changa(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          fontSize: 12)),
                  onPressed: () => _factoryReset(dp),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Erase all settings (name, description, password) '
                'and reboot the device. Compile-time defaults will be restored.',
                style: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.38), fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTag(String title) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          color: context.tokens.primary,
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.changa(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 1.5,
            color: context.tokens.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildTransportRow({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.tokens.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: enabled ? context.tokens.primary : context.tokens.onSurface.withValues(alpha: 0.38)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: enabled ? context.tokens.onSurface : context.tokens.onSurface.withValues(alpha: 0.54),
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        color: context.tokens.onSurface.withValues(alpha: 0.4),
                        fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: onChanged,
            activeThumbColor: context.tokens.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow(IconData icon, String label, String value, Widget trailing) {
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
        trailing,
      ],
    );
  }

  /// Builds a settings field with an inline save button that appears
  /// only when the value has been modified by the user.
  Widget _buildSaveField({
    required String label,
    required TextEditingController ctrl,
    required bool isChanged,
    required bool saving,
    required VoidCallback onSave,
    int maxLines = 1,
    bool isPassword = false,
    bool pwdVisible = false,
    VoidCallback? onTogglePwd,
    bool isAdmin = false,
  }) {
    final borderColor = isAdmin
        ? context.tokens.primary.withValues(alpha: 0.3)
        : context.tokens.onSurface.withValues(alpha: 0.12);
    final focusBorderColor = isAdmin
        ? context.tokens.primary.withValues(alpha: 0.7)
        : context.tokens.primary.withValues(alpha: 0.5);
    final labelColor =
        isAdmin ? context.tokens.primary.withValues(alpha: 0.7) : context.tokens.onSurface.withValues(alpha: 0.54);
    final labelIcon = isAdmin
        ? Icon(Icons.admin_panel_settings_outlined,
            size: 12, color: context.tokens.primary.withValues(alpha: 0.5))
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(label,
              style: TextStyle(
                  color: labelColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
          if (labelIcon != null) ...[const SizedBox(width: 6), labelIcon],
        ]),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                maxLines: maxLines,
                obscureText: isPassword && !pwdVisible,
                style: GoogleFonts.martianMono(
                    color: context.tokens.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: context.tokens.onSurface.withValues(alpha: 0.05),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  suffixIcon: isPassword && onTogglePwd != null
                      ? IconButton(
                          icon: Icon(
                              pwdVisible
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              size: 18,
                              color: context.tokens.onSurface.withValues(alpha: 0.38)),
                          onPressed: onTogglePwd,
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: focusBorderColor),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            // Save button appears only when the value has changed
            if (isChanged) ...[
              const SizedBox(width: 8),
              SizedBox(
                height: 40,
                width: 40,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: context.tokens.primary,
                    foregroundColor: context.tokens.onPrimary,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                  ),
                  onPressed: saving ? null : onSave,
                  child: saving
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: context.tokens.onPrimary))
                      : const Icon(Icons.save_rounded, size: 18),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// Save a single field to the device's NVS.
  Future<void> _saveField(DeviceProvider dp, String field) async {
    setState(() {
      if (field == 'name') _savingName = true;
      if (field == 'description') _savingDesc = true;
      if (field == 'password') _savingPwd = true;
      if (field == 'adminPassword') _savingAdminPwd = true;
    });

    final name = field == 'name' ? _nameCtrl.text.trim() : null;
    final desc = field == 'description' ? _descCtrl.text.trim() : null;
    final pwd = field == 'password' ? _pwdCtrl.text.trim() : null;
    final adminPwd =
        field == 'adminPassword' ? _adminPwdCtrl.text.trim() : null;

    final ok = await dp.sendSetConf(
      name: name,
      description: desc,
      password: pwd,
      adminPassword: adminPwd,
    );

    if (!mounted) return;
    setState(() {
      _savingName = false;
      _savingDesc = false;
      _savingPwd = false;
      _savingAdminPwd = false;
      // Update original values on success
      if (ok) {
        if (field == 'name') _originalName = name ?? _originalName;
        if (field == 'description') _originalDesc = desc ?? _originalDesc;
        if (field == 'password') _pwdCtrl.clear();
        if (field == 'adminPassword') _adminPwdCtrl.clear();
      }
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Field saved to device' : 'Failed to save'),
        backgroundColor: ok ? context.tokens.success : context.tokens.error,
      ),
    );
  }

  /// Show confirmation dialog and perform factory reset.
  Future<void> _factoryReset(DeviceProvider dp) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.warning_rounded,
            color: context.tokens.error, size: 32),
        title: const Text('Factory Reset?'),
        content: const Text(
            'This will erase all device settings (name, description, password) '
            'and reboot the device.\n\n'
            'After reboot, compile-time defaults will be restored.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: context.tokens.error.withValues(alpha: 0.2),
              foregroundColor: context.tokens.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('ERASE & REBOOT'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final ok = await dp.sendFactoryReset();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Factory reset sent — device rebooting...'
            : 'Failed to send factory reset'),
        backgroundColor: ok ? context.tokens.warning : context.tokens.error,
      ),
    );

    if (ok) {
      dp.disconnect();
      // Close the settings dialog
      Navigator.of(context).maybePop();
    }
  }
}
