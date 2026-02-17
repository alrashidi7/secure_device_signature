import 'package:flutter_root_jailbreak_checker/flutter_root_jailbreak_checker.dart';

import 'config.dart';
import 'device_integrity_report.dart';
import 'device_integrity_signature_impl.dart' show DeviceIntegritySignatureImpl, sha256Hash;
import 'device_integrity_signature_platform.dart';
import 'security_exception.dart';

/// Generates a persistent, hardware-bound device signature and runs
/// integrity checks. Throws [SecurityException] if device is compromised.
class DeviceIntegritySignature {
  static DeviceIntegritySignature? _instance;

  DeviceIntegritySignature({DeviceIntegritySignaturePlatform? platform})
      : _platform = platform ?? DeviceIntegritySignatureImpl();

  final DeviceIntegritySignaturePlatform _platform;

  /// Returns the singleton instance when [SecureDeviceSignatureConfig.useSingleton]
  /// is `true`. When `false`, throws — use constructor injection instead.
  static DeviceIntegritySignature get instance {
    if (!SecureDeviceSignatureConfig.useSingleton) {
      throw StateError(
        'DeviceIntegritySignature.instance is disabled. Set '
        'SecureDeviceSignatureConfig.useSingleton = true, or use constructor '
        'injection (recommended for DI).',
      );
    }
    return _instance ??= DeviceIntegritySignature();
  }

  /// Clears the cached singleton. Call when switching to DI or in tests.
  static void resetInstance() {
    _instance = null;
  }
  final _rootChecker = FlutterRootJailbreakChecker();

  /// Builds a canonical string from [payload] for hashing: hardwareId + uuid + metadata.
  static String _payloadString(Map<String, dynamic> payload) {
    final hardwareId = payload['hardwareId']?.toString() ?? '';
    final uuid = payload['uuid']?.toString() ?? '';
    final model = payload['deviceModel']?.toString() ?? '';
    final os = payload['osVersion']?.toString() ?? '';
    return '$hardwareId|$uuid|$model|$os';
  }

  /// Returns a [DeviceIntegrityReport] with signature and integrity status.
  /// Throws [SecurityException] if [throwOnCompromised] is true and device is compromised.
  Future<DeviceIntegrityReport> getReport({bool throwOnCompromised = true}) async {
    final payload = await _platform.getHardwarePayload();
    final integrity = await _rootChecker.checkOfflineIntegrity();
    final debugOrHooking = await _platform.isDebugOrHookingDetected();

    final isRootedOrJailbroken = integrity.isRooted || integrity.isJailbroken;
    final isEmulatorOrSimulator = integrity.isEmulator || !integrity.isRealDevice;
    final isCompromised = isRootedOrJailbroken ||
        isEmulatorOrSimulator ||
        integrity.hasPotentiallyDangerousApps ||
        debugOrHooking;

    final payloadStr = _payloadString(payload);
    final signature = payloadStr.isEmpty
        ? ''
        : sha256Hash(payloadStr);

    final metadata = <String, dynamic>{
      'deviceModel': payload['deviceModel'],
      'osVersion': payload['osVersion'],
      'uuid': payload['uuid'],
      'platform': payload['platform'],
    };

    final report = DeviceIntegrityReport(
      signature: signature,
      isCompromised: isCompromised,
      metadata: metadata,
    );

    if (throwOnCompromised && isCompromised) {
      String reason = 'compromised';
      if (isRootedOrJailbroken) {
        reason = integrity.isRooted ? 'rooted' : 'jailbroken';
      } else if (isEmulatorOrSimulator) {
        reason = 'emulator';
      } else if (integrity.hasPotentiallyDangerousApps) {
        reason = 'dangerous_apps';
      } else if (debugOrHooking) {
        reason = 'debug_or_hooking';
      }
      throw SecurityException(
        reason,
        'Device integrity check failed: $reason',
      );
    }

    return report;
  }
}
