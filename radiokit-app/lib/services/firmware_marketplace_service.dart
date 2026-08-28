import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'firmware_release_service.dart';

/// Parsed metadata for a firmware binary asset.
class MarketplaceBinaryInfo {
  final String assetName;
  final String downloadUrl;
  final int sizeBytes;
  final String? project;
  final String? version;
  final String? chip;
  final String? board;
  final String? variant;
  final String? boardOrVariant;
  final String? flashType; // 'factory' | 'ota' | null

  const MarketplaceBinaryInfo({
    required this.assetName,
    required this.downloadUrl,
    required this.sizeBytes,
    this.project,
    this.version,
    this.chip,
    this.board,
    this.variant,
    this.boardOrVariant,
    this.flashType,
  });

  bool get isFactory => flashType == 'factory';
  bool get isOta => flashType == 'ota';

  /// User-facing primary title (Board Name, Project Name, or base filename).
  String get displayName {
    if (board != null && board!.trim().isNotEmpty) {
      return board!;
    }
    if (boardOrVariant != null && boardOrVariant!.trim().isNotEmpty) {
      return boardOrVariant!;
    }
    if (project != null && project!.trim().isNotEmpty) {
      return project!;
    }
    if (assetName.toLowerCase().endsWith('.bin')) {
      return assetName.substring(0, assetName.length - 4);
    }
    return assetName;
  }

  /// Normalized chip token (e.g. 'esp32s3', 'esp32c3', 'esp32', etc.)
  static String normalizeChipName(String? rawChip) {
    if (rawChip == null) return '';
    return rawChip
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .trim();
  }

  /// Checks whether this binary matches the connected hardware chip type.
  bool matchesChip(String? connectedChip) {
    if (chip == null || connectedChip == null || connectedChip.trim().isEmpty) {
      return false;
    }
    final bChip = normalizeChipName(chip);
    final cChip = normalizeChipName(connectedChip);
    if (bChip.isEmpty || cChip.isEmpty) return false;

    if (bChip == cChip) return true;

    // Distinguish specific variants (s3, c3, c6, s2, h2) from base esp32
    final specificVariants = ['s3', 'c3', 'c6', 's2', 'h2'];
    for (final v in specificVariants) {
      final bHas = bChip.contains(v);
      final cHas = cChip.contains(v);
      if (bHas || cHas) {
        return bHas && cHas;
      }
    }

    // Both are base esp32
    return bChip == 'esp32' && cChip == 'esp32';
  }

  /// Formatted size string (e.g. "868.8 KB" or "1.2 MB").
  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  String toString() =>
      'MarketplaceBinaryInfo(name: $assetName, chip: $chip, board: $board, variant: $variant, type: $flashType)';
}

/// Release metadata and parsed binary assets for a marketplace repository.
class MarketplaceRelease {
  final String repoUrl;
  final String owner;
  final String repo;
  final String tagName;
  final String version;
  final String title;
  final DateTime? publishedAt;
  final String changelog;
  final List<MarketplaceBinaryInfo> binaries;

  const MarketplaceRelease({
    required this.repoUrl,
    required this.owner,
    required this.repo,
    required this.tagName,
    required this.version,
    required this.title,
    this.publishedAt,
    required this.changelog,
    required this.binaries,
  });

  /// Factory binaries (suitable for USB bootloader flasher).
  List<MarketplaceBinaryInfo> get factoryBinaries =>
      binaries.where((b) => b.isFactory).toList();

  /// OTA binaries (suitable for wireless / live OTA update).
  List<MarketplaceBinaryInfo> get otaBinaries =>
      binaries.where((b) => b.isOta).toList();

  /// Finds the best matching binary for the connected chip and board.
  MarketplaceBinaryInfo? findBestBinary({
    String? connectedChip,
    String? connectedBoard,
    bool preferFactory = true,
  }) {
    if (binaries.isEmpty) return null;

    // 1. Filter by preferred flash type if any matching exists
    var candidates = preferFactory
        ? (factoryBinaries.isNotEmpty ? factoryBinaries : binaries)
        : (otaBinaries.isNotEmpty ? otaBinaries : binaries);

    // 2. Filter by matching chip
    if (connectedChip != null && connectedChip.trim().isNotEmpty) {
      final chipMatches = candidates.where((b) => b.matchesChip(connectedChip)).toList();
      if (chipMatches.isNotEmpty) {
        candidates = chipMatches;
      }
    }

    // 3. Filter by matching board name (e.g. "MIKRO_V2")
    if (connectedBoard != null && connectedBoard.trim().isNotEmpty) {
      final cleanBoard = connectedBoard.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      for (final candidate in candidates) {
        if (candidate.boardOrVariant != null) {
          final cleanCandidate = candidate.boardOrVariant!
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]'), '');
          if (cleanCandidate == cleanBoard || cleanCandidate.contains(cleanBoard)) {
            return candidate;
          }
        }
      }
    }

