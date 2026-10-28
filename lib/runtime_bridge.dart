import 'package:flutter/services.dart';

class RuntimeBridge {
  static const MethodChannel _channel =
      MethodChannel('com.smapy/runtime');

  static Future<Map<String, dynamic>> getDeviceInfo() async {
    final result = await _channel.invokeMethod<Map<Object?, Object?>>(
      'getDeviceInfo',
    );

    if (result == null) {
      throw PlatformException(
        code: 'EMPTY_RESULT',
        message: 'Android runtime returned no device information.',
      );
    }

    return result.map(
      (key, value) => MapEntry(key.toString(), value),
    );
  }
}
