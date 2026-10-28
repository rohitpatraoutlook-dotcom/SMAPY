import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

enum LinuxInstallState {
  notInstalled,
  downloading,
  downloaded,
  verifying,
  extracting,
  configuring,
  installed,
  failed,
}

class LinuxInstallation {
  const LinuxInstallation({
    required this.state,
    required this.updatedAt,
    this.version,
    this.architecture,
    this.archivePath,
    this.rootfsPath,
    this.sha256,
    this.error,
  });

  final LinuxInstallState state;
  final DateTime updatedAt;
  final String? version;
  final String? architecture;
  final String? archivePath;
  final String? rootfsPath;
  final String? sha256;
  final String? error;

  bool get isInstalled => state == LinuxInstallState.installed;

  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'state': state.name,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'version': version,
        'architecture': architecture,
        'archivePath': archivePath,
        'rootfsPath': rootfsPath,
        'sha256': sha256,
        'error': error,
      };

  factory LinuxInstallation.fromJson(Map<String, dynamic> json) {
    final stateName = json['state'] as String?;
    final state = LinuxInstallState.values.firstWhere(
      (value) => value.name == stateName,
      orElse: () => LinuxInstallState.notInstalled,
    );

    return LinuxInstallation(
      state: state,
      updatedAt: DateTime.tryParse(
            json['updatedAt'] as String? ?? '',
          )?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      version: json['version'] as String?,
      architecture: json['architecture'] as String?,
      archivePath: json['archivePath'] as String?,
      rootfsPath: json['rootfsPath'] as String?,
      sha256: json['sha256'] as String?,
      error: json['error'] as String?,
    );
  }

  LinuxInstallation copyWith({
    LinuxInstallState? state,
    DateTime? updatedAt,
    String? version,
    String? architecture,
    String? archivePath,
    String? rootfsPath,
    String? sha256,
    String? error,
    bool clearError = false,
  }) {
    return LinuxInstallation(
      state: state ?? this.state,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
      version: version ?? this.version,
      architecture: architecture ?? this.architecture,
      archivePath: archivePath ?? this.archivePath,
      rootfsPath: rootfsPath ?? this.rootfsPath,
      sha256: sha256 ?? this.sha256,
      error: clearError ? null : error ?? this.error,
    );
  }

  static LinuxInstallation initial() => LinuxInstallation(
        state: LinuxInstallState.notInstalled,
        updatedAt: DateTime.now().toUtc(),
      );
}

class InstallationStore {
  InstallationStore._();

  static final InstallationStore instance = InstallationStore._();

  Future<File> _manifestFile() async {
    final directory = await getApplicationSupportDirectory();
    final runtimeDirectory = Directory(
      '${directory.path}/smapy-runtime',
    );

    await runtimeDirectory.create(recursive: true);
    return File('${runtimeDirectory.path}/installation.json');
  }

  Future<LinuxInstallation> load() async {
    final file = await _manifestFile();

    if (!await file.exists()) {
      return LinuxInstallation.initial();
    }

    try {
      final decoded = jsonDecode(await file.readAsString());

      if (decoded is! Map<String, dynamic> ||
          decoded['schemaVersion'] != 1) {
        throw const FormatException(
          'Unsupported installation manifest format.',
        );
      }

      return LinuxInstallation.fromJson(decoded);
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException(
        'Could not read installation manifest: $error',
      );
    }
  }

  Future<void> save(LinuxInstallation installation) async {
    final file = await _manifestFile();
    final temporary = File('${file.path}.tmp');

    await temporary.writeAsString(
      jsonEncode(installation.toJson()),
      flush: true,
    );

    if (await file.exists()) {
      await file.delete();
    }

    await temporary.rename(file.path);
  }

  Future<void> reset() async {
    final file = await _manifestFile();
    final temporary = File('${file.path}.tmp');

    if (await temporary.exists()) {
      await temporary.delete();
    }

    if (await file.exists()) {
      await file.delete();
    }
  }
}
