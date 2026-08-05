import '../../radiokit_widgets.dart';

enum DesignerElementType {
  button,
  slideSwitch,
  rockerSwitch,
  slider,
  knob,
  steeringWheel,
  joystick,
  multiButton,
  multiSelect,
  gasPedal,
  led,
  text,
  serialMonitor,
}

class WidgetDragPayload {
  final DesignerElementType type;
  final Map<String, dynamic> properties;
  const WidgetDragPayload(this.type, this.properties);
}

class DesignerElement {
  final String id;
  final DesignerElementType type;
  int x;
  int y;
  int width;
  int height;
  Map<String, dynamic> properties;
  String label;
  bool labelHidden;
  int rotation;
  bool hidden;

  /// The aspect ratio (width/height) that this widget type enforces, or `null`
  /// if the widget has free-form sizing. When non-null the inspector shows
  /// only a single dimension field and auto-computes the other.
  double? get aspectRatio {
    switch (type) {
      case DesignerElementType.multiButton:
      case DesignerElementType.multiSelect:
        final count = (properties['itemCount'] as num?)?.toInt() ?? 3;
        final baseAr = (count * 0.67).clamp(0.5, 10.0);
        // Positive  → horizontal (height is primary, width  = height × ar)
        // Negative  → vertical   (width  is primary, height = width  × |ar|)
        return width >= height ? baseAr : -baseAr;
      default:
        return aspectRatioFor(type, properties);
    }
  }

  /// The effective rendered size in grid units.
  (int, int) get renderedGridSize {
    final ar = aspectRatio;
    if (ar == null) return (width, height);
    if (ar >= 0) {
      // Height is primary (horizontal multi, square widgets)
      return ((height * ar).round().clamp(1, 999), height);
    } else {
      // Width is primary (vertical multi)
      return (width, (width * -ar).round().clamp(1, 999));
    }
  }

  DesignerElement({
    required this.id,
    required this.type,
    this.x = 10,
    this.y = 10,
    this.width = 20,
    this.height = 20,
    Map<String, dynamic>? properties,
    this.label = '',
    this.labelHidden = true,
    this.rotation = 0,
    this.hidden = false,
  }) : properties = _mergeDefaults(type, properties);

  /// Seeds [properties] from [_defaultProperties(type)] and merges any
  /// [overrides] on top so that partial property maps (e.g. `{variant: 'push'}`)
  /// never lose the unmentioned defaults.
  static Map<String, dynamic> _mergeDefaults(
      DesignerElementType type, Map<String, dynamic>? overrides) {
    final defaults = _defaultProperties(type);
    if (overrides != null && overrides.isNotEmpty) {
      defaults.addAll(overrides);
    }
    return defaults;
  }

  /// Returns a fresh copy of the default properties map for [type].
  static Map<String, dynamic> defaultPropertiesFor(DesignerElementType type) {
    return Map<String, dynamic>.from(_defaultProperties(type));
  }

  /// Parses the `autoCenter` value (List or Map) into a normalized list:
  ///
  ///     [position, springType, springDuration]
  ///
  /// where `position` is `null` (disabled) or `"min" | "center" | "max"`.
  /// List format: directly passed through.
  /// Map format: legacy structured map — extracted into array.
  /// Other: treated as disabled with smooth / 300 defaults.
  static List<dynamic> _parseAutoCenter(dynamic raw) {
    if (raw is List && raw.length >= 3) {
      return List<dynamic>.from(raw);
    }
    if (raw is Map) {
      final pos = raw['position'] as String?;
      final type = (raw['type'] as String?) ?? 'smooth';
      final duration = (raw['duration'] as num?)?.toInt() ?? 300;
      return [pos, type, duration];
    }
    return [null, 'smooth', 300];
  }

