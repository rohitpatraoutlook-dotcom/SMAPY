import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'installation_store.dart';
import 'linux_installer.dart';
import 'rootfs_extractor.dart';

class LinuxRuntimeInstaller {
  LinuxRuntimeInstaller._();

  static final LinuxRuntimeInstaller instance =
      LinuxRuntimeInstaller._();

  final InstallationStore _store = InstallationStore.instance;
  final LinuxInstaller _downloader = LinuxInstaller.instance;
  final RootfsExtractor _extractor = RootfsExtractor.instance;

  bool _busy = false;

  bool get isBusy => _busy;

  Future<LinuxInstallation> currentInstallation() {
    return _store.load();
  }

  Future<LinuxInstallation> install({
    required RootfsManifest manifest,
    void Function(String stage, double? progress)? onProgress,
  }) async {
    if (_busy) {
      throw StateError('A Linux installation is already in progress.');
    }

    _busy = true;

    try {
      manifest.validate();

      var installation = LinuxInstallation.initial().copyWith(
        state: LinuxInstallState.downloading,
        version: manifest.version,
        architecture: manifest.architecture,
        sha256: manifest.sha256.toLowerCase(),
        clearError: true,
      );

      await _store.save(installation);
      onProgress?.call('Downloading root filesystem', 0);

      final download = await _downloader.downloadRootfs(
        manifest,
        onProgress: (snapshot) {
          onProgress?.call(
            snapshot.message,
            snapshot.progress,
          );
        },
      );

      if (download.status != InstallerStatus.downloaded ||
          download.archivePath == null) {
        throw StateError(
          'Root filesystem download did not complete successfully.',
        );
      }

      installation = installation.copyWith(
        state: LinuxInstallState.downloaded,
        archivePath: download.archivePath,
      );
      await _store.save(installation);

      installation = installation.copyWith(
        state: LinuxInstallState.verifying,
      );
      await _store.save(installation);

      // The downloader only returns a final archive path after the
      // configured SHA-256 checksum matches.
      final appSupport = await getApplicationSupportDirectory();
      final runtimeDirectory = Directory(
        '${appSupport.path}/smapy-runtime',
      );

      await runtimeDirectory.create(recursive: true);

      final rootfs = Directory(
        '${runtimeDirectory.path}/rootfs-${manifest.version}',
      );

      if (await rootfs.exists()) {
        throw StateError(
          'A root filesystem directory for this version already exists. '
          'Remove it through a future explicit reset/recovery action '
          'before reinstalling.',
        );
      }

      installation = installation.copyWith(
        state: LinuxInstallState.extracting,
      );
      await _store.save(installation);

      onProgress?.call('Extracting Linux filesystem', 0);

      final extraction = await _extractor.extractTarGz(
        archivePath: download.archivePath!,
        destinationPath: rootfs.path,
        onProgress: (completed, total) {
          final progress = total == 0 ? 1.0 : completed / total;
          onProgress?.call('Extracting Linux filesystem', progress);
        },
      );

      installation = installation.copyWith(
        state: LinuxInstallState.configuring,
        rootfsPath: extraction.rootfsPath,
      );
      await _store.save(installation);

      // Only mark installed when both a shell and PRoot are present.
      final rootfsDir = Directory(extraction.rootfsPath);
      final runtimeDir = Directory('${runtimeDirectory.path}/bin');
      final proot = File('${runtimeDir.path}/proot');
      final shells = [
        File('${rootfsDir.path}/bin/sh'),
        File('${rootfsDir.path}/usr/bin/sh'),
        File('${rootfsDir.path}/bin/bash'),
        File('${rootfsDir.path}/usr/bin/bash'),
      ];
      final hasShell = shells.any((file) => file.existsSync());
      final ready = await proot.exists() && hasShell;

      installation = installation.copyWith(
        state: ready
            ? LinuxInstallState.installed
            : LinuxInstallState.configuring,
        rootfsPath: extraction.rootfsPath,
        archivePath: download.archivePath,
        sha256: manifest.sha256.toLowerCase(),
        clearError: true,
      );

      await _store.save(installation);

      onProgress?.call(
        ready
            ? 'Linux files extracted; runtime components found'
            : 'Rootfs extracted; PRoot or shell setup remains',
        1,
      );
      return installation;
    } catch (error) {
      try {
        final previous = await _store.load();
        final failed = previous.copyWith(
          state: LinuxInstallState.failed,
          error: error.toString(),
        );
        await _store.save(failed);
      } catch (_) {
        // Preserve the original installation error.
      }
      rethrow;
    } finally {
      _busy = false;
    }
  }
}
