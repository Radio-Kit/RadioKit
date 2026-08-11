import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';

/// Content widget for the "Add Widget" bottom sheet.
/// Shows a searchable grid of available widget types.
class DesignerWidgetSheet extends StatelessWidget {
  final DesignerState state;
  const DesignerWidgetSheet({super.key, required this.state});

  static const _controlVariants = [
    _SheetVariant('Push Button', LucideIcons.square, DesignerElementType.button, {'variant': 'push'}),
    _SheetVariant('Toggle Button', LucideIcons.toggleLeft, DesignerElementType.button, {'variant': 'toggle'}),
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
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 8, 24, 16 + bottomInset),
        child: Transform.translate(
          offset: const Offset(0, -18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
    late final Widget rawPreview;
    late final double previewW;
    late final double previewH;

    switch (variant.type) {
      case DesignerElementType.button:
        previewW = 60.0;
        previewH = 60.0;
        rawPreview = RKButton(
          mode: variant.properties['variant'] == 'toggle'
              ? RKButtonMode.toggle
              : RKButtonMode.push,
          onText: variant.properties['onText'] ?? 'ON',
          offText: variant.properties['offText'] ?? 'OFF',
          size: previewW,
          onChanged: (_) {},
          showDebug: false,
        );
        break;
      case DesignerElementType.slideSwitch:
        previewW = 80.0;
        previewH = 40.0;
        rawPreview = RKSlideSwitch(
          value: false,
          onText: variant.properties['onText'] ?? 'ON',
          offText: variant.properties['offText'] ?? 'OFF',
          width: previewW,
          height: previewH,
          onChanged: (_) {},
          showDebug: false,
        );
        break;
      case DesignerElementType.rockerSwitch:
        previewW = 40.0;
        previewH = 80.0;
        rawPreview = RKRockerSwitch(
          value: false,
          width: previewW,
          height: previewH,
          onChanged: (_) {},
          showDebug: false,
        );
        break;
      case DesignerElementType.slider:
        const thickness = 11.0;
        const sliderH = thickness * 6.8;
        previewH = sliderH;
        previewW = sliderH * 3.0;
        rawPreview = RKSlider(
          value: 0.5,
          orientation: RKAxis.horizontal,
          thickness: thickness,
          length: previewW,
          onChanged: (_) {},
          showDebug: false,
        );
        break;
      case DesignerElementType.steeringWheel:
        previewW = 80.0;
        previewH = 80.0;
        rawPreview = RKSteeringWheel(
          value: 0.5,
          size: previewW,
          onChanged: (_) {},
          showDebug: false,
        );
        break;
      case DesignerElementType.knob:
        previewW = 80.0;
        previewH = 80.0;
        rawPreview = RKKnob(
          value: 0.5,
          size: previewW,
          onChanged: (_) {},
          showDebug: false,
        );
        break;
      case DesignerElementType.joystick:
        previewW = 80.0;
        previewH = 80.0;
        rawPreview = RKJoystick(
          size: previewW,
          onChanged: (_) {},
          showDebug: false,
        );
        break;
      case DesignerElementType.multiButton:
        const buttonSize = 30.0;
        const shellPadding = 2.4;
        const gap = 6.0;
        previewW = buttonSize * 3 + gap * 2 + shellPadding * 2;
        previewH = buttonSize + shellPadding * 2;
        rawPreview = RKMultiButton(
          items: List.generate(
              3, (i) => RKToggleItem(onLabel: String.fromCharCode(65 + i))),
          selected: 0,
          buttonSize: buttonSize,
          orientation: RKAxis.horizontal,
          onChanged: (_) {},
          showDebug: false,
        );
        break;
      case DesignerElementType.multiSelect:
        const buttonSize = 30.0;
        const shellPadding = 2.4;
        const gap = 6.0;
        previewW = buttonSize * 3 + gap * 2 + shellPadding * 2;
        previewH = buttonSize + shellPadding * 2;
        rawPreview = RKMultiSelect(
          items: List.generate(
              3, (i) => RKToggleItem(onLabel: String.fromCharCode(65 + i))),
          bitmask: 0,
          buttonSize: buttonSize,
          orientation: RKAxis.horizontal,
          onChanged: (_) {},
          showDebug: false,
        );
        break;
      case DesignerElementType.gasPedal:
        const thickness = 10.0;
        previewW = thickness * 8.0;
        previewH = previewW * 3.0;
        rawPreview = RKGasPedal(
          value: 0.0,
          orientation: RKAxis.vertical,
          thickness: thickness,
          length: previewH,
          onChanged: (_) {},
          showDebug: false,
        );
        break;
      case DesignerElementType.led:
        previewW = 40.0;
        previewH = 40.0;
        rawPreview = RKLed(
          state: RKLEDState.on,
          shape: RKLEDShape.circle,
          size: previewW,
          showDebug: false,
        );
        break;
      case DesignerElementType.text:
        previewW = 120.0;
        previewH = 40.0;
        rawPreview = RKDisplay(
          text: 'Display',
          fontSize: 10,
          width: previewW,
          height: previewH,
          showDebug: false,
        );
        break;
      case DesignerElementType.serialMonitor:
        previewW = 120.0;
        previewH = 80.0;
        rawPreview = RKSerialMonitor(
          messages: const ['> Serial'],
          fontSize: 8,
          width: previewW,
          height: previewH,
          showDebug: false,
        );
        break;
    }

    final double aspect = previewW / previewH;

    return AspectRatio(
      aspectRatio: aspect,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: previewW,
          height: previewH,
          child: rawPreview,
        ),
      ),
    );
  }
}
