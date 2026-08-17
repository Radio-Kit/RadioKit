/// Parsed metadata from a bundled starter-template JSON file.
class StarterTemplate {
  /// Asset path (e.g. "starter-templates/Locomotive_Remote.json").
  final String assetPath;

  /// Display name from `config.name`.
  final String name;

  /// Template type from `config.type` (e.g. "Locomotive").
  final String type;

  /// Enabled transports from `config.transports` (e.g. "BLE", "BLE + WiFi").
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

    // Build transport badge from nested transports object
    final transports = json['config']?['transports'] as Map<String, dynamic>?;
    final List<String> enabled = [];
    if (transports != null) {
      if ((transports['ble']?['enabled'] as bool?) ?? false) enabled.add('BLE');
      if ((transports['wifi']?['enabled'] as bool?) ?? false) enabled.add('WiFi');
      if ((transports['cloud']?['enabled'] as bool?) ?? false) enabled.add('Cloud');
    }
    // Fallback to legacy single transport string
    if (enabled.isEmpty) {
      final legacy = (json['config']?['transport'] as String?) ?? '';
      if (legacy.isNotEmpty) enabled.add(legacy.toUpperCase());
    }

    return StarterTemplate(
      assetPath: assetPath,
      name: (json['config']?['name'] as String?) ?? 'Untitled',
      type: (json['config']?['type'] as String?) ?? '',
      transport: enabled.join(' + '),
      canvasSize: canvasSize,
      widgetCount: (json['widgets'] as List?)?.length ??
          ((json['pages'] as List?)?.fold<int>(
                  0,
                  (sum, page) =>
                      sum +
                      ((page is Map ? page['widgets'] as List? : null)?.length ??
                          0)) ??
              0),
      skin: (json['canvas']?['skin'] as String?) ?? 'dragon',
      jsonContent: jsonContent,
    );
  }

  /// Synthetic ID derived from the asset path for use with [DesignsProvider].
  String get id => 'template_${assetPath.replaceAll(RegExp(r'[/\.]'), '_')}';
}
