import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';
import '../../theme/app_theme.dart';
import '../../widgets/inspector_field_builders.dart';
import '../models/designer_element.dart';
import '../models/designer_state.dart';

class DesignerInspector extends StatelessWidget {
  final DesignerState state;
  const DesignerInspector({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);
    final el = state.selectedElement;

    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: Color(0xFF181818),
        border: Border(
          left: BorderSide(color: Color(0xFF222222), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(tokens),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (el == null) ...[
                    _buildGeneralProperties(tokens),
                  ] else ...[
                    InspectorFieldBuilders.buildSection(tokens, 'VALUES', [
                      InspectorFieldBuilders.buildTextField(tokens, 'Label', el.label, (v) {
                        state.updateElementLabel(el.id, v);
                      }),
                      _buildSizeRow(tokens, el),
                    ]),
                    InspectorFieldBuilders.buildSection(tokens, 'BEHAVIOR', _buildBehaviorFields(tokens, el)),
                    InspectorFieldBuilders.buildSection(tokens, 'TRANSFORM', [
                      _buildPositionRow(tokens, el),
                      const SizedBox(height: 8),
                      InspectorFieldBuilders.buildRotationSlider(tokens, el.rotation.toDouble(), (v) {
                        state.updateElementRotation(el.id, v.round());
                      }),
                      const SizedBox(height: 12),
                      _buildDeleteButton(tokens),
                    ]),
                  ],
                ],
              ),
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
          Icon(LucideIcons.list, color: tokens.primary, size: 20),
          const SizedBox(width: 10),
          const Text(
            'CONFIGURATION',
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

  Widget _buildGeneralProperties(RKTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InspectorFieldBuilders.buildSection(tokens, 'CONNECTION', [
          _buildOptionSelector(
            tokens, 'Type',
            state.connectionType,
            ['ble', 'serial'],
            (v) => state.setConnectionType(v),
          ),
        ]),
        InspectorFieldBuilders.buildSection(tokens, 'MODEL', [
          InspectorFieldBuilders.buildTextField(tokens, 'Name', state.modelName,
              (v) => state.setModelName(v)),
          InspectorFieldBuilders.buildTextField(tokens, 'Type', state.modelType,
              (v) => state.setModelType(v)),
          InspectorFieldBuilders.buildTextField(tokens, 'Password', state.connectionPassword,
              (v) => state.setConnectionPassword(v)),
        ]),
        InspectorFieldBuilders.buildSection(tokens, 'CANVAS', [
          _buildSkinSelector(tokens),
          _buildGridStyleSelector(tokens),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                const SizedBox(
                  width: 80,
                  child: Text(
                    'Size',
                    style: TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${state.canvasWidth} × ${state.canvasHeight}',
                  style: const TextStyle(
                    color: Color(0xFFE0E0E0),
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildSkinSelector(RKTokens tokens) {
    return _buildOptionSelector(tokens, 'Skin', state.activeSkin, ['dragon', 'neon', 'minimal'], (v) {
      state.setSkin(v);
      themeNotifier.value = switch (v) {
        'neon' => RKTokens.neon,
        'minimal' => RKTokens.minimal,
        _ => RKTokens.rambros,
      };
    });
  }

  Widget _buildGridStyleSelector(RKTokens tokens) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          const SizedBox(
            width: 80,
            child: Text(
              'Grid',
              style: TextStyle(
                color: Color(0xFF888888),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 8),
          ...GridStyle.values.map((style) {
            final isSelected = style == state.gridStyle;
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: GestureDetector(
                onTap: () => state.setGridStyle(style),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? tokens.primary : const Color(0xFF1A1A1A),
                    border: Border.all(
                      color: isSelected ? tokens.primary : const Color(0xFF444444),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        switch (style) {
                          GridStyle.lines => LucideIcons.grid2x2,
                          GridStyle.dots => LucideIcons.circle,
                          GridStyle.none => LucideIcons.eyeOff,
                        },
                        color: isSelected ? Colors.black : const Color(0xFF888888),
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        style.name.toUpperCase(),
                        style: TextStyle(
                          color: isSelected ? Colors.black : const Color(0xFF888888),
                          fontSize: 10,
                          fontFamily: 'monospace',
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildOptionSelector(RKTokens tokens, String label, String value, List<String> options, ValueChanged<String> onChanged) {
    return InspectorFieldBuilders.buildOptionSelector(tokens, label, value, options, onChanged);
  }

  Widget _buildPositionRow(RKTokens tokens, DesignerElement el) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: InspectorFieldBuilders.buildCompactNumField(tokens, 'X', el.x, (v) {
              state.updateElementPosition(el.id, v, el.y);
            }),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InspectorFieldBuilders.buildCompactNumField(tokens, 'Y', el.y, (v) {
              state.updateElementPosition(el.id, el.x, v);
            }),
          ),
        ],
      ),
    );
  }

  static const _squareTypes = {
    DesignerElementType.button,
    DesignerElementType.knob,
    DesignerElementType.joystick,
    DesignerElementType.led,
  };

  Widget _buildSizeRow(RKTokens tokens, DesignerElement el) {
    final isSquare = _squareTypes.contains(el.type);

    if (isSquare) {
      final edge = math.max(el.width, el.height);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: InspectorFieldBuilders.buildCompactNumField(tokens, 'Size', edge, (v) {
                state.updateElementSize(el.id, width: v, height: v);
              }),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: InspectorFieldBuilders.buildCompactNumField(tokens, 'W', el.width, (v) {
              state.updateElementSize(el.id, width: v);
            }),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InspectorFieldBuilders.buildCompactNumField(tokens, 'H', el.height, (v) {
              state.updateElementSize(el.id, height: v);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteButton(RKTokens tokens) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: () => state.removeSelected(),
          style: TextButton.styleFrom(
            backgroundColor: const Color(0xFF331111),
            side: const BorderSide(color: Color(0xFF663333)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
          child: const Text(
            'DELETE WIDGET',
            style: TextStyle(
              color: Color(0xFFFF5555),
              fontSize: 11,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBehaviorFields(RKTokens tokens, DesignerElement el) {
    final fields = <Widget>[];

    switch (el.type) {
      case DesignerElementType.button:
        fields.add(InspectorFieldBuilders.buildOptionSelector(
          tokens, 'Mode',
          el.properties['mode'] ?? 'push',
          ['push', 'toggle'],
          (v) => state.updateElementProperty(el.id, 'mode', v),
        ));
        fields.add(InspectorFieldBuilders.buildTextField(tokens, 'On Text', el.properties['onText'] ?? 'ON',
            (v) => state.updateElementProperty(el.id, 'onText', v)));
        fields.add(InspectorFieldBuilders.buildTextField(tokens, 'Off Text', el.properties['offText'] ?? 'OFF',
            (v) => state.updateElementProperty(el.id, 'offText', v)));
        fields.add(InspectorFieldBuilders.buildBoolToggle(tokens, 'Haptics', el.properties['enableHapticFeedback'] ?? true,
            (v) => state.updateElementProperty(el.id, 'enableHapticFeedback', v)));
        break;

      case DesignerElementType.slideSwitch:
        fields.add(InspectorFieldBuilders.buildTextField(tokens, 'On Text', el.properties['onText'] ?? 'ON',
            (v) => state.updateElementProperty(el.id, 'onText', v)));
        fields.add(InspectorFieldBuilders.buildTextField(tokens, 'Off Text', el.properties['offText'] ?? 'OFF',
            (v) => state.updateElementProperty(el.id, 'offText', v)));
        fields.add(InspectorFieldBuilders.buildBoolToggle(tokens, 'Haptics', el.properties['enableHapticFeedback'] ?? true,
            (v) => state.updateElementProperty(el.id, 'enableHapticFeedback', v)));
        break;

      case DesignerElementType.rockerSwitch:
        fields.add(InspectorFieldBuilders.buildBoolToggle(tokens, 'Haptics', el.properties['enableHapticFeedback'] ?? true,
            (v) => state.updateElementProperty(el.id, 'enableHapticFeedback', v)));
        break;

      case DesignerElementType.slider:
        fields.add(InspectorFieldBuilders.buildDoubleField(tokens, 'Min', (el.properties['min'] as num?)?.toDouble() ?? 0,
            (v) => state.updateElementProperty(el.id, 'min', v)));
        fields.add(InspectorFieldBuilders.buildDoubleField(tokens, 'Max', (el.properties['max'] as num?)?.toDouble() ?? 100,
            (v) => state.updateElementProperty(el.id, 'max', v)));
        fields.add(InspectorFieldBuilders.buildBoolToggle(tokens, 'AutoCenter', el.properties['autoCenter'] ?? false,
            (v) => state.updateElementProperty(el.id, 'autoCenter', v)));
        fields.add(InspectorFieldBuilders.buildOptionSelector(tokens, 'Spring',
            el.properties['springBehavior'] ?? 'smooth',
            ['smooth', 'elastic', 'linear'],
            (v) => state.updateElementProperty(el.id, 'springBehavior', v)));
        fields.add(InspectorFieldBuilders.buildDoubleField(tokens, 'Dur. (ms)', (el.properties['springDuration'] as num?)?.toDouble() ?? 300,
            (v) => state.updateElementProperty(el.id, 'springDuration', v)));
        break;

      case DesignerElementType.knob:
        fields.add(InspectorFieldBuilders.buildDoubleField(tokens, 'Min', (el.properties['min'] as num?)?.toDouble() ?? 0,
            (v) => state.updateElementProperty(el.id, 'min', v)));
        fields.add(InspectorFieldBuilders.buildDoubleField(tokens, 'Max', (el.properties['max'] as num?)?.toDouble() ?? 100,
            (v) => state.updateElementProperty(el.id, 'max', v)));
        fields.add(InspectorFieldBuilders.buildDoubleField(tokens, 'Min Angle', (el.properties['minAngle'] as num?)?.toDouble() ?? -135,
            (v) => state.updateElementProperty(el.id, 'minAngle', v)));
        fields.add(InspectorFieldBuilders.buildDoubleField(tokens, 'Max Angle', (el.properties['maxAngle'] as num?)?.toDouble() ?? 135,
            (v) => state.updateElementProperty(el.id, 'maxAngle', v)));
        fields.add(InspectorFieldBuilders.buildOptionSelector(tokens, 'Variant',
            el.properties['variant'] ?? 'standard',
            ['standard', 'steeringWheel'],
            (v) => state.updateElementProperty(el.id, 'variant', v)));
        fields.add(InspectorFieldBuilders.buildBoolToggle(tokens, 'AutoCenter', el.properties['autoCenter'] ?? false,
            (v) => state.updateElementProperty(el.id, 'autoCenter', v)));
        fields.add(InspectorFieldBuilders.buildOptionSelector(tokens, 'Spring',
            el.properties['springBehavior'] ?? 'smooth',
            ['smooth', 'elastic', 'linear'],
            (v) => state.updateElementProperty(el.id, 'springBehavior', v)));
        fields.add(InspectorFieldBuilders.buildDoubleField(tokens, 'Dur. (ms)', (el.properties['springDuration'] as num?)?.toDouble() ?? 500,
            (v) => state.updateElementProperty(el.id, 'springDuration', v)));
        break;

      case DesignerElementType.joystick:
        fields.add(InspectorFieldBuilders.buildBoolToggle(tokens, 'AutoCenter', el.properties['autoCenter'] ?? true,
            (v) => state.updateElementProperty(el.id, 'autoCenter', v)));
        fields.add(InspectorFieldBuilders.buildOptionSelector(tokens, 'Spring',
            el.properties['springBehavior'] ?? 'smooth',
            ['smooth', 'elastic', 'linear'],
            (v) => state.updateElementProperty(el.id, 'springBehavior', v)));
        fields.add(InspectorFieldBuilders.buildDoubleField(tokens, 'Dur. (ms)', (el.properties['springDuration'] as num?)?.toDouble() ?? 300,
            (v) => state.updateElementProperty(el.id, 'springDuration', v)));
        break;

      case DesignerElementType.multiButton:
        fields.add(InspectorFieldBuilders.buildBoolToggle(tokens, 'Haptics', el.properties['enableHapticFeedback'] ?? true,
            (v) => state.updateElementProperty(el.id, 'enableHapticFeedback', v)));
        fields.add(InspectorFieldBuilders.buildNumField(tokens, 'Items', (el.properties['itemCount'] as num?)?.toInt() ?? 3,
            (v) => state.updateElementProperty(el.id, 'itemCount', v)));
        break;

      case DesignerElementType.multiSelect:
        fields.add(InspectorFieldBuilders.buildBoolToggle(tokens, 'Haptics', el.properties['enableHapticFeedback'] ?? true,
            (v) => state.updateElementProperty(el.id, 'enableHapticFeedback', v)));
        fields.add(InspectorFieldBuilders.buildNumField(tokens, 'Items', (el.properties['itemCount'] as num?)?.toInt() ?? 3,
            (v) => state.updateElementProperty(el.id, 'itemCount', v)));
        break;

      case DesignerElementType.gasPedal:
        fields.add(InspectorFieldBuilders.buildDoubleField(tokens, 'Min', (el.properties['min'] as num?)?.toDouble() ?? 0,
            (v) => state.updateElementProperty(el.id, 'min', v)));
        fields.add(InspectorFieldBuilders.buildDoubleField(tokens, 'Max', (el.properties['max'] as num?)?.toDouble() ?? 100,
            (v) => state.updateElementProperty(el.id, 'max', v)));
        fields.add(InspectorFieldBuilders.buildBoolToggle(tokens, 'AutoCenter', el.properties['autoCenter'] ?? false,
            (v) => state.updateElementProperty(el.id, 'autoCenter', v)));
        fields.add(InspectorFieldBuilders.buildOptionSelector(tokens, 'Spring',
            el.properties['springBehavior'] ?? 'smooth',
            ['smooth', 'elastic', 'linear'],
            (v) => state.updateElementProperty(el.id, 'springBehavior', v)));
        fields.add(InspectorFieldBuilders.buildDoubleField(tokens, 'Dur. (ms)', (el.properties['springDuration'] as num?)?.toDouble() ?? 300,
            (v) => state.updateElementProperty(el.id, 'springDuration', v)));
        break;

      case DesignerElementType.led:
        fields.add(InspectorFieldBuilders.buildOptionSelector(tokens, 'State',
            el.properties['state'] ?? 'off',
            ['off', 'on', 'blink', 'breathe'],
            (v) => state.updateElementProperty(el.id, 'state', v)));
        fields.add(InspectorFieldBuilders.buildOptionSelector(tokens, 'Shape',
            el.properties['shape'] ?? 'circle',
            ['circle', 'square', 'diamond', 'star'],
            (v) => state.updateElementProperty(el.id, 'shape', v)));
        fields.add(InspectorFieldBuilders.buildNumField(tokens, 'Timing', (el.properties['timing'] as num?)?.toInt() ?? 500,
            (v) => state.updateElementProperty(el.id, 'timing', v)));
        break;

      case DesignerElementType.display:
        fields.add(InspectorFieldBuilders.buildTextField(tokens, 'Text', el.properties['text'] ?? 'Display',
            (v) => state.updateElementProperty(el.id, 'text', v)));
        fields.add(InspectorFieldBuilders.buildDoubleField(tokens, 'Font Size', (el.properties['fontSize'] as num?)?.toDouble() ?? 14,
            (v) => state.updateElementProperty(el.id, 'fontSize', v)));
        fields.add(InspectorFieldBuilders.buildOptionSelector(tokens, 'Font',
            el.properties['fontFamily'] ?? 'monospace',
            ['monospace', 'sans-serif', 'serif'],
            (v) => state.updateElementProperty(el.id, 'fontFamily', v)));
        break;

      case DesignerElementType.serialMonitor:
        fields.add(InspectorFieldBuilders.buildDoubleField(tokens, 'Font Size', (el.properties['fontSize'] as num?)?.toDouble() ?? 12,
            (v) => state.updateElementProperty(el.id, 'fontSize', v)));
        fields.add(InspectorFieldBuilders.buildOptionSelector(tokens, 'Font',
            el.properties['fontFamily'] ?? 'monospace',
            ['monospace', 'sans-serif', 'serif'],
            (v) => state.updateElementProperty(el.id, 'fontFamily', v)));
        break;
    }

    return fields;
  }
}
