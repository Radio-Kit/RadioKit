/// Parsed metadata from a bundled starter-template JSON file.
class StarterTemplate {
  /// Asset path (e.g. "starter-templates/Locomotive_Remote.json").
  final String assetPath;

  /// Display name from `config.name`.
  final String name;

  /// Template type from `config.type` (e.g. "Locomotive").
  final String type;

  /// Transport badge from `config.transport` (e.g. "BLE", "WiFi").
  final String transport;

  /// Canvas dimensions [width, height].
  final List<int> canvasSize;

  /// Number of widgets in the template.
  final int widgetCount;

  /// Skin name from `canvas.skin` (e.g. "dragon").
  final String skin;

  /// The full raw JSON string for loading into the designer.
  final String jsonContent;

  const StarterTemplate({
    required this.assetPath,
    required this.name,
    required this.type,
    required this.transport,
    required this.canvasSize,
    required this.widgetCount,
    required this.skin,
    required this.jsonContent,
  });

  /// Parse a [StarterTemplate] from decoded JSON and its asset path.
  factory StarterTemplate.fromParsed({
    required String assetPath,
    required Map<String, dynamic> json,
    required String jsonContent,
  }) {
    final canvasSizeRaw = json['canvas']?['size'];
    final canvasSize = canvasSizeRaw is List && canvasSizeRaw.length >= 2
        ? [(canvasSizeRaw[0] as num).toInt(), (canvasSizeRaw[1] as num).toInt()]
        : [200, 100];

    return StarterTemplate(
      assetPath: assetPath,
      name: (json['config']?['name'] as String?) ?? 'Untitled',
      type: (json['config']?['type'] as String?) ?? '',
      transport: (json['config']?['transport'] as String?) ?? '',
      canvasSize: canvasSize,
      widgetCount: (json['widgets'] as List?)?.length ?? 0,
      skin: (json['canvas']?['skin'] as String?) ?? 'dragon',
      jsonContent: jsonContent,
    );
  }

  /// Synthetic ID derived from the asset path for use with [DesignsProvider].
  String get id => 'template_${assetPath.replaceAll(RegExp(r'[/\.]'), '_')}';
}
