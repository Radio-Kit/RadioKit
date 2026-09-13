import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../themed_bottom_sheet.dart';

/// Actionable diagnostic checklist displayed when no physical devices are discovered.
class DiscoveryDiagnosticChecklist extends StatelessWidget {
  final VoidCallback? onScanAgain;

  const DiscoveryDiagnosticChecklist({super.key, this.onScanAgain});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tokens.base200,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.onSurface.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tokens.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.troubleshoot_rounded,
                    color: tokens.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HARDWARE_CHECKLIST',
                      style: GoogleFonts.changa(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 1.2,
                        color: tokens.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'No RadioKit boards detected. Verify physical connections:',
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCheckItem(
            context,
            Icons.bluetooth_searching_rounded,
            'Bluetooth & Permissions',
            'Ensure Bluetooth is active and Location/Nearby permissions are granted on your mobile device.',
          ),
          const SizedBox(height: 10),
          _buildCheckItem(
            context,
            Icons.usb_rounded,
            'USB Data Cable',
            'Use a data-sync USB cable. Many charging cables lack D+/D- lines needed for serial communication.',
          ),
          const SizedBox(height: 10),
          _buildCheckItem(
            context,
            Icons.power_rounded,
            'Microcontroller Power',
            'Check that the board LED is on and that the RadioKit Arduino sketch is executing `RK.begin()`.',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (onScanAgain != null) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tokens.primary,
                      side: BorderSide(color: tokens.primary.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(
                      'RESCAN',
                      style: GoogleFonts.changa(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        fontSize: 12,
                      ),
                    ),
                    onPressed: onScanAgain,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: tokens.primary.withValues(alpha: 0.15),
                    foregroundColor: tokens.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => BootloaderGuideDialog.show(context),
                  child: Text(
                    'BOOTLOADER GUIDE',
                    style: GoogleFonts.changa(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCheckItem(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final tokens = context.tokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: tokens.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: tokens.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: tokens.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Actionable empty state card for Flasher tab when 0 serial ports are found.
class SerialPortTroubleshootingCard extends StatelessWidget {
  final VoidCallback? onRefresh;

  const SerialPortTroubleshootingCard({super.key, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tokens.base200,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.usb_off_rounded, color: tokens.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'NO SERIAL PORTS DETECTED',
                  style: GoogleFonts.changa(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 1.2,
                    color: tokens.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Connect your ESP32 via USB. If your board is plugged in but not showing up:',
            style: TextStyle(
              fontSize: 12,
              color: tokens.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '1. Ensure you are using a USB data cable (not charge-only).\n'
            '2. On Linux, ensure user has dialout/plugdev group permissions (`sudo usermod -a -G dialout \$USER`).\n'
            '3. On Android/Chrome, tap Rescan to request USB device permissions.\n'
            '4. For native USB chips (ESP32-S3/C3), enter ROM bootloader mode manually.',
            style: TextStyle(
              fontSize: 11,
              height: 1.45,
              color: tokens.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (onRefresh != null) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.primary,
                    side: BorderSide(color: tokens.primary.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text('RESCAN PORTS',
                      style: GoogleFonts.changa(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.8,
                      )),
                  onPressed: onRefresh,
                ),
                const SizedBox(width: 10),
              ],
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.primary.withValues(alpha: 0.15),
                  foregroundColor: tokens.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => BootloaderGuideDialog.show(context),
                child: Text('BOOTLOADER GUIDE',
                    style: GoogleFonts.changa(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 0.8,
                    )),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Interactive modal sheet detailing the physical ESP32 button sequence.
class BootloaderGuideDialog extends StatefulWidget {
  const BootloaderGuideDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showThemedBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.tokens.base200,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => const BootloaderGuideDialog(),
    );
  }

  @override
  State<BootloaderGuideDialog> createState() => _BootloaderGuideDialogState();
}

class _BootloaderGuideDialogState extends State<BootloaderGuideDialog> {
  int _activeStep = 0;

  static const _steps = [
    {
      'num': '1',
      'title': 'HOLD BOOT BUTTON',
      'instruction': 'Press and hold the "BOOT" button (labeled BOOT, IO0, or 00) on your ESP32 board.',
      'detail': 'Do not let go of the BOOT button yet.',
      'icon': Icons.touch_app_rounded,
    },
    {
      'num': '2',
      'title': 'CLICK EN / RESET',
      'instruction': 'While continuing to hold BOOT, briefly press and release the "EN" or "RST" button once.',
      'detail': 'This triggers an ESP32 hardware reset while GPIO0 is pulled low.',
      'icon': Icons.restart_alt_rounded,
    },
    {
      'num': '3',
      'title': 'RELEASE BOOT',
      'instruction': 'Release the "BOOT" button.',
      'detail': 'The board is now in download mode and ready to accept firmware flash packets.',
      'icon': Icons.check_circle_outline_rounded,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final current = _steps[_activeStep];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tokens.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.memory_rounded, color: tokens.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ESP32 BOOTLOADER SEQUENCE',
                      style: GoogleFonts.changa(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 1.2,
                        color: tokens.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Manual timing sequence to force download mode',
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Step indicators
          Row(
            children: List.generate(_steps.length, (index) {
              final isActive = index == _activeStep;
              final isDone = index < _activeStep;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _activeStep = index),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDone || isActive
                          ? tokens.primary
                          : tokens.onSurface.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 18),
          // Step card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tokens.base300,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: tokens.primary.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: tokens.primary,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        current['num'] as String,
                        style: TextStyle(
                          color: tokens.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        current['title'] as String,
                        style: GoogleFonts.changa(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 1.0,
                          color: tokens.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  current['instruction'] as String,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: tokens.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  current['detail'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: tokens.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_activeStep > 0)
                TextButton(
                  onPressed: () => setState(() => _activeStep--),
                  child: const Text('Back'),
                )
              else
                const SizedBox.shrink(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: tokens.primary,
                  foregroundColor: tokens.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  if (_activeStep < _steps.length - 1) {
                    setState(() => _activeStep++);
                  } else {
                    Navigator.of(context).pop();
                  }
                },
                child: Text(
                  _activeStep == _steps.length - 1 ? 'READY TO FLASH' : 'NEXT STEP',
                  style: GoogleFonts.changa(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
