import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../theme/rk_tokens.dart';
import 'designer_element.dart';
import 'designer_page.dart';

enum GridStyle { lines, dots, none }

class DesignerState extends ChangeNotifier {
  // ── Multi-page state ────────────────────────────────────────────────────
  List<DesignerPage> _pages = [DesignerPage(name: 'Page 1')];
  int _activePageIndex = 0;

  String? _selectedElementId;
  bool _isPlayMode = false;
  bool _isInspectorVisible = true;
  GridStyle _gridStyle = GridStyle.none;
  String _activeSkin = 'dragon';
  bool _bleEnabled = true;
  bool _wifiEnabled = false;
  bool _cloudEnabled = false;
  String _wifiSsid = '';
  String _wifiPass = '';
  String _cloudAccount = '';
  String _cloudRelay = '';
  String _modelName = '';
  String _modelType = 'Locomotive';
  String _modelDescription = '';
  String _connectionPassword = '';
  Map<String, dynamic> _features = {'ota': false, 'filesystem': false};
  bool _enableControlUI = true;
  bool _showPageBar = true;
  List<Map<String, dynamic>> _telemetryWidgets = List.generate(4, (_) => <String, dynamic>{'label': '', 'icon': null, 'unit': ''});

  // appdata (metadata from the JSON block, not user-configurable)
  int? _lastEdit;
  String? _appVersion;

  String? _originalHeaderContent;
  String? _originalHeaderPath;

  final Map<String, dynamic> _runtimeWidgetValues = {};
  void Function(String id, dynamic value)? onRuntimeValueChanged;

  /// Monotonically-increasing counter bumped on every real data mutation.
  int _mutationCount = 0;
  int get mutationCount => _mutationCount;

  // ── Per-page undo/redo stacks ──────────────────────────────────────────
  final Map<int, List<List<DesignerElement>>> _undoStacks = {};
  final Map<int, List<List<DesignerElement>>> _redoStacks = {};
  static const int _maxUndoStack = 50;

  /// Snapshot saved at gesture start (resize/rotate).
  List<DesignerElement>? _gestureSnapshot;

  // ── Public getters ──────────────────────────────────────────────────────
  List<DesignerPage> get pages => _pages;
  int get activePageIndex => _activePageIndex;
  int get numPages => _pages.length;

  DesignerPage get activePage => _pages[_activePageIndex];

  /// Elements of the active page (backward-compatible getter).
  List<DesignerElement> get elements => activePage.elements;

  String? get selectedElementId => _selectedElementId;
  bool get isLandscape => activePage.isLandscape;
  bool get isPlayMode => _isPlayMode;
  bool get isInspectorVisible => _isInspectorVisible;
  GridStyle get gridStyle => _gridStyle;
  String get activeSkin => _activeSkin;
  bool get bleEnabled => _bleEnabled;
  bool get wifiEnabled => _wifiEnabled;
  bool get cloudEnabled => _cloudEnabled;
  String get wifiSsid => _wifiSsid;
  String get wifiPass => _wifiPass;
  String get cloudAccount => _cloudAccount;
  String get cloudRelay => _cloudRelay;
  String get modelName => _modelName;
  String get modelType => _modelType;
  String get modelDescription => _modelDescription;
  String get connectionPassword => _connectionPassword;
  int? get lastEdit => _lastEdit;
  String? get appVersion => _appVersion;
  bool get canUndo => (_undoStacks[_activePageIndex]?.isNotEmpty) ?? false;
  bool get canRedo => (_redoStacks[_activePageIndex]?.isNotEmpty) ?? false;

  bool get featureOta => (_features['ota'] as bool?) ?? false;
  bool get featureFilesystem => (_features['filesystem'] as bool?) ?? false;
  bool get enableControlUI => _enableControlUI;
  bool get showPageBar => _showPageBar;
  List<Map<String, dynamic>> get telemetryWidgets => _telemetryWidgets;

  DesignerElement? get selectedElement {
    if (_selectedElementId == null) return null;
    try {
      return elements.firstWhere((e) => e.id == _selectedElementId);
    } catch (_) {
      return null;
    }
  }

  int get canvasWidth => activePage.canvasWidth;
  int get canvasHeight => activePage.canvasHeight;
  bool get isLandscapeGlobal => canvasWidth >= canvasHeight;