  static Map<String, dynamic> _defaultProperties(DesignerElementType type) {
    final def = WidgetRegistry.instance.getByType(type);
    if (def != null) {
      return Map<String, dynamic>.from(def.defaultProperties);
    }
    switch (type) {
      case DesignerElementType.button:
        return {
          'variant': 'push',
          'onText': 'ON',
          'offText': 'OFF',
          'onIcon': null,
          'offIcon': null,
          'haptic': true,
        };
      case DesignerElementType.slideSwitch:
        return {
          'onText': 'ON',
          'offText': 'OFF',
          'haptic': true,
        };
      case DesignerElementType.rockerSwitch:
        return {
          'onIcon': null,
          'offIcon': null,
          'haptic': true,
        };
      case DesignerElementType.multiButton:
        return {
          'haptic': true,
          'itemCount': 3,
          'items': List.generate(
              3,
              (i) => <String, dynamic>{
                    'onLabel': String.fromCharCode(65 + i),
                    'onIcon': null,
                    'offLabel': null,
                    'offIcon': null,
                  }),
        };
      case DesignerElementType.multiSelect:
        return {
          'haptic': true,
          'itemCount': 3,
          'items': List.generate(
              3,
              (i) => <String, dynamic>{
                    'onLabel': String.fromCharCode(65 + i),
                    'onIcon': null,
                    'offLabel': null,
                    'offIcon': null,
                  }),
        };
      case DesignerElementType.slider:
        return {
          'min': -100,
          'max': 100,
          'autoCenter': [null, 'smooth', 300],
          'divisions': null,
        };
      case DesignerElementType.knob:
        return {
          'min': 0,
          'max': 100,
          'minAngle': -135,
          'maxAngle': 135,
          'autoCenter': [null, 'smooth', 500],
          'centerIcon': null,
          'divisions': null,
        };
      case DesignerElementType.steeringWheel:
        return {
          'min': -100,
          'max': 100,
          'minAngle': -135,
          'maxAngle': 135,
          'autoCenter': ['center', 'smooth', 500],
          'centerIcon': 'renault',
          'divisions': null,
        };
      case DesignerElementType.joystick:
        return {
          'autoCenter': ['center', 'smooth', 300],
          'centerX': 0.0,
          'centerY': 0.0,
        };
      case DesignerElementType.gasPedal:
        return {
          'min': 0,
          'max': 100,
          'autoCenter': ['min', 'smooth', 300],
        };
      case DesignerElementType.led:
        return {
          'state': 'off',
          'shape': 'circle',
          'color': 0x00FF00,
          'timing': 500,
        };
      case DesignerElementType.text:
        return {
          'text': 'Display',
          'fontSize': 14,
          'fontFamily': 'monospace',
        };
      case DesignerElementType.serialMonitor:
        return {
          'fontSize': 12,
          'fontFamily': 'monospace',
        };
    }
  }

  /// Returns the aspect ratio for [type] based on its current [properties],
  /// or `null` for free-form widgets.
  static double? aspectRatioFor(
      DesignerElementType type, Map<String, dynamic> properties) {
    final def = WidgetRegistry.instance.getByType(type);
    if (def != null) {
      return def.aspectRatio(properties, 20, 20);
    }
    switch (type) {
      case DesignerElementType.button:
        return RKButton.aspectRatio;
      case DesignerElementType.knob:
        return RKKnob.aspectRatio;
      case DesignerElementType.steeringWheel:
        return RKSteeringWheel.aspectRatio;
      case DesignerElementType.joystick:
        return RKJoystick.aspectRatio;
      case DesignerElementType.slideSwitch:
        return RKSlideSwitch.aspectRatio;
      case DesignerElementType.rockerSwitch:
        return RKRockerSwitch.aspectRatio;
      case DesignerElementType.slider:
        return null; // slider is free-form
      case DesignerElementType.led:
        return RKLed.aspectRatio;
      default:
        return null;
    }
  }

