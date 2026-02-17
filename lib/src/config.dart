/// Configuration for [secure_device_signature] package behavior.
///
/// Use this to control whether the package uses singleton instances for its
/// main services. When using dependency injection in your main app, set
/// [useSingleton] to `false` (default) and inject [DeviceIntegritySignature],
/// [SignatureService], and [SignatureStorage] via your DI container.
///
/// Example with DI (recommended):
/// ```dart
/// void main() {
///   SecureDeviceSignatureConfig.useSingleton = false;
///   // Register services in your DI container
///   getIt.registerSingleton<DeviceIntegritySignature>(DeviceIntegritySignature());
///   getIt.registerSingleton<SignatureService>(SignatureService());
///   runApp(MyApp());
/// }
/// ```
///
/// Example without DI (singleton mode):
/// ```dart
/// void main() {
///   SecureDeviceSignatureConfig.useSingleton = true;
///   runApp(MyApp());
/// }
/// // Later: DeviceIntegritySignature.instance, SignatureService.instance
/// ```
class SecureDeviceSignatureConfig {
  SecureDeviceSignatureConfig._();

  /// When `true`, [DeviceIntegritySignature.instance], [SignatureService.instance],
  /// and [SignatureStorage.instance] return cached singleton instances.
  ///
  /// When `false` (default), those static getters throw. Use constructor
  /// injection instead — ideal for apps using get_it, injectable, riverpod, etc.
  static bool useSingleton = false;

  /// When switching from singleton to DI or resetting for tests, call:
  /// [DeviceIntegritySignature.resetInstance()],
  /// [SignatureService.resetInstance()],
  /// [SignatureStorage.resetInstance()].
}