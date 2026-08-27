import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Information extracted from a parsed GitHub repository URL.
class RepoUrlInfo {
  final String owner;
  final String repo;
  final String ref;
  final String subfolder;

  const RepoUrlInfo({
    required this.owner,
    required this.repo,
    this.ref = 'HEAD',
    this.subfolder = '',
  });

  /// Base URL for raw content download on raw.githubusercontent.com.
  String get rawBase => 'https://raw.githubusercontent.com/$owner/$repo/$ref';

  /// Resolves the raw download URL for a file given its repo path.
  String rawFileUrl(String repoPath) {
    final cleanPath = repoPath.startsWith('/') ? repoPath.substring(1) : repoPath;
    return '$rawBase/$cleanPath';
  }

  @override
  String toString() =>
      'RepoUrlInfo(owner: $owner, repo: $repo, ref: $ref, subfolder: $subfolder)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RepoUrlInfo &&
          runtimeType == other.runtimeType &&
          owner == other.owner &&
          repo == other.repo &&
          ref == other.ref &&
          subfolder == other.subfolder;

  @override
  int get hashCode =>
      owner.hashCode ^ repo.hashCode ^ ref.hashCode ^ subfolder.hashCode;
}

/// Represents a file or folder inside a remote repository.
class RepoFileEntry {
  final String path;
  final String relativePath;
  final String name;
  final bool isDirectory;
  final int size;
  final String downloadUrl;

  const RepoFileEntry({
    required this.path,
    required this.relativePath,
    required this.name,
    required this.isDirectory,
    required this.size,
    required this.downloadUrl,
  });

  @override
  String toString() =>
      'RepoFileEntry(name: $name, isDir: $isDirectory, size: $size, rel: $relativePath)';
}

/// Service for parsing GitHub URLs, fetching directory trees, and downloading files.
class RepoTreeService {
  final http.Client _client;

  RepoTreeService({http.Client? client}) : _client = client ?? http.Client();

  /// Parse a GitHub URL (e.g. `https://github.com/owner/repo` or
  /// `https://github.com/owner/repo/tree/main/subfolder`).
  static RepoUrlInfo? parseGithubUrl(String input) {
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

    if (segments.length == 2) {
      return RepoUrlInfo(owner: owner, repo: repo, ref: 'HEAD', subfolder: '');
    }

    // Check for /tree/{ref}/{path...} or /blob/{ref}/{path...}
    final mode = segments[2];
    if (mode == 'tree' || mode == 'blob') {
      if (segments.length == 3) {
        return RepoUrlInfo(owner: owner, repo: repo, ref: 'HEAD', subfolder: '');
      }
      final ref = segments[3];
      final subfolder = segments.skip(4).join('/');
      return RepoUrlInfo(owner: owner, repo: repo, ref: ref, subfolder: subfolder);
    }

    return RepoUrlInfo(owner: owner, repo: repo, ref: 'HEAD', subfolder: '');
  }

  /// Fetches the file tree for the repository and subfolder.
  Future<List<RepoFileEntry>> fetchTree(RepoUrlInfo info) async {
    final apiUrl = Uri.parse(
        'https://api.github.com/repos/${info.owner}/${info.repo}/git/trees/${info.ref}?recursive=1');

    final response = await _client.get(apiUrl, headers: {
      'Accept': 'application/vnd.github.v3+json',
      'User-Agent': 'RadioKit-CompanionApp',
    });

    if (response.statusCode != 200) {
      throw Exception(
          'Failed to fetch repository tree (HTTP ${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final tree = data['tree'] as List<dynamic>? ?? [];

    final cleanSubfolder = info.subfolder.replaceAll(RegExp(r'^/+|/+$'), '');
    final entries = <RepoFileEntry>[];

    for (final item in tree) {
      if (item is! Map<String, dynamic>) continue;
      final fullPath = (item['path'] as String?) ?? '';
      final type = (item['type'] as String?) ?? '';
      final size = (item['size'] as num?)?.toInt() ?? 0;
      final isDir = type == 'tree';

      // Check if entry belongs to the subfolder
      if (cleanSubfolder.isNotEmpty) {
        if (fullPath == cleanSubfolder) continue;
        if (!fullPath.startsWith('$cleanSubfolder/')) continue;
      }

      final relPath = cleanSubfolder.isNotEmpty
          ? fullPath.substring(cleanSubfolder.length + 1)
          : fullPath;
      final name = relPath.split('/').last;
      final downloadUrl = isDir ? '' : info.rawFileUrl(fullPath);

      entries.add(RepoFileEntry(
        path: fullPath,
        relativePath: relPath,
        name: name,
        isDirectory: isDir,
        size: size,
        downloadUrl: downloadUrl,
      ));
    }

    return entries;
  }

  /// Downloads a raw file's bytes from the given URL.
  Future<Uint8List> downloadFile(String url) async {
    final response = await _client.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to download file (HTTP ${response.statusCode}) from $url');
    }
    return response.bodyBytes;
  }

  void close() {
    _client.close();
  }
}
