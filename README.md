# secure_device_signature

A Flutter plugin that generates a **persistent, hardware-bound device signature** and runs integrity checks. The signature is designed to remain stable across app uninstall/reinstall where the platform allows. Optionally combines with **biometric signing** so the server can bind proofs to both identity and device.

---

## Features

- **Persistent signature**: SHA-256 hash of (HardwareID + UUID + device metadata).
- **Android**: Uses Widevine `MediaDrm` device unique ID and Android Keystore (StrongBox when available). Falls back to Android ID for reinstall persistence.
- **iOS**: Uses Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` so the stored UUID persists across uninstall/reinstall.
- **Integrity checks**: Integrates `flutter_root_jailbreak_checker` for root/jailbreak, emulator/simulator, and dangerous-app detection; plus native debugger/hooking checks.
- **SecurityException**: Thrown when `getReport(throwOnCompromised: true)` and the device is compromised.
- **Biometric signing**: Optional `SignatureService` for hardware-backed sign + device signature binding; `SignatureVerifier` and `SignatureStorage` for local verification and storage.
- **UI widgets**: Drop-in `DeviceIntegrityChecker`, `BiometricSignatureFlow`, status cards, and info sections.

---

## Requirements

| Requirement | Value |
|------------|--------|
| Flutter   | `>=3.38.0` |
| Dart      | `>=3.0.0 <4.0.0` |
| Android   | `minSdk 24`, `compileSdk 34` |
| iOS       | `12.0+` |

---

## Installation

### From pub.dev (when published)

```yaml
dependencies:
  secure_device_signature: ^1.0.0
```

### Local / path dependency (e.g. monorepo)

```yaml
dependencies:
  secure_device_signature:
    path: ../secure_device_signature   # or packages/secure_device_signature
```

Then run:

```bash
flutter pub get
```

---

## Integrating in your app (parent app setup)

### 1. Dependency

Add `secure_device_signature` to your app’s `pubspec.yaml` as above.

### 2. Android

- **minSdkVersion**: Your app’s `android/app/build.gradle` must use at least **24** (this package uses `minSdk 24`).
- **Biometrics**: If you use `SignatureService` (biometric signing), the plugin depends on `biometric_signature`, which uses the standard Android biometric APIs; no extra manifest permissions are required beyond what the plugin declares.
- **ProGuard**: Consumer ProGuard rules are included; no extra keep rules are required in the app.

Example alignment in the parent app:

```gradle
// android/app/build.gradle
android {
    defaultConfig {
        minSdkVersion 24   // or higher
    }
}
```

### 3. iOS

- **Deployment target**: Set your app’s iOS deployment target to **12.0** or higher (e.g. in `ios/Podfile`: `platform :ios, '12.0'`).
- **Face ID usage (optional)**: If you use biometric signing, add a usage description in `ios/Runner/Info.plist`:

```xml
<key>NSFaceIDUsageDescription</key>
<string>We use Face ID to sign your data securely.</string>
```

### 4. No extra assets or environment variables

The package does not require environment variables or additional asset configuration in the parent app.

---

## Usage

### Device integrity only

```dart
import 'package:secure_device_signature/device_integrity_signature.dart';

final api = DeviceIntegritySignature();

// Get report; throws SecurityException if device is compromised (default)
try {
  final report = await api.getReport();
  print('Signature: ${report.signature}');
  print('Compromised: ${report.isCompromised}');
  print('Metadata: ${report.metadata}');
} on SecurityException catch (e) {
  print('Blocked: ${e.reason}');
}

// Get report without throwing (inspect isCompromised yourself)
final report = await api.getReport(throwOnCompromised: false);
if (report.isCompromised) {
  // Handle compromised device
}
```

### Biometric signing with device signature

```dart
import 'package:secure_device_signature/device_integrity_signature.dart';

final service = SignatureService();

// Sign a payload (e.g. challenge from server)
final result = await service.sign(
  'challenge-from-server',
  promptMessage: 'Verify identity to sign',
  throwOnCompromised: false,
);
// result.signature, result.publicKey, result.deviceSignature, result.deviceReport
```

### Drop-in widget: device check

```dart
DeviceIntegrityChecker(
  title: 'Device security',
  subtitle: 'We verify your device to keep your data safe',
  throwOnCompromised: false,
  showInfoSection: true,
  showMetadata: false,
  onSecure: () => Navigator.push(...),
  onCompromised: () => showDialog(...),
  onError: (e) => debugPrint('$e'),
)
```

### Drop-in widget: biometric signature flow

```dart
BiometricSignatureFlow(
  throwOnCompromised: false,
  onSuccess: (result) => ...,
  onError: (error) => ...,
  onVerify: (result) {
    // POST result.signResult to your server
  },
)
```

---

## Dependency injection

The package supports both **constructor injection** (recommended for DI) and optional **singleton mode**. Control this via [SecureDeviceSignatureConfig].

**With dependency injection (default):**

```dart
// In main.dart — SecureDeviceSignatureConfig.useSingleton = false (default)
// Register with get_it, injectable, riverpod, etc.
getIt.registerSingleton<DeviceIntegritySignature>(DeviceIntegritySignature());
getIt.registerSingleton<SignatureService>(
  SignatureService(deviceIntegrity: getIt<DeviceIntegritySignature>()),
);
getIt.registerSingleton<SignatureStorage>(SignatureStorage());

