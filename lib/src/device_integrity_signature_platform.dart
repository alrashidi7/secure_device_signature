import 'dart:async';

/// Platform interface for native hardware signature and integrity data.
abstract class DeviceIntegritySignaturePlatform {
  /// Returns hardware-bound identifiers and metadata from native side.
  /// Keys: hardwareId, uuid, deviceModel, osVersion, etc.
  Future<Map<String, dynamic>> getHardwarePayload();

  /// True if a debugger is attached or hooking is detected (native check).
  Future<bool> isDebugOrHookingDetected();
}
