import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'logo_icon.dart';

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
  }) : super(
          clipBehavior: Clip.hardEdge,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Builder(builder: (context) {
                final orientation = MediaQuery.of(context).orientation;
                if (orientation == Orientation.landscape) {
                  return const SizedBox.shrink();
                }
                return const LogoIcon();
              }),
              const SizedBox(width: 12),
              Flexible(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final text = title ?? 'RADIO_KIT';
                    // If available width is less than 120px, show short version
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
          actions: actions,
        );
}
