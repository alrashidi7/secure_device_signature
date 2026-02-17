/// Result of device integrity and hardware signature generation.
///
/// [signature] is a SHA-256 hash of hardware identifiers (persistent across
/// app uninstall/reinstall where supported). [isCompromised] is true if any
/// security check failed (root/jailbreak, emulator, or debugging/hooking).
class DeviceIntegrityReport {
  /// SHA-256 hash of (HardwareID + UUID + device metadata).
  final String signature;

  /// True if device is rooted/jailbroken, emulator/simulator, or
  /// debugging/hooking was detected.
  final bool isCompromised;

  /// Device model, OS version, and UUID for auditing.
  final Map<String, dynamic> metadata;

  const DeviceIntegrityReport({
    required this.signature,
    required this.isCompromised,
    required this.metadata,
  });

  factory DeviceIntegrityReport.fromMap(Map<Object?, Object?> map) {
    final meta = map['metadata'];
    return DeviceIntegrityReport(
      signature: map['signature'] as String? ?? '',
      isCompromised: map['isCompromised'] as bool? ?? true,
      metadata: meta is Map<String, dynamic> 
          ? Map<String, dynamic>.from(meta) 
          : <String, dynamic>{},
    );
  }

  Map<String, dynamic> toMap() => {
        'signature': signature,
        'isCompromised': isCompromised,
        'metadata': metadata,
      };

  @override
  String toString() =>
      'DeviceIntegrityReport(signature: $signature, isCompromised: $isCompromised, metadata: $metadata)';
}
