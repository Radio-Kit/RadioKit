import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class LogoIcon extends StatelessWidget {
  const LogoIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dot(AppColors.brandOrange),
            _dot(AppColors.brandOrange),
            _dot(AppColors.brandOrange),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dot(AppColors.brandOrange),
            _dot(Colors.white10),
            _dot(AppColors.brandOrange),
          ],
        ),
      ],
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: 4,
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}
