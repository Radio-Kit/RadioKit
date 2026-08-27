import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Information for an asset attached to a GitHub Release.
class ReleaseAsset {
  final String name;
  final int size;
  final String downloadUrl;
  final String? contentType;

  const ReleaseAsset({
    required this.name,
    required this.size,
    required this.downloadUrl,
    this.contentType,
  });

  factory ReleaseAsset.fromJson(Map<String, dynamic> json) {
    return ReleaseAsset(
      name: json['name'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      downloadUrl: (json['browser_download_url'] as String?) ?? '',
      contentType: json['content_type'] as String?,
    );
  }

  @override
  String toString() => 'ReleaseAsset(name: $name, size: $size)';
}

/// Metadata and assets for a GitHub firmware release.
class FirmwareRelease {
  final String tagName;
  final String version;
  final String title;
  final DateTime? publishedAt;
  final String changelog;
  final List<ReleaseAsset> assets;
  final bool isPrerelease;

  const FirmwareRelease({
    required this.tagName,
    required this.version,
    required this.title,
    this.publishedAt,
    required this.changelog,
    required this.assets,
    this.isPrerelease = false,
  });

  /// All `.bin` assets attached to this release.
  List<ReleaseAsset> get binAssets =>
      assets.where((a) => a.name.toLowerCase().endsWith('.bin')).toList();

  /// Finds the best matching `.bin` asset for a given device name.
  ReleaseAsset? findBestAsset(String? deviceName) {
    final bins = binAssets;
    if (bins.isEmpty) return null;

    if (deviceName != null && deviceName.trim().isNotEmpty) {
      final cleanName = deviceName.trim().toLowerCase();

      // 1. Exact match without extension (e.g. "MIKRO_V2" -> "mikro_v2.bin")
      for (final asset in bins) {
        final assetBase = asset.name.toLowerCase().replaceAll(RegExp(r'\.bin$'), '');
        if (assetBase == cleanName) {
          return asset;
        }
      }

      // 2. Substring match (e.g. "mikro" in "firmware_mikro_v2.bin")
      for (final asset in bins) {
        if (asset.name.toLowerCase().contains(cleanName)) {
          return asset;
        }
      }
    }

    // 3. Fallback to single or first binary
    return bins.first;
  }

  factory FirmwareRelease.fromJson(Map<String, dynamic> json) {
    final tag = (json['tag_name'] as String?) ?? '';
    final cleanVersion = FirmwareReleaseService.normalizeVersion(tag);
    final rawAssets = json['assets'] as List<dynamic>? ?? [];
    final assets = rawAssets
        .whereType<Map<String, dynamic>>()
        .map((a) => ReleaseAsset.fromJson(a))
        .toList();

    DateTime? published;
    final publishedStr = json['published_at'] as String?;
    if (publishedStr != null) {
      published = DateTime.tryParse(publishedStr);
    }

    return FirmwareRelease(
      tagName: tag,
      version: cleanVersion,
      title: (json['name'] as String?)?.isNotEmpty == true
          ? (json['name'] as String)
          : tag,
      publishedAt: published,
      changelog: (json['body'] as String?) ?? '',
      assets: assets,
      isPrerelease: (json['prerelease'] as bool?) ?? false,
    );
  }

  @override
  String toString() =>
      'FirmwareRelease(tag: $tagName, version: $version, assets: ${assets.length})';
}

/// Service for querying GitHub Releases and downloading firmware binaries.
class FirmwareReleaseService {
  final http.Client _client;

  FirmwareReleaseService({http.Client? client}) : _client = client ?? http.Client();

  /// Parse owner and repo from a GitHub URL (e.g. `https://github.com/owner/repo`).
  static ({String owner, String repo})? parseGithubRepo(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    Uri? uri;
    try {
      uri = Uri.parse(trimmed);
    } catch (_) {
      return null;
    }

    if (uri.host != 'github.com' && uri.host != 'www.github.com') {
      return null;
    }

    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length < 2) return null;

    final owner = segments[0];
    var repo = segments[1];
    if (repo.endsWith('.git')) {
      repo = repo.substring(0, repo.length - 4);
    }

    return (owner: owner, repo: repo);
  }

  /// Normalizes a version tag (e.g. "v1.2.3" -> "1.2.3").
  static String normalizeVersion(String tag) {
    var v = tag.trim();
    if (v.startsWith('v') || v.startsWith('V')) {
      v = v.substring(1).trim();
    }
    return v;
  }

  /// Compares two semver strings (e.g. "1.2.0" and "1.1.5").
  /// Returns > 0 if [v1] > [v2], 0 if [v1] == [v2], < 0 if [v1] < [v2].
  static int compareSemver(String v1, String v2) {
    final clean1 = normalizeVersion(v1);
    final clean2 = normalizeVersion(v2);

    final parts1 = _extractVersionParts(clean1);
    final parts2 = _extractVersionParts(clean2);

    final maxLen = parts1.length > parts2.length ? parts1.length : parts2.length;
    for (int i = 0; i < maxLen; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      if (p1 != p2) {
        return p1.compareTo(p2);
      }
    }
    return 0;
  }

  /// Returns true if [remoteVersion] is strictly newer than [currentVersion].
  static bool isNewerVersion(String remoteVersion, String currentVersion) {
    if (remoteVersion.trim().isEmpty || currentVersion.trim().isEmpty) {
      return false;
    }
    return compareSemver(remoteVersion, currentVersion) > 0;
  }

  static List<int> _extractVersionParts(String version) {
    // Strip pre-release or build metadata (e.g. "1.2.3-rc1" -> "1.2.3")
    final core = version.split(RegExp(r'[-+]')).first.trim();
    final segments = core.split('.');
    return segments.map((s) => int.tryParse(s) ?? 0).toList();
  }

  /// Fetches the latest release from GitHub for the given repo URL.
  /// Returns null if URL is invalid or no release is found.
  Future<FirmwareRelease?> fetchLatestRelease(String repoUrl) async {
    final parsed = parseGithubRepo(repoUrl);
    if (parsed == null) return null;

    final apiUrl = Uri.parse(
        'https://api.github.com/repos/${parsed.owner}/${parsed.repo}/releases/latest');

    final response = await _client.get(apiUrl, headers: {
      'Accept': 'application/vnd.github.v3+json',
      'User-Agent': 'RadioKit-CompanionApp',
    });

    if (response.statusCode == 404) {
      return null;
    }

    if (response.statusCode != 200) {
      throw Exception(
          'Failed to fetch latest release (HTTP ${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return FirmwareRelease.fromJson(data);
  }

  /// Streams the download of a binary asset, reporting received and total bytes.
  Future<Uint8List> downloadAsset(
    String downloadUrl, {
    void Function(int received, int total)? onProgress,
  }) async {
    final request = http.Request('GET', Uri.parse(downloadUrl));
    request.headers['User-Agent'] = 'RadioKit-CompanionApp';
    request.headers['Accept'] = 'application/octet-stream';

    final streamedResponse = await _client.send(request);

    if (streamedResponse.statusCode != 200) {
      throw Exception(
          'Failed to download firmware asset (HTTP ${streamedResponse.statusCode}) from $downloadUrl');
    }

    final total = streamedResponse.contentLength ?? 0;
    final bytesBuilder = BytesBuilder(copy: false);
    int received = 0;

    await for (final chunk in streamedResponse.stream) {
      bytesBuilder.add(chunk);
      received += chunk.length;
      onProgress?.call(received, total);
    }

    return bytesBuilder.toBytes();
  }

  void close() {
    _client.close();
  }
}
