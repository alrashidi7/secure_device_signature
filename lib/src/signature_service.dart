import 'dart:convert';
import 'dart:typed_data';

import 'package:biometric_signature/biometric_signature.dart';
import 'package:flutter/services.dart';

import 'config.dart';
import 'device_integrity_report.dart';
import 'device_integrity_signature.dart';
import 'signature_exceptions.dart';

/// Result of signing with biometric + device integrity.
typedef SignResult = ({
  String signature,
  String? publicKey,
  String signedPayload,
  String deviceSignature,
  DeviceIntegrityReport deviceReport,
});

/// Service for hardware-backed biometric signatures with device integrity.
///
/// Lives in [secure_device_signature] because it is device-related: when signing,
/// it includes [DeviceIntegrityReport.signature] so the server can bind the
/// biometric proof to the device.
///
/// Throws [BiometricHardwareUnavailableException] when hardware is unavailable.
/// Throws [UserCanceledException] when user dismisses the prompt.
class SignatureService {
  static SignatureService? _instance;

  SignatureService({
    BiometricSignature? plugin,
    DeviceIntegritySignature? deviceIntegrity,
  })  : _plugin = plugin ?? BiometricSignature(),
        _deviceIntegrity = deviceIntegrity ?? DeviceIntegritySignature();

  final BiometricSignature _plugin;
  final DeviceIntegritySignature _deviceIntegrity;

  /// Returns the singleton instance when [SecureDeviceSignatureConfig.useSingleton]
  /// is `true`. When `false`, throws — use constructor injection instead.
  static SignatureService get instance {
    if (!SecureDeviceSignatureConfig.useSingleton) {
      throw StateError(
        'SignatureService.instance is disabled. Set '
        'SecureDeviceSignatureConfig.useSingleton = true, or use constructor '
        'injection (recommended for DI).',
      );
    }
    return _instance ??= SignatureService();
  }

  /// Clears the cached singleton. Call when switching to DI or in tests.
  static void resetInstance() {
    _instance = null;
  }

  /// Checks if biometric hardware is available and can authenticate.
  Future<bool> get isAvailable async {
    final availability = await _plugin.biometricAuthAvailable();
    return availability != null && availability != 'none';
  }

  /// Ensures keys exist. Creates them if not present.
  /// If existing keys are invalid (e.g. biometrics changed), deletes and recreates.
  Future<void> ensureKeys({
    String promptMessage = 'Authenticate to create keys',
  }) async {
    if (!await isAvailable) {
      throw BiometricHardwareUnavailableException();
    }

    final keysExist = await _plugin.biometricKeyExists(checkValidity: true);
    if (keysExist == true) return;

    await _createKeys(promptMessage: promptMessage);
  }

  Future<void> _createKeys({String promptMessage = 'Authenticate to create keys'}) async {
    final result = await _plugin.createKeys(
      androidConfig: AndroidConfig(
        useDeviceCredentials: false,
        setInvalidatedByBiometricEnrollment: true,
      ),
      iosConfig: IosConfig(
        useDeviceCredentials: false,
        biometryCurrentSet: true,
      ),
      keyFormat: KeyFormat.base64,
      promptMessage: promptMessage,
    );

    if (result == null) {
      throw BiometricHardwareUnavailableException(
          'Failed to create biometric keys');
    }
  }

  static bool _isKeysNotInitializedError(Object e) {
    final msg = (e is PlatformException ? (e.message ?? '') : e.toString()).toLowerCase();
    return msg.contains('object not initialized') ||
        msg.contains('not initialized for signature or verification') ||
        (msg.contains('auth failed') && msg.contains('signature'));
  }

  /// Signs [payload] and includes device integrity signature from [DeviceIntegrityReport].
  ///
  /// [throwOnCompromised]: if true, throws [SecurityException] when device is compromised.
  /// If false, report is still included so server can decide.
  ///
  /// On "object not initialized" / "auth failed" errors, deletes and recreates keys, then retries once.
  Future<SignResult> sign(
    String payload, {
    String promptMessage = 'Verify identity to sign',
    bool throwOnCompromised = false,
  }) async {
    await ensureKeys();

    final deviceReport = await _deviceIntegrity.getReport(
      throwOnCompromised: throwOnCompromised,
    );

    try {
      return await _doSign(payload, promptMessage, deviceReport);
    } catch (e) {
      if (_isKeysNotInitializedError(e)) {
        await _plugin.deleteKeys();
        await _createKeys(promptMessage: 'Authenticate to recreate keys');
        return _doSign(payload, promptMessage, deviceReport);
      }
      rethrow;
    }
  }

  Future<SignResult> _doSign(
    String payload,
    String promptMessage,
    DeviceIntegrityReport deviceReport,
  ) async {
    final result = await _plugin.createSignature(
      SignatureOptions(
        payload: payload,
        promptMessage: promptMessage,
        keyFormat: KeyFormat.pem,
        androidOptions: AndroidSignatureOptions(allowDeviceCredentials: false),
        iosOptions: IosSignatureOptions(),
      ),
    );

    if (result == null) {
      throw UserCanceledException('Signing failed or was canceled');
    }

    final sigStr = result.signature.asString() ?? result.signature.toBase64();
    final keyStr = result.publicKey.asString() ?? result.publicKey.toPem();
    return (
      signature: sigStr,
      publicKey: keyStr,
      signedPayload: payload,
      deviceSignature: deviceReport.signature,
      deviceReport: deviceReport,
    );
  }

  /// Signs the given [embedding] (base64 Float32 bytes). Includes device signature.
  Future<SignResult> signEmbedding(
    List<double> embedding, {
    bool throwOnCompromised = false,
  }) async {
    final bytes = Float32List.fromList(embedding).buffer.asUint8List();
    final payload = base64Encode(bytes);
    return sign(
      payload,
      promptMessage: 'Verify identity to sign',
      throwOnCompromised: throwOnCompromised,
    );
  }

  /// Signs a [challenge] from the server. Includes device signature.
  Future<SignResult> signChallenge(
    String challenge, {
    String promptMessage = 'Verify identity to sign challenge',
    bool throwOnCompromised = false,
  }) async {
    return sign(
      challenge,
      promptMessage: promptMessage,
      throwOnCompromised: throwOnCompromised,
    );
  }

  Future<bool> deleteKeys() async => (await _plugin.deleteKeys()) ?? false;
}
