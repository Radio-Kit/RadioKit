import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';
import '../models/designer_element.dart';

class DesignerSidebar extends StatelessWidget {
  const DesignerSidebar({super.key});

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
    _SidebarVariant('Text Display', LucideIcons.monitor, DesignerElementType.display, <String, dynamic>{}),
    _SidebarVariant('Serial Monitor', LucideIcons.terminal, DesignerElementType.serialMonitor, <String, dynamic>{}),
    _SidebarVariant('LED', LucideIcons.circle, DesignerElementType.led, <String, dynamic>{}),
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);

    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: Color(0xFF181818),
        border: Border(
          right: BorderSide(color: Color(0xFF222222), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(tokens),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildCategory('CONTROLS', _controlVariants, tokens),
                _buildCategory('INDICATORS', _indicatorVariants, tokens),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(RKTokens tokens) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(LucideIcons.palette, color: tokens.primary, size: 20),
          const SizedBox(width: 10),
          const Text(
            'RADIOKIT WIDGETS',
            style: TextStyle(
              color: Color(0xFFE0E0E0),
              fontSize: 14,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategory(String title, List<_SidebarVariant> items, RKTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 1.0,
            children: items.map((v) => _GridItem(variant: v, tokens: tokens)).toList(),
          ),
        ),
        const SizedBox(height: 12),
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

  const _GridItem({required this.variant, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Draggable<WidgetDragPayload>(
      data: WidgetDragPayload(variant.type, variant.properties),
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: tokens.primary.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(variant.icon, color: Colors.black, size: 20),
              const SizedBox(height: 4),
              Text(
                variant.label,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 9,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.2,
        child: _buildCell(),
      ),
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
