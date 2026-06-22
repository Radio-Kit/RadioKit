import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../theme/rk_tokens.dart';
import 'designer_element.dart';

enum GridStyle { lines, dots, none }

class DesignerState extends ChangeNotifier {
  List<DesignerElement> _elements = [];
  String? _selectedElementId;
  bool _isLandscape = true;
  bool _isPlayMode = false;
  bool _isInspectorVisible = true;
  GridStyle _gridStyle = GridStyle.none;
  String _activeSkin = 'dragon';
  String _connectionType = 'ble';
  String _modelName = '';
  String _modelType = 'Locomotive';
  String _modelDescription = '';
  String _connectionPassword = '';
  String _screenSize = '200 x 100';
  Map<String, dynamic> _features = {'ota': false, 'filesystem': false};
  bool _enableControlUI = true;
  List<Map<String, dynamic>> _telemetryWidgets = List.generate(4, (_) => <String, dynamic>{'label': '', 'icon': null, 'unit': ''});

  // appdata (metadata from the JSON block, not user-configurable)
  int? _lastEdit;
  String? _appVersion;

  String? _originalHeaderContent;
  String? _originalHeaderPath;

  final Map<String, dynamic> _runtimeWidgetValues = {};
  void Function(String id, dynamic value)? onRuntimeValueChanged;

  /// Monotonically-increasing counter bumped on every real data mutation.
  /// The screen listener compares this against a saved baseline to detect
  /// unsaved changes without false positives from UI-only notifications
  /// (e.g. selectElement, togglePlayMode).
  int _mutationCount = 0;
  int get mutationCount => _mutationCount;

  final List<List<DesignerElement>> _undoStack = [];
  final List<List<DesignerElement>> _redoStack = [];
  static const int _maxUndoStack = 50;

  /// Snapshot saved at gesture start (resize/rotate). Intermediate mutations
  /// during the gesture skip _pushUndo(); commitGesture() pushes the snapshot
  /// to the undo stack once, preventing one undo entry per drag frame.
  List<DesignerElement>? _gestureSnapshot;

  List<DesignerElement> get elements => _elements;
  String? get selectedElementId => _selectedElementId;
  bool get isLandscape => _isLandscape;
  bool get isPlayMode => _isPlayMode;
  bool get isInspectorVisible => _isInspectorVisible;
  GridStyle get gridStyle => _gridStyle;
  String get activeSkin => _activeSkin;
  String get connectionType => _connectionType;
  String get modelName => _modelName;
  String get modelType => _modelType;
  String get modelDescription => _modelDescription;
  String get connectionPassword => _connectionPassword;
  String get screenSize => _screenSize;
  int? get lastEdit => _lastEdit;
  String? get appVersion => _appVersion;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  bool get featureOta => (_features['ota'] as bool?) ?? false;
  bool get featureFilesystem => (_features['filesystem'] as bool?) ?? false;
  bool get enableControlUI => _enableControlUI;
  List<Map<String, dynamic>> get telemetryWidgets => _telemetryWidgets;

  DesignerElement? get selectedElement {
    if (_selectedElementId == null) return null;
    try {
      return _elements.firstWhere((e) => e.id == _selectedElementId);
    } catch (_) {
      return null;
    }
  }

  int get canvasWidth => _isLandscape ? 200 : 100;
  int get canvasHeight => _isLandscape ? 100 : 200;

