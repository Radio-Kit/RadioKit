import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';
import 'inspector_field_builders.dart';

/// Validates that [name] is a legal C++ identifier.
/// A valid C++ identifier starts with a letter or underscore and contains
/// only letters, digits, or underscores.
bool isCppIdentifier(String name) {
  if (name.isEmpty) return true; // empty is allowed (no label)
  return RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$').hasMatch(name);
}

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
                      _buildLabelField(tokens, el),
                    ]),
                    InspectorFieldBuilders.buildSection(
                        tokens, 'BEHAVIOR', _buildBehaviorFields(tokens, el)),
                    InspectorFieldBuilders.buildSection(tokens, 'TRANSFORM', [
                      _buildSizeRow(tokens, el),
                      _buildPositionRow(tokens, el),
                      const SizedBox(height: 8),
                      InspectorFieldBuilders.buildRotationSlider(
                          tokens, el.rotation.toDouble(), (v) {
                        widget.state.updateElementRotation(el.id, v.round());
                      },
                          onReset: () =>
                              widget.state.updateElementRotation(el.id, 0)),
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
      case DesignerElementType.button:
        return 'Button';
      case DesignerElementType.slideSwitch:
        return 'Slide Switch';
      case DesignerElementType.rockerSwitch:
        return 'Rocker Switch';
      case DesignerElementType.slider:
        return 'Linear Slider';
      case DesignerElementType.gasPedal:
        return 'Gas Pedal';
      case DesignerElementType.knob:
        return 'Rotary Knob';
      case DesignerElementType.steeringWheel:
        return 'Steering Wheel';
      case DesignerElementType.joystick:
        return 'Joystick';
      case DesignerElementType.multiButton:
        return 'Multi Button';
      case DesignerElementType.multiSelect:
        return 'Multi Select';
      case DesignerElementType.led:
        return 'LED';
      case DesignerElementType.text:
        return 'Text Display';
      case DesignerElementType.serialMonitor:
        return 'Serial Monitor';
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
            icon:
                const Icon(LucideIcons.chevronRight, color: Color(0xFFE0E0E0)),
            onPressed: () => widget.state.setInspectorVisible(false),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildLabelField(RKTokens tokens, DesignerElement el) {
    final isValid = el.label.isEmpty || isCppIdentifier(el.label);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              'Label',
              style: TextStyle(
                color:
                    isValid ? const Color(0xFF888888) : const Color(0xFFFF5555),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D0D),
                border: Border.all(
                  color: isValid
                      ? const Color(0xFF333333)
                      : const Color(0xFFFF5555),
                ),
                borderRadius: BorderRadius.circular(2),
              ),
              child: TextField(
                controller: TextEditingController(text: el.label)
                  ..selection =
                      TextSelection.collapsed(offset: el.label.length),
                style: const TextStyle(
                  color: Color(0xFFE0E0E0),
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  border: InputBorder.none,
                  isDense: true,
                  suffixIcon: !isValid
                      ? const Tooltip(
                          message:
                              'Must be a valid C++ identifier\n(starts with letter or _, contains\nonly letters, digits, or _)',
                          child: Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              LucideIcons.alertCircle,
                              size: 14,
                              color: Color(0xFFFF5555),
                            ),
                          ),
                        )
                      : null,
                ),
                inputFormatters: [CppIdentifierFormatter()],
                onChanged: (v) => widget.state.updateElementLabel(el.id, v),
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => widget.state.toggleElementLabelHidden(el.id),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: el.labelHidden
                    ? const Color(0xFF0D0D0D)
                    : const Color(0xFF1A1A1A),
                border: Border.all(
                  color:
                      el.labelHidden ? const Color(0xFF555555) : tokens.primary,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Icon(
                el.labelHidden ? LucideIcons.eyeOff : LucideIcons.eye,
                size: 14,
                color:
                    el.labelHidden ? const Color(0xFF666666) : tokens.primary,
              ),
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
          InspectorFieldBuilders.buildCenterPinnedSelector(
            tokens,
            'Type',
            widget.state.connectionType,
            ['ble', 'serial'],
            (v) => widget.state.setConnectionType(v),
          ),
          InspectorFieldBuilders.buildTextField(
              tokens,
              'Password',
              widget.state.connectionPassword,
              (v) => widget.state.setConnectionPassword(v)),
        ]),
        InspectorFieldBuilders.buildSection(tokens, 'MODEL', [
          InspectorFieldBuilders.buildTextField(tokens, 'Name *',
              widget.state.modelName, (v) => widget.state.setModelName(v)),
          InspectorFieldBuilders.buildTextField(
              tokens,
              'Description',
              widget.state.modelDescription,
              (v) => widget.state.setModelDescription(v)),
          InspectorFieldBuilders.buildCenterPinnedSelector(
            tokens,
            'Type',
            widget.state.modelType.isEmpty
                ? 'Locomotive'
                : widget.state.modelType,
            ['Locomotive', 'Truck', 'Car', 'IOT'],
            (v) => widget.state.setModelType(v),
          ),
        ]),
        InspectorFieldBuilders.buildSection(tokens, 'CANVAS', [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    'Orientation',
                    style: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildMiniToggle(
                          tokens,
                          label: 'LANDSCAPE',
                          selected: widget.state.isLandscape,
                          onTap: () {
                            if (!widget.state.isLandscape)
                              widget.state.toggleOrientation();
                          },
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _buildMiniToggle(
                          tokens,
                          label: 'PORTRAIT',
                          selected: !widget.state.isLandscape,
                          onTap: () {
                            if (widget.state.isLandscape)
                              widget.state.toggleOrientation();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          InspectorFieldBuilders.buildReadOnlyField(
            tokens,
            'Size',
            widget.state.isLandscape ? '200 x 100' : '100 x 200',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    'Grid',
                    style: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildMiniToggle(
                          tokens,
                          label: 'LINES',
                          selected: widget.state.gridStyle == GridStyle.lines,
                          onTap: () =>
                              widget.state.setGridStyle(GridStyle.lines),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _buildMiniToggle(
                          tokens,
                          label: 'DOTS',
                          selected: widget.state.gridStyle == GridStyle.dots,
                          onTap: () =>
                              widget.state.setGridStyle(GridStyle.dots),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _buildMiniToggle(
                          tokens,
                          label: 'NONE',
                          selected: widget.state.gridStyle == GridStyle.none,
                          onTap: () =>
                              widget.state.setGridStyle(GridStyle.none),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          InspectorFieldBuilders.buildCenterPinnedSelector(
            tokens,
            'Skin',
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Position',
            style: TextStyle(
              color: Color(0xFF888888),
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: InspectorFieldBuilders.buildCompactNumField(
                    tokens, 'X', el.x, (v) {
                  widget.state.updateElementPosition(el.id, v, el.y);
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InspectorFieldBuilders.buildCompactNumField(
                    tokens, 'Y', el.y, (v) {
                  widget.state.updateElementPosition(el.id, el.x, v);
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSizeRow(RKTokens tokens, DesignerElement el) {
    final ar = el.aspectRatio;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Size',
                style: TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  final (dw, dh) = DesignerElement.defaultSize(el.type);
                  widget.state.updateElementSize(el.id, width: dw, height: dh);
                },
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(LucideIcons.rotateCcw,
                      size: 12, color: const Color(0xFF555555)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (ar != null && ar >= 0)
                // Horizontal fixed-AR or square: height is primary.
                Expanded(
                  child: InspectorFieldBuilders.buildCompactNumField(
                      tokens, 'H', el.height, (v) {
                    final autoW = (v * ar).round().clamp(1, 999);
                    widget.state
                        .updateElementSize(el.id, width: autoW, height: v);
                  }),
                )
              else if (ar != null && ar < 0)
                // Vertical fixed-AR: width is primary.
                Expanded(
                  child: InspectorFieldBuilders.buildCompactNumField(
                      tokens, 'W', el.width, (v) {
                    final autoH = (v * -ar).round().clamp(1, 999);
                    widget.state
                        .updateElementSize(el.id, width: v, height: autoH);
                  }),
                )
              else ...[
                Expanded(
                  child: InspectorFieldBuilders.buildCompactNumField(
                      tokens, 'W', el.width, (v) {
                    widget.state.updateElementSize(el.id, width: v);
                  }),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InspectorFieldBuilders.buildCompactNumField(
                      tokens, 'H', el.height, (v) {
                    widget.state.updateElementSize(el.id, height: v);
                  }),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniToggle(
    RKTokens tokens, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? tokens.primary : const Color(0xFF1A1A1A),
          border: Border.all(
            color: selected ? tokens.primary : const Color(0xFF444444),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.black : const Color(0xFF888888),
            fontSize: 10,
            fontFamily: 'monospace',
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
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
        fields.add(InspectorFieldBuilders.buildCenterPinnedSelector(
            tokens,
            'Mode',
            el.properties['variant'] ?? 'push',
            ['push', 'toggle'],
            (v) => widget.state.updateElementProperty(el.id, 'variant', v)));
        fields.add(InspectorFieldBuilders.buildTextField(
            tokens,
            'On Text',
            el.properties['onText'] ?? 'ON',
            (v) => widget.state.updateElementProperty(el.id, 'onText', v)));
        fields.add(IconFieldBuilder.buildIconSelectorField(
            context,
            'On Icon',
            el.properties['onIcon'] as String?,
            (v) => widget.state.updateElementProperty(el.id, 'onIcon', v)));
        fields.add(InspectorFieldBuilders.buildTextField(
            tokens,
            'Off Text',
            el.properties['offText'] ?? 'OFF',
            (v) => widget.state.updateElementProperty(el.id, 'offText', v)));
        fields.add(IconFieldBuilder.buildIconSelectorField(
            context,
            'Off Icon',
            el.properties['offIcon'] as String?,
            (v) => widget.state.updateElementProperty(el.id, 'offIcon', v)));
        fields.add(InspectorFieldBuilders.buildBoolToggle(
            tokens,
            'Haptics',
            el.properties['haptic'] ?? true,
            (v) => widget.state.updateElementProperty(el.id, 'haptic', v)));
        break;

      case DesignerElementType.slideSwitch:
        fields.add(InspectorFieldBuilders.buildTextField(
            tokens,
            'On Text',
            el.properties['onText'] ?? 'ON',
            (v) => widget.state.updateElementProperty(el.id, 'onText', v)));
        fields.add(InspectorFieldBuilders.buildTextField(
            tokens,
            'Off Text',
            el.properties['offText'] ?? 'OFF',
            (v) => widget.state.updateElementProperty(el.id, 'offText', v)));
        fields.add(InspectorFieldBuilders.buildBoolToggle(
            tokens,
            'Haptics',
            el.properties['haptic'] ?? true,
            (v) => widget.state.updateElementProperty(el.id, 'haptic', v)));
        break;

      case DesignerElementType.rockerSwitch:
        fields.add(IconFieldBuilder.buildIconSelectorField(
            context,
            'On Icon',
            el.properties['onIcon'] as String?,
            (v) => widget.state.updateElementProperty(el.id, 'onIcon', v)));
        fields.add(IconFieldBuilder.buildIconSelectorField(
            context,
            'Off Icon',
            el.properties['offIcon'] as String?,
            (v) => widget.state.updateElementProperty(el.id, 'offIcon', v)));
        fields.add(InspectorFieldBuilders.buildBoolToggle(
            tokens,
            'Haptics',
            el.properties['haptic'] ?? true,
            (v) => widget.state.updateElementProperty(el.id, 'haptic', v)));
        break;

      case DesignerElementType.slider:
        final currentMin = (el.properties['min'] as num?)?.toInt() ?? 0;
        final currentType = currentMin == -100 ? 'bi' : 'uni';
        fields.add(InspectorFieldBuilders.buildOptionSelector(
          tokens,
          'Range',
          currentType,
          ['uni', 'bi'],
          (v) {
            if (v == 'bi') {
              widget.state.updateElementProperty(el.id, 'min', -100);
              widget.state.updateElementProperty(el.id, 'max', 100);
            } else {
              widget.state.updateElementProperty(el.id, 'min', 0);
              widget.state.updateElementProperty(el.id, 'max', 100);
            }
          },
          suffix: Text(
            currentType == 'bi' ? '(-100 - 100)' : '(0 - 100)',
            style: const TextStyle(
              color: Color(0xFF666666),
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
        ));
        fields.add(InspectorFieldBuilders.buildBoolToggle(
            tokens,
            'AutoCenter',
            el.properties['autoCenter'] ?? false,
            (v) => widget.state.updateElementProperty(el.id, 'autoCenter', v)));
        final autoCenterSlider = el.properties['autoCenter'] ?? false;
        if (autoCenterSlider) {
          final double centerVal =
              (el.properties['center'] as num?)?.toDouble() ?? 0.5;
          String positionString = 'center';
          if (centerVal == 0.0) {
            positionString = 'min';
          } else if (centerVal == 1.0) {
            positionString = 'max';
          } else {
            positionString = 'center';
          }
          fields.add(InspectorFieldBuilders.buildOptionSelector(
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
          fields.add(InspectorFieldBuilders.buildOptionSelector(
              tokens,
              'Spring',
              el.properties['springBehavior'] ?? 'smooth',
              ['smooth', 'elastic', 'linear'],
              (v) => widget.state
                  .updateElementProperty(el.id, 'springBehavior', v)));
          fields.add(InspectorFieldBuilders.buildNumField(
              tokens,
              'Dur. (ms)',
              (el.properties['springDuration'] as num?)?.toInt() ?? 300,
              (v) => widget.state
                  .updateElementProperty(el.id, 'springDuration', v)));
        }
        break;

      case DesignerElementType.knob:
        fields.add(IconFieldBuilder.buildIconSelectorField(
            context,
            'Center Icon',
            el.properties['centerIcon'] as String?,
            (v) => widget.state.updateElementProperty(el.id, 'centerIcon', v)));
        final currentMin = (el.properties['min'] as num?)?.toInt() ?? 0;
        final currentType = currentMin == -100 ? 'bi' : 'uni';
        fields.add(InspectorFieldBuilders.buildOptionSelector(
          tokens,
          'Range',
          currentType,
          ['uni', 'bi'],
          (v) {
            if (v == 'bi') {
              widget.state.updateElementProperty(el.id, 'min', -100);
              widget.state.updateElementProperty(el.id, 'max', 100);
            } else {
              widget.state.updateElementProperty(el.id, 'min', 0);
              widget.state.updateElementProperty(el.id, 'max', 100);
            }
          },
          suffix: Text(
            currentType == 'bi' ? '(-100 - 100)' : '(0 - 100)',
            style: const TextStyle(
              color: Color(0xFF666666),
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
        ));
        fields.add(InspectorFieldBuilders.buildNumField(
            tokens,
            'Min Angle',
            (el.properties['minAngle'] as num?)?.toInt() ?? -135,
            (v) => widget.state.updateElementProperty(el.id, 'minAngle', v),
            min: -360.0,
            max: 360.0));
        fields.add(InspectorFieldBuilders.buildNumField(
            tokens,
            'Max Angle',
            (el.properties['maxAngle'] as num?)?.toInt() ?? 135,
            (v) => widget.state.updateElementProperty(el.id, 'maxAngle', v),
            min: -360.0,
            max: 360.0));
        fields.add(InspectorFieldBuilders.buildBoolToggle(
            tokens,
            'AutoCenter',
            el.properties['autoCenter'] ?? false,
            (v) => widget.state.updateElementProperty(el.id, 'autoCenter', v)));
        final autoCenterKnob = el.properties['autoCenter'] ?? false;
        if (autoCenterKnob) {
          final double centerVal =
              (el.properties['center'] as num?)?.toDouble() ?? 0.5;
          String positionString = 'center';
          if (centerVal == 0.0) {
            positionString = 'min';
          } else if (centerVal == 1.0) {
            positionString = 'max';
          } else {
            positionString = 'center';
          }
          fields.add(InspectorFieldBuilders.buildOptionSelector(
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
          fields.add(InspectorFieldBuilders.buildOptionSelector(
              tokens,
              'Spring',
              el.properties['springBehavior'] ?? 'smooth',
              ['smooth', 'elastic', 'linear'],
              (v) => widget.state
                  .updateElementProperty(el.id, 'springBehavior', v)));
          fields.add(InspectorFieldBuilders.buildNumField(
              tokens,
              'Dur. (ms)',
              (el.properties['springDuration'] as num?)?.toInt() ?? 500,
              (v) => widget.state
                  .updateElementProperty(el.id, 'springDuration', v)));
        }
        break;

      case DesignerElementType.steeringWheel: // forceSwitch
        fields.add(IconFieldBuilder.buildIconSelectorField(
            context,
            'Center Icon',
            el.properties['centerIcon'] as String?,
            (v) => widget.state.updateElementProperty(el.id, 'centerIcon', v)));
        final currentMin = (el.properties['min'] as num?)?.toInt() ?? 0;
        final currentType = currentMin == -100 ? 'bi' : 'uni';
        fields.add(InspectorFieldBuilders.buildOptionSelector(
          tokens,
          'Range',
          currentType,
          ['uni', 'bi'],
          (v) {
            if (v == 'bi') {
              widget.state.updateElementProperty(el.id, 'min', -100);
              widget.state.updateElementProperty(el.id, 'max', 100);
            } else {
              widget.state.updateElementProperty(el.id, 'min', 0);
              widget.state.updateElementProperty(el.id, 'max', 100);
            }
          },
          suffix: Text(
            currentType == 'bi' ? '(-100 - 100)' : '(0 - 100)',
            style: const TextStyle(
              color: Color(0xFF666666),
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
        ));
        fields.add(InspectorFieldBuilders.buildNumField(
            tokens,
            'Min Angle',
            (el.properties['minAngle'] as num?)?.toInt() ?? -135,
            (v) => widget.state.updateElementProperty(el.id, 'minAngle', v),
            min: -360.0,
            max: 360.0));
        fields.add(InspectorFieldBuilders.buildNumField(
            tokens,
            'Max Angle',
            (el.properties['maxAngle'] as num?)?.toInt() ?? 135,
            (v) => widget.state.updateElementProperty(el.id, 'maxAngle', v),
            min: -360.0,
            max: 360.0));
        fields.add(InspectorFieldBuilders.buildBoolToggle(
            tokens,
            'AutoCenter',
            el.properties['autoCenter'] ?? false,
            (v) => widget.state.updateElementProperty(el.id, 'autoCenter', v)));
        final autoCenterSteering = el.properties['autoCenter'] ?? false;
        if (autoCenterSteering) {
          final double centerVal =
              (el.properties['center'] as num?)?.toDouble() ?? 0.5;
          String positionString = 'center';
          if (centerVal == 0.0) {
            positionString = 'min';
          } else if (centerVal == 1.0) {
            positionString = 'max';
          } else {
            positionString = 'center';
          }
          fields.add(InspectorFieldBuilders.buildOptionSelector(
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
          fields.add(InspectorFieldBuilders.buildOptionSelector(
              tokens,
              'Spring',
              el.properties['springBehavior'] ?? 'smooth',
              ['smooth', 'elastic', 'linear'],
              (v) => widget.state
                  .updateElementProperty(el.id, 'springBehavior', v)));
          fields.add(InspectorFieldBuilders.buildNumField(
              tokens,
              'Dur. (ms)',
              (el.properties['springDuration'] as num?)?.toInt() ?? 500,
              (v) => widget.state
                  .updateElementProperty(el.id, 'springDuration', v)));
        }
        break;

      case DesignerElementType.joystick:
        fields.add(InspectorFieldBuilders.buildBoolToggle(
            tokens,
            'AutoCenter',
            el.properties['autoCenter'] ?? true,
            (v) => widget.state.updateElementProperty(el.id, 'autoCenter', v)));
        final autoCenterJoystick = el.properties['autoCenter'] ?? true;
        if (autoCenterJoystick) {
          final double cx =
              (el.properties['centerX'] as num?)?.toDouble() ?? 0.0;
          final double cy =
              (el.properties['centerY'] as num?)?.toDouble() ?? 0.0;
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
          fields.add(InspectorFieldBuilders.buildOptionSelector(
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
          fields.add(InspectorFieldBuilders.buildOptionSelector(
              tokens,
              'Spring',
              el.properties['springBehavior'] ?? 'smooth',
              ['smooth', 'elastic', 'linear'],
              (v) => widget.state
                  .updateElementProperty(el.id, 'springBehavior', v)));
          fields.add(InspectorFieldBuilders.buildNumField(
              tokens,
              'Dur. (ms)',
              (el.properties['springDuration'] as num?)?.toInt() ?? 300,
              (v) => widget.state
                  .updateElementProperty(el.id, 'springDuration', v)));
        }
        break;

      case DesignerElementType.multiButton:
        fields.add(InspectorFieldBuilders.buildBoolToggle(
            tokens,
            'Haptics',
            el.properties['haptic'] ?? true,
            (v) => widget.state.updateElementProperty(el.id, 'haptic', v)));
        fields.add(_buildMultiItemCountField(tokens, el));
        fields.add(_buildMultiOrientationField(tokens, el));
        fields.add(_DesignerMultiItemEditor(
          elementId: el.id,
          items: _getMultiItems(el),
          state: widget.state,
          tokens: tokens,
          showOffState: true,
        ));
        break;

      case DesignerElementType.multiSelect:
        fields.add(InspectorFieldBuilders.buildBoolToggle(
            tokens,
            'Haptics',
            el.properties['haptic'] ?? true,
            (v) => widget.state.updateElementProperty(el.id, 'haptic', v)));
        fields.add(_buildMultiItemCountField(tokens, el));
        fields.add(_buildMultiOrientationField(tokens, el));
        fields.add(_DesignerMultiItemEditor(
          elementId: el.id,
          items: _getMultiItems(el),
          state: widget.state,
          tokens: tokens,
          showOffState: true,
        ));
        break;

      case DesignerElementType.gasPedal:
        final currentMin = (el.properties['min'] as num?)?.toInt() ?? 0;
        final currentType = currentMin == -100 ? 'bi' : 'uni';
        fields.add(InspectorFieldBuilders.buildOptionSelector(
          tokens,
          'Range',
          currentType,
          ['uni', 'bi'],
          (v) {
            if (v == 'bi') {
              widget.state.updateElementProperty(el.id, 'min', -100);
              widget.state.updateElementProperty(el.id, 'max', 100);
            } else {
              widget.state.updateElementProperty(el.id, 'min', 0);
              widget.state.updateElementProperty(el.id, 'max', 100);
            }
          },
          suffix: Text(
            currentType == 'bi' ? '(-100 - 100)' : '(0 - 100)',
            style: const TextStyle(
              color: Color(0xFF666666),
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
        ));
        fields.add(InspectorFieldBuilders.buildBoolToggle(
            tokens,
            'AutoCenter',
            el.properties['autoCenter'] ?? false,
            (v) => widget.state.updateElementProperty(el.id, 'autoCenter', v)));
        final autoCenterPedal = el.properties['autoCenter'] ?? false;
        if (autoCenterPedal) {
          final double centerVal =
              (el.properties['center'] as num?)?.toDouble() ?? 0.5;
          String positionString = 'center';
          if (centerVal == 0.0) {
            positionString = 'min';
          } else if (centerVal == 1.0) {
            positionString = 'max';
          } else {
            positionString = 'center';
          }
          fields.add(InspectorFieldBuilders.buildOptionSelector(
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
          fields.add(InspectorFieldBuilders.buildOptionSelector(
              tokens,
              'Spring',
              el.properties['springBehavior'] ?? 'smooth',
              ['smooth', 'elastic', 'linear'],
              (v) => widget.state
                  .updateElementProperty(el.id, 'springBehavior', v)));
          fields.add(InspectorFieldBuilders.buildNumField(
              tokens,
              'Dur. (ms)',
              (el.properties['springDuration'] as num?)?.toInt() ?? 300,
              (v) => widget.state
                  .updateElementProperty(el.id, 'springDuration', v)));
        }
        break;

      case DesignerElementType.led:
        fields.add(InspectorFieldBuilders.buildCenterPinnedSelector(
            tokens,
            'State',
            el.properties['state'] ?? 'off',
            ['off', 'on', 'blink', 'breathe'],
            (v) => widget.state.updateElementProperty(el.id, 'state', v)));
        fields.add(InspectorFieldBuilders.buildCenterPinnedSelector(
            tokens,
            'Shape',
            el.properties['shape'] ?? 'circle',
            ['circle', 'square', 'diamond', 'star'],
            (v) => widget.state.updateElementProperty(el.id, 'shape', v)));
        fields.add(InspectorFieldBuilders.buildNumField(
            tokens,
            'Timing',
            (el.properties['timing'] as num?)?.toInt() ?? 500,
            (v) => widget.state.updateElementProperty(el.id, 'timing', v)));
        break;

      case DesignerElementType.text:
        fields.add(InspectorFieldBuilders.buildTextField(
            tokens,
            'Text',
            el.properties['text'] ?? 'Display',
            (v) => widget.state.updateElementProperty(el.id, 'text', v)));
        fields.add(InspectorFieldBuilders.buildNumField(
            tokens,
            'Font Size',
            (el.properties['fontSize'] as num?)?.toInt() ?? 14,
            (v) => widget.state.updateElementProperty(el.id, 'fontSize', v)));
        fields.add(InspectorFieldBuilders.buildCenterPinnedSelector(
            tokens,
            'Font',
            el.properties['fontFamily'] ?? 'monospace',
            ['monospace', 'sans-serif', 'serif'],
            (v) => widget.state.updateElementProperty(el.id, 'fontFamily', v)));
        break;

      case DesignerElementType.serialMonitor:
        fields.add(InspectorFieldBuilders.buildNumField(
            tokens,
            'Font Size',
            (el.properties['fontSize'] as num?)?.toInt() ?? 12,
            (v) => widget.state.updateElementProperty(el.id, 'fontSize', v)));
        fields.add(InspectorFieldBuilders.buildCenterPinnedSelector(
            tokens,
            'Font',
            el.properties['fontFamily'] ?? 'monospace',
            ['monospace', 'sans-serif', 'serif'],
            (v) => widget.state.updateElementProperty(el.id, 'fontFamily', v)));
        break;
    }

    return fields;
  }

  /// Returns the current items list for a multi-button or multi-select element,
  /// falling back to auto-generated labels if no items are stored.
  static List<Map<String, dynamic>> _getMultiItems(DesignerElement el) {
    final count = (el.properties['itemCount'] as num?)?.toInt() ?? 3;
    final raw = el.properties['items'] as List?;
    return List.generate(count, (i) {
      if (raw != null && i < raw.length) {
        final entry = raw[i];
        return Map<String, dynamic>.from(entry is Map ? entry : {});
      }
      return <String, dynamic>{
        'onLabel': String.fromCharCode(65 + i),
        'onIcon': null,
      };
    });
  }

  /// Orientation selector for multiButton / multiSelect.
  /// Orientation is inferred from dimensions (w >= h → horizontal).
  /// Switching adjusts the other dimension to maintain proportions:
  ///   → horizontal: keep width, recalculate height = width / (count × 0.67)
  ///   → vertical:   keep height, recalculate width  = height / (count × 0.67)
  Widget _buildMultiOrientationField(RKTokens tokens, DesignerElement el) {
    final current = el.width >= el.height ? 'horizontal' : 'vertical';
    final count = (el.properties['itemCount'] as num?)?.toInt() ?? 3;
    const double ratio = 0.67;
    return InspectorFieldBuilders.buildCenterPinnedSelector(
      tokens,
      'Direction',
      current,
      ['horizontal', 'vertical'],
      (v) {
        if (v == 'vertical') {
          final newW = (el.height / (count * ratio)).round().clamp(5, 999);
          widget.state.updateElementSize(el.id, width: newW, height: el.height);
        } else {
          final newH = (el.width / (count * ratio)).round().clamp(5, 999);
          widget.state.updateElementSize(el.id, width: el.width, height: newH);
        }
      },
    );
  }

  /// Keeps the `items` list in sync with count and resizes to maintain
  /// the correct fixed aspect ratio for the new count.
  Widget _buildMultiItemCountField(RKTokens tokens, DesignerElement el) {
    final count = (el.properties['itemCount'] as num?)?.toInt() ?? 3;
    return InspectorFieldBuilders.buildNumField(
      tokens,
      'Items',
      count,
      (newCount) {
        // Sync items list.
        final current = _getMultiItems(el);
        final List<Map<String, dynamic>> synced;
        if (newCount > current.length) {
          synced = [
            ...current,
            ...List.generate(
              newCount - current.length,
              (i) => <String, dynamic>{
                'onLabel': String.fromCharCode(65 + current.length + i),
                'onIcon': null,
              },
            ),
          ];
        } else {
          synced = current.sublist(0, newCount);
        }
        widget.state.updateElementProperty(el.id, 'itemCount', newCount);
        widget.state.updateElementProperty(el.id, 'items', synced);

        // Resize to maintain correct proportions for the new count.
        const double ratio = 0.67;
        final newAr = (newCount * ratio).clamp(0.5, 10.0);
        final isHorizontal = el.width >= el.height;
        if (isHorizontal) {
          final autoW = (el.height * newAr).round().clamp(5, 999);
          widget.state
              .updateElementSize(el.id, width: autoW, height: el.height);
        } else {
          final autoH = (el.width * newAr).round().clamp(5, 999);
          widget.state.updateElementSize(el.id, width: el.width, height: autoH);
        }
      },
      min: 1,
      max: 8,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-item editor for multiButton / multiSelect
// ─────────────────────────────────────────────────────────────────────────────

class _DesignerMultiItemEditor extends StatefulWidget {
  const _DesignerMultiItemEditor({
    required this.elementId,
    required this.items,
    required this.state,
    required this.tokens,
    this.showOffState = false,
  });

  final String elementId;
  final List<Map<String, dynamic>> items;
  final DesignerState state;
  final RKTokens tokens;

  /// When true an OFF-state row (offLabel + offIcon) is shown below the ON row.
  final bool showOffState;

  @override
  State<_DesignerMultiItemEditor> createState() =>
      _DesignerMultiItemEditorState();
}

class _DesignerMultiItemEditorState extends State<_DesignerMultiItemEditor> {
  int _editingIndex = 0;

  List<Map<String, dynamic>> get _items => widget.items;

  void _updateItem(Map<String, dynamic> updated) {
    final newList = List<Map<String, dynamic>>.from(
      _items.map((m) => Map<String, dynamic>.from(m)),
    );
    newList[_editingIndex] = updated;
    widget.state.updateElementProperty(widget.elementId, 'items', newList);
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    if (_editingIndex >= _items.length) _editingIndex = 0;

    final item = _items[_editingIndex];
    final onLabel = item['onLabel'] as String? ?? '';
    final onIconName = item['onIcon'] as String?;
    final offLabel = item['offLabel'] as String? ?? '';
    final offIconName = item['offIcon'] as String?;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Item index selector ────────────────────────────────────
          Row(
            children: [
              Icon(LucideIcons.pencil, color: widget.tokens.primary, size: 12),
              const SizedBox(width: 6),
              const Text(
                'EDIT ITEM',
                style: TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 10,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_items.length, (i) {
                final active = _editingIndex == i;
                return GestureDetector(
                  onTap: () => setState(() => _editingIndex = i),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: active
                          ? widget.tokens.primary
                          : const Color(0xFF1A1A1A),
                      border: Border.all(
                        color: active
                            ? widget.tokens.primary
                            : const Color(0xFF333333),
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          color: active ? Colors.black : Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 14),

          // ── ON state row ───────────────────────────────────────────
          _buildStateLabel('ON'),
          const SizedBox(height: 6),
          _buildTextIconRow(
            context,
            textValue: onLabel,
            iconName: onIconName,
            onTextChanged: (v) => _updateItem({...item, 'onLabel': v}),
            onIconChanged: (v) => _updateItem({...item, 'onIcon': v}),
          ),

          if (widget.showOffState) ...[
            const SizedBox(height: 12),
            _buildStateLabel('OFF'),
            const SizedBox(height: 6),
            _buildTextIconRow(
              context,
              textValue: offLabel,
              iconName: offIconName,
              onTextChanged: (v) => _updateItem({...item, 'offLabel': v}),
              onIconChanged: (v) => _updateItem({...item, 'offIcon': v}),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStateLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF666666),
        fontSize: 9,
        fontFamily: 'monospace',
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildTextIconRow(
    BuildContext context, {
    required String textValue,
    required String? iconName,
    required ValueChanged<String> onTextChanged,
    required ValueChanged<String?> onIconChanged,
  }) {
    return Row(
      children: [
        // Text field
        Expanded(
          child: Container(
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D0D),
              border: Border.all(color: const Color(0xFF333333)),
              borderRadius: BorderRadius.circular(2),
            ),
            child: TextField(
              controller: TextEditingController(text: textValue)
                ..selection = TextSelection.collapsed(offset: textValue.length),
              style: const TextStyle(
                color: Color(0xFFE0E0E0),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
              decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                border: InputBorder.none,
                isDense: true,
                hintText: 'Text',
                hintStyle: TextStyle(
                  color: Color(0xFF555555),
                  fontSize: 11,
                ),
              ),
              onChanged: onTextChanged,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Icon picker
        GestureDetector(
          onTap: () => IconFieldBuilder.openIconPickerDialog(
            context,
            currentIconName: iconName,
            onChanged: onIconChanged,
          ),
          child: Container(
            height: 28,
            width: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              border: Border.all(color: const Color(0xFF333333)),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (iconName != null && kDesignerIcons.containsKey(iconName))
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      kDesignerIcons[iconName]!,
                      color: const Color(0xFFFF8C00),
                      size: 14,
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Text(
                      '—',
                      style: TextStyle(
                        color: Color(0xFF555555),
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                const Icon(
                  LucideIcons.chevronDown,
                  color: Color(0xFF666666),
                  size: 10,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Replaces any character that isn't a valid C++ identifier character
/// (letters, digits, underscore) with an underscore.
class CppIdentifierFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final sanitized = newValue.text.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    if (sanitized == newValue.text) return newValue;

    final cursorPos = newValue.selection.baseOffset;
    final adjustedPos = cursorPos.clamp(0, sanitized.length);

    return TextEditingValue(
      text: sanitized,
      selection: TextSelection.collapsed(offset: adjustedPos),
    );
  }
}
