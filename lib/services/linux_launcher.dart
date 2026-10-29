import 'dart:async';
import 'dart:io';

import 'installation_store.dart';
import 'runtime_process.dart';

enum LinuxSessionStatus {
  stopped,
  starting,
  running,
  stopping,
  failed,
}

class LinuxSessionSnapshot {
  const LinuxSessionSnapshot({
    required this.status,
    this.processId,
    this.rootfsPath,
    this.message = 'Linux session is stopped.',
  });

  final LinuxSessionStatus status;
  final int? processId;
  final String? rootfsPath;
  final String message;

  bool get isRunning => status == LinuxSessionStatus.running;
}

class LinuxLauncher {
  LinuxLauncher._() {
    RuntimeProcess.instance.output.listen((event) {
      if (event.type != 'exit' || event.processId == null) return;

      final current = _snapshot;
      if (current.processId != event.processId) return;

      _snapshot = LinuxSessionSnapshot(
        status: LinuxSessionStatus.stopped,
        rootfsPath: current.rootfsPath,
        message: 'Linux process exited (code ${event.exitCode ?? 'unknown'}).',
      );
    });
  }

  static final LinuxLauncher instance = LinuxLauncher._();

  LinuxSessionSnapshot _snapshot = const LinuxSessionSnapshot(
    status: LinuxSessionStatus.stopped,
  );

  LinuxSessionSnapshot get snapshot => _snapshot;

  Future<LinuxSessionSnapshot> start() async {
    if (_snapshot.status == LinuxSessionStatus.running ||
        _snapshot.status == LinuxSessionStatus.starting) {
      return _snapshot;
    }

    _snapshot = const LinuxSessionSnapshot(
      status: LinuxSessionStatus.starting,
      message: 'Checking Linux runtime files...',
    );

    try {
      final installation = await InstallationStore.instance.load();

      if (!installation.isInstalled || installation.rootfsPath == null) {
        throw StateError('Linux root filesystem is not installed.');
      }

      final rootfs = Directory(installation.rootfsPath!).absolute;
      if (!await rootfs.exists()) {
        throw StateError('Installed root filesystem directory is missing.');
      }

      final shellCandidates = [
        File('${rootfs.path}/bin/sh'),
        File('${rootfs.path}/usr/bin/sh'),
        File('${rootfs.path}/bin/bash'),
        File('${rootfs.path}/usr/bin/bash'),
      ];

      final shellExists = shellCandidates.any(
        (file) => file.existsSync(),
      );

      if (!shellExists) {
        throw StateError(
          'No supported shell was found in the Linux root filesystem.',
        );
      }

      final base = rootfs.parent;
      final proot = File('${base.path}/bin/proot').absolute;

      if (!await proot.exists()) {
        throw StateError(
          'PRoot executable is missing. Install a compatible Android ARM64 '
          'PRoot binary before launching Linux.',
        );
      }

      final home = Directory('${rootfs.path}/root');
      if (!await home.exists()) {
        await home.create(recursive: true);
      }

      final tmp = Directory('${rootfs.path}/tmp');
      if (!await tmp.exists()) {
        await tmp.create(recursive: true);
      }

      final shell = shellCandidates.firstWhere(
        (file) => file.existsSync(),
      );

      _snapshot = LinuxSessionSnapshot(
        status: LinuxSessionStatus.starting,
        rootfsPath: rootfs.path,
        message: 'Starting Linux process...',
      );

      final readyMarker =
          '__SMAPY_SHELL_READY_${DateTime.now().microsecondsSinceEpoch}__';
      final ready = Completer<void>();
      var processIdForCheck = -1;
      var shellOutput = '';
      late final StreamSubscription<RuntimeOutput> readinessSubscription;

      readinessSubscription = RuntimeProcess.instance.output.listen((event) {
        if (processIdForCheck < 0 || event.processId != processIdForCheck) {
          return;
        }

        if (event.type == 'exit') {
          if (!ready.isCompleted) {
            ready.completeError(
              StateError(
                'Linux shell exited before readiness '
                '(code ${event.exitCode ?? 'unknown'}).',
              ),
            );
          }
          return;
        }

        if (event.type == 'stderr') {
          shellOutput += '${event.text}\n';
          return;
        }

        if (event.text.contains(readyMarker) && !ready.isCompleted) {
          ready.complete();
        }
      });

      try {
        final processId = await RuntimeProcess.instance.start(
          executablePath: proot.path,
          workingDirectory: rootfs.path,
          arguments: [
            '-0',
            '-r',
            rootfs.path,
            '-w',
            '/root',
            '-b',
            '/dev',
            '-b',
            '/proc',
            '-b',
            '/sys',
            shell.path.replaceFirst(rootfs.path, ''),
            '-l',
          ],
        );

        processIdForCheck = processId;
        _snapshot = LinuxSessionSnapshot(
          status: LinuxSessionStatus.starting,
          processId: processId,
          rootfsPath: rootfs.path,
          message: 'Waiting for Linux shell...',
        );

        await RuntimeProcess.instance.writeInput(
          processId,
          'printf "$readyMarker\\n"\\n',
        );

        try {
          await ready.future.timeout(const Duration(seconds: 12));
        } on TimeoutException {
          await RuntimeProcess.instance.stop(processId);
          final detail = shellOutput.trim();
          throw StateError(
            'Linux shell readiness timed out after 12 seconds.'
            '${detail.isEmpty ? '' : ' stderr: ${detail.length > 500 ? detail.substring(detail.length - 500) : detail}'}',
          );
        }

        _snapshot = LinuxSessionSnapshot(
          status: LinuxSessionStatus.running,
          processId: processId,
          rootfsPath: rootfs.path,
          message: 'Linux shell is ready.',
        );

        return _snapshot;
      } finally {
        await readinessSubscription.cancel();
      }
    } catch (error) {
      _snapshot = LinuxSessionSnapshot(
        status: LinuxSessionStatus.failed,
        message: error.toString(),
      );
      rethrow;
    }
  }

  Future<void> sendInput(String text) async {
    final processId = _snapshot.processId;

    if (_snapshot.status != LinuxSessionStatus.running ||
        processId == null) {
      throw StateError('No Linux process is running.');
    }

    await RuntimeProcess.instance.writeInput(processId, text);
  }

  Future<void> stop() async {
    final processId = _snapshot.processId;

    if (processId == null) {
      _snapshot = const LinuxSessionSnapshot(
        status: LinuxSessionStatus.stopped,
      );
      return;
    }

    _snapshot = LinuxSessionSnapshot(
      status: LinuxSessionStatus.stopping,
      processId: processId,
      rootfsPath: _snapshot.rootfsPath,
      message: 'Stopping Linux process...',
    );

    await RuntimeProcess.instance.stop(processId);

    _snapshot = const LinuxSessionSnapshot(
      status: LinuxSessionStatus.stopped,
      message: 'Linux process stopped.',
    );
  }
}
