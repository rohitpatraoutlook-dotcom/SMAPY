import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../runtime_bridge.dart';
import 'linux_installer.dart';
import 'linux_runtime_installer.dart';

enum RuntimeStatus {
  notInitialized,
  preparing,
  storageReady,
  linuxInstalling,
  linuxReady,
  pythonReady,
  failed,
}

class RuntimeSnapshot {
  const RuntimeSnapshot({
    required this.status,
    this.androidVersion,
    this.sdkInt,
    this.primaryAbi,
    this.supportedAbis = const [],
    this.runtimePaths = const {},
    this.message = 'Runtime has not been initialized.',
  });

  final RuntimeStatus status;
  final String? androidVersion;
  final int? sdkInt;
  final String? primaryAbi;
  final List<String> supportedAbis;
  final Map<String, String> runtimePaths;
  final String message;

  bool get isArm64 =>
      primaryAbi == 'arm64-v8a' || supportedAbis.contains('arm64-v8a');

  bool get isLinuxReady =>
      status == RuntimeStatus.linuxReady ||
      status == RuntimeStatus.pythonReady;

  bool get isPythonReady => status == RuntimeStatus.pythonReady;
}

class RuntimeManager {
  RuntimeManager._();

  static final RuntimeManager instance = RuntimeManager._();

  RuntimeSnapshot _snapshot = const RuntimeSnapshot(
    status: RuntimeStatus.notInitialized,
  );

  RuntimeSnapshot get snapshot => _snapshot;

  Future<RuntimeSnapshot> installLinux() async {
    try {
      if (_snapshot.status == RuntimeStatus.notInitialized) {
        await initialize();
      }

      if (!_snapshot.isArm64) {
        throw StateError('SMAPY Linux runtime currently requires Android ARM64.');
      }

      await RuntimeBridge.installProot();

      const version = '3.24.3';
      const filename = 'alpine-minirootfs-$version-aarch64.tar.gz';
      const baseUrl =
          'https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/aarch64/';

      final checksumResponse = await http.get(
        Uri.parse('$baseUrl$filename.sha256'),
      ).timeout(const Duration(seconds: 30));

      if (checksumResponse.statusCode != 200) {
        throw StateError(
          'Could not retrieve Alpine SHA-256 checksum '
          '(HTTP ${checksumResponse.statusCode}).',
        );
      }

      final match = RegExp(r'^[a-fA-F0-9]{64}').firstMatch(
        checksumResponse.body.trim(),
      );
      if (match == null) {
        throw const FormatException('Alpine checksum file is invalid.');
      }

      final manifest = RootfsManifest(
        name: 'Alpine Linux',
        version: version,
        architecture: 'aarch64',
        archiveUrl: '$baseUrl$filename',
        sha256: match.group(0)!,
        archiveFileName: filename,
      );

      _snapshot = RuntimeSnapshot(
        status: RuntimeStatus.linuxInstalling,
        androidVersion: _snapshot.androidVersion,
        sdkInt: _snapshot.sdkInt,
        primaryAbi: _snapshot.primaryAbi,
        supportedAbis: _snapshot.supportedAbis,
        runtimePaths: _snapshot.runtimePaths,
        message: 'Downloading and installing Alpine Linux...',
      );

      final installation = await LinuxRuntimeInstaller.instance.install(
        manifest: manifest,
      );

      if (!installation.isInstalled) {
        throw StateError(
          'Linux rootfs extracted, but runtime setup is incomplete. '
          'PRoot and shell readiness need to be checked.',
        );
      }

      _snapshot = RuntimeSnapshot(
        status: RuntimeStatus.linuxReady,
        androidVersion: _snapshot.androidVersion,
        sdkInt: _snapshot.sdkInt,
        primaryAbi: _snapshot.primaryAbi,
        supportedAbis: _snapshot.supportedAbis,
        runtimePaths: _snapshot.runtimePaths,
        message: 'Alpine Linux installed. Python setup is still pending.',
      );
    } catch (error) {
      _snapshot = RuntimeSnapshot(
        status: RuntimeStatus.failed,
        androidVersion: _snapshot.androidVersion,
        sdkInt: _snapshot.sdkInt,
        primaryAbi: _snapshot.primaryAbi,
        supportedAbis: _snapshot.supportedAbis,
        runtimePaths: _snapshot.runtimePaths,
        message: 'Linux installation failed: $error',
      );
    }

    return _snapshot;
  }

  Future<RuntimeSnapshot> installProot() async {
    try {
      if (_snapshot.status == RuntimeStatus.notInitialized) {
        await initialize();
      }

      if (!_snapshot.isArm64) {
        throw StateError(
          'The bundled PRoot build currently supports Android ARM64 only.',
        );
      }

      await RuntimeBridge.installProot();

      _snapshot = RuntimeSnapshot(
        status: RuntimeStatus.storageReady,
        androidVersion: _snapshot.androidVersion,
        sdkInt: _snapshot.sdkInt,
        primaryAbi: _snapshot.primaryAbi,
        supportedAbis: _snapshot.supportedAbis,
        runtimePaths: _snapshot.runtimePaths,
        message: 'PRoot installed. Linux root filesystem is still required.',
      );
    } catch (error) {
      _snapshot = RuntimeSnapshot(
        status: RuntimeStatus.failed,
        androidVersion: _snapshot.androidVersion,
        sdkInt: _snapshot.sdkInt,
        primaryAbi: _snapshot.primaryAbi,
        supportedAbis: _snapshot.supportedAbis,
        runtimePaths: _snapshot.runtimePaths,
        message: 'PRoot installation failed: $error',
      );
    }

    return _snapshot;
  }

  Future<RuntimeSnapshot> initialize() async {
    _snapshot = const RuntimeSnapshot(
      status: RuntimeStatus.preparing,
      message: 'Preparing local runtime storage...',
    );

    try {
      final device = await RuntimeBridge.getDeviceInfo();
      final storage = await RuntimeBridge.prepareRuntimeStorage();

      final rawAbis = device['supportedAbis'];
      final rawPaths = storage['directories'];

      final abis = rawAbis is List
          ? rawAbis.map((value) => value.toString()).toList()
          : <String>[];

      final paths = <String, String>{};
      if (rawPaths is Map) {
        for (final entry in rawPaths.entries) {
          paths[entry.key.toString()] = entry.value.toString();
        }
      }

      _snapshot = RuntimeSnapshot(
        status: RuntimeStatus.storageReady,
        androidVersion: device['androidVersion']?.toString(),
        sdkInt: device['sdkInt'] is int ? device['sdkInt'] as int : null,
        primaryAbi: device['primaryAbi']?.toString(),
        supportedAbis: abis,
        runtimePaths: paths,
        message: 'Private storage is ready. Linux is not installed yet.',
      );
    } on PlatformException catch (error) {
      _snapshot = RuntimeSnapshot(
        status: RuntimeStatus.failed,
        message: error.message ?? 'Android runtime bridge failed.',
      );
    } catch (error) {
      _snapshot = RuntimeSnapshot(
        status: RuntimeStatus.failed,
        message: 'Runtime initialization failed: $error',
      );
    }

    return _snapshot;
  }
}