  static (int, int) defaultSize(DesignerElementType type) {
    final def = WidgetRegistry.instance.getByType(type);
    if (def != null) {
      return def.defaultSize;
    }
    switch (type) {
      case DesignerElementType.button:
        return (40, 40);
      case DesignerElementType.slideSwitch:
        return (40, 20);
      case DesignerElementType.rockerSwitch:
        return (20, 40);
      case DesignerElementType.slider:
        return (45, 15);
      case DesignerElementType.knob:
        return (40, 40);
      case DesignerElementType.steeringWheel:
        return (40, 40);
      case DesignerElementType.joystick:
        return (40, 40);
      case DesignerElementType.multiButton:
        return (30, 15);
      case DesignerElementType.multiSelect:
        return (30, 15);
      case DesignerElementType.gasPedal:
        return (15, 30);
      case DesignerElementType.led:
        return (15, 15);
      case DesignerElementType.text:
        return (60, 20);
      case DesignerElementType.serialMonitor:
        return (60, 40);
    }
  }

  /// Returns the minimum size (width, height) for [type].
  /// For slider, orientation is inferred from [currentWidth]/[currentHeight]:
  ///   - width >= height → horizontal → min (30, 10)
  ///   - width <  height → vertical   → min (10, 30)
  /// Used to prevent widgets from being resized too small in the canvas.
  static (int, int) minSize(DesignerElementType type,
      {int currentWidth = 0, int currentHeight = 0}) {
    switch (type) {
      case DesignerElementType.button:
      case DesignerElementType.knob:
      case DesignerElementType.steeringWheel:
      case DesignerElementType.joystick:
        return (20, 20);
      case DesignerElementType.slideSwitch:
      case DesignerElementType.multiButton:
      case DesignerElementType.multiSelect:
      case DesignerElementType.led:
        return (0, 10);
      case DesignerElementType.rockerSwitch:
        return (0, 20);
      case DesignerElementType.slider:
        return currentWidth >= currentHeight
            ? (30, 10)  // horizontal
            : (10, 30); // vertical
      case DesignerElementType.text:
      case DesignerElementType.serialMonitor:
        return (30, 15);
      case DesignerElementType.gasPedal:
        // Gas pedal is always vertical (pedal shape)
        return currentHeight >= currentWidth
            ? (10, 30)
            : (30, 10);
    }
  }

  DesignerElement copyWith({
    String? id,
    DesignerElementType? type,
    int? x,
    int? y,
    int? width,
    int? height,
    Map<String, dynamic>? properties,
    String? label,
    bool? labelHidden,
    int? rotation,
    bool? hidden,
  }) {
    return DesignerElement(
      id: id ?? this.id,
      type: type ?? this.type,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      properties: properties ?? Map<String, dynamic>.from(this.properties),
      label: label ?? this.label,
      labelHidden: labelHidden ?? this.labelHidden,
      rotation: rotation ?? this.rotation,
      hidden: hidden ?? this.hidden,
    );
  }

  String get jsonTypeStr {
    switch (type) {
      case DesignerElementType.button:
        return 'button';
      case DesignerElementType.slideSwitch:
      case DesignerElementType.rockerSwitch:
        return 'switch';
      case DesignerElementType.slider:
        return 'slider';
      case DesignerElementType.gasPedal:
        return 'slider';
      case DesignerElementType.knob:
        return 'knob';
      case DesignerElementType.steeringWheel:
        return 'knob';
      case DesignerElementType.joystick:
        return 'joystick';
      case DesignerElementType.multiButton:
        return 'multiple';
      case DesignerElementType.multiSelect:
        return 'multiple';
      case DesignerElementType.led:
        return 'led';
      case DesignerElementType.text:
        return 'text';
      case DesignerElementType.serialMonitor:
        return 'serialMonitor';
    }
  }

