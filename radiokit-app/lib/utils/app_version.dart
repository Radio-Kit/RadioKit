/// Centralized application version and release tag metadata.
class AppVersion {
  /// The active Git release tag for the application (e.g. 'v2.1.0').
  /// Can be overridden at compile time via `--dart-define=APP_RELEASE_TAG=<tag>`.
  static const String releaseTag = String.fromEnvironment(
    'APP_RELEASE_TAG',
    defaultValue: 'v2.2.0',
  );

  /// Semantic version string without 'v' prefix (e.g. '2.1.0').
  static String get semver =>
      releaseTag.startsWith('v') ? releaseTag.substring(1) : releaseTag;
}
