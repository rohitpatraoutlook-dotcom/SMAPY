import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class RootfsManifest {
  const RootfsManifest({
    required this.name,
    required this.version,
    required this.architecture,
    required this.archiveUrl,
    required this.sha256,
    required this.archiveFileName,
  });

  final String name;
  final String version;
  final String architecture;
  final String archiveUrl;
  final String sha256;
  final String archiveFileName;

  void validate() {
    final uri = Uri.tryParse(archiveUrl);

    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty) {
      throw const FormatException(
        'Root filesystem must use a valid HTTPS download URL.',
      );
    }

    if (architecture != 'aarch64' &&
        architecture != 'arm64') {
      throw const FormatException(
        'Only ARM64 root filesystems are supported currently.',
      );
    }

    if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(sha256)) {
      throw const FormatException(
        'A valid 64-character SHA-256 checksum is required.',
      );
    }

    if (archiveFileName.isEmpty ||
        archiveFileName.contains('/') ||
        archiveFileName.contains(r'\') ||
        archiveFileName == '.' ||
        archiveFileName == '..') {
      throw const FormatException(
        'Invalid archive filename.',
      );
    }
  }
}

enum InstallerStatus {
  idle,
  downloading,
  verifying,
  downloaded,
  failed,
  cancelled,
}

class InstallerSnapshot {
  const InstallerSnapshot({
    required this.status,
    this.downloadedBytes = 0,
    this.totalBytes,
    this.archivePath,
    this.message = 'Ready to install.',
  });

  final InstallerStatus status;
  final int downloadedBytes;
  final int? totalBytes;
  final String? archivePath;
  final String message;

  double? get progress {
    final total = totalBytes;
    if (total == null || total <= 0) return null;

    return (downloadedBytes / total).clamp(0.0, 1.0);
  }
}

class LinuxInstaller {
  LinuxInstaller._();

  static final LinuxInstaller instance = LinuxInstaller._();

  http.Client _client = http.Client();

  InstallerSnapshot _snapshot = const InstallerSnapshot(
    status: InstallerStatus.idle,
  );

  InstallerSnapshot get snapshot => _snapshot;

  bool _cancelRequested = false;
  bool _busy = false;

  Future<Directory> _installerDirectory() async {
    final appDirectory = await getApplicationSupportDirectory();
    final directory = Directory(
      '${appDirectory.path}/smapy-runtime/downloads',
    );

    await directory.create(recursive: true);
    return directory;
  }

  Future<void> cancel() async {
    if (!_busy) return;

    _cancelRequested = true;
    _client.close();
    _client = http.Client();

    _snapshot = const InstallerSnapshot(
      status: InstallerStatus.cancelled,
      message: 'Download cancellation requested.',
    );
  }

  Future<InstallerSnapshot> downloadRootfs(
    RootfsManifest manifest, {
    void Function(InstallerSnapshot snapshot)? onProgress,
  }) async {
    if (_busy) {
      throw StateError('An installer operation is already running.');
    }

    manifest.validate();

    _busy = true;
    _cancelRequested = false;

    File? partialFile;

    try {
      _snapshot = const InstallerSnapshot(
        status: InstallerStatus.downloading,
        message: 'Preparing download...',
      );
      onProgress?.call(_snapshot);

      final directory = await _installerDirectory();
      final destination = File(
        '${directory.path}/${manifest.archiveFileName}',
      );
      partialFile = File('${destination.path}.part');

      if (await partialFile.exists()) {
        await partialFile.delete();
      }

      final request = http.Request(
        'GET',
        Uri.parse(manifest.archiveUrl),
      );

      final response = await _client.send(request);

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Rootfs download failed: HTTP ${response.statusCode}.',
          uri: Uri.parse(manifest.archiveUrl),
        );
      }

      final total = response.contentLength;
      var downloaded = 0;

      final sink = partialFile.openWrite();

      try {
        await for (final chunk in response.stream) {
          if (_cancelRequested) {
            throw const _DownloadCancelled();
          }

          sink.add(chunk);
          downloaded += chunk.length;

          _snapshot = InstallerSnapshot(
            status: InstallerStatus.downloading,
            downloadedBytes: downloaded,
            totalBytes: total,
            message: 'Downloading Linux root filesystem...',
          );

          onProgress?.call(_snapshot);
        }

        await sink.flush();
      } finally {
        await sink.close();
      }

      if (_cancelRequested) {
        throw const _DownloadCancelled();
      }

      _snapshot = InstallerSnapshot(
        status: InstallerStatus.verifying,
        downloadedBytes: downloaded,
        totalBytes: total,
        message: 'Verifying SHA-256 checksum...',
      );
      onProgress?.call(_snapshot);

      final digest = await sha256.bind(partialFile.openRead()).first;
      final actualHash = digest.toString().toLowerCase();
      final expectedHash = manifest.sha256.toLowerCase();

      if (actualHash != expectedHash) {
        throw const FormatException(
          'SHA-256 mismatch. The downloaded archive was rejected.',
        );
      }

      if (await destination.exists()) {
        await destination.delete();
      }

      await partialFile.rename(destination.path);
      partialFile = null;

      _snapshot = InstallerSnapshot(
        status: InstallerStatus.downloaded,
        downloadedBytes: downloaded,
        totalBytes: total,
        archivePath: destination.path,
        message: 'Archive downloaded and checksum verified.',
      );

      onProgress?.call(_snapshot);
      return _snapshot;
    } on _DownloadCancelled {
      _snapshot = const InstallerSnapshot(
        status: InstallerStatus.cancelled,
        message: 'Download cancelled.',
      );
      return _snapshot;
    } catch (error) {
      _snapshot = InstallerSnapshot(
        status: InstallerStatus.failed,
        message: 'Installer failed: $error',
      );
      rethrow;
    } finally {
      if (partialFile != null && await partialFile.exists()) {
        await partialFile.delete();
      }

      _busy = false;
    }
  }
}

class _DownloadCancelled implements Exception {
  const _DownloadCancelled();
}
