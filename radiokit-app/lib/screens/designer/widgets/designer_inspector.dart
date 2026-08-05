import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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

// ─── autoCenter helpers ───────────────────────────────────────────────────────
// stored as a 3-element List:
//   [position, springType, springDuration]
// where position is null (disabled) or "min" | "center" | "max" (enabled).

/// Returns true when auto-center is enabled (position is not null).
bool _acEnabled(List<dynamic>? ac) =>
    (ac?[0] as String?) != null;

/// Converts the position label to its numeric value for widget constructors.
double _acPosition(List<dynamic>? ac) {
  final pos = ac?[0] as String?;
  switch (pos) {
    case 'min':
      return 0.0;
    case 'max':
      return 1.0;
    case 'center':
    default:
      return 0.5;
  }
}

/// Converts a numeric value back to a position label for the inspector UI.
String _acPositionLabel(double value) {
  if (value <= 0.0) return 'min';
  if (value >= 1.0) return 'max';
  return 'center';
}

/// Returns the spring type string from position [1].
String _acType(List<dynamic>? ac) =>
    (ac?[1] as String?) ?? 'smooth';

/// Returns the spring duration (ms) from position [2].
int _acDuration(List<dynamic>? ac, int fallback) =>
    (ac?[2] as num?)?.toInt() ?? fallback;

/// Writes a single value back into the autoCenter list and commits via state.
void _updateACArrayProp(
  DesignerState state,
  String elementId,
  List<dynamic>? ac,
  int index,
  dynamic value,
) {
  final newAC = List<dynamic>.from(ac ?? [null, 'smooth', 300]);
  newAC[index] = value;
  state.updateElementProperty(elementId, 'autoCenter', newAC);
}

class DesignerInspector extends StatefulWidget {
  final DesignerState state;
  const DesignerInspector({super.key, required this.state});

  @override
  State<DesignerInspector> createState() => _DesignerInspectorState();
}