  // ── Private helpers ─────────────────────────────────────────────────────
  List<List<DesignerElement>> _getUndoStack(int pageIndex) =>
      _undoStacks.putIfAbsent(pageIndex, () => []);
  List<List<DesignerElement>> _getRedoStack(int pageIndex) =>
      _redoStacks.putIfAbsent(pageIndex, () => []);

  void _pushUndo() {
    if (_gestureSnapshot != null) return;
    _mutationCount++;
    final stack = _getUndoStack(_activePageIndex);
    stack.add(elements.map((e) => e.copyWith()).toList());
    if (stack.length > _maxUndoStack) stack.removeAt(0);
    _getRedoStack(_activePageIndex).clear();
  }

  void beginGesture() {
    assert(_gestureSnapshot == null, 'beginGesture without matching commitGesture');
    _gestureSnapshot = elements.map((e) => e.copyWith()).toList();
  }

  void commitGesture() {
    if (_gestureSnapshot == null) return;
    _mutationCount++;
    final stack = _getUndoStack(_activePageIndex);
    stack.add(_gestureSnapshot!);
    if (stack.length > _maxUndoStack) stack.removeAt(0);
    _getRedoStack(_activePageIndex).clear();
    _gestureSnapshot = null;
  }

  void cancelGesture() {
    if (_gestureSnapshot == null) return;
    activePage.elements = _gestureSnapshot!;
    _gestureSnapshot = null;
    notifyListeners();
  }

  // ── Page management ─────────────────────────────────────────────────────

  void setActivePage(int index) {
    if (index < 0 || index >= _pages.length) return;
    _activePageIndex = index;
    _selectedElementId = null;
    notifyListeners();
  }

  void addPage({String? name, bool? isLandscape}) {
    _mutationCount++;
    final newPage = DesignerPage(
      name: name ?? 'Page ${_pages.length + 1}',
      isLandscape: isLandscape ?? true,
    );
    _pages.add(newPage);
    _activePageIndex = _pages.length - 1;
    _selectedElementId = null;
    notifyListeners();
  }

  void removePage(int index) {
    if (_pages.length <= 1) return;
    _mutationCount++;
    _pages.removeAt(index);
    // Clean up undo/redo stacks for removed page
    _undoStacks.remove(index);
    _redoStacks.remove(index);
    // Adjust active index
    if (_activePageIndex >= _pages.length) {
      _activePageIndex = _pages.length - 1;
    }
    _selectedElementId = null;
    notifyListeners();
  }

  void renamePage(int index, String name) {
    if (index < 0 || index >= _pages.length) return;
    _mutationCount++;
    _pages[index].name = name;
    notifyListeners();
  }

  void reorderPage(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    if (newIndex > oldIndex) newIndex -= 1;
    _mutationCount++;
    final page = _pages.removeAt(oldIndex);
    _pages.insert(newIndex, page);
    // Remap undo/redo stacks to follow their pages
    final oldUndo = _undoStacks.remove(oldIndex);
    final oldRedo = _redoStacks.remove(oldIndex);
    // Shift stacks between oldIndex and newIndex
    if (oldIndex < newIndex) {
      for (int i = oldIndex; i < newIndex; i++) {
        final nextUndo = _undoStacks.remove(i + 1);
        final nextRedo = _redoStacks.remove(i + 1);
        if (nextUndo != null) _undoStacks[i] = nextUndo;
        if (nextRedo != null) _redoStacks[i] = nextRedo;
      }
    } else {
      for (int i = oldIndex; i > newIndex; i--) {
        final prevUndo = _undoStacks.remove(i - 1);
        final prevRedo = _redoStacks.remove(i - 1);
        if (prevUndo != null) _undoStacks[i] = prevUndo;
        if (prevRedo != null) _redoStacks[i] = prevRedo;
      }
    }
    if (oldUndo != null) _undoStacks[newIndex] = oldUndo;
    if (oldRedo != null) _redoStacks[newIndex] = oldRedo;
    // Update active index to follow the active page
    if (_activePageIndex == oldIndex) {
      _activePageIndex = newIndex;
    } else if (oldIndex < _activePageIndex && newIndex >= _activePageIndex) {
      _activePageIndex--;
    } else if (oldIndex > _activePageIndex && newIndex <= _activePageIndex) {
      _activePageIndex++;
    }
    notifyListeners();
  }

