import 'package:flutter_test/flutter_test.dart';
import 'package:radiokit/utils/app_version.dart';

void main() {
  group('AppVersion', () {
    test('defaults to v2.2.0 release tag', () {
      expect(AppVersion.releaseTag, equals('v2.2.0'));
      expect(AppVersion.semver, equals('2.2.0'));
    });
  });
}
