import 'designer_element.dart';

/// Represents a single page in a multi-page designer config.
///
/// Each page owns its own set of [DesignerElement]s and has an independent
/// orientation (landscape/portrait) that controls canvas dimensions.
class DesignerPage {
  String name;
  bool isLandscape;
  String? orientationOverride; // null | 'global' | 'landscape' | 'portrait'
  List<DesignerElement> elements;

  DesignerPage({
    required this.name,
    this.isLandscape = true,
    this.orientationOverride,
    List<DesignerElement>? elements,
  }) : elements = elements ?? [];

  /// Returns the effective landscape flag based on the override and global setting.
  bool effectiveIsLandscape(bool globalIsLandscape) {
    switch (orientationOverride) {
      case 'landscape':
        return true;
      case 'portrait':
        return false;
      case 'global':
      default:
        return globalIsLandscape;
    }
  }

  /// Deep copy of this page with all elements duplicated.
  DesignerPage copyWith({String? name, bool? isLandscape, String? orientationOverride, List<DesignerElement>? elements}) {
    return DesignerPage(
      name: name ?? this.name,
      isLandscape: isLandscape ?? this.isLandscape,
      orientationOverride: orientationOverride ?? this.orientationOverride,
      elements: elements ?? this.elements.map((e) => e.copyWith()).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'orientation': orientationOverride ?? 'global',
    'widgets': elements.map((e) => e.toJson()).toList(),
  };

  factory DesignerPage.fromJson(Map<String, dynamic> json) {
    final orientation = json['orientation'] as String? ?? 'global';
    final rawWidgets = json['widgets'] as List? ?? [];
    // Determine override and base isLandscape
    String? override;
    bool baseLandscape;
    switch (orientation) {
      case 'global':
        override = 'global';
        baseLandscape = true; // will be resolved against global later
        break;
      case 'landscape':
        override = 'landscape';
        baseLandscape = true;
        break;
      case 'portrait':
        override = 'portrait';
        baseLandscape = false;
        break;
      default:
        // Legacy: "landscape"/"portrait" without override semantics
        override = null;
        baseLandscape = orientation != 'portrait';
        break;
    }
    return DesignerPage(
      name: json['name'] as String? ?? 'Page',
      isLandscape: baseLandscape,
      orientationOverride: override,
      elements: rawWidgets
          .map((e) => DesignerElement.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
