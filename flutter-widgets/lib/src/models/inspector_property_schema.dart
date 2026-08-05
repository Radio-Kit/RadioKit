enum InspectorPropertyType {
  number,
  boolean,
  option,
  icon,
  text,
  custom,
}

abstract class InspectorPropertySchema {
  final String key;
  final String label;
  final InspectorPropertyType type;

  const InspectorPropertySchema({
    required this.key,
    required this.label,
    required this.type,
  });
}

class NumPropertySchema extends InspectorPropertySchema {
  final double? min;
  final double? max;
  final double step;
  final bool isCompact;

  const NumPropertySchema({
    required super.key,
    required super.label,
    this.min,
    this.max,
    this.step = 1.0,
    this.isCompact = false,
  }) : super(type: InspectorPropertyType.number);
}

class BoolPropertySchema extends InspectorPropertySchema {
  const BoolPropertySchema({
    required super.key,
    required super.label,
  }) : super(type: InspectorPropertyType.boolean);
}

class OptionPropertySchema extends InspectorPropertySchema {
  final List<String> options;
  final Map<String, String>? optionLabels;

  const OptionPropertySchema({
    required super.key,
    required super.label,
    required this.options,
    this.optionLabels,
  }) : super(type: InspectorPropertyType.option);
}

class IconPropertySchema extends InspectorPropertySchema {
  const IconPropertySchema({
    required super.key,
    required super.label,
  }) : super(type: InspectorPropertyType.icon);
}

class TextPropertySchema extends InspectorPropertySchema {
  const TextPropertySchema({
    required super.key,
    required super.label,
  }) : super(type: InspectorPropertyType.text);
}
