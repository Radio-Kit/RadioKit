import 'designer_element.dart';
import 'widget_definition.dart';
import '../widgets/definitions/register_all.dart';

class WidgetRegistry {
  static final WidgetRegistry _instance = WidgetRegistry._internal();
  static bool _initialized = false;

  factory WidgetRegistry() => instance;
  WidgetRegistry._internal();

  static WidgetRegistry get instance {
    if (!_initialized) {
      _initialized = true;
      registerDefaultWidgets();
    }
    return _instance;
  }

  final Map<String, WidgetDefinition> _definitionsById = {};
  final Map<DesignerElementType, WidgetDefinition> _definitionsByType = {};

  void register(WidgetDefinition definition) {
    _definitionsById[definition.id] = definition;
    _definitionsByType[definition.type] = definition;
  }

  WidgetDefinition? getById(String id) {
    return _definitionsById[id];
  }

  WidgetDefinition? getByType(DesignerElementType type) {
    return _definitionsByType[type];
  }

  List<WidgetDefinition> get allDefinitions => _definitionsById.values.toList();
}
