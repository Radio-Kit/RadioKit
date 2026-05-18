import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';

class DesignerWidgetDialog extends StatelessWidget {
  final DesignerState state;
  const DesignerWidgetDialog({super.key, required this.state});

  static const _controlVariants = [
    _SidebarVariant('Push Button', LucideIcons.square, DesignerElementType.button, {'mode': 'push'}),
    _SidebarVariant('Toggle Button', LucideIcons.toggleLeft, DesignerElementType.button, {'mode': 'toggle'}),
    _SidebarVariant('Slide Switch', LucideIcons.toggleLeft, DesignerElementType.slideSwitch, <String, dynamic>{}),
    _SidebarVariant('Rocker Switch', LucideIcons.arrowUpDown, DesignerElementType.rockerSwitch, <String, dynamic>{}),
    _SidebarVariant('Multiple Button', LucideIcons.radio, DesignerElementType.multiButton, <String, dynamic>{}),
    _SidebarVariant('Multiple Select', LucideIcons.badgeCheck, DesignerElementType.multiSelect, <String, dynamic>{}),
    _SidebarVariant('Linear Slider', LucideIcons.slidersHorizontal, DesignerElementType.slider, <String, dynamic>{}),
    _SidebarVariant('Gas Pedal', LucideIcons.gauge, DesignerElementType.gasPedal, <String, dynamic>{}),
    _SidebarVariant('Rotary Knob', LucideIcons.cog, DesignerElementType.knob, <String, dynamic>{}),
    _SidebarVariant('Steering Wheel', LucideIcons.rotateCw, DesignerElementType.steeringWheel, <String, dynamic>{}),
    _SidebarVariant('Joystick', LucideIcons.gamepad2, DesignerElementType.joystick, <String, dynamic>{}),
  ];

  static const _indicatorVariants = [
    _SidebarVariant('Text Display', LucideIcons.monitor, DesignerElementType.text, <String, dynamic>{}),
    _SidebarVariant('Serial Monitor', LucideIcons.terminal, DesignerElementType.serialMonitor, <String, dynamic>{}),
    _SidebarVariant('LED', LucideIcons.circle, DesignerElementType.led, <String, dynamic>{}),
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);

    return Dialog(
      backgroundColor: const Color(0xFF181818),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        width: 600,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.palette, color: tokens.primary, size: 24),
                const SizedBox(width: 10),
                const Text(
                  'ADD WIDGET',
                  style: TextStyle(
                    color: Color(0xFFE0E0E0),
                    fontSize: 16,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(LucideIcons.x, color: Color(0xFFE0E0E0)),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildCategory('CONTROLS', _controlVariants, tokens, context),
                  _buildCategory('INDICATORS', _indicatorVariants, tokens, context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategory(String title, List<_SidebarVariant> items, RKTokens tokens, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Text(
            title,
            style: TextStyle(
              color: tokens.primary,
              fontSize: 11,
              fontFamily: 'monospace',
              letterSpacing: 1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          child: GridView.count(
            crossAxisCount: 5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.0,
            children: items.map((v) => _GridItem(variant: v, tokens: tokens, state: state)).toList(),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _SidebarVariant {
  final String label;
  final IconData icon;
  final DesignerElementType type;
  final Map<String, dynamic> properties;
  const _SidebarVariant(this.label, this.icon, this.type, this.properties);
}

class _GridItem extends StatelessWidget {
  final _SidebarVariant variant;
  final RKTokens tokens;
  final DesignerState state;

  const _GridItem({required this.variant, required this.tokens, required this.state});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // Place widget near the center
        state.addElement(
          variant.type,
          100, // x
          100, // y
          properties: variant.properties,
        );
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(4),
      child: _buildCell(),
    );
  }

  Widget _buildCell() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border.all(color: const Color(0xFF333333), width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(variant.icon, color: const Color(0xFFAAAAAA), size: 18),
          const SizedBox(height: 4),
          Text(
            variant.label,
            style: const TextStyle(
              color: Color(0xFFAAAAAA),
              fontSize: 9,
              fontFamily: 'monospace',
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
