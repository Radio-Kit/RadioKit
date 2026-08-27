import 'package:flutter/material.dart';
import 'inspector_property_schema.dart';
import 'designer_element.dart';

class WidgetBuildContext {
  final String id;
  final DesignerElementType type;
  final Map<String, dynamic> properties;
  final dynamic runtimeValue;
  final ValueChanged<dynamic>? onChanged;
  final bool isPlayMode;
  final bool isSelected;
  final double cellSize;
  final int width;
  final int height;
  final String label;
  final bool labelHidden;

  const WidgetBuildContext({
    required this.id,
    required this.type,
    required this.properties,
    required this.runtimeValue,
    required this.onChanged,
    required this.isPlayMode,
    required this.isSelected,
    required this.cellSize,
    required this.width,
    required this.height,
    required this.label,
    required this.labelHidden,
  });
}

class CodegenContext {
  final String varName;
  final String cppType;
  final String? variant;
  final Map<String, dynamic> properties;
  final String label;
  final int pageIndex;

  const CodegenContext({
    required this.varName,
    required this.cppType,
    this.variant,
    required this.properties,
    required this.label,
    required this.pageIndex,
  });
}

abstract class WidgetDefinition {
  String get id;
  DesignerElementType get type;
  String get displayName;
  IconData get icon;
  (int, int) get defaultSize;
  
  double? aspectRatio(Map<String, dynamic> properties, int width, int height) => null;
  Map<String, dynamic> get defaultProperties;
  List<InspectorPropertySchema> get propertiesSchema => const [];

  Widget buildCanvasWidget(BuildContext context, WidgetBuildContext ctx);

  String generateCppCode(CodegenContext ctx) {
    return '';
  }
}