// Pass into widgets
DeviceIntegrityChecker(api: getIt<DeviceIntegritySignature>());
BiometricSignatureFlow(signatureService: getIt<SignatureService>());
```

**Without DI (singleton mode):**

```dart
void main() {
  SecureDeviceSignatureConfig.useSingleton = true;
  runApp(MyApp());
}

// Later
final report = await DeviceIntegritySignature.instance.getReport();
final result = await SignatureService.instance.sign('challenge');
```

When [SecureDeviceSignatureConfig.useSingleton] is `false`, `.instance` getters throw. Call `ClassName.resetInstance()` when switching modes or in tests.

---

## API reference

### Configuration

| API | Description |
|-----|-------------|
| `SecureDeviceSignatureConfig.useSingleton` | When `false` (default), `.instance` getters throw — use constructor injection. When `true`, `DeviceIntegritySignature.instance`, `SignatureService.instance`, `SignatureStorage.instance` return cached singletons. |
| `DeviceIntegritySignature.resetInstance()` | Clears cached singleton. Same for `SignatureService`, `SignatureStorage`. |

### Core

| API | Description |
|-----|-------------|
| `DeviceIntegritySignature()` | Constructs the main API; optional `platform` for tests. |
| `Future<DeviceIntegrityReport> getReport({ bool throwOnCompromised = true })` | Returns report with `signature`, `isCompromised`, `metadata`. If `throwOnCompromised` is true and any check fails, throws `SecurityException`. |

### Report and exceptions

| Type | Description |
|------|-------------|
| `DeviceIntegrityReport` | `signature` (SHA-256 hex), `isCompromised`, `metadata` (e.g. `deviceModel`, `osVersion`, `uuid`, `platform`). |
| `SecurityException` | `reason` (e.g. `rooted`, `jailbroken`, `emulator`, `dangerous_apps`, `debug_or_hooking`), optional `message`. |

### Biometric signing

| API | Description |
|-----|-------------|
| `SignatureService({ BiometricSignature? plugin, DeviceIntegritySignature? deviceIntegrity })` | Service for signing with biometrics and attaching device signature. |
| `Future<bool> get isAvailable` | Whether biometric hardware is available. |
| `Future<void> ensureKeys({ String promptMessage = '...' })` | Ensures keys exist; creates them if needed. |
| `Future<SignResult> sign(String payload, { String promptMessage, bool throwOnCompromised = false })` | Signs `payload` and returns `SignResult` (signature, publicKey, signedPayload, deviceSignature, deviceReport). |
| `Future<SignResult> signEmbedding(List<double> embedding, { bool throwOnCompromised = false })` | Signs base64-encoded Float32 embedding. |
| `Future<SignResult> signChallenge(String challenge, { String promptMessage, bool throwOnCompromised = false })` | Signs a server challenge. |
| `Future<bool> deleteKeys()` | Deletes biometric keys. |

| Type | Description |
|------|-------------|
| `SignResult` | `signature`, `publicKey`, `signedPayload`, `deviceSignature`, `deviceReport`. |
| `BiometricHardwareUnavailableException` | Thrown when biometric hardware is unavailable. |
| `UserCanceledException` | Thrown when the user dismisses the biometric prompt. |

### Storage and verification

| API | Description |
|-----|-------------|
| `SignatureStorage({ String filename = 'stored_signature.json' })` | Saves/loads `StoredSignature` to app documents. |
| `StoredSignature` | `biometricSignature`, `biometricPublicKey`, `signedPayload`, `deviceSignature`, `metadata`. |
| `SignatureVerifier({ bool requireDeviceSignatureMatch = false })` | Verifies a new `SignResult` against stored data. |
| `VerifyResult` | `VerifySuccess`, `VerifyDeviceMismatch`, or `VerifyError`. |

### Widgets (exported from `package:secure_device_signature/device_integrity_signature.dart`)

| Widget | Description |
|--------|-------------|
| `DeviceIntegrityChecker` | Full UI: header, “Check” button, status card, optional info section. Parameters: `api`, `throwOnCompromised`, `showInfoSection`, `showMetadata`, `title`, `subtitle`, `checkButtonLabel`, `onSecure`, `onCompromised`, `onError`. |
| `BiometricSignatureFlow` | Flow: device integrity → keys → authenticate → sign. Parameters: `signatureService`, `initialPayload` (e.g. `DeviceSignaturePayload()` or `ChallengePayload(challenge)`), `title`, `subtitle`, `throwOnCompromised`, `onSuccess`, `onError`, `onVerify`. |
| `DeviceIntegrityStatusCard` | Status card for a `DeviceIntegrityReport`; `showMetadata`, `compact`. |
| `DeviceIntegrityInfoSection` | Explains what is checked; `title`, `subtitle`, `showAllChecks`, `compact`. |

---

## Security notes

- Integrity checks run on the device and can be bypassed on a fully compromised system. For high-assurance scenarios, combine with server-side attestation (e.g. Google Play Integrity, Apple App Attest).
- On Android, the Widevine device ID may be app-scoped on API 26+; the package still provides a stable signature per device using Android ID and Keystore where needed.
- Full cryptographic verification of biometric signatures (RSA verify) should be done server-side; `SignatureVerifier` is for local “same device / same key” checks.

---

## License

See the [LICENSE](LICENSE) file.
