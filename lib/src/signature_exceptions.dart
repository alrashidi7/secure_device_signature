/// Exceptions thrown by [SignatureService].
sealed class SignatureException implements Exception {
  const SignatureException(this.message, [this.details]);
  final String message;
  final String? details;

  @override
  String toString() => details != null ? '$message ($details)' : message;
}

/// Device does not support or has no available biometric hardware for signing.
final class BiometricHardwareUnavailableException extends SignatureException {
  const BiometricHardwareUnavailableException([String? details])
      : super('Biometric hardware unavailable', details);
}

/// User canceled the flow (e.g. biometric prompt dismissed).
final class UserCanceledException extends SignatureException {
  const UserCanceledException([String? details])
      : super('User canceled', details);
}