  Map<String, dynamic> toJson() {
    // Build the base properties map: widget-specific values only.
    // Promoted / derived keys are stripped.
    final baseProps = <String, dynamic>{
      ...properties,
    }
      ..remove('autoCenter')
      ..remove('center')
      ..remove('springBehavior')
      ..remove('springDuration')
      ..remove('rotation')
      ..remove('label')
      ..remove('labelHidden')
      ..remove('haptic');

    // For multi-button/multi-select items, fill empty items (no label, no icon)
    // with a default 'power' icon so they are never blank in saved output.
    if (baseProps.containsKey('items') && baseProps['items'] is List) {
      final items = (baseProps['items'] as List).map((item) {
        if (item is! Map) return item;
        final m = Map<String, dynamic>.from(item);
        final hasLabel =
            m['onLabel'] is String && (m['onLabel'] as String).isNotEmpty;
        final hasIcon =
            m['onIcon'] is String && (m['onIcon'] as String).isNotEmpty;
        if (!hasLabel && !hasIcon) {
          m['onIcon'] = 'power';
        }
        return m;
      }).toList();
      baseProps['items'] = items;
    }

    // Serialize autoCenter as [position, type, duration] array.
    // Only emit autoCenter if it was set on this element (skip for types that
    // don't support auto-center, like switches).
    if (properties.containsKey('autoCenter')) {
      final ac = properties['autoCenter'];
      if (ac is List) {
        baseProps['autoCenter'] = List<dynamic>.from(ac);
      } else if (ac is Map) {
        final pos = ac['position'] as String?;
        final type = ac['type'] as String? ?? 'smooth';
        final duration = (ac['duration'] as num?)?.toInt() ?? 300;
        baseProps['autoCenter'] = [pos, type, duration];
      } else {
        baseProps['autoCenter'] = [null, 'smooth', 300];
      }
    }

    // Determine the variant for this widget type
    // Only promote variant to top level for types that derive from a base type
    // (gasPedal→slider, steeringWheel→knob, multiButton/multiSelect→multiple, rockerSwitch→switch).
    final String? variant;
    final bool promoteVariant;
    switch (type) {
      case DesignerElementType.gasPedal:
        variant = 'gasPedal';
        promoteVariant = true;
        break;
      case DesignerElementType.steeringWheel:
        variant = 'steeringWheel';
        promoteVariant = true;
        break;
      case DesignerElementType.multiSelect:
        variant = 'multiSelect';
        promoteVariant = true;
        break;
      case DesignerElementType.multiButton:
        variant = 'multiButton';
        promoteVariant = true;
        break;
      case DesignerElementType.rockerSwitch:
        variant = 'rockerSwitch';
        promoteVariant = true;
        break;
      case DesignerElementType.slideSwitch:
        variant = 'slideSwitch';
        promoteVariant = true;
        break;
      default:
        variant = null;
        promoteVariant = false;
    }
    // Strip variant from baseProps when promoted to top level (prevents duplicates).
    // For other types (e.g. buttons with push/toggle), variant stays in properties.
    if (promoteVariant) {
      baseProps.remove('variant');
    }

    final ar = aspectRatio;

    final result = <String, dynamic>{
      'type': jsonTypeStr,
      'name': label,
      'label': <String, dynamic>{
        'text': label,
        'show': !labelHidden,
      },
      'position': [x, y, rotation],
      'size': ar == null
          ? [width, height]
          : ar >= 0
              ? [null, height]
              : [width, null],
      'haptic': (properties['haptic'] as bool?) ?? true,
      if (hidden) 'hidden': true,
      if (variant != null) 'variant': variant,
      'properties': baseProps,
    };

    return result;
  }

