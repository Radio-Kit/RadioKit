import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:go_router/go_router.dart';
import '../../providers/device_provider.dart';
import '../../models/device_info.dart';
import '../../models/protocol.dart';
import '../../theme/app_theme.dart';
import '../../services/cloud_identity.dart';
import '../designer/widgets/inspector_field_builders.dart';
import 'package:radiokit_widgets/src/utils/icon_registry.dart';

class SettingsTabContent extends StatefulWidget {
  @override
  State<SettingsTabContent> createState() => _SettingsTabContentState();
}

class _SettingsTabContentState extends State<SettingsTabContent> {
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _pwdCtrl;
  late TextEditingController _adminPwdCtrl;

  String _originalName = '';
  String _originalDesc = '';
  bool _pwdVisible = false;
  bool _adminPwdVisible = false;
  bool _savingName = false;
  bool _savingDesc = false;
  bool _savingPwd = false;
  bool _savingAdminPwd = false;

  bool _bleEnabled = true;
  bool _wifiEnabled = false;
  bool _cloudEnabled = false;
  bool _cloudMatched = false;
  bool _transportChanged = false;
  String _deviceIcon = '';
  bool _hasDevicePassword = false;
  bool _iconChanged = false;

  @override
  void initState() {
    super.initState();
    final dp = context.read<DeviceProvider>();
    _originalName = dp.configName ?? '';
    _originalDesc = dp.description ?? '';
    _deviceIcon = dp.deviceIcon ?? '';
    _nameCtrl = TextEditingController(text: _originalName);
    _descCtrl = TextEditingController(text: _originalDesc);
    _pwdCtrl = TextEditingController();
    _adminPwdCtrl = TextEditingController();
    _hasDevicePassword = dp.hasPassword;

    // Load NVS transport enable states
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTransportNvsKeys(dp));
  }

  Future<void> _loadTransportNvsKeys(DeviceProvider dp) async {
    if (!dp.isConnected) return;
    final bleResult = await dp.readNvsRawKey('rk_ble_on');
    final wifiResult = await dp.readNvsRawKey('rk_wifi_on');
    final cloudResult = await dp.readNvsRawKey('rk_cloud_on');
    if (!mounted) return;
    setState(() {
      _bleEnabled = (bleResult.value ?? 1) != 0;
      _wifiEnabled = (wifiResult.value ?? 0) != 0;
      _cloudEnabled = (cloudResult.value ?? 0) != 0;
    });

    // Check cloud account match
    try {
      final cloudInfo = await dp.sendGetCloudInfo();
      if (cloudInfo != null && mounted) {
        final identityService = CloudIdentityService();
        await identityService.initialize();
        _cloudMatched =
            identityService.hasIdentity && identityService.account == cloudInfo.account;
      }
    } catch (_) {}
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

  String? _connectedTransportName(DeviceProvider dp) {
    if (!dp.isConnected) return null;
    final connected = dp.connectedDevice;
    final transport = connected?.currentTransport;
    switch (transport) {
      case TransportType.ble:
        return 'BLE';
      case TransportType.wifi:
        return 'WIFI';
      case TransportType.cloud:
        return 'CLOUD';
      case TransportType.serial:
        return 'Serial';
      default:
        return null;
    }
  }

  /// Returns true if disabling this transport would leave NO transports enabled.
  bool _willAllTransportsDisabled(String transport) {
    final othersOn = switch (transport) {
      'BLE'   => _wifiEnabled || _cloudEnabled,
      'WIFI'  => _bleEnabled,  // cloud is also turned off when wifi is disabled
      'CLOUD' => _bleEnabled || _wifiEnabled,
      _       => true,
    };
    return !othersOn;
  }

  Future<bool> _confirmDisableTransport(
      DeviceProvider dp, String transport) async {
    final connectedVia = _connectedTransportName(dp);
    if (connectedVia != transport) return true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_rounded,
            color: Colors.orangeAccent, size: 32),
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
              backgroundColor: Colors.orangeAccent.withValues(alpha: 0.2),
              foregroundColor: Colors.orangeAccent,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('DISABLE'),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  Future<bool> _confirmDisableAllTransports(String transport) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.error_rounded,
            color: Colors.redAccent, size: 32),
        title: const Text('All Transports Disabled?'),
        content: Text(
          'Disabling $transport will leave no transports enabled on this device. '
          'It will become unreachable until manually reconnected via a wired connection or factory reset.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL',
                style: TextStyle(color: Colors.white54)),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
              foregroundColor: Colors.redAccent,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('DISABLE ANYWAY'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DeviceProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          _buildIconPicker(dp),
          const SizedBox(height: 16),
          _buildSaveField(
            label: 'DEVICE PASSWORD (leave empty to clear)',
            ctrl: _pwdCtrl,
            isChanged: _pwdChanged,
            saving: _savingPwd,
            onSave: () => _saveField(dp, 'password'),
            isPassword: true,
            pwdVisible: _pwdVisible,
            onTogglePwd: () => setState(() => _pwdVisible = !_pwdVisible),
          ),
          if (_hasDevicePassword) ...[const SizedBox(height: 16),
          _buildSaveField(
            label: 'USER PASSWORD (leave empty to clear)',
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
          ],
          const SizedBox(height: 32),
          _buildSectionTag('CONNECTION'),
          const SizedBox(height: 16),
          _buildTransportRow(
            icon: Icons.bluetooth_rounded,
            label: 'BLE',
            subtitle: 'Bluetooth Low Energy',
            enabled: _bleEnabled,
            onChanged: (v) async {
              if (!v) {
                if (_willAllTransportsDisabled('BLE')) {
                  final ok = await _confirmDisableAllTransports('BLE');
                  if (!ok) return;
                } else {
                  final ok = await _confirmDisableTransport(dp, 'BLE');
                  if (!ok) return;
                }
              }
              setState(() => _bleEnabled = v);
              await _writeTransportKey(dp, 'rk_ble_on', v ? 1 : 0);
            },
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.wifi_rounded,
                        size: 20,
                        color: _wifiEnabled
                            ? AppColors.brandOrange
                            : Colors.white38),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('WIFI',
                              style: TextStyle(
                                  color: _wifiEnabled
                                      ? Colors.white
                                      : Colors.white54,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('Wireless network',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontSize: 11)),
                        ],
                      ),
                    ),
                    Switch(
                      value: _wifiEnabled,
                      onChanged: (v) async {
                        if (!v) {
                          if (_willAllTransportsDisabled('WIFI')) {
                            final ok = await _confirmDisableAllTransports('WIFI');
                            if (!ok) return;
                          } else {
                            final ok = await _confirmDisableTransport(dp, 'WIFI');
                            if (!ok) return;
                          }
                        }
                        setState(() {
                          _wifiEnabled = v;
                          if (!v) _cloudEnabled = false;
                        });
                        await _writeTransportKey(dp, 'rk_wifi_on', v ? 1 : 0);
                      },
                      activeThumbColor: AppColors.brandOrange,
                    ),
                  ],
                ),
                if (_wifiEnabled) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1, color: Colors.white10),
                  ),
                  _buildSettingRow(
                    Icons.cloud_rounded,
                    'CLOUD',
                    _cloudMatched
                        ? 'Remote access over internet'
                        : 'Configure in Pairing',
                    Switch(
                      value: _cloudEnabled && _cloudMatched,
                      onChanged: _cloudMatched
                          ? (v) async {
                              if (!v && _willAllTransportsDisabled('CLOUD')) {
                                final ok = await _confirmDisableAllTransports('CLOUD');
                                if (!ok) return;
                              }
                              setState(() => _cloudEnabled = v);
                              await _writeTransportKey(dp, 'rk_cloud_on', v ? 1 : 0);
                            }
                          : null,
                      activeThumbColor: AppColors.brandOrange,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_transportChanged) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandOrange,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _applyTransportAndReboot(dp),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('CONFIRM TO APPLY',
                        style: GoogleFonts.changa(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            fontSize: 14,
                            color: Colors.black)),
                    Text('& REBOOT NOW',
                        style: GoogleFonts.changa(
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.5,
                            fontSize: 11,
                            color: Colors.black.withValues(alpha: 0.7))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Transport changes only take effect after reboot. '
              'Close without applying to keep current configuration.',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
          const SizedBox(height: 32),
          _buildSectionTag('REBOOT'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orangeAccent,
                side: BorderSide(
                    color: Colors.orangeAccent.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              icon: const Icon(Icons.restart_alt_rounded, size: 20),
              label: Text('REBOOT DEVICE',
                  style: GoogleFonts.changa(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      fontSize: 12)),
              onPressed: () => _confirmReboot(dp),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Restart the device without erasing any settings. '
            'Useful after changing transport configuration.',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 32),
          _buildSectionTag('FACTORY_RESET'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side:
                    BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              icon: const Icon(Icons.delete_forever_rounded, size: 20),
              label: Text('FACTORY RESET',
                  style: GoogleFonts.changa(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      fontSize: 12)),
              onPressed: () => _factoryReset(dp),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Erase all settings (name, description, password) '
            'and reboot the device. Compile-time defaults will be restored.',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTag(String title) {
    return Row(
      children: [
        Container(width: 6, height: 6, color: AppColors.brandOrange),
        const SizedBox(width: 10),
        Text(title,
            style: GoogleFonts.changa(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 1.5,
                color: AppColors.brandOrange)),
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
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 20,
              color: enabled ? AppColors.brandOrange : Colors.white38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: enabled ? Colors.white : Colors.white54,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11)),
              ],
            ),
          ),
          Switch(
              value: enabled,
              onChanged: onChanged,
              activeThumbColor: AppColors.brandOrange),
        ],
      ),
    );
  }

  Widget _buildSettingRow(
      IconData icon, String label, String value, Widget trailing) {
    return Row(
      children: [
        Icon(icon,
            size: 18, color: AppColors.brandOrange.withValues(alpha: 0.7)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13)),
            ],
          ),
        ),
        trailing,
      ],
    );
  }

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
    final borderColor =
        isAdmin ? AppColors.brandOrange.withValues(alpha: 0.3) : Colors.white12;
    final focusBorderColor = isAdmin
        ? AppColors.brandOrange.withValues(alpha: 0.7)
        : AppColors.brandOrange.withValues(alpha: 0.5);
    final labelColor =
        isAdmin ? AppColors.brandOrange.withValues(alpha: 0.7) : Colors.white54;
    final labelIcon = isAdmin
        ? Icon(Icons.admin_panel_settings_outlined,
            size: 12, color: AppColors.brandOrange.withValues(alpha: 0.5))
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
                style: GoogleFonts.jetBrainsMono(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  suffixIcon: isPassword && onTogglePwd != null
                      ? IconButton(
                          icon: Icon(
                              pwdVisible
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              size: 18,
                              color: Colors.white38),
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
            if (isChanged) ...[
              const SizedBox(width: 8),
              SizedBox(
                height: 40,
                width: 40,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandOrange,
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                  ),
                  onPressed: saving ? null : onSave,
                  child: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.save_rounded, size: 18),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildIconPicker(DeviceProvider dp) {
    final iconData = _deviceIcon.isNotEmpty && kDesignerIcons.containsKey(_deviceIcon)
        ? kDesignerIcons[_deviceIcon]!
        : Icons.memory_rounded;
    final iconChanged = _deviceIcon != (dp.deviceIcon ?? '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('ICON',
              style: const TextStyle(
                  color: Colors.white54, fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _pickIcon(context, dp),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(iconData,
                            color: AppColors.brandOrange, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _deviceIcon.isNotEmpty ? _deviceIcon : 'Tap to select',
                              style: GoogleFonts.jetBrainsMono(
                                color: _deviceIcon.isNotEmpty
                                    ? Colors.white
                                    : Colors.white38,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _deviceIcon.isNotEmpty
                                  ? 'Tap to change'
                                  : 'Choose a device icon',
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          size: 18, color: Colors.white24),
                    ],
                  ),
                ),
              ),
            ),
            if (iconChanged) ...[
              const SizedBox(width: 8),
              SizedBox(
                height: 40,
                width: 40,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandOrange,
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                  ),
                  onPressed: () => _saveIcon(dp),
                  child: const Icon(Icons.save_rounded, size: 18),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Future<void> _pickIcon(BuildContext context, DeviceProvider dp) async {
    IconFieldBuilder.openIconPickerDialog(
      context,
      currentIconName: _deviceIcon.isNotEmpty ? _deviceIcon : null,
      onChanged: (newIcon) {
        if (!mounted) return;
        setState(() => _deviceIcon = newIcon ?? '');
      },
    );
  }

  Future<void> _saveIcon(DeviceProvider dp) async {
    final icon = _deviceIcon.isNotEmpty ? _deviceIcon : null;
    final ok = await dp.sendSetConf(icon: icon, clearIcon: icon == null);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Device icon saved'),
          backgroundColor: Colors.greenAccent,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save icon'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

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
      if (ok) {
        if (field == 'name') _originalName = name ?? _originalName;
        if (field == 'description') _originalDesc = desc ?? _originalDesc;
        if (field == 'password') {
          _pwdCtrl.clear();
          _hasDevicePassword = (pwd != null && pwd.isNotEmpty) || dp.hasPassword;
        }
        if (field == 'adminPassword') _adminPwdCtrl.clear();
      }
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Field saved to device' : 'Failed to save'),
        backgroundColor: ok ? Colors.greenAccent : Colors.redAccent,
      ),
    );
  }

  Future<void> _writeTransportKey(DeviceProvider dp, String key, int value) async {
    final status = await dp.writeNvsRawKey(key, value);
    if (!mounted) return;

    if (status != kSettingsNvsRawOk) {
      // Show error — likely auth issue (NVS_RAW_WRITE requires device-level auth)
      final isDevMode = dp.isDeviceMode;
      final msg = isDevMode
          ? 'Failed to write to device NVS (status=$status).'
          : 'Device-level access required. Authenticate with the device password '
              'before changing transport settings. ';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    // Mark transport as changed — show Apply & Reboot button instead of dialog
    setState(() => _transportChanged = true);
  }

  Future<void> _applyTransportAndReboot(DeviceProvider dp) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.restart_alt_rounded,
            color: Colors.orangeAccent, size: 32),
        title: const Text('Reboot to Apply Changes?'),
        content: const Text(
          'The device will reboot to apply the transport changes. '
          'After reboot, you may need to reconnect via the new transport.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orangeAccent.withValues(alpha: 0.2),
              foregroundColor: Colors.orangeAccent,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('REBOOT'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await dp.sendReboot();
    if (!mounted) return;
    dp.disconnect();
    if (context.mounted) context.go('/models');
  }

  Future<void> _confirmReboot(DeviceProvider dp) async {
    if (!dp.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No device connected'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.restart_alt_rounded,
            color: Colors.orangeAccent, size: 32),
        title: const Text('Reboot Device?'),
        content: const Text(
          'Restart the device without erasing any settings. '
          'The device will disconnect and reconnect.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orangeAccent.withValues(alpha: 0.2),
              foregroundColor: Colors.orangeAccent,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('REBOOT'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final ok = await dp.sendReboot();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Reboot sent — device restarting...'
            : 'Failed to send reboot command'),
        backgroundColor: ok ? Colors.orangeAccent : Colors.redAccent,
      ),
    );
  }

  Future<void> _factoryReset(DeviceProvider dp) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_rounded,
            color: Colors.redAccent, size: 32),
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
              backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
              foregroundColor: Colors.redAccent,
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
        backgroundColor: ok ? Colors.orangeAccent : Colors.redAccent,
      ),
    );

    if (ok) {
      dp.disconnect();
      if (context.mounted) context.go('/models');
    }
  }
}

// ── Filesystem Tab Content ───────────────────────────────────────────────────

