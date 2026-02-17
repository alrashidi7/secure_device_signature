# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-02-17

### Added

- Persistent hardware-bound device signature (SHA-256 of HardwareID + UUID + metadata).
- Android: Widevine MediaDrm + Keystore; fallback to Android ID for reinstall persistence.
- iOS: Keychain-stored UUID with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
- Integrity checks via `flutter_root_jailbreak_checker`: root/jailbreak, emulator/simulator, dangerous apps, debug/hooking.
- `DeviceIntegritySignature.getReport({ throwOnCompromised })` and `SecurityException` with reason codes.
- `SignatureService` for biometric signing with device signature binding (`sign`, `signChallenge`, `signEmbedding`).
- `SignatureStorage` and `StoredSignature` for local save/load of signature data.
- `SignatureVerifier` for local verification (public key and optional device signature match).
- Widgets: `DeviceIntegrityChecker`, `BiometricSignatureFlow`, `DeviceIntegrityStatusCard`, `DeviceIntegrityInfoSection`.
- Exceptions: `BiometricHardwareUnavailableException`, `UserCanceledException`.

### Requirements

- Flutter >= 3.38.0, Dart >= 3.0.0
- Android minSdk 24, compileSdk 34
- iOS 12.0+

[1.0.0]: https://github.com/your-org/secure_device_signature/releases/tag/v1.0.0