  void _pushUndo() {
    // During an active resize/rotate gesture, skip undo pushes per frame.
    // The pre-gesture snapshot is saved in beginGesture() and committed
    // once in commitGesture() at gesture end.
    if (_gestureSnapshot != null) return;
    _mutationCount++;
    _undoStack.add(_elements.map((e) => e.copyWith()).toList());
    if (_undoStack.length > _maxUndoStack) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  /// Call when a gesture (resize/rotate) starts. Saves a snapshot of
  /// the current element state so commitGesture can push it to undo.
  void beginGesture() {
    assert(_gestureSnapshot == null, 'beginGesture without matching commitGesture');
    _gestureSnapshot = _elements.map((e) => e.copyWith()).toList();
  }

  /// Call when a gesture ends. Pushes the pre-gesture snapshot to the
  /// undo stack — a single undo point for the whole gesture.
  void commitGesture() {
    if (_gestureSnapshot == null) return;
    _mutationCount++;
    _undoStack.add(_gestureSnapshot!);
    if (_undoStack.length > _maxUndoStack) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
    _gestureSnapshot = null;
  }

  /// Call if the gesture is cancelled without applying changes.
  void cancelGesture() {
    if (_gestureSnapshot == null) return;
    // Restore elements to the pre-gesture state
    _elements = _gestureSnapshot!;
    _gestureSnapshot = null;
    notifyListeners();
  }

  void addElement(DesignerElementType type, int x, int y,
      {Map<String, dynamic>? properties, int? width, int? height}) {
    _pushUndo();
    final (dw, dh) = DesignerElement.defaultSize(type);
    final w = width ?? dw;
    final h = height ?? dh;
    final halfW = w ~/ 2;
    final halfH = h ~/ 2;
    final autoLabel = _generateAutoLabel(type);
    final element = DesignerElement(
      id: UniqueKey().toString(),
      type: type,
      x: x.clamp(halfW, canvasWidth - halfW),
      y: y.clamp(halfH, canvasHeight - halfH),
      width: w,
      height: h,
      properties: properties,
      label: autoLabel,
    );
    _elements = [..._elements, element];
    _selectedElementId = element.id;
    notifyListeners();
  }

  void removeSelected() {
    if (_selectedElementId == null) return;
    _pushUndo();
    _elements = _elements.where((e) => e.id != _selectedElementId).toList();
    _selectedElementId = null;
    notifyListeners();
  }

  void selectElement(String? id) {
    _selectedElementId = id;
    notifyListeners();
  }

  void updateElementPosition(String id, int x, int y) {
    final index = _elements.indexWhere((e) => e.id == id);
    if (index == -1) return;
    _pushUndo();
    final el = _elements[index];
    final halfW = el.width ~/ 2;
    final halfH = el.height ~/ 2;
    _elements = [
      for (int i = 0; i < _elements.length; i++)
        if (i == index) _elements[i].copyWith(
          x: x.clamp(halfW, canvasWidth - halfW),
          y: y.clamp(halfH, canvasHeight - halfH),
        )
        else _elements[i],
    ];
    notifyListeners();
  }

  void updateElementProperty(String id, String key, dynamic value) {
    final index = _elements.indexWhere((e) => e.id == id);
    if (index == -1) return;
    _pushUndo();
    final el = _elements[index];
    final newProps = Map<String, dynamic>.from(el.properties);
    newProps[key] = value;
    _elements = [
      for (int i = 0; i < _elements.length; i++)
        if (i == index) el.copyWith(properties: newProps)
        else _elements[i],
    ];
    notifyListeners();
  }

  void updateElementSize(String id, {int? width, int? height}) {
    final index = _elements.indexWhere((e) => e.id == id);
    if (index == -1) return;
    _pushUndo();
    final el = _elements[index];
    final (minW, minH) = DesignerElement.minSize(el.type,
        currentWidth: el.width, currentHeight: el.height);
    _elements = [
      for (int i = 0; i < _elements.length; i++)
        if (i == index) el.copyWith(
          width: (width ?? el.width).clamp(minW, canvasWidth),
          height: (height ?? el.height).clamp(minH, canvasHeight),
        )
        else _elements[i],
    ];
    notifyListeners();
  }

  void updateElementLabel(String id, String label) {
    final index = _elements.indexWhere((e) => e.id == id);
    if (index == -1) return;
    _pushUndo();
    final uniqueLabel = _ensureUniqueLabel(label, excludeElementId: id);
    _elements = [
      for (int i = 0; i < _elements.length; i++)
        if (i == index) _elements[i].copyWith(label: uniqueLabel)
        else _elements[i],
    ];
    notifyListeners();
  }

  void toggleElementLabelHidden(String id) {
    final index = _elements.indexWhere((e) => e.id == id);
    if (index == -1) return;
    _pushUndo();
    _elements = [
      for (int i = 0; i < _elements.length; i++)
        if (i == index) _elements[i].copyWith(labelHidden: !_elements[i].labelHidden)
        else _elements[i],
    ];
    notifyListeners();
  }

  void updateElementRotation(String id, int rotation) {
    final index = _elements.indexWhere((e) => e.id == id);
    if (index == -1) return;
    _pushUndo();
    // Normalize to -180..180
    var r = rotation % 360;
    if (r > 180) r -= 360;
    _elements = [
      for (int i = 0; i < _elements.length; i++)
        if (i == index) _elements[i].copyWith(rotation: r)
        else _elements[i],
    ];
    notifyListeners();
  }

  void resetSelectedTransform() {
    if (_selectedElementId == null) return;
    final index = _elements.indexWhere((e) => e.id == _selectedElementId);
    if (index == -1) return;
    final el = _elements[index];
    final (defaultW, defaultH) = DesignerElement.defaultSize(el.type);
    _pushUndo();
    _elements = [
      for (int i = 0; i < _elements.length; i++)
        if (i == index)
          el.copyWith(
            width: defaultW,
            height: defaultH,
            rotation: 0,
          )
        else
          _elements[i],
    ];
    notifyListeners();
  }

  void toggleOrientation() {
    final oldCw = _isLandscape ? 200 : 100;
    final oldCh = _isLandscape ? 100 : 200;
    final newCw = _isLandscape ? 100 : 200;
    final newCh = _isLandscape ? 200 : 100;

    final ratioX = newCw / oldCw;
    final ratioY = newCh / oldCh;

    _pushUndo();
    _elements = _elements.map((e) {
      final halfW = e.width ~/ 2;
      final halfH = e.height ~/ 2;
      return e.copyWith(
        x: (e.x * ratioX).round().clamp(halfW, newCw - halfW),
        y: (e.y * ratioY).round().clamp(halfH, newCh - halfH),

      );
    }).toList();

    _isLandscape = !_isLandscape;
    _screenSize = _isLandscape ? '200 x 100' : '100 x 200';
    notifyListeners();
  }

  void setSkin(String name) {
    _mutationCount++;
    _activeSkin = name;
    notifyListeners();
  }

  void setGridStyle(GridStyle style) {
    _mutationCount++;
    _gridStyle = style;
    notifyListeners();
  }

  void cycleGridStyle() {
    _mutationCount++;
    _gridStyle = switch (_gridStyle) {
      GridStyle.lines => GridStyle.dots,
      GridStyle.dots => GridStyle.none,
      GridStyle.none => GridStyle.lines,
    };
    notifyListeners();
  }

  dynamic getRuntimeWidgetValue(String id, dynamic defaultValue) {
    return _runtimeWidgetValues.containsKey(id) ? _runtimeWidgetValues[id] : defaultValue;
  }

  void setRuntimeWidgetValue(String id, dynamic value) {
    _runtimeWidgetValues[id] = value;
    if (onRuntimeValueChanged != null) {
      onRuntimeValueChanged!(id, value);
    }
    notifyListeners();
  }

  void togglePlayMode() {
    _isPlayMode = !_isPlayMode;
    if (_isPlayMode) {
      _selectedElementId = null;
      _runtimeWidgetValues.clear();
      _isInspectorVisible = false;
    } else {
      _isInspectorVisible = true;
    }
    notifyListeners();
  }

  void setInspectorVisible(bool visible) {
    _isInspectorVisible = visible;
    notifyListeners();
  }

  void notifyChanged() {
    notifyListeners();
  }

  void setConnectionType(String value) {
    _mutationCount++;
    _connectionType = value;
    notifyListeners();
  }

  void setModelName(String value) {
    _mutationCount++;
    _modelName = value;
    notifyListeners();
  }

  void setModelType(String value) {
    _mutationCount++;
    _modelType = value;
    notifyListeners();
  }

  void setModelDescription(String value) {
    _mutationCount++;
    _modelDescription = value;
    notifyListeners();
  }

  void setConnectionPassword(String value) {
    _mutationCount++;
    _connectionPassword = value;
    notifyListeners();
  }

  void setFeatureOta(bool v) {
    _features['ota'] = v;
    _mutationCount++;
    notifyListeners();
  }

  void setFeatureFilesystem(bool v) {
    _features['filesystem'] = v;
    _mutationCount++;
    notifyListeners();
  }

  void setEnableControlUI(bool v) {
    _mutationCount++;
    _enableControlUI = v;
    notifyListeners();
  }

  void setTelemetryLabel(int index, String label) {
    _mutationCount++;
    final newList = List<Map<String, dynamic>>.from(_telemetryWidgets);
    newList[index] = Map<String, dynamic>.from(newList[index])..['label'] = label;
    _telemetryWidgets = newList;
    notifyListeners();
  }

  void setTelemetryIcon(int index, String? icon) {
    _mutationCount++;
    final newList = List<Map<String, dynamic>>.from(_telemetryWidgets);
    newList[index] = Map<String, dynamic>.from(newList[index])..['icon'] = icon;
    _telemetryWidgets = newList;
    notifyListeners();
  }

  void setTelemetryUnit(int index, String unit) {
    _mutationCount++;
    final newList = List<Map<String, dynamic>>.from(_telemetryWidgets);
    newList[index] = Map<String, dynamic>.from(newList[index])..['unit'] = unit;
    _telemetryWidgets = newList;
    notifyListeners();
  }

  void setAppData({int? lastEdit, String? appVersion}) {
    if (lastEdit != null) _lastEdit = lastEdit;
    if (appVersion != null) _appVersion = appVersion;
  }

  void setScreenSize(dynamic value) {
    _mutationCount++;
    if (value is List && value.length >= 2) {
      final w = (value[0] as num?)?.toInt() ?? 200;
      final h = (value[1] as num?)?.toInt() ?? 100;
      _isLandscape = w >= h;
      _screenSize = '${w} x ${h}';
    } else if (value is String) {
      final parts = value.split(' x ');
      final w = int.tryParse(parts[0]) ?? 200;
      final h = int.tryParse(parts[1]) ?? 100;
      _isLandscape = w >= h;
      _screenSize = '${w} x ${h}';
    }
    notifyListeners();
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _mutationCount++;
    _redoStack.add(_elements.map((e) => e.copyWith()).toList());
    _elements = _undoStack.removeLast();
    _selectedElementId = null;
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _mutationCount++;
    _undoStack.add(_elements.map((e) => e.copyWith()).toList());
    _elements = _redoStack.removeLast();
    _selectedElementId = null;
    notifyListeners();
  }

  void clearAll() {
    if (_elements.isEmpty) return;
    _pushUndo();
    _elements = [];
    _selectedElementId = null;
    _runtimeWidgetValues.clear();
    notifyListeners();
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  .h-file persistence — reads/writes the JSON inside
  //  /*__RadioKit_UI_Designer_Config__ … RadioKit_UI_Designer_Config__*/
  // ──────────────────────────────────────────────────────────────────────────

  static const _configStart = '/*__RadioKit_UI_Designer_Config__';
  static const _configEnd = 'RadioKit_UI_Designer_Config__*/';

  static final RegExp configPattern = RegExp(
    RegExp.escape(_configStart) + r'(.*?)' + RegExp.escape(_configEnd),
    dotAll: true,
  );

  /// Load designer state from a `.h` file's embedded JSON comment block.
  Future<void> loadFromHeaderFile(String filePath) async {
    if (kIsWeb || !(Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
      throw UnsupportedError('Header-file I/O requires a desktop platform');
    }
    final content = await File(filePath).readAsString();
    loadFromHeaderContent(content, path: filePath);
  }

  /// Load designer state from a plain `.json` file (no header markers).
  Future<void> loadJsonFromPath(String filePath) async {
    if (kIsWeb || !(Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
      throw UnsupportedError('JSON file I/O requires a desktop platform');
    }
    final content = await File(filePath).readAsString();
    _originalHeaderContent = content;
    _originalHeaderPath = filePath;
    final decoded = json.decode(content) as Map<String, dynamic>;
    loadFromJson(decoded);
  }

  /// Load designer state from raw header string content.
  void loadFromHeaderContent(String content, {String? path}) {
    _originalHeaderContent = content;
    _originalHeaderPath = path;

    final match = configPattern.firstMatch(content);
    if (match == null || match.group(1) == null) {
      throw FormatException(
        'No /*__RadioKit_UI_Designer_Config__ … */ block found in content',
      );
    }
    final jsonStr = (match.group(1) as String).trim();
    final decoded = json.decode(jsonStr) as Map<String, dynamic>;
    loadFromJson(decoded);
  }

  void loadFromJson(Map<String, dynamic> decoded) {
    _elements.clear();
    for (final wJson in (decoded['widgets'] as List? ?? [])) {
      _elements.add(DesignerElement.fromJson(wJson as Map<String, dynamic>));
    }

    // restore model config so the generated header block uses the right values
    _modelName = (decoded['config']?['name'] as String?) ?? '';
    _modelDescription = (decoded['config']?['description'] as String?) ?? '';
    _modelType = (decoded['config']?['type'] as String?) ?? 'Locomotive';
    _connectionType = ((decoded['config']?['transport'] as String?) ?? 'BLE').toLowerCase();
    _activeSkin = _normaliseSkin((decoded['config']?['theme'] as String?) ?? 'dragon');
    _connectionPassword = (decoded['config']?['password'] as String?) ?? '';

    // canvas section: read 'size' (array [w, h] or legacy string "W x H")
    final rawSize = decoded['canvas']?['size'] ?? decoded['canvas']?['screenSize'];
    if (rawSize is List && rawSize.length >= 2) {
      final w = (rawSize[0] as num?)?.toInt() ?? 200;
      final h = (rawSize[1] as num?)?.toInt() ?? 100;
      _isLandscape = w >= h;
      _screenSize = '${w} x ${h}';
    } else if (rawSize is String) {
      final parts = rawSize.split(' x ');
      final w = int.tryParse(parts[0]) ?? 200;
      final h = int.tryParse(parts[1]) ?? 100;
      _isLandscape = w >= h;
      _screenSize = '${w} x ${h}';
    } else if (rawSize == null) {
      // default to landscape
      _isLandscape = true;
      _screenSize = '200 x 100';
    }

    // read grid style (string: 'lines', 'dots', 'none')
    final gridStr = decoded['canvas']?['grid'] as String?;
    if (gridStr != null) {
      _gridStyle = switch (gridStr) {
        'lines' => GridStyle.lines,
        'dots' => GridStyle.dots,
        _ => GridStyle.none,
      };
    }

    // read skin from canvas (overrides config.theme if present)
    final canvasSkin = decoded['canvas']?['skin'] as String?;
    if (canvasSkin != null) {
      _activeSkin = canvasSkin;
    }

    // appdata
    final appData = decoded['appdata'];
    if (appData is Map) {
      _lastEdit = appData['lastEdit'] as int?;
      _appVersion = appData['appVersion'] as String?;
    }

    // enableControlUI
    _enableControlUI = (decoded['enableControlUI'] as bool?) ?? true;

    // telemetry
    final rawTelemetry = decoded['telemetry'] as List?;
    if (rawTelemetry != null && rawTelemetry.length == 4) {
      _telemetryWidgets = rawTelemetry
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } else {
      _telemetryWidgets = List.generate(4, (_) => <String, dynamic>{'label': '', 'icon': null, 'unit': ''});
    }

    // features
    if (decoded['features'] is Map) {
      _features = Map<String, dynamic>.from(decoded['features'] as Map);
    }

    _selectedElementId = null;
    notifyListeners();
  }

  String? get originalHeaderContent => _originalHeaderContent;
  String? get originalHeaderPath => _originalHeaderPath;

  /// Write the current designer state into the `.h` file's embedded JSON block,
  /// preserving everything else (user code below the markers) unchanged.
  Future<void> saveToHeaderFile(String filePath) async {
    if (kIsWeb || !(Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
      throw UnsupportedError('Header-file I/O requires a desktop platform');
    }
    _lastEdit = DateTime.now().millisecondsSinceEpoch;
    final content = await File(filePath).readAsString();
    final result = generateHeaderContent(content);
    await File(filePath).writeAsString(result);
  }

  /// Replaces the embedded JSON block in the given [originalContent] with the
  /// current designer state and returns the new complete header string.
  String generateHeaderContent(String originalContent) {
    final match = configPattern.firstMatch(originalContent);
    final encoder = JsonEncoder.withIndent('  ');
    final newJson = encoder.convert(toJson());
    final fullBlock = '$_configStart\n$newJson\n$_configEnd\n';

    if (match == null || match.group(1) == null) {
      if (originalContent.trim().isEmpty) {
        return '$fullBlock\n//__RadioKit_Generated_Code__\n';
      }
      return '$originalContent\n\n$fullBlock';
    }
    return originalContent.replaceRange(match.start, match.end, fullBlock);
  }

  /// Returns a snake_case base label name for the given widget type.
  String _baseLabelForType(DesignerElementType type) {
    switch (type) {
      case DesignerElementType.button: return 'button';
      case DesignerElementType.slideSwitch: return 'slide_switch';
      case DesignerElementType.rockerSwitch: return 'switch';
      case DesignerElementType.slider: return 'slider';
      case DesignerElementType.gasPedal: return 'gas_pedal';
      case DesignerElementType.knob: return 'knob';
      case DesignerElementType.steeringWheel: return 'steering_wheel';
      case DesignerElementType.joystick: return 'joystick';
      case DesignerElementType.multiButton: return 'multi_button';
      case DesignerElementType.multiSelect: return 'multi_select';
      case DesignerElementType.led: return 'led';
      case DesignerElementType.text: return 'text';
      case DesignerElementType.serialMonitor: return 'serial_monitor';
    }
  }

  /// Generates an auto-label for the given [type] in the format `{base}_{N}`
  /// (e.g., `button_1`, `button_2`), always starting the counter at 1 and
  /// incrementing until a unique label is found.
  String _generateAutoLabel(DesignerElementType type) {
    final base = _baseLabelForType(type);
    final existingLabels = _elements.map((e) => e.label).toSet();
    int counter = 1;
    while (existingLabels.contains('${base}_$counter')) {
      counter++;
    }
    return '${base}_$counter';
  }

  /// Ensures [label] is unique among all elements, excluding the element
  /// with [excludeElementId] (if provided). Appends `_N` suffix as needed.
  String _ensureUniqueLabel(String label, {String? excludeElementId}) {
    final existingLabels = _elements
        .where((e) => e.id != excludeElementId)
        .map((e) => e.label)
        .toSet();

    if (!existingLabels.contains(label)) return label;

    int counter = 1;
    while (existingLabels.contains('${label}_$counter')) {
      counter++;
    }
    return '${label}_$counter';
  }

  /// Validates and normalises a skin/theme name to a lowercase preset key
  /// or 'default'. Used for both serialisation and deserialisation.
  String _normaliseSkin(String name) {
    if (name == 'default') return 'default';
    if (RKTokens.presetsByName.containsKey(name)) return name;
    return 'dragon';
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'appdata': {
          if (_appVersion != null) 'appVersion': _appVersion,
          if (_lastEdit != null) 'lastEdit': _lastEdit,
        },
        'config': {
          'name': _modelName,
          'description': _modelDescription,
          'type': _modelType,
          'transport': _connectionType.toUpperCase(),
          'theme': _normaliseSkin(_activeSkin),
          'password': _connectionPassword,
        },
        'canvas': {
          'size': [canvasWidth, canvasHeight],
          'grid': _gridStyle.name,
          'skin': _activeSkin,
        },
        'enableControlUI': _enableControlUI,
        'telemetry': List<Map<String, dynamic>>.from(_telemetryWidgets),
        'features': Map<String, dynamic>.from(_features),
        'widgets': _elements.map((e) => e.toJson()).toList(),
      };
}
