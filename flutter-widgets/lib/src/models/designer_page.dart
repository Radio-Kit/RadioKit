import 'designer_element.dart';

/// Represents a single page in a multi-page designer config.
///
/// Each page owns its own set of [DesignerElement]s and has an independent
/// orientation (landscape/portrait) that controls canvas dimensions.
class DesignerPage {
  String name;
  bool isLandscape;
  List<DesignerElement> elements;

  DesignerPage({
    required this.name,
    this.isLandscape = true,
    List<DesignerElement>? elements,
  }) : elements = elements ?? [];

  int get canvasWidth => isLandscape ? 200 : 100;
  int get canvasHeight => isLandscape ? 100 : 200;

  /// Deep copy of this page with all elements duplicated.
  DesignerPage copyWith({String? name, bool? isLandscape, List<DesignerElement>? elements}) {
    return DesignerPage(
      name: name ?? this.name,
      isLandscape: isLandscape ?? this.isLandscape,
      elements: elements ?? this.elements.map((e) => e.copyWith()).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'orientation': isLandscape ? 'landscape' : 'portrait',
    'widgets': elements.map((e) => e.toJson()).toList(),
  };

  factory DesignerPage.fromJson(Map<String, dynamic> json) {
    final orientation = json['orientation'] as String? ?? 'landscape';
    final rawWidgets = json['widgets'] as List? ?? [];
    return DesignerPage(
      name: json['name'] as String? ?? 'Page',
      isLandscape: orientation != 'portrait',
      elements: rawWidgets
          .map((e) => DesignerElement.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
