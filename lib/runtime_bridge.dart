import 'package:flutter/services.dart';

class RuntimeBridge {
  RuntimeBridge._();

  static const MethodChannel _channel =
      MethodChannel('com.smapy/runtime');

  static Future<Map<String, dynamic>> _invokeMap(
    String method,
  ) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(method);

    if (result == null) {
      throw PlatformException(
        code: 'EMPTY_RESULT',
        message: 'Android returned no data for $method.',
      );
    }

    return result;
  }

  static Future<Map<String, dynamic>> getDeviceInfo() {
    return _invokeMap('getDeviceInfo');
  }

  static Future<Map<String, dynamic>> prepareRuntimeStorage() {
    return _invokeMap('prepareRuntimeStorage');
  }

  static Future<String> getRuntimeBasePath() async {
    final paths = await getRuntimePaths();
    final base = paths['base'];

    if (base is! String || base.isEmpty) {
      throw StateError('Android runtime base path is unavailable.');
    }

    return base;
  }

  static Future<Map<String, dynamic>> installProot() {
    return _invokeMap('installProot');
  }

  static Future<Map<String, dynamic>> getRuntimePaths() {
    return _invokeMap('getRuntimePaths');
  }
}
