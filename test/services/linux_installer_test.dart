import 'package:flutter_test/flutter_test.dart';
import 'package:smapy/services/linux_installer.dart';

RootfsManifest validManifest({
  String url = 'https://example.com/rootfs.tar.gz',
  String architecture = 'aarch64',
  String? checksum,
  String filename = 'rootfs.tar.gz',
}) {
  checksum ??= List.filled(64, 'a').join();

  return RootfsManifest(
    name: 'Alpine Linux',
    version: '3.24.3',
    architecture: architecture,
    archiveUrl: url,
    sha256: checksum,
    archiveFileName: filename,
  );
}

void main() {
  group('RootfsManifest validation', () {
    test('accepts a valid HTTPS ARM64 manifest', () {
      expect(() => validManifest().validate(), returnsNormally);
    });

    test('rejects a non-HTTPS URL', () {
      expect(
        () => validManifest(url: 'http://example.com/rootfs.tar.gz').validate(),
        throwsFormatException,
      );
    });

    test('rejects a missing URL host', () {
      expect(
        () => validManifest(url: 'https:///rootfs.tar.gz').validate(),
        throwsFormatException,
      );
    });

    test('rejects unsupported architectures', () {
      expect(
        () => validManifest(architecture: 'x86_64').validate(),
        throwsFormatException,
      );
    });

    test('rejects malformed SHA-256 checksums', () {
      expect(
        () => validManifest(checksum: '12345').validate(),
        throwsFormatException,
      );
    });

    test('rejects archive paths instead of filenames', () {
      expect(
        () => validManifest(filename: '../rootfs.tar.gz').validate(),
        throwsFormatException,
      );
    });

    test('rejects Windows-style archive paths', () {
      expect(
        () => validManifest(filename: r'folder\rootfs.tar.gz').validate(),
        throwsFormatException,
      );
    });
  });

  group('InstallerSnapshot progress', () {
    test('calculates download progress', () {
      const snapshot = InstallerSnapshot(
        status: InstallerStatus.downloading,
        downloadedBytes: 25,
        totalBytes: 100,
      );

      expect(snapshot.progress, 0.25);
    });

    test('caps progress at 100 percent', () {
      const snapshot = InstallerSnapshot(
        status: InstallerStatus.downloading,
        downloadedBytes: 120,
        totalBytes: 100,
      );

      expect(snapshot.progress, 1.0);
    });

    test('returns null when total size is unknown', () {
      const snapshot = InstallerSnapshot(
        status: InstallerStatus.downloading,
        downloadedBytes: 25,
      );

      expect(snapshot.progress, isNull);
    });
  });
}
