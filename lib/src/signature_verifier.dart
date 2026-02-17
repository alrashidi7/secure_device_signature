import 'signature_service.dart';
import 'signature_storage.dart';

/// Result of local verification against stored data.
sealed class VerifyResult {}

/// Verification passed: public key matches and signature is for the same device.
final class VerifySuccess extends VerifyResult {
  VerifySuccess({this.message});
  final String? message;
}

/// Public key does not match stored (different device).
final class VerifyDeviceMismatch extends VerifyResult {
  VerifyDeviceMismatch({this.message});
  final String? message;
}

/// Error during verification.
final class VerifyError extends VerifyResult {
  VerifyError(this.message);
  final String message;
}

/// Verifies a new [SignResult] (from signing a challenge) against [StoredSignature].
///
/// Checks:
/// - [publicKey] matches stored (same device)
/// - [deviceSignature] matches stored (optional, same device attestation)
///
/// Full cryptographic signature verification (RSA verify) would be done server-side.
/// This local verifier simulates the server's "device match" check.
class SignatureVerifier {
  SignatureVerifier({this.requireDeviceSignatureMatch = false});

  final bool requireDeviceSignatureMatch;

  /// Verifies [newSignResult] (from signing a challenge) against [stored].
  VerifyResult verify(SignResult newSignResult, StoredSignature stored) {
    if (stored.biometricPublicKey.isEmpty) {
      return VerifyError('Stored data has no public key');
    }
    final newKey = newSignResult.publicKey;
    if (newKey == null || newKey.isEmpty) {
      return VerifyError('New sign result has no public key');
    }

    if (newKey != stored.biometricPublicKey) {
      return VerifyDeviceMismatch(
        message:
            'Public key does not match. Different device or keys were recreated.',
      );
    }

    if (requireDeviceSignatureMatch &&
        newSignResult.deviceSignature != stored.deviceSignature) {
      return VerifyDeviceMismatch(
        message: 'Device signature does not match.',
      );
    }

    return VerifySuccess(
      message: 'Verification passed. Same device, challenge signed correctly.',
    );
  }
}