  factory DesignerElement.fromJson(Map<String, dynamic> json) {
    String typeStr = json['type'] as String;

    // ── Read properties ──────────────────────────────────────────────────────
    // New format uses a nested 'properties' map; old format uses flat top-level keys.
    Map<String, dynamic> props;
    if (json.containsKey('properties')) {
      props = Map<String, dynamic>.from(json['properties'] as Map? ?? {});
    } else {
      props = {};
      const knownKeys = {
        'type',
        'name',
        'label',
        'position',
        'size',
        'x',
        'y',
        'width',
        'height',
        'rotation',
        'labelHidden',
        'variant',
        'haptic',
        'properties',
        'behavior',
      };
      for (final key in json.keys) {
        if (key == 'behavior' && json[key] is Map) {
          final behavior = json[key] as Map<String, dynamic>;
          props.addAll(Map<String, dynamic>.from(behavior));
        } else if (!knownKeys.contains(key)) {
          props[key] = json[key];
        }
      }
    }
    DesignerElementType parsedType;

    switch (typeStr) {
      case 'button':
        parsedType = DesignerElementType.button;
        break;
      case 'switch':
        {
          final v = (json['variant'] is String)
              ? json['variant'] as String
              : (props['variant'] is String
                  ? props['variant'] as String
                  : null);
          parsedType = (v == 'slideSwitch')
              ? DesignerElementType.slideSwitch
              : DesignerElementType.rockerSwitch;
          break;
        }
      case 'slideSwitch':
        parsedType = DesignerElementType.slideSwitch;
        break;
      case 'slider':
        {
          final v = (json['variant'] is String)
              ? json['variant'] as String
              : (props['variant'] is String
                  ? props['variant'] as String
                  : null);
          parsedType = (v == 'gasPedal')
              ? DesignerElementType.gasPedal
              : DesignerElementType.slider;
          break;
        }
      case 'knob':
        {
          final v = (json['variant'] is String)
              ? json['variant'] as String
              : (props['variant'] is String
                  ? props['variant'] as String
                  : null);
          parsedType = (v == 'steeringWheel')
              ? DesignerElementType.steeringWheel
              : DesignerElementType.knob;
          break;
        }
      case 'joystick':
        parsedType = DesignerElementType.joystick;
        break;
      case 'multiple':
        {
          final v = (json['variant'] is String)
              ? json['variant'] as String
              : ((props['variant'] is String)
                  ? props['variant'] as String
                  : null);
          parsedType = (v == 'multiSelect')
              ? DesignerElementType.multiSelect
              : DesignerElementType.multiButton;
          break;
        }
      case 'led':
        parsedType = DesignerElementType.led;
        break;
      case 'text':
        parsedType = DesignerElementType.text;
        break;
      case 'display':
        parsedType = DesignerElementType.text;
        break;
      default:
        try {
          parsedType = DesignerElementType.values.byName(typeStr);
        } catch (_) {
          parsedType = DesignerElementType.button;
        }
    }

    // ── Backward compat: map old keys to new names ───────────────────────────
    if (props.containsKey('mode') && !props.containsKey('variant')) {
      props['variant'] = props.remove('mode');
    }
    if (props.containsKey('enableHapticFeedback') &&
        !props.containsKey('haptic')) {
      props['haptic'] = props.remove('enableHapticFeedback');
    }

    // ── Parse label (new format: { text, show } old format: flat string) ─────
    // New format: "label": { "text": "...", "show": true/false }
    final rawLabelField = json['label'];
    String labelVal;
    bool labelHiddenVal;
    if (rawLabelField is Map) {
      labelVal = (rawLabelField['text'] as String?) ?? '';
      labelHiddenVal = !((rawLabelField['show'] as bool?) ?? true);
    } else {
      // Old flat format.
      labelVal = (rawLabelField as String?) ??
          props.remove('label') as String? ??
          '';
      labelHiddenVal =
          (json['labelHidden'] as bool?) ??
          (props.remove('labelHidden') as bool?) ??
          false;
    }
    // "name" is an alias for the label/hint name.
    if (json['name'] is String &&
        (json['name'] as String).isNotEmpty) {
      labelVal = json['name'] as String;
    }

    // Parse hidden flag.
    final hiddenVal = (json['hidden'] as bool?) ?? false;

    // ── Parse position (new: {x,y,rotation}; old: flat) ──────────────────────
    final rawPosition = json['position'];
    late final int resolvedX;
    late final int resolvedY;
    late final int resolvedRotation;
    if (rawPosition is List && rawPosition.length >= 3) {
      resolvedX = (rawPosition[0] as num?)?.toInt() ?? 10;
      resolvedY = (rawPosition[1] as num?)?.toInt() ?? 10;
      resolvedRotation = (rawPosition[2] as num?)?.toInt() ?? 0;
    } else if (rawPosition is Map) {
      resolvedX = (rawPosition['x'] as num?)?.toInt() ?? 10;
      resolvedY = (rawPosition['y'] as num?)?.toInt() ?? 10;
      resolvedRotation =
          (rawPosition['rotation'] as num?)?.toInt() ?? 0;
    } else {
      resolvedX = (json['x'] as num?)?.toInt() ??
          (props['x'] as num?)?.toInt() ??
          10;
      resolvedY = (json['y'] as num?)?.toInt() ??
          (props['y'] as num?)?.toInt() ??
          10;
      resolvedRotation = (json['rotation'] as num?)?.toInt() ??
          (json['rotation'] as num?)?.round() ??
          0;
    }

    // ── Parse size (new: {w,h}; old: flat width/height) ──────────────────────
    final rawSize = json['size'];
    int? rawWidthJson;
    int? rawHeightJson;
    if (rawSize is List && rawSize.length >= 2) {
      final wVal = rawSize[0];
      final hVal = rawSize[1];
      rawWidthJson = (wVal is num) ? wVal.toInt() : null;
      rawHeightJson = (hVal is num) ? hVal.toInt() : null;
    } else if (rawSize is Map) {
      final wVal = rawSize['w'];
      final hVal = rawSize['h'];
      rawWidthJson = (wVal is num) ? wVal.toInt() : null;
      rawHeightJson = (hVal is num) ? hVal.toInt() : null;
    } else {
      rawWidthJson = json['width'] as int?;
      rawHeightJson = json['height'] as int?;
    }

    // ── Seed defaults + merge supplier props ─────────────────────────────────
    final seeded = _defaultProperties(parsedType);
    seeded.addAll(props);

    // ── Normalize autoCenter into a map ──────────────────────────────────────
    // Accepts List [position, type, duration] (new JSON format) or Map (legacy).
    seeded['autoCenter'] = _parseAutoCenter(seeded['autoCenter']);

    // ── Extract promoted top-level fields ────────────────────────────────────
    final String? variantVal =
        (seeded.remove('variant') as String?) ??
        (json['variant'] as String?);
    if (variantVal != null) seeded['variant'] = variantVal;
    final bool hapticVal =
        (seeded.remove('haptic') as bool?) ??
        (json['haptic'] as bool?) ??
        true;
    seeded['haptic'] = hapticVal;

    // ── Resolve width and height ─────────────────────────────────────────────
    int effectiveWidth;
    int effectiveHeight;

    if (parsedType == DesignerElementType.multiButton ||
        parsedType == DesignerElementType.multiSelect) {
      final count = (seeded['itemCount'] as num?)?.toInt() ?? 3;
      final ratio = (count * 0.67).clamp(0.5, 10.0);
      if (rawWidthJson != null && rawHeightJson == null) {
        // Vertical: only width saved — derive height.
        effectiveWidth = rawWidthJson;
        effectiveHeight = (rawWidthJson * ratio).round().clamp(1, 999);
      } else if (rawHeightJson != null && rawWidthJson == null) {
        // Horizontal: only height saved — derive width.
        effectiveHeight = rawHeightJson;
        effectiveWidth = (rawHeightJson * ratio).round().clamp(1, 999);
      } else if (rawWidthJson != null && rawHeightJson != null) {
        effectiveWidth = rawWidthJson;
        effectiveHeight = rawHeightJson;
      } else {
        effectiveHeight = 20;
        effectiveWidth = (20 * ratio).round().clamp(1, 999);
      }
    } else {
      effectiveHeight = rawHeightJson ?? 20;
      if (rawWidthJson != null) {
        effectiveWidth = rawWidthJson;
      } else {
        final ar = aspectRatioFor(parsedType, seeded);
        if (ar != null) {
          effectiveWidth = (effectiveHeight * ar).round().clamp(1, 999);
        } else {
          effectiveWidth = effectiveHeight.clamp(1, 200);
        }
      }
    }

    return DesignerElement(
      id: labelVal,
      type: parsedType,
      x: resolvedX,
      y: resolvedY,
      width: effectiveWidth,
      height: effectiveHeight,
      properties: seeded,
      label: labelVal,
      labelHidden: labelHiddenVal,
      rotation: resolvedRotation,
      hidden: hiddenVal,
    );
  }
}