    // 4. Return top candidate
    return candidates.first;
  }
}

/// Service managing saved repository sources, release discovery, and binary metadata.
class FirmwareMarketplaceService {
  static const String kPrefsKey = 'firmware_marketplace_repos';

  static const List<String> defaultRepos = [
    'https://github.com/DragonRailway/RC_Engine',
    'https://github.com/Radio-Kit/demo-fs-assets',
  ];

  final http.Client _client;
  final Map<String, (DateTime, MarketplaceRelease)> _releaseCache = {};
  static const Duration _cacheTtl = Duration(minutes: 15);

  FirmwareMarketplaceService({http.Client? client})
      : _client = client ?? http.Client();

  /// Retrieves the persisted list of repository URLs.
  Future<List<String>> getSavedRepos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(kPrefsKey);
      if (list != null && list.isNotEmpty) {
        return list;
      }
    } catch (e) {
      debugPrint('FirmwareMarketplaceService: Error reading prefs: $e');
    }
    return List<String>.from(defaultRepos);
  }

  /// Adds a new repository URL and persists it.
  Future<bool> addRepo(String rawUrl) async {
    final parsed = parseRepoUrl(rawUrl);
    if (parsed == null) return false;
    final normalized = 'https://github.com/${parsed.$1}/${parsed.$2}';

    final repos = await getSavedRepos();
    if (!repos.contains(normalized)) {
      repos.add(normalized);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(kPrefsKey, repos);
    }
    return true;
  }

  /// Removes a repository URL from the saved list.
  Future<void> removeRepo(String rawUrl) async {
    final parsed = parseRepoUrl(rawUrl);
    final normalized = parsed != null
        ? 'https://github.com/${parsed.$1}/${parsed.$2}'
        : rawUrl.trim();

    final repos = await getSavedRepos();
    repos.removeWhere((r) => r.toLowerCase() == normalized.toLowerCase());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(kPrefsKey, repos);
    _releaseCache.remove(normalized);
  }

  /// Resets saved repositories back to default community sources.
  Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(kPrefsKey, List<String>.from(defaultRepos));
    _releaseCache.clear();
  }

  /// Extracts `(owner, repo)` from any GitHub repository URL or deep link.
  static (String, String)? parseRepoUrl(String rawUrl) {
    if (rawUrl.trim().isEmpty) return null;
    var clean = rawUrl.trim();

    // Deep link format: radiokit://firmware?url=...
    if (clean.startsWith('radiokit://') || clean.startsWith('radiokit:')) {
      final uri = Uri.tryParse(clean);
      if (uri != null) {
        final queryUrl = uri.queryParameters['url'] ?? uri.queryParameters['repo'];
        if (queryUrl != null && queryUrl.isNotEmpty) {
          clean = queryUrl;
        }
      }
    }

    final isGithub = clean.contains('github.com') ||
        (!clean.contains('://') && clean.split('/').length == 2 && !clean.contains('.'));

    if (!isGithub && clean.contains('://')) {
      return null;
    }

    clean = clean.replaceAll(RegExp(r'^https?:\/\/'), '');
    clean = clean.replaceAll(RegExp(r'^github\.com\/'), '');
    clean = clean.replaceAll(RegExp(r'\/+$'), '');
    clean = clean.replaceAll(RegExp(r'\.git$'), '');
    clean = clean.replaceAll(RegExp(r'\/+$'), '');

    final parts = clean.split('/');
    if (parts.length >= 2) {
      final owner = parts[0].trim();
      final repo = parts[1].trim();
      if (owner.isNotEmpty && repo.isNotEmpty && !owner.contains('.')) {
        return (owner, repo);
      }
    }
    return null;
  }

  /// Parses a binary filename following the pattern:
  /// `<Project>-<Version>-<Chip>[-<BoardOrVariant>][-<Type>].bin`
  /// or `<Project>-<Chip>[-<Board>][-<Type>].bin`
  static MarketplaceBinaryInfo parseBinaryFilename(
    String filename, {
    required String downloadUrl,
    required int sizeBytes,
  }) {
    final clean = filename.trim();
    if (!clean.toLowerCase().endsWith('.bin')) {
      return MarketplaceBinaryInfo(
        assetName: clean,
        downloadUrl: downloadUrl,
        sizeBytes: sizeBytes,
      );
    }

    final nameWithoutExt = clean.substring(0, clean.length - 4);
    final segments = nameWithoutExt.split('-');

    // Known chip identifiers
    final knownChips = {'esp32', 'esp32s3', 'esp32c3', 'esp32c6', 'esp32s2', 'esp32h2'};
    final knownTypes = {'factory', 'ota'};

    String? project;
    String? version;
    String? chip;
    String? flashType;
    final otherSegments = <String>[];

    // Detect type from last segment
    if (segments.length > 1 && knownTypes.contains(segments.last.toLowerCase())) {
      flashType = segments.last.toLowerCase();
    }

    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final segLower = seg.toLowerCase();

      // Check if this segment is a flash type at the end
      if (i == segments.length - 1 && knownTypes.contains(segLower)) {
        continue;
      }

      // Check if this is a version token (e.g. 'v1.0.0' or '1.0.0')
      if (version == null &&
          i == 1 &&
          RegExp(r'^v?[0-9]+\.[0-9]+(?:\.[0-9]+)?$').hasMatch(seg)) {
        version = seg;
        continue;
      }

      // Check if this is a chip identifier
      if (chip == null && knownChips.contains(segLower)) {
        chip = segLower;
        continue;
      }

      if (project == null && i == 0) {
        project = seg;
      } else {
        otherSegments.add(seg);
      }
    }

    // Fallback: search for chip tokens anywhere in filename if not isolated by hyphens
    if (chip == null) {
      final nameLower = clean.toLowerCase();
      if (nameLower.contains('esp32s3') || nameLower.contains('esp32-s3')) {
        chip = 'esp32s3';
      } else if (nameLower.contains('esp32c3') || nameLower.contains('esp32-c3')) {
        chip = 'esp32c3';
      } else if (nameLower.contains('esp32c6') || nameLower.contains('esp32-c6')) {
        chip = 'esp32c6';
      } else if (nameLower.contains('esp32s2') || nameLower.contains('esp32-s2')) {
        chip = 'esp32s2';
      } else if (nameLower.contains('esp32')) {
        chip = 'esp32';
      }
    }

    // Fallback: search for flash type token in filename
    if (flashType == null) {
      final nameLower = clean.toLowerCase();
      if (nameLower.contains('factory')) {
        flashType = 'factory';
      } else if (nameLower.contains('ota')) {
        flashType = 'ota';
      }
    }

    final board = otherSegments.isNotEmpty ? otherSegments[0] : null;
    final variant = otherSegments.length > 1 ? otherSegments.sublist(1).join('-') : null;
    final boardOrVariant = otherSegments.isNotEmpty ? otherSegments.join('-') : null;

    return MarketplaceBinaryInfo(
      assetName: clean,
      downloadUrl: downloadUrl,
      sizeBytes: sizeBytes,
      project: project,
      version: version,
      chip: chip,
      board: board,
      variant: variant,
      boardOrVariant: boardOrVariant,
      flashType: flashType,
    );
  }

  /// Fetches the latest release metadata and parsed binaries for a given repository.
  Future<MarketplaceRelease?> fetchRelease(
    String repoUrl, {
    bool forceRefresh = false,
  }) async {
    final parsed = parseRepoUrl(repoUrl);
    if (parsed == null) return null;
    final (owner, repo) = parsed;
    final normalized = 'https://github.com/$owner/$repo';

    if (!forceRefresh && _releaseCache.containsKey(normalized)) {
      final (timestamp, cached) = _releaseCache[normalized]!;
      if (DateTime.now().difference(timestamp) < _cacheTtl) {
        return cached;
      }
    }

    final apiUrl = 'https://api.github.com/repos/$owner/$repo/releases/latest';
    try {
      final response = await _client.get(
        Uri.parse(apiUrl),
        headers: {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'RadioKit-Companion-App',
        },
      );

      if (response.statusCode == 200) {
        final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
        final tag = (jsonMap['tag_name'] as String?) ?? '';
        final title = (jsonMap['name'] as String?) ?? tag;
        final changelog = (jsonMap['body'] as String?) ?? '';
        final version = FirmwareReleaseService.normalizeVersion(tag);

        DateTime? publishedAt;
        if (jsonMap['published_at'] != null) {
          publishedAt = DateTime.tryParse(jsonMap['published_at'] as String);
        }

        final rawAssets = jsonMap['assets'] as List<dynamic>? ?? [];
        final binaries = <MarketplaceBinaryInfo>[];

        for (final item in rawAssets) {
          if (item is Map<String, dynamic>) {
            final assetName = item['name'] as String? ?? '';
            final downloadUrl = item['browser_download_url'] as String? ?? '';
            final size = (item['size'] as num?)?.toInt() ?? 0;

            if (assetName.toLowerCase().endsWith('.bin')) {
              binaries.add(parseBinaryFilename(
                assetName,
                downloadUrl: downloadUrl,
                sizeBytes: size,
              ));
            }
          }
        }

        final release = MarketplaceRelease(
          repoUrl: normalized,
          owner: owner,
          repo: repo,
          tagName: tag,
          version: version,
          title: title,
          publishedAt: publishedAt,
          changelog: changelog,
          binaries: binaries,
        );

        _releaseCache[normalized] = (DateTime.now(), release);
        return release;
      }
    } catch (e) {
      debugPrint('FirmwareMarketplaceService: Error fetching release for $repoUrl: $e');
    }
    return null;
  }
}