class _DesignerInspectorState extends State<DesignerInspector> {
  int? _draggingIndex;
  int? _dragOverIndex;

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);
    final el = widget.state.selectedElement;

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: tokens.base300,
        border: Border(
          left: BorderSide(color: tokens.effectiveOutline, width: 1),
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
                      _buildHiddenToggle(tokens, el),
                    ]),
                    InspectorFieldBuilders.buildSection(
                        tokens, 'BEHAVIOR', _buildBehaviorFields(tokens, el)),
                    InspectorFieldBuilders.buildSection(tokens, 'TRANSFORM', [
                      _buildSizeRow(tokens, el),
                      _buildPositionRow(tokens, el),
                      SizedBox(height: 8),
                      InspectorFieldBuilders.buildRotationSlider(
                          tokens, el.rotation.toDouble(), (v) {
                        widget.state.updateElementRotation(el.id, v.round());
                      },
                          onReset: () =>
                              widget.state.updateElementRotation(el.id, 0)),
                      SizedBox(height: 12),
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
          SizedBox(width: 10),
          Expanded(
            child: Text(
              _headerTitle(),
              style: TextStyle(
                color: tokens.onSurface.withValues(alpha: 0.88),
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
                Icon(LucideIcons.chevronRight, color: tokens.onSurface.withValues(alpha: 0.88)),
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
                    isValid ? tokens.onSurface.withValues(alpha: 0.5) : tokens.error,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 28,
              decoration: BoxDecoration(
                color: tokens.base200,
                border: Border.all(
                  color: isValid
                      ? tokens.effectiveOutline
                      : tokens.error,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
              child: TextField(
                controller: TextEditingController(text: el.label)
                  ..selection =
                      TextSelection.collapsed(offset: el.label.length),
                style: TextStyle(
                  color: tokens.onSurface.withValues(alpha: 0.88),
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  border: InputBorder.none,
                  isDense: true,
                  suffixIcon: !isValid
                      ? Tooltip(
                          message:
                              'Must be a valid C++ identifier\n(starts with letter or _, contains\nonly letters, digits, or _)',
                          child: Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              LucideIcons.alertCircle,
                              size: 14,
                              color: tokens.error,
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
          SizedBox(width: 6),
          GestureDetector(
            onTap: () => widget.state.toggleElementLabelHidden(el.id),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: el.labelHidden
                    ? tokens.base200
                    : tokens.base200,
                border: Border.all(
                  color:
                      el.labelHidden ? tokens.onSurface.withValues(alpha: 0.38) : tokens.primary,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Icon(
                el.labelHidden ? LucideIcons.eyeOff : LucideIcons.eye,
                size: 14,
                color:
                    el.labelHidden ? tokens.onSurface.withValues(alpha: 0.38) : tokens.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHiddenToggle(RKTokens tokens, DesignerElement el) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              'Hidden',
              style: TextStyle(
                color: tokens.onSurface.withValues(alpha: 0.5),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => widget.state.toggleElementHidden(el.id),
              child: Container(
                height: 28,
                decoration: BoxDecoration(
                  color: el.hidden
                      ? tokens.primary.withValues(alpha: 0.15)
                      : tokens.base200,
                  border: Border.all(
                    color: el.hidden ? tokens.primary : tokens.effectiveOutline,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      el.hidden ? LucideIcons.eyeOff : LucideIcons.eye,
                      size: 14,
                      color: el.hidden
                          ? tokens.primary
                          : tokens.onSurface.withValues(alpha: 0.38),
                    ),
                    SizedBox(width: 6),
                    Text(
                      el.hidden ? 'HIDDEN' : 'VISIBLE',
                      style: TextStyle(
                        color: el.hidden
                            ? tokens.primary
                            : tokens.onSurface.withValues(alpha: 0.5),
                        fontSize: 10,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
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
        // ── PAGE SETTINGS (multi-page only) ─────────────────────────
        if (widget.state.numPages > 1) _buildPageSettingsSection(tokens),
        // ── MODEL ────────────────────────────────────────────────────
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
          if (widget.state.connectionPassword.isNotEmpty)
            InspectorFieldBuilders.buildTextField(
                tokens,
                'Password',
                widget.state.connectionPassword,
                (v) => widget.state.setConnectionPassword(v)),
        ]),
        // ── TRANSPORTS ──────────────────────────────────────────────
        _buildTransportsSection(tokens),
        // ── FEATURES ────────────────────────────────────────────────
        InspectorFieldBuilders.buildSection(tokens, 'FEATURES', [
          InspectorFieldBuilders.buildBoolToggle(
              tokens, 'Enable OTA', widget.state.featureOta, (v) {
              widget.state.setFeatureOta(v);
            }),
          Padding(
            padding: const EdgeInsets.only(left: 20, bottom: 8),
            child: Text(
              'Include OTA firmware update support',
              style: TextStyle(
                color: tokens.onSurface.withValues(alpha: 0.5),
                fontSize: 10,
              ),
            ),
          ),
          InspectorFieldBuilders.buildBoolToggle(
            tokens,
            'Enable Filesystem',
            widget.state.featureFilesystem,
            (v) => widget.state.setFeatureFilesystem(v),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 20, bottom: 8),
            child: Text(
              'Include LittleFS support for file management',
              style: TextStyle(
                color: tokens.onSurface.withValues(alpha: 0.5),
                fontSize: 10,
              ),
            ),
          ),
        ]),
        // ── CONTROL UI ──────────────────────────────────────────────
        _buildControlUISection(tokens),
        // ── TELEMETRY ────────────────────────────────────────────────
        _buildTelemetrySection(tokens),
      ],
    );
  }

  Widget _buildPositionRow(RKTokens tokens, DesignerElement el) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Position',
            style: TextStyle(
              color: tokens.onSurface.withValues(alpha: 0.5),
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
          SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: InspectorFieldBuilders.buildCompactNumField(
                    tokens, 'X', el.x, (v) {
                  widget.state.updateElementPosition(el.id, v, el.y);
                }),
              ),
              SizedBox(width: 8),
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
              Text(
                'Size',
                style: TextStyle(
                  color: tokens.onSurface.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
              Spacer(),
              GestureDetector(
                onTap: () {
                  final (dw, dh) = DesignerElement.defaultSize(el.type);
                  widget.state.updateElementSize(el.id, width: dw, height: dh);
                },
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(LucideIcons.rotateCcw,
                      size: 12, color: tokens.onSurface.withValues(alpha: 0.38)),
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
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
                SizedBox(width: 8),
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
          color: selected ? tokens.primary : tokens.base200,
          border: Border.all(
            color: selected ? tokens.primary : tokens.effectiveOutline,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? tokens.onPrimary : tokens.onSurface.withValues(alpha: 0.5),
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
            backgroundColor: tokens.error.withValues(alpha: 0.15),
            side: BorderSide(color: tokens.error.withValues(alpha: 0.4)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
          child: Text(
            'DELETE WIDGET',
            style: TextStyle(
              color: tokens.error,
              fontSize: 11,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // ── TRANSPORTS section ──────────────────────────────────────────────────

  Widget _buildTransportsSection(RKTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Text(
            'TRANSPORTS',
            style: TextStyle(
              color: tokens.primary,
              fontSize: 12,
              fontFamily: 'monospace',
              letterSpacing: 1,
            ),
          ),
        ),
        // BLE toggle
        InspectorFieldBuilders.buildBoolToggle(
          tokens, 'BLE', widget.state.bleEnabled,
          (v) => widget.state.setBleEnabled(v),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 20, bottom: 8),
          child: Text(
            'Bluetooth Low Energy',
            style: TextStyle(
              color: tokens.onSurface.withValues(alpha: 0.5),
              fontSize: 10,
            ),
          ),
        ),
        // WiFi toggle
        InspectorFieldBuilders.buildBoolToggle(
          tokens, 'WiFi', widget.state.wifiEnabled,
          (v) => widget.state.setWifiEnabled(v),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 20, bottom: 8),
          child: Text(
            'Wireless network',
            style: TextStyle(
              color: tokens.onSurface.withValues(alpha: 0.5),
              fontSize: 10,
            ),
          ),
        ),
        // WiFi STA settings (shown when WiFi enabled)
        if (widget.state.wifiEnabled) ...[
          InspectorFieldBuilders.buildTextField(
            tokens, 'STA SSID', widget.state.wifiSsid,
            (v) => widget.state.setWifiSsid(v),
          ),
          InspectorFieldBuilders.buildTextField(
            tokens, 'STA PASS', widget.state.wifiPass,
            (v) => widget.state.setWifiPass(v),
          ),
        ],
        // Cloud toggle (shown only when WiFi enabled)
        if (widget.state.wifiEnabled) ...[
          InspectorFieldBuilders.buildBoolToggle(
            tokens, 'Cloud', widget.state.cloudEnabled,
            (v) => widget.state.setCloudEnabled(v),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 20, bottom: 8),
            child: Text(
              'Remote access over internet',
              style: TextStyle(
                color: tokens.onSurface.withValues(alpha: 0.5),
                fontSize: 10,
              ),
            ),
          ),
        ],
        // Cloud settings (shown when Cloud enabled)
        if (widget.state.cloudEnabled) ...[
          InspectorFieldBuilders.buildTextField(
            tokens, 'Account', widget.state.cloudAccount,
            (v) => widget.state.setCloudAccount(v),
          ),
          InspectorFieldBuilders.buildTextField(
            tokens, 'Relay URL', widget.state.cloudRelay,
            (v) => widget.state.setCloudRelay(v),
          ),
        ],
        Container(height: 1, color: tokens.effectiveOutline),
      ],
    );
  }

  // ── PAGE SETTINGS section (multi-page only) ──────────────────────────────

  Widget _buildPageSettingsSection(RKTokens tokens) {
    final page = widget.state.activePage;
    final override = page.orientationOverride ?? 'global';

    return InspectorFieldBuilders.buildSection(tokens, 'PAGE SETTINGS', [
      InspectorFieldBuilders.buildTextField(
        tokens,
        'Page Name',
        page.name,
        (v) => widget.state.renamePage(widget.state.activePageIndex, v),
      ),
      InspectorFieldBuilders.buildCenterPinnedSelector(
        tokens,
        'Orientation',
        override,
        ['global', 'landscape', 'portrait'],
        (v) => widget.state.setPageOrientationOverride(v),
      ),
    ]);
  }

  // ── CONTROL UI section (replaces CANVAS) ──────────────────────────────────

  Widget _buildControlUISection(RKTokens tokens) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section header with toggle ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Text(
                  'CONTROL UI',
                  style: TextStyle(
                    color: tokens.primary,
                    fontSize: 12,
                    fontFamily: 'monospace',
                    letterSpacing: 1,
                  ),
                ),
                Spacer(),
                GestureDetector(
                  onTap: () =>
                      widget.state.setEnableControlUI(!widget.state.enableControlUI),
                  child: Container(
                    width: 28,
                    height: 16,
                    decoration: BoxDecoration(
                      color: widget.state.enableControlUI
                          ? tokens.primary
                          : tokens.effectiveOutline,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 200),
                      alignment: widget.state.enableControlUI
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: tokens.onSurface.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.all(Radius.circular(6)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Control UI content (only visible when enabled) ────────────
          if (widget.state.enableControlUI) ...[
            // Orientation
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      'Orientation',
                      style: TextStyle(
                        color: tokens.onSurface.withValues(alpha: 0.5),
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildMiniToggle(
                            tokens,
                            label: 'LANDSCAPE',
                            selected: widget.state.globalIsLandscape,
                            onTap: () {
                              if (!widget.state.globalIsLandscape)
                                widget.state.setGlobalOrientation(true);
                            },
                          ),
                        ),
                        SizedBox(width: 4),
                        Expanded(
                          child: _buildMiniToggle(
                            tokens,
                            label: 'PORTRAIT',
                            selected: !widget.state.globalIsLandscape,
                            onTap: () {
                              if (widget.state.globalIsLandscape)
                                widget.state.setGlobalOrientation(false);
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
              widget.state.globalIsLandscape ? '200 x 100' : '100 x 200',
            ),
            // Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      'Grid',
                      style: TextStyle(
                        color: tokens.onSurface.withValues(alpha: 0.5),
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
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
                        SizedBox(width: 4),
                        Expanded(
                          child: _buildMiniToggle(
                            tokens,
                            label: 'DOTS',
                            selected: widget.state.gridStyle == GridStyle.dots,
                            onTap: () =>
                                widget.state.setGridStyle(GridStyle.dots),
                          ),
                        ),
                        SizedBox(width: 4),
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
            // Skin
            InspectorFieldBuilders.buildCenterPinnedSelector(
              tokens,
              'Skin',
              widget.state.activeSkin,
              ['default', ...RKTokens.presetsByName.keys.toList()],
              (v) {
                widget.state.setSkin(v);
              },
            ),
            // Show Page Bar in Control UI
            InspectorFieldBuilders.buildBoolToggle(
              tokens,
              'Show Page Bar in Control UI',
              widget.state.showControlPageBar,
              (v) => widget.state.toggleControlPageBar(),
            ),
          ],
          Container(height: 1, color: tokens.effectiveOutline),
        ],
    );
  }

  // ── TELEMETRY section ──────────────────────────────────────────────────────

  Widget _buildTelemetrySection(RKTokens tokens) {
    final telemetry = widget.state.telemetryWidgets;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            children: [
              Text(
                'TELEMETRY',
                style: TextStyle(
                  color: tokens.primary,
                  fontSize: 12,
                  fontFamily: 'monospace',
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              if (telemetry.length < 4)
                GestureDetector(
                  onTap: () => widget.state.addTelemetrySlot(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: tokens.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.plus, size: 12, color: tokens.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Add',
                          style: TextStyle(
                            color: tokens.primary,
                            fontSize: 10,
                            fontFamily: 'monospace',
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Preview row
        if (telemetry.any((tw) => ((tw['label'] as String?) ?? '').isNotEmpty))
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final tw in telemetry)
                  if (((tw['label'] as String?) ?? '').isNotEmpty)
                    Flexible(
                      child: _TelemetryPreviewItem(
                        label: tw['label'] ?? '',
                        iconName: tw['icon'] as String?,
                        unit: tw['unit'] ?? '',
                      ),
                    ),
              ],
            ),
          ),
        ...List.generate(telemetry.length, (i) {
          final tw = telemetry[i];
          final label = (tw['label'] as String?) ?? '';
          final iconName = tw['icon'] as String?;
          final unit = (tw['unit'] as String?) ?? '';
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drop indicator above this row
              if (_dragOverIndex == i && _draggingIndex != null && _draggingIndex != i)
                Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  color: tokens.primary,
                ),
              DragTarget<int>(
                onWillAccept: (data) => data != i,
                onMove: (details) {
                  setState(() {
                    _dragOverIndex = i;
                  });
                },
                onLeave: (_) {
                  setState(() {
                    _dragOverIndex = null;
                  });
                },
                onAccept: (data) {
                  final target = _dragOverIndex ?? i;
                  setState(() {
                    widget.state.reorderTelemetrySlot(data, target);
                    _draggingIndex = null;
                    _dragOverIndex = null;
                  });
                },
                builder: (context, candidateData, rejectedData) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Row(
                    children: [
                      // Grip handle
                      if (telemetry.length > 1)
                        LongPressDraggable<int>(
                          data: i,
                          feedback: Material(
                            color: Colors.transparent,
                            child: Opacity(
                              opacity: 0.8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(LucideIcons.gripVertical, color: tokens.primary, size: 14),
                                    const SizedBox(width: 6),
                                    Text(label.isNotEmpty ? label : 'Slot ${i + 1}',
                                      style: TextStyle(color: tokens.onSurface, fontSize: 11, fontFamily: 'monospace')),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          onDragStarted: () {
                            setState(() {
                              _draggingIndex = i;
                            });
                          },
                          onDragEnd: (_) {
                            setState(() {
                              _draggingIndex = null;
                              _dragOverIndex = null;
                            });
                          },
                          child: Icon(
                            LucideIcons.gripVertical,
                            color: _draggingIndex == i
                                ? tokens.primary
                                : tokens.onSurface.withValues(alpha: 0.38),
                            size: 14,
                          ),
                        ),
                      if (telemetry.length > 1) const SizedBox(width: 6),
                      // Icon picker
                      GestureDetector(
                        onTap: () => IconFieldBuilder.openIconPickerDialog(
                    context,
                    currentIconName: iconName,
                    onChanged: (v) => widget.state.setTelemetryIcon(i, v),
                  ),
                  child: Container(
                    height: 28,
                    width: 40,
                    decoration: BoxDecoration(
                      color: tokens.base200,
                      border: Border.all(color: tokens.effectiveOutline),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (iconName != null &&
                            kDesignerIcons.containsKey(iconName))
                          Padding(
                            padding: const EdgeInsets.only(right: 2),
                            child: Icon(
                              kDesignerIcons[iconName]!,
                              color: tokens.primary,
                              size: 14,
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(right: 2),
                            child: Text(
                              '—',
                              style: TextStyle(
                                color: tokens.onSurface.withValues(alpha: 0.38),
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        Icon(
                          LucideIcons.chevronDown,
                          color: tokens.onSurface.withValues(alpha: 0.38),
                          size: 10,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Label (C++ variable name)
                Expanded(
                  flex: 3,
                  child: Container(
                    height: 28,
                    decoration: BoxDecoration(
                      color: tokens.base200,
                      border: Border.all(color: tokens.effectiveOutline),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: TextField(
                      controller: TextEditingController(text: label)
                        ..selection = TextSelection.collapsed(
                            offset: label.length),
                      style: TextStyle(
                        color: tokens.onSurface.withValues(alpha: 0.88),
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        border: InputBorder.none,
                        isDense: true,
                        hintText: 'Label',
                        hintStyle: TextStyle(
                          color: tokens.onSurface.withValues(alpha: 0.38),
                          fontSize: 11,
                        ),
                      ),
                      onChanged: (v) =>
                          widget.state.setTelemetryLabel(i, v),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Unit
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 28,
                    decoration: BoxDecoration(
                      color: tokens.base200,
                      border: Border.all(color: tokens.effectiveOutline),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: TextField(
                      controller: TextEditingController(text: unit)
                        ..selection = TextSelection.collapsed(
                            offset: unit.length),
                      style: TextStyle(
                        color: tokens.onSurface.withValues(alpha: 0.88),
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        border: InputBorder.none,
                        isDense: true,
                        hintText: 'Unit',
                        hintStyle: TextStyle(
                          color: tokens.onSurface.withValues(alpha: 0.38),
                          fontSize: 11,
                        ),
                      ),
                      onChanged: (v) =>
                          widget.state.setTelemetryUnit(i, v),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Remove button
                GestureDetector(
                  onTap: () => widget.state.removeTelemetrySlot(i),
                  child: Container(
                    height: 28,
                    width: 28,
                    decoration: BoxDecoration(
                      color: tokens.base200,
                      border: Border.all(color: tokens.effectiveOutline),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Icon(
                      LucideIcons.x,
                      color: tokens.onSurface.withValues(alpha: 0.5),
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
        }),
        Container(height: 1, color: tokens.effectiveOutline),
      ],
    );
  }

  // ── Behavior fields helpers ──────────────────────────────────────────────

  List<Widget> _buildBehaviorFields(RKTokens tokens, DesignerElement el) {
    final fields = <Widget>[];

    final definition = WidgetRegistry.instance.getByType(el.type);
    if (definition != null && definition.propertiesSchema.isNotEmpty) {
      for (final schema in definition.propertiesSchema) {
        final val = el.properties[schema.key];
        if (schema is NumPropertySchema) {
          fields.add(InspectorFieldBuilders.buildNumField(
            tokens,
            schema.label,
            (val as num?)?.toInt() ?? 0,
            (v) => widget.state.updateElementProperty(el.id, schema.key, v),
            min: schema.min,
            max: schema.max,
          ));
        } else if (schema is BoolPropertySchema) {
          fields.add(InspectorFieldBuilders.buildBoolToggle(
            tokens,
            schema.label,
            (val as bool?) ?? true,
            (v) => widget.state.updateElementProperty(el.id, schema.key, v),
          ));
        } else if (schema is OptionPropertySchema) {
          fields.add(InspectorFieldBuilders.buildCenterPinnedSelector(
            tokens,
            schema.label,
            (val as String?) ?? schema.options.first,
            schema.options,
            (v) => widget.state.updateElementProperty(el.id, schema.key, v),
          ));
        } else if (schema is IconPropertySchema) {
          fields.add(IconFieldBuilder.buildIconSelectorField(
            context,
            schema.label,
            val as String?,
            (v) => widget.state.updateElementProperty(el.id, schema.key, v),
          ));
        } else if (schema is TextPropertySchema) {
          fields.add(InspectorFieldBuilders.buildTextField(
            tokens,
            schema.label,
            (val as String?) ?? '',
            (v) => widget.state.updateElementProperty(el.id, schema.key, v),
          ));
        }
      }
      return fields;
    }

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
      case DesignerElementType.rockerSwitch:
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
            style: TextStyle(
              color: tokens.onSurface.withValues(alpha: 0.38),
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
        ));
        fields.add(InspectorFieldBuilders.buildBoolToggle(
            tokens,
            'AutoCenter',
            _acEnabled(el.properties['autoCenter'] as List?),
            (v) {
              final pos = v ? 'center' : null;
              _updateACArrayProp(widget.state, el.id,
                  el.properties['autoCenter'] as List?, 0, pos);
            }));
        final autoCenterSlider = _acEnabled(el.properties['autoCenter'] as List?);
        if (autoCenterSlider) {
          final double centerVal = _acPosition(el.properties['autoCenter'] as List?);
          String positionString = _acPositionLabel(centerVal);
          fields.add(InspectorFieldBuilders.buildOptionSelector(
            tokens,
            'Position',
            positionString,
            ['min', 'center', 'max'],
            (v) {
              _updateACArrayProp(widget.state, el.id,
                  el.properties['autoCenter'] as List?, 0, v);
            },
          ));
          fields.add(InspectorFieldBuilders.buildOptionSelector(
              tokens,
              'Spring',
              _acType(el.properties['autoCenter'] as List?),
              ['smooth', 'elastic', 'linear'],
              (v) => _updateACArrayProp(
                  widget.state,
                  el.id,
                  el.properties['autoCenter'] as List?,
                  1,
                  v)));
          fields.add(InspectorFieldBuilders.buildNumField(
              tokens,
              'Dur. (ms)',
              _acDuration(el.properties['autoCenter'] as List?, 300),
              (v) => _updateACArrayProp(
                  widget.state,
                  el.id,
                  el.properties['autoCenter'] as List?,
                  2,
                  v)));
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
            style: TextStyle(
              color: tokens.onSurface.withValues(alpha: 0.38),
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
            _acEnabled(el.properties['autoCenter'] as List?),
            (v) {
              final pos = v ? 'center' : null;
              _updateACArrayProp(widget.state, el.id,
                  el.properties['autoCenter'] as List?, 0, pos);
            }));
        final autoCenterKnob = _acEnabled(el.properties['autoCenter'] as List?);
        if (autoCenterKnob) {
          final double centerVal =
              _acPosition(el.properties['autoCenter'] as List?);
          String positionString = _acPositionLabel(centerVal);
          fields.add(InspectorFieldBuilders.buildOptionSelector(
            tokens,
            'Position',
            positionString,
            ['min', 'center', 'max'],
            (v) {
              _updateACArrayProp(widget.state, el.id,
                  el.properties['autoCenter'] as List?, 0, v);
            },
          ));
          fields.add(InspectorFieldBuilders.buildOptionSelector(
              tokens,
              'Spring',
              _acType(el.properties['autoCenter'] as List?),
              ['smooth', 'elastic', 'linear'],
              (v) => _updateACArrayProp(
                  widget.state,
                  el.id,
                  el.properties['autoCenter'] as List?,
                  1,
                  v)));
          fields.add(InspectorFieldBuilders.buildNumField(
              tokens,
              'Dur. (ms)',
              _acDuration(el.properties['autoCenter'] as List?, 500),
              (v) => _updateACArrayProp(
                  widget.state,
                  el.id,
                  el.properties['autoCenter'] as List?,
                  2,
                  v)));
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
            style: TextStyle(
              color: tokens.onSurface.withValues(alpha: 0.38),
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
            _acEnabled(el.properties['autoCenter'] as List?),
            (v) {
              final pos = v ? 'center' : null;
              _updateACArrayProp(widget.state, el.id,
                  el.properties['autoCenter'] as List?, 0, pos);
            }));
        final autoCenterSteering = _acEnabled(el.properties['autoCenter'] as List?);
        if (autoCenterSteering) {
          final double centerVal =
              _acPosition(el.properties['autoCenter'] as List?);
          String positionString = _acPositionLabel(centerVal);
          fields.add(InspectorFieldBuilders.buildOptionSelector(
            tokens,
            'Position',
            positionString,
            ['min', 'center', 'max'],
            (v) {
              _updateACArrayProp(widget.state, el.id,
                  el.properties['autoCenter'] as List?, 0, v);
            },
          ));
          fields.add(InspectorFieldBuilders.buildOptionSelector(
              tokens,
              'Spring',
              _acType(el.properties['autoCenter'] as List?),
              ['smooth', 'elastic', 'linear'],
              (v) => _updateACArrayProp(
                  widget.state,
                  el.id,
                  el.properties['autoCenter'] as List?,
                  1,
                  v)));
          fields.add(InspectorFieldBuilders.buildNumField(
              tokens,
              'Dur. (ms)',
              _acDuration(el.properties['autoCenter'] as List?, 500),
              (v) => _updateACArrayProp(
                  widget.state,
                  el.id,
                  el.properties['autoCenter'] as List?,
                  2,
                  v)));
        }
        break;

      case DesignerElementType.joystick:
        fields.add(InspectorFieldBuilders.buildBoolToggle(
            tokens,
            'AutoCenter',
            _acEnabled(el.properties['autoCenter'] as List?),
            (v) {
              final pos = v ? 'center' : null;
              _updateACArrayProp(widget.state, el.id,
                  el.properties['autoCenter'] as List?, 0, pos);
            }));
        final autoCenterJoystick = _acEnabled(el.properties['autoCenter'] as List?);
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
              _acType(el.properties['autoCenter'] as List?),
              ['smooth', 'elastic', 'linear'],
              (v) => _updateACArrayProp(
                  widget.state,
                  el.id,
                  el.properties['autoCenter'] as List?,
                  1,
                  v)));
          fields.add(InspectorFieldBuilders.buildNumField(
              tokens,
              'Dur. (ms)',
              _acDuration(el.properties['autoCenter'] as List?, 300),
              (v) => _updateACArrayProp(
                  widget.state,
                  el.id,
                  el.properties['autoCenter'] as List?,
                  2,
                  v)));
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
            style: TextStyle(
              color: tokens.onSurface.withValues(alpha: 0.38),
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
        ));
        fields.add(InspectorFieldBuilders.buildBoolToggle(
            tokens,
            'AutoCenter',
            _acEnabled(el.properties['autoCenter'] as List?),
            (v) {
              final pos = v ? 'center' : null;
              _updateACArrayProp(widget.state, el.id,
                  el.properties['autoCenter'] as List?, 0, pos);
            }));
        final autoCenterPedal = _acEnabled(el.properties['autoCenter'] as List?);
        if (autoCenterPedal) {
          final double centerVal =
              _acPosition(el.properties['autoCenter'] as List?);
          String positionString = _acPositionLabel(centerVal);
          fields.add(InspectorFieldBuilders.buildOptionSelector(
            tokens,
            'Position',
            positionString,
            ['min', 'center', 'max'],
            (v) {
              _updateACArrayProp(widget.state, el.id,
                  el.properties['autoCenter'] as List?, 0, v);
            },
          ));
          fields.add(InspectorFieldBuilders.buildOptionSelector(
              tokens,
              'Spring',
              _acType(el.properties['autoCenter'] as List?),
              ['smooth', 'elastic', 'linear'],
              (v) => _updateACArrayProp(
                  widget.state,
                  el.id,
                  el.properties['autoCenter'] as List?,
                  1,
                  v)));
          fields.add(InspectorFieldBuilders.buildNumField(
              tokens,
              'Dur. (ms)',
              _acDuration(el.properties['autoCenter'] as List?, 300),
              (v) => _updateACArrayProp(
                  widget.state,
                  el.id,
                  el.properties['autoCenter'] as List?,
                  2,
                  v)));
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
        final item = Map<String, dynamic>.from(entry is Map ? entry : {});
        // Apply power-icon fallback for empty items so the editor UI matches
        // what will be serialised at save time (see DesignerElement.toJson()).
        if ((item['onLabel'] is! String || (item['onLabel'] as String).isEmpty) &&
            (item['onIcon'] is! String || (item['onIcon'] as String).isEmpty)) {
          item['onIcon'] = 'power';
        }
        return item;
      }
      return <String, dynamic>{
        'onLabel': String.fromCharCode(65 + i),
        'onIcon': null,
        'offLabel': null,
        'offIcon': null,
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
    return InspectorFieldBuilders.buildButtonGroup(
      tokens,
      'Direction',
      current,
      ['horizontal', 'vertical'],
      (v) {
        if (v == 'vertical') {
          // Switch to vertical: Keep height, assign it to height, and width to height / (count * ratio)
          // Wait, requirement: "When switching from horizontal to vertical, preserve the height as width and vice versa"
          // So new height = old width, new width = old height
          widget.state
              .updateElementSize(el.id, width: el.height, height: el.width);
        } else {
          // Switch to horizontal:
          // new width = old height, new height = old width
          widget.state
              .updateElementSize(el.id, width: el.height, height: el.width);
        }
      },
      labels: ['H', 'V'],
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
                'offLabel': null,
                'offIcon': null,
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
  List<Map<String, dynamic>> get _items => widget.items;

  void _updateItemIndex(int index, Map<String, dynamic> updated) {
    final newList = List<Map<String, dynamic>>.from(
      _items.map((m) => Map<String, dynamic>.from(m)),
    );
    newList[index] = updated;
    widget.state.updateElementProperty(widget.elementId, 'items', newList);
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.list, color: widget.tokens.primary, size: 12),
              SizedBox(width: 6),
              Text(
                'ITEMS',
                style: TextStyle(
                  color: widget.tokens.onSurface.withValues(alpha: 0.5),
                  fontSize: 10,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          ...List.generate(_items.length, (i) {
            final item = _items[i];
            final onLabel = item['onLabel'] as String?;
            final onIconName = item['onIcon'] as String?;
            final offLabel = item['offLabel'] as String?;
            final offIconName = item['offIcon'] as String?;

            final showOn = onLabel != null || onIconName != null;
            final showOff = widget.showOffState;

            if (!showOn && !showOff) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ITEM ${i + 1}',
                    style: TextStyle(
                      color: widget.tokens.onSurface.withValues(alpha: 0.88),
                      fontSize: 10,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (showOn) ...[
                    SizedBox(height: 6),
                    _buildCompactStateRow(
                      context,
                      label: 'ON',
                      textValue: onLabel ?? '',
                      iconName: onIconName,
                      onTextChanged: (v) => _updateItemIndex(
                          i, {...item, 'onLabel': v.isEmpty ? null : v}),
                      onIconChanged: (v) => _updateItemIndex(i, {
                        ...item,
                        'onIcon': (v == null || v.isEmpty) ? null : v
                      }),
                    ),
                  ],
                  if (showOff) ...[
                    SizedBox(height: 6),
                    _buildCompactStateRow(
                      context,
                      label: 'OFF',
                      textValue: offLabel ?? '',
                      iconName: offIconName,
                      onTextChanged: (v) => _updateItemIndex(
                          i, {...item, 'offLabel': v.isEmpty ? null : v}),
                      onIconChanged: (v) => _updateItemIndex(i, {
                        ...item,
                        'offIcon': (v == null || v.isEmpty) ? null : v
                      }),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCompactStateRow(
    BuildContext context, {
    required String label,
    required String textValue,
    required String? iconName,
    required ValueChanged<String> onTextChanged,
    required ValueChanged<String?> onIconChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          child: Text(
            label,
            style: TextStyle(
              color: widget.tokens.onSurface.withValues(alpha: 0.38),
              fontSize: 9,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
        // Text field
        Expanded(
          child: Container(
            height: 28,
            decoration: BoxDecoration(
              color: widget.tokens.base200,
              border: Border.all(color: widget.tokens.effectiveOutline),
              borderRadius: BorderRadius.circular(2),
            ),
            child: TextField(
              controller: TextEditingController(text: textValue)
                ..selection = TextSelection.collapsed(offset: textValue.length),
              style: TextStyle(
                color: widget.tokens.onSurface.withValues(alpha: 0.88),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
              decoration: InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                border: InputBorder.none,
                isDense: true,
                hintText: 'Text',
                hintStyle: TextStyle(
                  color: widget.tokens.onSurface.withValues(alpha: 0.38),
                  fontSize: 11,
                ),
              ),
              onChanged: onTextChanged,
            ),
          ),
        ),
        SizedBox(width: 8),
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
              color: widget.tokens.base200,
              border: Border.all(color: widget.tokens.effectiveOutline),
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
                      color: widget.tokens.primary,
                      size: 14,
                    ),
                  )
                else
                  Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Text(
                      '—',
                      style: TextStyle(
                        color: widget.tokens.onSurface.withValues(alpha: 0.38),
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                Icon(
                  LucideIcons.chevronDown,
                  color: widget.tokens.onSurface.withValues(alpha: 0.38),
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

class _TelemetryPreviewItem extends StatelessWidget {
  final String label;
  final String? iconName;
  final String unit;
  const _TelemetryPreviewItem({required this.label, this.iconName, required this.unit});

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            color: tokens.onSurface.withValues(alpha: 0.38),
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (iconName != null && kDesignerIcons.containsKey(iconName))
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  kDesignerIcons[iconName]!,
                  color: tokens.primary,
                  size: 16,
                ),
              ),
            Text(
              '120',
              style: GoogleFonts.exo2(
                color: tokens.primary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              unit,
              style: TextStyle(
                color: tokens.onSurface.withValues(alpha: 0.38),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