  void duplicatePage(int index) {
    if (index < 0 || index >= _pages.length) return;
    _mutationCount++;
    final original = _pages[index];
    final copy = original.copyWith(
      name: '${original.name} (Copy)',
      elements: original.elements.map((e) {
        final newElement = e.copyWith(
          id: UniqueKey().toString(),
          label: _generateUniqueLabelAcrossAllPages(e.label),
        );
        return newElement;
      }).toList(),
    );
    _pages.insert(index + 1, copy);
    _activePageIndex = index + 1;
    _selectedElementId = null;
    notifyListeners();
  }

  void toggleOrientation() {
    final page = activePage;
    final oldCw = page.isLandscape ? 200 : 100;
    final oldCh = page.isLandscape ? 100 : 200;
    final newCw = page.isLandscape ? 100 : 200;
    final newCh = page.isLandscape ? 200 : 100;

    final ratioX = newCw / oldCw;
    final ratioY = newCh / oldCh;

    _pushUndo();
    page.elements = page.elements.map((e) {
      final halfW = e.width ~/ 2;
      final halfH = e.height ~/ 2;
      return e.copyWith(
        x: (e.x * ratioX).round().clamp(halfW, newCw - halfW),
        y: (e.y * ratioY).round().clamp(halfH, newCh - halfH),
      );
    }).toList();

    page.isLandscape = !page.isLandscape;
    notifyListeners();
  }

