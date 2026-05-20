import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
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
  
  String? _originalHeaderContent;
  String? _originalHeaderPath;

  final Map<String, dynamic> _runtimeWidgetValues = {};
  void Function(String id, dynamic value)? onRuntimeValueChanged;

  final List<List<DesignerElement>> _undoStack = [];
  final List<List<DesignerElement>> _redoStack = [];
  static const int _maxUndoStack = 50;

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
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

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
    _undoStack.add(_elements.map((e) => e.copyWith()).toList());
    if (_undoStack.length > _maxUndoStack) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  void addElement(DesignerElementType type, int x, int y, {Map<String, dynamic>? properties}) {
    _pushUndo();
    final (w, h) = DesignerElement.defaultSize(type);
    final halfW = w ~/ 2;
    final halfH = h ~/ 2;
    final element = DesignerElement(
      id: UniqueKey().toString(),
      type: type,
      x: x.clamp(halfW, canvasWidth - halfW),
      y: y.clamp(halfH, canvasHeight - halfH),
      width: w,
      height: h,
      properties: properties,
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
    _elements = [
      for (int i = 0; i < _elements.length; i++)
        if (i == index) el.copyWith(
          width: (width ?? el.width).clamp(5, canvasWidth),
          height: (height ?? el.height).clamp(5, canvasHeight),
        )
        else _elements[i],
    ];
    notifyListeners();
  }

  void updateElementLabel(String id, String label) {
    final index = _elements.indexWhere((e) => e.id == id);
    if (index == -1) return;
    _pushUndo();
    _elements = [
      for (int i = 0; i < _elements.length; i++)
        if (i == index) _elements[i].copyWith(label: label)
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

  void toggleOrientation() {
    _isLandscape = !_isLandscape;
    _screenSize = _isLandscape ? '200 x 100' : '100 x 200';
    notifyListeners();
  }

  void setSkin(String name) {
    _activeSkin = name;
    notifyListeners();
  }

  void setGridStyle(GridStyle style) {
    _gridStyle = style;
    notifyListeners();
  }

  void cycleGridStyle() {
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
    _connectionType = value;
    notifyListeners();
  }

  void setModelName(String value) {
    _modelName = value;
    notifyListeners();
  }

  void setModelType(String value) {
    _modelType = value;
    notifyListeners();
  }

  void setModelDescription(String value) {
    _modelDescription = value;
    notifyListeners();
  }

  void setConnectionPassword(String value) {
    _connectionPassword = value;
    notifyListeners();
  }

  void setScreenSize(String value) {
    _screenSize = value;
    final newLandscape = (value == '200 x 100');
    if (newLandscape != _isLandscape) {
      _isLandscape = newLandscape;
    }
    notifyListeners();
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_elements.map((e) => e.copyWith()).toList());
    _elements = _undoStack.removeLast();
    _selectedElementId = null;
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
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
    loadFromHeaderContent(content);
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

    // restore model name so the generated header block uses the right name
    _modelName = (decoded['config']?['name'] as String?) ?? '';
    _modelDescription = (decoded['config']?['description'] as String?) ?? '';
    _connectionType = ((decoded['config']?['transport'] as String?) ?? 'BLE').toLowerCase();
    _activeSkin = _arduinoToTheme((decoded['config']?['theme'] as String?) ?? 'RK_DEFAULT');
    _connectionPassword = (decoded['config']?['password'] as String?) ?? '';

    final orientation =
        (decoded['canvas']?['orientation'] as String?) ?? 'landscape';
    _isLandscape = orientation == 'landscape' || orientation == 'auto';
    final rawSize = decoded['canvas']?['screenSize'] as String?;
    if (rawSize == '200 x 100' || rawSize == '100 x 200') {
      _screenSize = rawSize!;
    } else {
      _screenSize = _isLandscape ? '200 x 100' : '100 x 200';
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

  /// Build the serialisable map for saveToHeaderFile.
  String _themeToArduino(String skin) {
    switch (skin) {
      case 'neon':
        return 'RK_NEON';
      case 'minimal':
        return 'RK_MINIMAL';
      case 'dragon':
      default:
        return 'RK_DEFAULT';
    }
  }

  String _arduinoToTheme(String theme) {
    switch (theme) {
      case 'RK_NEON':
        return 'neon';
      case 'RK_MINIMAL':
        return 'minimal';
      case 'RK_DEFAULT':
      default:
        return 'dragon';
    }
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'config': {
          'name': _modelName,
          'description': _modelDescription,
          'transport': _connectionType.toUpperCase(),
          'theme': _themeToArduino(_activeSkin),
          'password': _connectionPassword,
        },
        'canvas': {
          'orientation': _isLandscape ? 'landscape' : 'portrait',
          'screenSize': _screenSize,
        },
        'widgets': _elements.map((e) => e.toJson()).toList(),
      };
}
