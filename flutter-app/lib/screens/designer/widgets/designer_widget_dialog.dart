import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';

/// Content widget for the "Add Widget" bottom sheet.
/// Shows a searchable grid of available widget types.
class DesignerWidgetSheet extends StatelessWidget {
  final DesignerState state;
  const DesignerWidgetSheet({super.key, required this.state});

  static const _controlVariants = [
    _SheetVariant('Push Button', LucideIcons.square, DesignerElementType.button, {'mode': 'push'}),
    _SheetVariant('Toggle Button', LucideIcons.toggleLeft, DesignerElementType.button, {'mode': 'toggle'}),
    _SheetVariant('Slide Switch', LucideIcons.toggleLeft, DesignerElementType.slideSwitch, <String, dynamic>{}),
    _SheetVariant('Rocker Switch', LucideIcons.arrowUpDown, DesignerElementType.rockerSwitch, <String, dynamic>{}),
    _SheetVariant('Multiple Button', LucideIcons.radio, DesignerElementType.multiButton, <String, dynamic>{}),
    _SheetVariant('Multiple Select', LucideIcons.badgeCheck, DesignerElementType.multiSelect, <String, dynamic>{}),
    _SheetVariant('Linear Slider', LucideIcons.slidersHorizontal, DesignerElementType.slider, <String, dynamic>{}),
    _SheetVariant('Gas Pedal', LucideIcons.gauge, DesignerElementType.gasPedal, <String, dynamic>{}),
    _SheetVariant('Rotary Knob', LucideIcons.cog, DesignerElementType.knob, <String, dynamic>{}),
    _SheetVariant('Steering Wheel', LucideIcons.rotateCw, DesignerElementType.steeringWheel, <String, dynamic>{}),
    _SheetVariant('Joystick', LucideIcons.gamepad2, DesignerElementType.joystick, <String, dynamic>{}),
  ];

  static const _indicatorVariants = [
    _SheetVariant('Text Display', LucideIcons.monitor, DesignerElementType.text, <String, dynamic>{}),
    _SheetVariant('Serial Monitor', LucideIcons.terminal, DesignerElementType.serialMonitor, <String, dynamic>{}),
    _SheetVariant('LED', LucideIcons.circle, DesignerElementType.led, <String, dynamic>{}),
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height,
      decoration: const BoxDecoration(
        color: Color(0xFF181818),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 8, 24, 16 + bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF444444),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title row
            Row(
              children: [
                Icon(LucideIcons.palette, color: tokens.primary, size: 20),
                const SizedBox(width: 10),
                const Text(
                  'ADD WIDGET',
                  style: TextStyle(
                    color: Color(0xFFE0E0E0),
                    fontSize: 15,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF222222),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: const Icon(LucideIcons.x, color: Color(0xFF888888), size: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Scrollable categories
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildCategory('CONTROLS', _controlVariants, tokens),
                  const SizedBox(height: 8),
                  _buildCategory('INDICATORS', _indicatorVariants, tokens),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategory(String title, List<_SheetVariant> items, RKTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Text(
            title,
            style: TextStyle(
              color: tokens.primary,
              fontSize: 10,
              fontFamily: 'monospace',
              letterSpacing: 1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.0,
          children: items.map((v) => _SheetGridItem(variant: v, tokens: tokens, state: state)).toList(),
        ),
      ],
    );
  }
}

class _SheetVariant {
  final String label;
  final IconData icon;
  final DesignerElementType type;
  final Map<String, dynamic> properties;
  const _SheetVariant(this.label, this.icon, this.type, this.properties);
}

class _SheetGridItem extends StatelessWidget {
  final _SheetVariant variant;
  final RKTokens tokens;
  final DesignerState state;

  const _SheetGridItem({required this.variant, required this.tokens, required this.state});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        state.addElement(
          variant.type,
          100,
          100,
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
                padding: const EdgeInsets.all(6),
                child: IgnorePointer(
                  child: _buildPreview(),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, bottom: 6),
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
    // Use defaultSize aspect ratios for preview proportions so widgets
    // always render in their expected shape. Scale up for visibility.
    final (defW, defH) = DesignerElement.defaultSize(variant.type);
    final previewSize = 44.0;

    switch (variant.type) {
      case DesignerElementType.button:
        return RKButton(
          mode: variant.properties['mode'] == 'toggle'
              ? RKButtonMode.toggle
              : RKButtonMode.push,
          onText: variant.properties['onText'] ?? 'ON',
          offText: variant.properties['offText'] ?? 'OFF',
          size: previewSize,
          onChanged: (_) {},
          showDebug: false,
        );
      case DesignerElementType.slideSwitch:
        final aspect = defW / defH.clamp(1, 999);
        final w = previewSize * (aspect > 1 ? 1.0 : aspect);
        final h = previewSize / (aspect > 1 ? aspect : 1.0);
        return RKSlideSwitch(
          value: false,
          onText: variant.properties['onText'] ?? 'ON',
          offText: variant.properties['offText'] ?? 'OFF',
          width: w.clamp(20, 60),
          height: h.clamp(12, 30),
          onChanged: (_) {},
          showDebug: false,
        );
      case DesignerElementType.rockerSwitch:
        final aspect = defW / defH.clamp(1, 999);
        final h = previewSize;
        final w = h * aspect;
        return RKRockerSwitch(
          value: false,
          width: w.clamp(14, 30),
          height: h.clamp(30, 50),
          onChanged: (_) {},
          showDebug: false,
        );
      case DesignerElementType.slider:
        return RKSlider(
          value: 0.5,
          orientation: RKAxis.horizontal,
          thickness: 6,
          length: 56,
          onChanged: (_) {},
          showDebug: false,
        );
      case DesignerElementType.steeringWheel:
        return RKSteeringWheel(
          value: 0.5,
          size: previewSize,
          onChanged: (_) {},
          showDebug: false,
        );
      case DesignerElementType.knob:
        return RKKnob(
          value: 0.5,
          size: previewSize,
          onChanged: (_) {},
          showDebug: false,
        );
      case DesignerElementType.joystick:
        return RKJoystick(
          size: previewSize,
          onChanged: (_) {},
          showDebug: false,
        );
      case DesignerElementType.multiButton:
        return RKMultiButton(
          items: List.generate(3, (i) => RKToggleItem(onLabel: String.fromCharCode(65 + i))),
          selected: 0,
          buttonSize: 14,
          orientation: RKAxis.horizontal,
          onChanged: (_) {},
          showDebug: false,
        );
      case DesignerElementType.multiSelect:
        return RKMultiSelect(
          items: List.generate(3, (i) => RKToggleItem(onLabel: String.fromCharCode(65 + i))),
          bitmask: 0,
          buttonSize: 14,
          orientation: RKAxis.horizontal,
          onChanged: (_) {},
          showDebug: false,
        );
      case DesignerElementType.gasPedal:
        return RKGasPedal(
          value: 0.0,
          orientation: RKAxis.vertical,
          thickness: 5,
          length: previewSize - 4,
          onChanged: (_) {},
          showDebug: false,
        );
      case DesignerElementType.led:
        return const RKLed(
          state: RKLEDState.on,
          shape: RKLEDShape.circle,
          size: 24,
          showDebug: false,
        );
      case DesignerElementType.text:
        return const RKDisplay(
          text: 'Display',
          fontSize: 9,
          width: 56,
          height: 20,
          showDebug: false,
        );
      case DesignerElementType.serialMonitor:
        return const RKSerialMonitor(
          messages: ['> Serial'],
          fontSize: 7,
          width: 56,
          height: 30,
          showDebug: false,
        );
    }
  }
}
