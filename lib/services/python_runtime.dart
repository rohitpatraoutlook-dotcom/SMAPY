import 'dart:async';
import 'dart:io';

import 'installation_store.dart';
import 'linux_launcher.dart';
import 'runtime_process.dart';

enum PythonExecutionStatus {
  completed,
  failed,
  timedOut,
}

class PythonExecutionResult {
  const PythonExecutionResult({
    required this.status,
    required this.stdout,
    required this.stderr,
    this.exitCode,
  });

  final PythonExecutionStatus status;
  final String stdout;
  final String stderr;
  final int? exitCode;

  bool get succeeded =>
      status == PythonExecutionStatus.completed && exitCode == 0;
}

class PythonRuntime {
  PythonRuntime._();

  static final PythonRuntime instance = PythonRuntime._();

  Future<PythonExecutionResult> execute(
    String source, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final installation = await InstallationStore.instance.load();

    if (!installation.isInstalled || installation.rootfsPath == null) {
      throw StateError(
        'Linux root filesystem is not installed. '
        'Install and configure Linux before running Python.',
      );
    }

    var session = LinuxLauncher.instance.snapshot;

    if (!session.isRunning) {
      session = await LinuxLauncher.instance.start();
    }

    final processId = session.processId;
    final rootfsPath = session.rootfsPath;

    if (processId == null || rootfsPath == null) {
      throw StateError('Linux shell session is not available.');
    }

    final scriptsDirectory = Directory(
      '$rootfsPath/root/smapy_scripts',
    );
    await scriptsDirectory.create(recursive: true);

    final executionId = DateTime.now().microsecondsSinceEpoch;
    final scriptName = 'script_$executionId.py';
    final scriptFile = File(
      '${scriptsDirectory.path}/$scriptName',
    );

    await scriptFile.writeAsString(source, flush: true);

    final marker = '__SMAPY_DONE_${executionId}__';
    final completer = Completer<PythonExecutionResult>();
    final stdout = StringBuffer();
    final stderr = StringBuffer();

    late final StreamSubscription<RuntimeOutput> subscription;

    subscription = RuntimeProcess.instance.output.listen((event) {
      if (event.processId != processId) return;

      if (event.type == 'stderr') {
        stderr.writeln(event.text);
        return;
      }

      if (event.type == 'exit') {
        if (!completer.isCompleted) {
          completer.complete(
            PythonExecutionResult(
              status: PythonExecutionStatus.failed,
              stdout: stdout.toString(),
              stderr: stderr.toString(),
              exitCode: event.exitCode,
            ),
          );
        }
        return;
      }

      final line = event.text;
      if (line.startsWith('$marker:')) {
        final code = int.tryParse(line.substring(marker.length + 1));

        if (!completer.isCompleted) {
          completer.complete(
            PythonExecutionResult(
              status: code == 0
                  ? PythonExecutionStatus.completed
                  : PythonExecutionStatus.failed,
              stdout: stdout.toString(),
              stderr: stderr.toString(),
              exitCode: code,
            ),
          );
        }
        return;
      }

      stdout.writeln(line);
    });

    try {
      final command =
          'python3 -u /root/smapy_scripts/$scriptName; '
          'smapy_exit=\$?; '
          'printf "$marker:%s\\n" "\$smapy_exit"\n';

      await LinuxLauncher.instance.sendInput(command);

      return await completer.future.timeout(
        timeout,
        onTimeout: () => PythonExecutionResult(
          status: PythonExecutionStatus.timedOut,
          stdout: stdout.toString(),
          stderr: stderr.toString(),
        ),
      );
    } finally {
      await subscription.cancel();
    }
  }
}
