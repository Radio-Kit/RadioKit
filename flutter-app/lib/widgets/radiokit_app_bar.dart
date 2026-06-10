import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'logo_icon.dart';
import '../theme/app_theme.dart';

class RadioKitAppBar extends AppBar {
  RadioKitAppBar({
    super.key,
    super.bottom,
    super.automaticallyImplyLeading,
    super.leading,
    super.leadingWidth,
    super.centerTitle,
    String? title,
    List<Widget>? actions,
    int? tabIndex,
    VoidCallback? onConnect,
    VoidCallback? onOpen,
    VoidCallback? onCreate,
  }) : super(
          clipBehavior: Clip.hardEdge,
          toolbarHeight: 30,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LogoIcon(),
              const SizedBox(width: 12),
              Flexible(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final text = title ?? 'RADIO_KIT';
                    if (constraints.maxWidth < 120) {
                      return Text(
                        'RK',
                        style: GoogleFonts.audiowide(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                        overflow: TextOverflow.clip,
                      );
                    }
                    return Text(
                      text,
                      style: GoogleFonts.audiowide(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                      overflow: TextOverflow.clip,
                    );
                  },
                ),
              ),
            ],
          ),
          actions: actions ?? _buildActionsForTab(tabIndex, onConnect, onOpen, onCreate),
        );

  static List<Widget> _buildActionsForTab(
    int? tabIndex,
    VoidCallback? onConnect,
    VoidCallback? onOpen,
    VoidCallback? onCreate,
  ) {
    switch (tabIndex) {
      case 0: // Models
        return [
          if (onConnect != null)
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandOrange.withValues(alpha: 0.15),
                foregroundColor: AppColors.brandOrange,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                minimumSize: const Size(0, 30),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: onConnect,
              child: Text('+ Connect',
                  style: GoogleFonts.changa(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      fontSize: 15,
                      color: AppColors.brandOrange)),
            ),
          const SizedBox(width: 8),
        ];
      case 1: // Projects
        return [
          if (onOpen != null)
            _AppBarPillButton(
              label: 'Open',
              onTap: onOpen,
            ),
          const SizedBox(width: 6),
          if (onCreate != null)
            _AppBarPillButton(
              label: 'Create',
              onTap: onCreate,
            ),
          const SizedBox(width: 8),
        ];
      case 3: // System
        return [
          IconButton(
            icon: const Icon(Icons.sensors_rounded, size: 20),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ];
      default:
        return [];
    }
  }
}

class _AppBarPillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AppBarPillButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          height: 30,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.changa(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                fontSize: 15,
                color: Colors.white70,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
