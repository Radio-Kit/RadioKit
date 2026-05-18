import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';
import 'inspector_field_builders.dart';

class DesignerInspector extends StatefulWidget {
  final DesignerState state;
  const DesignerInspector({super.key, required this.state});

  @override
  State<DesignerInspector> createState() => _DesignerInspectorState();
}

class _DesignerInspectorState extends State<DesignerInspector> {

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);
    final el = widget.state.selectedElement;

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
                          widget.state.updateElementLabel(el.id, v);
                        }),
                        _buildSizeRow(tokens, el),
                      ]),
                      InspectorFieldBuilders.buildSection(tokens, 'BEHAVIOR', _buildBehaviorFields(tokens, el)),
                      InspectorFieldBuilders.buildSection(tokens, 'TRANSFORM', [
                        _buildPositionRow(tokens, el),
                        const SizedBox(height: 8),
                        InspectorFieldBuilders.buildRotationSlider(tokens, el.rotation.toDouble(), (v) {
                          widget.state.updateElementRotation(el.id, v.round());
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

  String _headerTitle() {
    final el = widget.state.selectedElement;
    if (el == null) return 'Model Settings';
    return '${_widgetTypeName(el.type)} Widget';
  }

  static String _widgetTypeName(DesignerElementType type) {
    switch (type) {
      case DesignerElementType.button:        return 'Button';
      case DesignerElementType.slideSwitch:   return 'Slide Switch';
      case DesignerElementType.rockerSwitch:  return 'Rocker Switch';
      case DesignerElementType.slider:        return 'Linear Slider';
      case DesignerElementType.gasPedal:      return 'Gas Pedal';
      case DesignerElementType.knob:          return 'Rotary Knob';
      case DesignerElementType.steeringWheel: return 'Steering Wheel';
      case DesignerElementType.joystick:      return 'Joystick';
      case DesignerElementType.multiButton:   return 'Multi Button';
      case DesignerElementType.multiSelect:   return 'Multi Select';
      case DesignerElementType.led:           return 'LED';
      case DesignerElementType.text:          return 'Text Display';
      case DesignerElementType.serialMonitor: return 'Serial Monitor';
    }
  }

  Widget _buildHeader(RKTokens tokens) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(LucideIcons.list, color: tokens.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _headerTitle(),
              style: const TextStyle(
                color: Color(0xFFE0E0E0),
                fontSize: 14,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(LucideIcons.chevronRight, color: Color(0xFFE0E0E0)),
            onPressed: () => widget.state.setInspectorVisible(false),
            tooltip: 'Close',
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
          InspectorFieldBuilders.buildCenterPinnedSelector(
            tokens, 'Type',
            widget.state.connectionType,
            ['ble', 'serial'],
            (v) => widget.state.setConnectionType(v),
          ),
          InspectorFieldBuilders.buildTextField(tokens, 'Password', widget.state.connectionPassword,
              (v) => widget.state.setConnectionPassword(v)),
        ]),
        InspectorFieldBuilders.buildSection(tokens, 'MODEL', [
          InspectorFieldBuilders.buildTextField(tokens, 'Name *', widget.state.modelName,
              (v) => widget.state.setModelName(v)),
          InspectorFieldBuilders.buildTextField(tokens, 'Description', widget.state.modelDescription,
              (v) => widget.state.setModelDescription(v)),
          InspectorFieldBuilders.buildCenterPinnedSelector(
            tokens, 'Type',
            widget.state.modelType.isEmpty ? 'Locomotive' : widget.state.modelType,
            ['Locomotive', 'Truck', 'Car', 'IOT'],
            (v) => widget.state.setModelType(v),
          ),
        ]),
        InspectorFieldBuilders.buildSection(tokens, 'CANVAS', [
          InspectorFieldBuilders.buildCenterPinnedSelector(
            tokens, 'Orientation',
            widget.state.isLandscape ? 'Landscape' : 'Portrait',
            ['Landscape', 'Portrait'],
            (v) {
              if ((v == 'Landscape') != widget.state.isLandscape) {
                widget.state.toggleOrientation();
              }
            },
          ),
          InspectorFieldBuilders.buildReadOnlyField(
            tokens, 'Size',
            widget.state.isLandscape ? '200 x 100' : '100 x 200',
          ),
          InspectorFieldBuilders.buildCenterPinnedSelector(
            tokens, 'Grid',
            widget.state.gridStyle.name,
            ['lines', 'dots', 'none'],
            (v) => widget.state.setGridStyle(GridStyle.values.byName(v)),
          ),
          InspectorFieldBuilders.buildCenterPinnedSelector(
            tokens, 'Skin',
            widget.state.activeSkin,
            ['dragon', 'neon', 'minimal'],
            (v) {
              widget.state.setSkin(v);
            },
          ),
        ]),
      ],
    );
  }

  Widget _buildPositionRow(RKTokens tokens, DesignerElement el) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: InspectorFieldBuilders.buildCompactNumField(tokens, 'X', el.x, (v) {
              widget.state.updateElementPosition(el.id, v, el.y);
            }),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InspectorFieldBuilders.buildCompactNumField(tokens, 'Y', el.y, (v) {
              widget.state.updateElementPosition(el.id, el.x, v);
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
                widget.state.updateElementSize(el.id, width: v, height: v);
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
              widget.state.updateElementSize(el.id, width: v);
            }),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InspectorFieldBuilders.buildCompactNumField(tokens, 'H', el.height, (v) {
              widget.state.updateElementSize(el.id, height: v);
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
          onPressed: () => widget.state.removeSelected(),
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
        fields.add(InspectorFieldBuilders.buildCenterPinnedSelector(tokens, 'Mode',
            el.properties['mode'] ?? 'push',
            ['push', 'toggle'],
            (v) => widget.state.updateElementProperty(el.id, 'mode', v)));
        fields.add(InspectorFieldBuilders.buildTextField(tokens, 'On Text', el.properties['onText'] ?? 'ON',
            (v) => widget.state.updateElementProperty(el.id, 'onText', v)));
        fields.add(InspectorFieldBuilders.buildTextField(tokens, 'Off Text', el.properties['offText'] ?? 'OFF',
            (v) => widget.state.updateElementProperty(el.id, 'offText', v)));
        fields.add(InspectorFieldBuilders.buildBoolToggle(tokens, 'Haptics', el.properties['enableHapticFeedback'] ?? true,
            (v) => widget.state.updateElementProperty(el.id, 'enableHapticFeedback', v)));
        break;

      case DesignerElementType.slideSwitch:
        fields.add(InspectorFieldBuilders.buildTextField(tokens, 'On Text', el.properties['onText'] ?? 'ON',
            (v) => widget.state.updateElementProperty(el.id, 'onText', v)));
        fields.add(InspectorFieldBuilders.buildTextField(tokens, 'Off Text', el.properties['offText'] ?? 'OFF',
            (v) => widget.state.updateElementProperty(el.id, 'offText', v)));
        fields.add(InspectorFieldBuilders.buildBoolToggle(tokens, 'Haptics', el.properties['enableHapticFeedback'] ?? true,
            (v) => widget.state.updateElementProperty(el.id, 'enableHapticFeedback', v)));
        break;

      case DesignerElementType.rockerSwitch:
        fields.add(InspectorFieldBuilders.buildBoolToggle(tokens, 'Haptics', el.properties['enableHapticFeedback'] ?? true,
            (v) => widget.state.updateElementProperty(el.id, 'enableHapticFeedback', v)));
        break;

      case DesignerElementType.slider:
        fields.add(InspectorFieldBuilders.buildDoubleField(tokens, 'Min', (el.properties['min'] as num?)?.toDouble() ?? 0,
            (v) => widget.state.updateElementProperty(el.id, 'min', v)));
        fields.add(InspectorFieldBuilders.buildDoubleField(tokens, 'Max', (el.properties['max'] as num?)?.toDouble() ?? 100,
            (v) => widget.state.updateElementProperty(el.id, 'max', v)));
        fields.add(InspectorFieldBuilders.buildBoolToggle(tokens, 'AutoCenter', el.properties['autoCenter'] ?? false,
            (v) => widget.state.updateElementProperty(el.id, 'autoCenter', v)));
        final autoCenterSlider = el.properties['autoCenter'] ?? false;
        if (autoCenterSlider) {
          final double centerVal = (el.properties['center'] as num?)?.toDouble() ?? 0.5;
          String positionString = 'center';
          if (centerVal == 0.0) {
            positionString = 'min';
          } else if (centerVal == 1.0) {
            positionString = 'max';
          } else {
            positionString = 'center';
          }
          fields.add(InspectorFieldBuilders.buildCenterPinnedSelector(
            tokens,
            'Position',
            positionString,
            ['min', 'center', 'max'],
            (v) {
              double targetVal = 0.5;
              if (v == 'min') targetVal = 0.0;
              if (v == 'max') targetVal = 1.0;
              widget.state.updateElementProperty(el.id, 'center', targetVal);
            },
          ));
          fields.add(InspectorFieldBuilders.buildCenterPinnedSelector(tokens, 'Spring',
            el.properties['springBehavior'] ?? 'smooth',
            ['smooth', 'elastic', 'linear'],
            (v) => widget.state.updateElementProperty(el.id, 'springBehavior', v)));
          fields.add(InspectorFieldBuilders.buildDoubleField(tokens, 'Dur. (ms)', (el.properties['springDuration'] as num?)?.toDouble() ?? 300,
            (v) => widget.state.updateElementProperty(el.id, 'springDuration', v)));
        }
        break;

      case DesignerElementType.knob:
        fields.add(InspectorFieldBuilders.buildDoubleField(tokens, 'Min', (el.properties['min'] as num?)?.toDouble() ?? 0,
            (v) => widget.state.updateElementProperty(el.id, 'min', v)));
        fields.add(InspectorFieldBuilders.buildDoubleField(tokens, 'Max', (el.properties['max'] as num?)?.toDouble() ?? 100,
            (v) => widget.state.updateElementProperty(el.id, 'max', v)));
        fields.add(InspectorFieldBuilders.buildDoubleField(tokens, 'Min Angle', (el.properties['minAngle'] as num?)?.toDouble() ?? -135,
            (v) => widget.state.updateElementProperty(el.id, 'minAngle', v)));
        fields.add(InspectorFieldBuilders.buildDoubleField(tokens, 'Max Angle', (el.properties['maxAngle'] as num?)?.toDouble() ?? 135,
            (v) => widget.state.updateElementProperty(el.id, 'maxAngle', v)));
        fields.add(InspectorFieldBuilders.buildBoolToggle(tokens, 'AutoCenter', el.properties['autoCenter'] ?? false,
            (v) => widget.state.updateElementProperty(el.id, 'autoCenter', v)));
        final autoCenterKnob = el.properties['autoCenter'] ?? false;
        if (autoCenterKnob) {
          final double centerVal = (el.properties['center'] as num?)?.toDouble() ?? 0.5;
          String positionString = 'center';
          if (centerVal == 0.0) {
            positionString = 'min';
          } else if (centerVal == 1.0) {
            positionString = 'max';
          } else {
            positionString = 'center';
          }
          fields.add(InspectorFieldBuilders.buildCenterPinnedSelector(
            tokens,
            'Position',
            positionString,
            ['min', 'center', 'max'],
            (v) {
              double targetVal = 0.5;
              if (v == 'min') targetVal = 0.0;
              if (v == 'max') targetVal = 1.0;
              widget.state.updateElementProperty(el.id, 'center', targetVal);
            },
          ));
          fields.add(InspectorFieldBuilders.buildCenterPinnedSelector(tokens, 'Spring',
            el.properties['springBehavior'] ?? 'smooth',
            ['smooth', 'elastic', 'linear'],
            (v) => widget.state.updateElementProperty(el.id, 'springBehavior', v)));
          fields.add(InspectorFieldBuilders.buildDoubleField(tokens, 'Dur. (ms)', (el.properties['springDuration'] as num?)?.toDouble() ?? 500,
            (v) => widget.state.updateElementProperty(el.id, 'springDuration', v)));
        }
        break;

      case DesignerElementType.steeringWheel: // forceSwitch
        fields.add(InspectorFieldBuilders.buildDoubleField(tokens, 'Min', (el.properties['min'] as num?)?.toDouble() ?? 0,
            (v) => widget.state.updateElementProperty(el.id, 'min', v)));
        fields.add(InspectorFieldBuilders.buildDoubleField(tokens, 'Max', (el.properties['max'] as num?)?.toDouble() ?? 100,
            (v) => widget.state.updateElementProperty(el.id, 'max', v)));
        fields.add(InspectorFieldBuilders.buildDoubleField(tokens, 'Min Angle', (el.properties['minAngle'] as num?)?.toDouble() ?? -135,
            (v) => widget.state.updateElementProperty(el.id, 'minAngle', v)));
        fields.add(InspectorFieldBuilders.buildDoubleField(tokens, 'Max Angle', (el.properties['maxAngle'] as num?)?.toDouble() ?? 135,
            (v) => widget.state.updateElementProperty(el.id, 'maxAngle', v)));
        fields.add(InspectorFieldBuilders.buildBoolToggle(tokens, 'AutoCenter', el.properties['autoCenter'] ?? false,
            (v) => widget.state.updateElementProperty(el.id, 'autoCenter', v)));
        final autoCenterSteering = el.properties['autoCenter'] ?? false;
        if (autoCenterSteering) {
          final double centerVal = (el.properties['center'] as num?)?.toDouble() ?? 0.5;
          String positionString = 'center';
          if (centerVal == 0.0) {
            positionString = 'min';
          } else if (centerVal == 1.0) {
            positionString = 'max';
          } else {
            positionString = 'center';
          }
          fields.add(InspectorFieldBuilders.buildCenterPinnedSelector(
            tokens,
            'Position',
            positionString,
            ['min', 'center', 'max'],
            (v) {
              double targetVal = 0.5;
              if (v == 'min') targetVal = 0.0;
              if (v == 'max') targetVal = 1.0;
              widget.state.updateElementProperty(el.id, 'center', targetVal);
            },
          ));
          fields.add(InspectorFieldBuilders.buildCenterPinnedSelector(tokens, 'Spring',
            el.properties['springBehavior'] ?? 'smooth',
            ['smooth', 'elastic', 'linear'],
            (v) => widget.state.updateElementProperty(el.id, 'springBehavior', v)));
          fields.add(InspectorFieldBuilders.buildDoubleField(tokens, 'Dur. (ms)', (el.properties['springDuration'] as num?)?.toDouble() ?? 500,
            (v) => widget.state.updateElementProperty(el.id, 'springDuration', v)));
        }
        break;

      case DesignerElementType.joystick:
        fields.add(InspectorFieldBuilders.buildBoolToggle(tokens, 'AutoCenter', el.properties['autoCenter'] ?? true,
            (v) => widget.state.updateElementProperty(el.id, 'autoCenter', v)));
        final autoCenterJoystick = el.properties['autoCenter'] ?? true;
        if (autoCenterJoystick) {
          final double cx = (el.properties['centerX'] as num?)?.toDouble() ?? 0.0;
          final double cy = (el.properties['centerY'] as num?)?.toDouble() ?? 0.0;
          String positionString = 'center';
          if (cx == -1.0 && cy == 0.0) {
            positionString = 'left';
          } else if (cx == 1.0 && cy == 0.0) {
            positionString = 'right';
          } else if (cx == 0.0 && cy == 1.0) {
            positionString = 'top';
          } else if (cx == 0.0 && cy == -1.0) {
            positionString = 'down';
          } else {
            positionString = 'center';
          }
          fields.add(InspectorFieldBuilders.buildCenterPinnedSelector(
            tokens,
            'Position',
            positionString,
            ['left', 'right', 'top', 'down', 'center'],
            (v) {
              double targetCx = 0.0;
              double targetCy = 0.0;
              if (v == 'left') targetCx = -1.0;
              if (v == 'right') targetCx = 1.0;
              if (v == 'top') targetCy = 1.0;
              if (v == 'down') targetCy = -1.0;
              widget.state.updateElementProperty(el.id, 'centerX', targetCx);
              widget.state.updateElementProperty(el.id, 'centerY', targetCy);
            },
          ));
          fields.add(InspectorFieldBuilders.buildCenterPinnedSelector(tokens, 'Spring',
            el.properties['springBehavior'] ?? 'smooth',
            ['smooth', 'elastic', 'linear'],
            (v) => widget.state.updateElementProperty(el.id, 'springBehavior', v)));
          fields.add(InspectorFieldBuilders.buildDoubleField(tokens, 'Dur. (ms)', (el.properties['springDuration'] as num?)?.toDouble() ?? 300,
            (v) => widget.state.updateElementProperty(el.id, 'springDuration', v)));
        }
        break;

      case DesignerElementType.multiButton:
        fields.add(InspectorFieldBuilders.buildBoolToggle(tokens, 'Haptics', el.properties['enableHapticFeedback'] ?? true,
            (v) => widget.state.updateElementProperty(el.id, 'enableHapticFeedback', v)));
        fields.add(InspectorFieldBuilders.buildNumField(tokens, 'Items', (el.properties['itemCount'] as num?)?.toInt() ?? 3,
            (v) => widget.state.updateElementProperty(el.id, 'itemCount', v)));
        break;

      case DesignerElementType.multiSelect:
        fields.add(InspectorFieldBuilders.buildBoolToggle(tokens, 'Haptics', el.properties['enableHapticFeedback'] ?? true,
            (v) => widget.state.updateElementProperty(el.id, 'enableHapticFeedback', v)));
        fields.add(InspectorFieldBuilders.buildNumField(tokens, 'Items', (el.properties['itemCount'] as num?)?.toInt() ?? 3,
            (v) => widget.state.updateElementProperty(el.id, 'itemCount', v)));
        break;

      case DesignerElementType.gasPedal:
        fields.add(InspectorFieldBuilders.buildDoubleField(tokens, 'Min', (el.properties['min'] as num?)?.toDouble() ?? 0,
            (v) => widget.state.updateElementProperty(el.id, 'min', v)));
        fields.add(InspectorFieldBuilders.buildDoubleField(tokens, 'Max', (el.properties['max'] as num?)?.toDouble() ?? 100,
            (v) => widget.state.updateElementProperty(el.id, 'max', v)));
        fields.add(InspectorFieldBuilders.buildBoolToggle(tokens, 'AutoCenter', el.properties['autoCenter'] ?? false,
            (v) => widget.state.updateElementProperty(el.id, 'autoCenter', v)));
        final autoCenterPedal = el.properties['autoCenter'] ?? false;
        if (autoCenterPedal) {
          final double centerVal = (el.properties['center'] as num?)?.toDouble() ?? 0.5;
          String positionString = 'center';
          if (centerVal == 0.0) {
            positionString = 'min';
          } else if (centerVal == 1.0) {
            positionString = 'max';
          } else {
            positionString = 'center';
          }
          fields.add(InspectorFieldBuilders.buildCenterPinnedSelector(
            tokens,
            'Position',
            positionString,
            ['min', 'center', 'max'],
            (v) {
              double targetVal = 0.5;
              if (v == 'min') targetVal = 0.0;
              if (v == 'max') targetVal = 1.0;
              widget.state.updateElementProperty(el.id, 'center', targetVal);
            },
          ));
          fields.add(InspectorFieldBuilders.buildCenterPinnedSelector(tokens, 'Spring',
            el.properties['springBehavior'] ?? 'smooth',
            ['smooth', 'elastic', 'linear'],
            (v) => widget.state.updateElementProperty(el.id, 'springBehavior', v)));
          fields.add(InspectorFieldBuilders.buildDoubleField(tokens, 'Dur. (ms)', (el.properties['springDuration'] as num?)?.toDouble() ?? 300,
            (v) => widget.state.updateElementProperty(el.id, 'springDuration', v)));
        }
        break;

      case DesignerElementType.led:
        fields.add(InspectorFieldBuilders.buildCenterPinnedSelector(tokens, 'State',
            el.properties['state'] ?? 'off',
            ['off', 'on', 'blink', 'breathe'],
            (v) => widget.state.updateElementProperty(el.id, 'state', v)));
        fields.add(InspectorFieldBuilders.buildCenterPinnedSelector(tokens, 'Shape',
            el.properties['shape'] ?? 'circle',
            ['circle', 'square', 'diamond', 'star'],
            (v) => widget.state.updateElementProperty(el.id, 'shape', v)));
        fields.add(InspectorFieldBuilders.buildNumField(tokens, 'Timing', (el.properties['timing'] as num?)?.toInt() ?? 500,
            (v) => widget.state.updateElementProperty(el.id, 'timing', v)));
        break;

      case DesignerElementType.text:
        fields.add(InspectorFieldBuilders.buildTextField(tokens, 'Text', el.properties['text'] ?? 'Display',
            (v) => widget.state.updateElementProperty(el.id, 'text', v)));
        fields.add(InspectorFieldBuilders.buildDoubleField(tokens, 'Font Size', (el.properties['fontSize'] as num?)?.toDouble() ?? 14,
            (v) => widget.state.updateElementProperty(el.id, 'fontSize', v)));
        fields.add(InspectorFieldBuilders.buildCenterPinnedSelector(tokens, 'Font',
            el.properties['fontFamily'] ?? 'monospace',
            ['monospace', 'sans-serif', 'serif'],
            (v) => widget.state.updateElementProperty(el.id, 'fontFamily', v)));
        break;

      case DesignerElementType.serialMonitor:
        fields.add(InspectorFieldBuilders.buildDoubleField(tokens, 'Font Size', (el.properties['fontSize'] as num?)?.toDouble() ?? 12,
            (v) => widget.state.updateElementProperty(el.id, 'fontSize', v)));
        fields.add(InspectorFieldBuilders.buildCenterPinnedSelector(tokens, 'Font',
            el.properties['fontFamily'] ?? 'monospace',
            ['monospace', 'sans-serif', 'serif'],
            (v) => widget.state.updateElementProperty(el.id, 'fontFamily', v)));
        break;
    }

    return fields;
  }
}
