import 'package:flutter/foundation.dart';
import 'designer_element.dart';

enum GridStyle { lines, dots, none }

class DesignerState extends ChangeNotifier {
  List<DesignerElement> _elements = [];
  String? _selectedElementId;
  bool _isLandscape = true;
  bool _isPlayMode = false;
  GridStyle _gridStyle = GridStyle.none;
  String _activeSkin = 'dragon';
  String _connectionType = 'ble';
  String _modelName = '';
  String _modelType = '';
  String _connectionPassword = '';

  final Map<String, dynamic> _runtimeWidgetValues = {};

  final List<List<DesignerElement>> _undoStack = [];
  final List<List<DesignerElement>> _redoStack = [];
  static const int _maxUndoStack = 50;

  List<DesignerElement> get elements => _elements;
  String? get selectedElementId => _selectedElementId;
  bool get isLandscape => _isLandscape;
  bool get isPlayMode => _isPlayMode;
  GridStyle get gridStyle => _gridStyle;
  String get activeSkin => _activeSkin;
  String get connectionType => _connectionType;
  String get modelName => _modelName;
  String get modelType => _modelType;
  String get connectionPassword => _connectionPassword;
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
    _elements = [
      for (int i = 0; i < _elements.length; i++)
        if (i == index) _elements[i].copyWith(rotation: rotation)
        else _elements[i],
    ];
    notifyListeners();
  }

  void toggleOrientation() {
    _isLandscape = !_isLandscape;
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
    notifyListeners();
  }

  void togglePlayMode() {
    _isPlayMode = !_isPlayMode;
    if (_isPlayMode) {
      _selectedElementId = null;
      _runtimeWidgetValues.clear();
    }
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

  void setConnectionPassword(String value) {
    _connectionPassword = value;
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
}
