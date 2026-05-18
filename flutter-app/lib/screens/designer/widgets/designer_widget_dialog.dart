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
            crossAxisCount: 4,
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
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: IgnorePointer(
                  child: _buildPreview(),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
            child: Text(
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
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    switch (variant.type) {
      case DesignerElementType.button:
        return RKButton(
          mode: variant.properties['mode'] == 'toggle'
              ? RKButtonMode.toggle
              : RKButtonMode.push,
          onText: variant.properties['onText'] ?? 'ON',
          offText: variant.properties['offText'] ?? 'OFF',
          size: 40,
          onChanged: (_) {},
        );
      case DesignerElementType.slideSwitch:
        return RKSlideSwitch(
          value: false,
          onText: variant.properties['onText'] ?? 'ON',
          offText: variant.properties['offText'] ?? 'OFF',
          width: 50,
          height: 25,
          onChanged: (_) {},
        );
      case DesignerElementType.rockerSwitch:
        return RKRockerSwitch(
          value: false,
          width: 25,
          height: 44,
          onChanged: (_) {},
        );
      case DesignerElementType.slider:
        return RKSlider(
          value: 0.5,
          orientation: RKAxis.horizontal,
          thickness: 6,
          length: 60,
          onChanged: (_) {},
        );
      case DesignerElementType.steeringWheel:
        return RKSteeringWheel(
          value: 0.5,
          size: 44,
          onChanged: (_) {},
        );
      case DesignerElementType.knob:
        return RKKnob(
          value: 0.5,
          size: 44,
          onChanged: (_) {},
        );
      case DesignerElementType.joystick:
        return RKJoystick(
          size: 44,
          onChanged: (_) {},
        );
      case DesignerElementType.multiButton:
        return RKMultiButton(
          items: List.generate(3, (i) => RKToggleItem(onLabel: String.fromCharCode(65 + i))),
          selected: 0,
          buttonSize: 15,
          orientation: RKAxis.horizontal,
          onChanged: (_) {},
        );
      case DesignerElementType.multiSelect:
        return RKMultiSelect(
          items: List.generate(3, (i) => RKToggleItem(onLabel: String.fromCharCode(65 + i))),
          bitmask: 0,
          buttonSize: 15,
          orientation: RKAxis.horizontal,
          onChanged: (_) {},
        );
      case DesignerElementType.gasPedal:
        return RKGasPedal(
          value: 0.0,
          orientation: RKAxis.vertical,
          thickness: 5,
          length: 44,
          onChanged: (_) {},
        );
      case DesignerElementType.led:
        return const RKLed(
          state: RKLEDState.on,
          shape: RKLEDShape.circle,
          size: 24,
        );
      case DesignerElementType.text:
        return const RKDisplay(
          text: 'Display',
          fontSize: 9,
          width: 60,
          height: 22,
        );
      case DesignerElementType.serialMonitor:
        return const RKSerialMonitor(
          messages: ['> Serial'],
          fontSize: 7,
          width: 60,
          height: 32,
        );
    }
  }
}
