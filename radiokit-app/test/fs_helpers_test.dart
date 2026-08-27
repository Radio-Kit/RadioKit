import 'package:flutter_test/flutter_test.dart';
import 'package:radiokit/screens/filesystem/fs_helpers.dart';

void main() {
  group('formatBytes', () {
    test('formats bytes < 1 KB with B suffix', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(512), '512 B');
      expect(formatBytes(1023), '1023 B');
    });

    test('formats bytes < 1 MB with KB suffix and 1 decimal', () {
      expect(formatBytes(1024), '1.0 KB');
      expect(formatBytes(1536), '1.5 KB');
      expect(formatBytes(1024 * 100), '100.0 KB');
    });

    test('formats bytes < 1 GB with MB suffix and 2 decimals', () {
      expect(formatBytes(1024 * 1024), '1.00 MB');
      expect(formatBytes(1024 * 1024 * 5 + 1024 * 100), '5.10 MB');
    });

    test('formats bytes >= 1 GB with GB suffix and 2 decimals', () {
      expect(formatBytes(1024 * 1024 * 1024), '1.00 GB');
    });
  });

  group('fileExtension', () {
    test('returns lowercase extension', () {
      expect(fileExtension('README.TXT'), 'txt');
      expect(fileExtension('photo.JPG'), 'jpg');
      expect(fileExtension('data.json'), 'json');
    });

    test('returns empty for no extension', () {
      expect(fileExtension('Makefile'), '');
      expect(fileExtension('LICENSE'), '');
    });

    test('returns empty for trailing dot', () {
      expect(fileExtension('weird.'), '');
    });
  });

  group('baseName', () {
    test('extracts last segment of a path', () {
      expect(baseName('/foo/bar/baz.txt'), 'baz.txt');
      expect(baseName('/foo/bar'), 'bar');
    });

    test('returns whole input if no slash', () {
      expect(baseName('hello.txt'), 'hello.txt');
    });

    test('handles root', () {
      expect(baseName('/'), '');
    });
  });

  group('parentPath', () {
    test('returns / for root', () {
      expect(parentPath('/'), '/');
    });

    test('returns / for top-level entry', () {
      expect(parentPath('/foo'), '/');
    });

    test('returns parent dir without trailing slash', () {
      expect(parentPath('/foo/bar/baz'), '/foo/bar');
    });
  });

  group('joinPath', () {
    test('joins root with child', () {
      expect(joinPath('/', 'foo'), '/foo');
    });

    test('joins nested with child', () {
      expect(joinPath('/foo/bar', 'baz'), '/foo/bar/baz');
    });
  });

  group('pathSegments', () {
    test('returns empty for root', () {
      expect(pathSegments('/'), isEmpty);
      expect(pathSegments(''), isEmpty);
    });

    test('splits nested path', () {
      expect(pathSegments('/foo/bar/baz'), ['foo', 'bar', 'baz']);
    });

    test('skips empty segments from double slashes', () {
      expect(pathSegments('/foo//bar'), ['foo', 'bar']);
    });
  });
}
