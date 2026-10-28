import 'package:flutter/services.dart';

import '../runtime_bridge.dart';

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
