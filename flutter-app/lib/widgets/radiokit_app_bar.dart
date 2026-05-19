import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'logo_icon.dart';

class RadioKitAppBar extends AppBar {
  RadioKitAppBar({
    super.key,
    super.actions,
    super.bottom,
    super.automaticallyImplyLeading,
    super.leading,
    super.leadingWidth,
    super.centerTitle,
    String? title,
  }) : super(
          title: Row(
            children: [
              const LogoIcon(),
              const SizedBox(width: 12),
              Text(
                title ?? 'RADIO_KIT',
                style: GoogleFonts.audiowide(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        );
}