  // ── Element operations (operate on active page) ─────────────────────────

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
    activePage.elements = [...activePage.elements, element];
    _selectedElementId = element.id;
    notifyListeners();
  }

  void removeSelected() {
    if (_selectedElementId == null) return;
    _pushUndo();
    activePage.elements = activePage.elements.where((e) => e.id != _selectedElementId).toList();
    _selectedElementId = null;
    notifyListeners();
  }

  void selectElement(String? id) {
    _selectedElementId = id;
    notifyListeners();
  }

  void updateElementPosition(String id, int x, int y) {
    final index = elements.indexWhere((e) => e.id == id);
    if (index == -1) return;
    _pushUndo();
    final el = elements[index];
    final halfW = el.width ~/ 2;
    final halfH = el.height ~/ 2;
    activePage.elements = [
      for (int i = 0; i < elements.length; i++)
        if (i == index) elements[i].copyWith(
          x: x.clamp(halfW, canvasWidth - halfW),
          y: y.clamp(halfH, canvasHeight - halfH),
        )
        else elements[i],
    ];
    notifyListeners();
  }

  void updateElementProperty(String id, String key, dynamic value) {
    final index = elements.indexWhere((e) => e.id == id);
    if (index == -1) return;
    _pushUndo();
    final el = elements[index];
    final newProps = Map<String, dynamic>.from(el.properties);
    newProps[key] = value;
    activePage.elements = [
      for (int i = 0; i < elements.length; i++)
        if (i == index) el.copyWith(properties: newProps)
        else elements[i],
    ];
    notifyListeners();
  }

  void updateElementSize(String id, {int? width, int? height}) {
    final index = elements.indexWhere((e) => e.id == id);
    if (index == -1) return;
    _pushUndo();
    final el = elements[index];
    final (minW, minH) = DesignerElement.minSize(el.type,
        currentWidth: el.width, currentHeight: el.height);
    activePage.elements = [
      for (int i = 0; i < elements.length; i++)
        if (i == index) elements[i].copyWith(
          width: (width ?? el.width).clamp(minW, canvasWidth),
          height: (height ?? el.height).clamp(minH, canvasHeight),
        )
        else elements[i],
    ];
    notifyListeners();
  }

  void updateElementLabel(String id, String label) {
    final index = elements.indexWhere((e) => e.id == id);
    if (index == -1) return;
    _pushUndo();
    final uniqueLabel = _ensureUniqueLabel(label, excludeElementId: id);
    activePage.elements = [
      for (int i = 0; i < elements.length; i++)
        if (i == index) elements[i].copyWith(label: uniqueLabel)
        else elements[i],
    ];
    notifyListeners();
  }

  void toggleElementLabelHidden(String id) {
    final index = elements.indexWhere((e) => e.id == id);
    if (index == -1) return;
    _pushUndo();
    activePage.elements = [
      for (int i = 0; i < elements.length; i++)
        if (i == index) elements[i].copyWith(labelHidden: !elements[i].labelHidden)
        else elements[i],
    ];
    notifyListeners();
  }

  void toggleElementHidden(String id) {
    final index = elements.indexWhere((e) => e.id == id);
    if (index == -1) return;
    _pushUndo();
    activePage.elements = [
      for (int i = 0; i < elements.length; i++)
        if (i == index) elements[i].copyWith(hidden: !elements[i].hidden)
        else elements[i],
    ];
    notifyListeners();
  }

  void updateElementRotation(String id, int rotation) {
    final index = elements.indexWhere((e) => e.id == id);
    if (index == -1) return;
    _pushUndo();
    var r = rotation % 360;
    if (r > 180) r -= 360;
    activePage.elements = [
      for (int i = 0; i < elements.length; i++)
        if (i == index) elements[i].copyWith(rotation: r)
        else elements[i],
    ];
    notifyListeners();
  }

  void resetSelectedTransform() {
    if (_selectedElementId == null) return;
    final index = elements.indexWhere((e) => e.id == _selectedElementId);
    if (index == -1) return;
    final el = elements[index];
    final (defaultW, defaultH) = DesignerElement.defaultSize(el.type);
    _pushUndo();
    activePage.elements = [
      for (int i = 0; i < elements.length; i++)
        if (i == index)
          el.copyWith(
            width: defaultW,
            height: defaultH,
            rotation: 0,
          )
        else
          elements[i],
    ];
    notifyListeners();
  }

  // ── Cross-page operations ───────────────────────────────────────────────

  /// Copies an element to the clipboard (stored internally).
  DesignerElement? _clipboard;

  void copyElement(String id) {
    final pageElements = elements;
    final index = pageElements.indexWhere((e) => e.id == id);
    if (index == -1) return;
    _clipboard = pageElements[index].copyWith();
  }

  void pasteElement({int? targetPageIndex}) {
    if (_clipboard == null) return;
    final targetIndex = targetPageIndex ?? _activePageIndex;
    final savedIndex = _activePageIndex;
    if (targetIndex != _activePageIndex) {
      _activePageIndex = targetIndex;
    }
    _pushUndo();
    final newElement = _clipboard!.copyWith(
      id: UniqueKey().toString(),
      label: _generateUniqueLabelAcrossAllPages(_clipboard!.label),
    );
    activePage.elements = [...activePage.elements, newElement];
    _selectedElementId = newElement.id;
    if (targetIndex != savedIndex) {
      _activePageIndex = savedIndex;
    }
    notifyListeners();
  }

  // ── Skin / grid ─────────────────────────────────────────────────────────

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

  // ── Runtime values ──────────────────────────────────────────────────────

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

  // ── Config setters ──────────────────────────────────────────────────────

  void setBleEnabled(bool v) {
    _mutationCount++;
    _bleEnabled = v;
    notifyListeners();
  }

  void setWifiEnabled(bool v) {
    _mutationCount++;
    _wifiEnabled = v;
    if (!v) _cloudEnabled = false;
    notifyListeners();
  }

  void setCloudEnabled(bool v) {
    _mutationCount++;
    _cloudEnabled = v;
    notifyListeners();
  }

  void setWifiSsid(String v) {
    _mutationCount++;
    _wifiSsid = v;
    notifyListeners();
  }

  void setWifiPass(String v) {
    _mutationCount++;
    _wifiPass = v;
    notifyListeners();
  }

  void setCloudAccount(String v) {
    _mutationCount++;
    _cloudAccount = v;
    notifyListeners();
  }

  void setCloudRelay(String v) {
    _mutationCount++;
    _cloudRelay = v;
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

  void togglePageBar() {
    _mutationCount++;
    _showPageBar = !_showPageBar;
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
      activePage.isLandscape = w >= h;
    } else if (value is String) {
      final parts = value.split(' x ');
      final w = int.tryParse(parts[0]) ?? 200;
      final h = int.tryParse(parts[1]) ?? 100;
      activePage.isLandscape = w >= h;
    }
    notifyListeners();
  }

  // ── Undo / redo ─────────────────────────────────────────────────────────

  void undo() {
    final stack = _getUndoStack(_activePageIndex);
    if (stack.isEmpty) return;
    _mutationCount++;
    _getRedoStack(_activePageIndex).add(elements.map((e) => e.copyWith()).toList());
    activePage.elements = stack.removeLast();
    _selectedElementId = null;
    notifyListeners();
  }

  void redo() {
    final stack = _getRedoStack(_activePageIndex);
    if (stack.isEmpty) return;
    _mutationCount++;
    _getUndoStack(_activePageIndex).add(elements.map((e) => e.copyWith()).toList());
    activePage.elements = stack.removeLast();
    _selectedElementId = null;
    notifyListeners();
  }

  void clearAll() {
    if (elements.isEmpty) return;
    _pushUndo();
    activePage.elements = [];
    _selectedElementId = null;
    _runtimeWidgetValues.clear();
    notifyListeners();
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  .h-file persistence
  // ──────────────────────────────────────────────────────────────────────────

  static const _configStart = '/*__RadioKit_UI_Designer_Config__';
  static const _configEnd = 'RadioKit_UI_Designer_Config__*/';

  static final RegExp configPattern = RegExp(
    RegExp.escape(_configStart) + r'(.*?)' + RegExp.escape(_configEnd),
    dotAll: true,
  );

  Future<void> loadFromHeaderFile(String filePath) async {
    if (kIsWeb || !(Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
      throw UnsupportedError('Header-file I/O requires a desktop platform');
    }
    final content = await File(filePath).readAsString();
    loadFromHeaderContent(content, path: filePath);
  }

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

  /// Load designer state from a JSON map.
  ///
  /// Supports both v1 (flat `widgets[]`) and v2 (`pages[]`) formats.
  void loadFromJson(Map<String, dynamic> decoded) {
    _pages.clear();
    _undoStacks.clear();
    _redoStacks.clear();

    final version = decoded['version'] as int? ?? 1;

    if (version >= 2 && decoded.containsKey('pages')) {
      // ── v2 format: pages[] ──────────────────────────────────────────
      for (final pageJson in (decoded['pages'] as List? ?? [])) {
        _pages.add(DesignerPage.fromJson(pageJson as Map<String, dynamic>));
      }
      // Read per-page orientation from page data (already in DesignerPage)
    } else {
      // ── v1 format: flat widgets[] (backward compat for loading) ─────
      final page = DesignerPage(name: 'Page 1');
      for (final wJson in (decoded['widgets'] as List? ?? [])) {
        page.elements.add(DesignerElement.fromJson(wJson as Map<String, dynamic>));
      }
      // Read orientation from canvas.size
      final rawSize = decoded['canvas']?['size'] ?? decoded['canvas']?['screenSize'];
      if (rawSize is List && rawSize.length >= 2) {
        final w = (rawSize[0] as num?)?.toInt() ?? 200;
        final h = (rawSize[1] as num?)?.toInt() ?? 100;
        page.isLandscape = w >= h;
      }
      _pages.add(page);
    }

    if (_pages.isEmpty) {
      _pages.add(DesignerPage(name: 'Page 1'));
    }
    _activePageIndex = 0;

    // restore model config
    _modelName = (decoded['config']?['name'] as String?) ?? '';
    _modelDescription = (decoded['config']?['description'] as String?) ?? '';
    _modelType = (decoded['config']?['type'] as String?) ?? 'Locomotive';
    final transports = decoded['config']?['transports'] as Map<String, dynamic>?;
    if (transports != null) {
      _bleEnabled = (transports['ble']?['enabled'] as bool?) ?? true;
      _wifiEnabled = (transports['wifi']?['enabled'] as bool?) ?? false;
      _cloudEnabled = (transports['cloud']?['enabled'] as bool?) ?? false;
      _wifiSsid = (transports['wifi']?['ssid'] as String?) ?? '';
      _wifiPass = (transports['wifi']?['pass'] as String?) ?? '';
      _cloudAccount = (transports['cloud']?['account'] as String?) ?? '';
      _cloudRelay = (transports['cloud']?['relay'] as String?) ?? '';
    } else {
      _bleEnabled = true;
      _wifiEnabled = false;
      _cloudEnabled = false;
      _wifiSsid = '';
      _wifiPass = '';
      _cloudAccount = '';
      _cloudRelay = '';
    }
    _activeSkin = _normaliseSkin((decoded['config']?['theme'] as String?) ?? 'dragon');
    _connectionPassword = (decoded['config']?['password'] as String?) ?? '';

    // read grid style
    final gridStr = decoded['canvas']?['grid'] as String?;
    if (gridStr != null) {
      _gridStyle = switch (gridStr) {
        'lines' => GridStyle.lines,
        'dots' => GridStyle.dots,
        _ => GridStyle.none,
      };
    }

    // read skin from canvas
    final canvasSkin = decoded['canvas']?['skin'] as String?;
    if (canvasSkin != null) {
      _activeSkin = canvasSkin;
    }

    // read showPageBar from canvas
    _showPageBar = (decoded['canvas']?['showPageBar'] as bool?) ?? true;

    // appdata
    final appData = decoded['appdata'];
    if (appData is Map) {
      _lastEdit = appData['lastEdit'] as int?;
      _appVersion = appData['appVersion'] as String?;
    }

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

  Future<void> saveToHeaderFile(String filePath) async {
    if (kIsWeb || !(Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
      throw UnsupportedError('Header-file I/O requires a desktop platform');
    }
    _lastEdit = DateTime.now().millisecondsSinceEpoch;
    final content = await File(filePath).readAsString();
    final result = generateHeaderContent(content);
    await File(filePath).writeAsString(result);
  }

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

  // ── Label generation helpers ────────────────────────────────────────────

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

  /// Generates an auto-label unique across ALL pages.
  String _generateAutoLabel(DesignerElementType type) {
    final base = _baseLabelForType(type);
    final existingLabels = _allLabels();
    int counter = 1;
    while (existingLabels.contains('${base}_$counter')) {
      counter++;
    }
    return '${base}_$counter';
  }

  /// Generates a label unique across ALL pages.
  String _generateUniqueLabelAcrossAllPages(String base) {
    final existingLabels = _allLabels();
    if (!existingLabels.contains(base)) return base;
    int counter = 1;
    while (existingLabels.contains('${base}_$counter')) {
      counter++;
    }
    return '${base}_$counter';
  }

  /// Returns all labels across all pages.
  Set<String> _allLabels() {
    final labels = <String>{};
    for (final page in _pages) {
      for (final el in page.elements) {
        labels.add(el.label);
      }
    }
    return labels;
  }

  String _ensureUniqueLabel(String label, {String? excludeElementId}) {
    final existingLabels = <String>{};
    for (final page in _pages) {
      for (final el in page.elements) {
        if (el.id != excludeElementId) {
          existingLabels.add(el.label);
        }
      }
    }
    if (!existingLabels.contains(label)) return label;
    int counter = 1;
    while (existingLabels.contains('${label}_$counter')) {
      counter++;
    }
    return '${label}_$counter';
  }

  String _normaliseSkin(String name) {
    if (name == 'default') return 'default';
    if (RKTokens.presetsByName.containsKey(name)) return name;
    return 'dragon';
  }

  // ── Serialization ───────────────────────────────────────────────────────

  /// Serialize to v2 JSON format with pages[].
  Map<String, dynamic> toJson() => {
    'version': 2,
    'appdata': {
      if (_appVersion != null) 'appVersion': _appVersion,
      if (_lastEdit != null) 'lastEdit': _lastEdit,
    },
    'config': {
      'name': _modelName,
      'description': _modelDescription,
      'type': _modelType,
      'transports': {
        'ble': {'enabled': _bleEnabled},
        'wifi': {
          'enabled': _wifiEnabled,
          'ssid': _wifiSsid,
          'pass': _wifiPass,
        },
        'cloud': {
          'enabled': _cloudEnabled,
          'account': _cloudAccount,
          'relay': _cloudRelay,
        },
      },
      'theme': _normaliseSkin(_activeSkin),
      'password': _connectionPassword,
    },
    'canvas': {
      'grid': _gridStyle.name,
      'skin': _activeSkin,
      'showPageBar': _showPageBar,
    },
    'enableControlUI': _enableControlUI,
    'telemetry': List<Map<String, dynamic>>.from(_telemetryWidgets),
    'features': Map<String, dynamic>.from(_features),
    'pages': _pages.map((p) => p.toJson()).toList(),
  };
}
