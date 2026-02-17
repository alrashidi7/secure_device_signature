/// Thrown when device integrity checks fail: rooted/jailbroken device,
/// emulator/simulator, or debugging/hooking detected.
class SecurityException implements Exception {
  /// Short reason code (e.g. rooted, jailbroken, emulator, debug).
  final String reason;

  /// Optional detailed message.
  final String? message;

  SecurityException(this.reason, [this.message]);

  @override
  String toString() =>
      message != null ? 'SecurityException($reason): $message' : 'SecurityException($reason)';
}
