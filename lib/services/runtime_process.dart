import 'package:flutter/services.dart';

class RuntimeOutput {
  const RuntimeOutput({
    required this.type,
    required this.text,
    this.processId,
    this.exitCode,
  });

  final String type;
  final String text;
  final int? processId;
  final int? exitCode;

  factory RuntimeOutput.fromMap(Map<Object?, Object?> map) {
    return RuntimeOutput(
      type: map['type']?.toString() ?? 'output',
      text: map['text']?.toString() ?? '',
      processId: map['processId'] is int ? map['processId'] as int : null,
      exitCode: map['exitCode'] is int ? map['exitCode'] as int : null,
    );
  }
}

class RuntimeProcess {
  RuntimeProcess._();

  static final RuntimeProcess instance = RuntimeProcess._();

  static const MethodChannel _methods = MethodChannel('com.smapy/process');
  static const EventChannel _events =
      EventChannel('com.smapy/process-events');

  late final Stream<RuntimeOutput> output =
      _events.receiveBroadcastStream().map((event) {
    if (event is Map) return RuntimeOutput.fromMap(event);

    return const RuntimeOutput(
      type: 'error',
      text: 'Unexpected process event received.',
    );
  }).asBroadcastStream();

  Future<int> start({
    required String executablePath,
    required List<String> arguments,
    required String workingDirectory,
  }) async {
    final id = await _methods.invokeMethod<int>('startProcess', {
      'executablePath': executablePath,
      'arguments': arguments,
      'workingDirectory': workingDirectory,
    });

    if (id == null) {
      throw PlatformException(
        code: 'NO_PROCESS_ID',
        message: 'Native runner returned no process ID.',
      );
    }

    return id;
  }

  Future<void> writeInput(int processId, String text) async {
    await _methods.invokeMethod<void>('writeInput', {
      'processId': processId,
      'text': text,
    });
  }

  Future<void> closeInput(int processId) async {
    await _methods.invokeMethod<void>(
      'closeInput',
      {'processId': processId},
    );
  }

  Future<void> stop(int processId) async {
    await _methods.invokeMethod<void>(
      'stopProcess',
      {'processId': processId},
    );
  }

  Future<Map<String, dynamic>> status() async {
    final result = await _methods.invokeMapMethod<String, dynamic>(
      'getProcessStatus',
    );
    return result ?? <String, dynamic>{};
  }
}
