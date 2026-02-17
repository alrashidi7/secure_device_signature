import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import 'device_integrity_signature_platform.dart';

const MethodChannel _channel =
    MethodChannel('com.diyar.device_integrity_signature/native');

/// Method-channel implementation of [DeviceIntegritySignaturePlatform].
class DeviceIntegritySignatureImpl implements DeviceIntegritySignaturePlatform {
  @override
  Future<Map<String, dynamic>> getHardwarePayload() async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>('getHardwarePayload');
      if (result == null) return {};
      return _stringKeys(result);
    } on PlatformException {
      return {};
    }
  }

  @override
  Future<bool> isDebugOrHookingDetected() async {
    try {
      final result = await _channel.invokeMethod<bool>('isDebugOrHookingDetected');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Map<String, dynamic> _stringKeys(Map<Object?, Object?> map) {
    return map.map((k, v) {
      final key = k?.toString() ?? '';
      Object? value = v;
      if (value is Map) value = _stringKeys(value as Map<Object?, Object?>);
      if (value is List) value = value.map((e) => e is Map ? _stringKeys(e as Map<Object?, Object?>) : e).toList();
      return MapEntry(key, value);
    });
  }
}

/// SHA-256 hex of UTF-8 bytes of [input]. Used to build signature from payload.
String sha256Hash(String input) {
  final bytes = utf8.encode(input);
  final digest = sha256.convert(bytes);
  return digest.toString();
}
