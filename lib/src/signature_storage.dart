import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'config.dart';
import 'signature_service.dart';

/// Stored registration data (acts as server-stored record for local testing).
class StoredSignature {
  const StoredSignature({
    required this.biometricSignature,
    required this.biometricPublicKey,
    required this.signedPayload,
    required this.deviceSignature,
    this.metadata = const {},
  });

  final String biometricSignature;
  final String biometricPublicKey;
  final String signedPayload;
  final String deviceSignature;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() => {
        'biometricSignature': biometricSignature,
        'biometricPublicKey': biometricPublicKey,
        'signedPayload': signedPayload,
        'deviceSignature': deviceSignature,
        'metadata': metadata,
      };

  factory StoredSignature.fromJson(Map<String, dynamic> json) {
    final meta = json['metadata'];
    return StoredSignature(
      biometricSignature: json['biometricSignature'] as String? ?? '',
      biometricPublicKey: json['biometricPublicKey'] as String? ?? '',
      signedPayload: json['signedPayload'] as String? ?? '',
      deviceSignature: json['deviceSignature'] as String? ?? '',
      metadata: meta is Map<String, dynamic>
          ? Map<String, dynamic>.from(meta)
          : <String, dynamic>{},
    );
  }

  static StoredSignature fromSignResult(SignResult r) {
    return StoredSignature(
      biometricSignature: r.signature,
      biometricPublicKey: r.publicKey ?? '',
      signedPayload: r.signedPayload,
      deviceSignature: r.deviceSignature,
      metadata: r.deviceReport.metadata,
    );
  }
}

/// Save and load [StoredSignature] to a local JSON file (simulates server storage for testing).
class SignatureStorage {
  static SignatureStorage? _instance;

  SignatureStorage({this.filename = 'stored_signature.json'});

  final String filename;

  /// Returns the singleton instance when [SecureDeviceSignatureConfig.useSingleton]
  /// is `true`. When `false`, throws — use constructor injection instead.
  static SignatureStorage get instance {
    if (!SecureDeviceSignatureConfig.useSingleton) {
      throw StateError(
        'SignatureStorage.instance is disabled. Set '
        'SecureDeviceSignatureConfig.useSingleton = true, or use constructor '
        'injection (recommended for DI).',
      );
    }
    return _instance ??= SignatureStorage();
  }

  /// Clears the cached singleton. Call when switching to DI or in tests.
  static void resetInstance() {
    _instance = null;
  }

  Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, filename));
  }

  /// Saves [data] to local JSON file.
  Future<void> save(StoredSignature data) async {
    final file = await _file;
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data.toJson()),
    );
  }

  /// Loads stored data from file. Returns null if file does not exist or is invalid.
  Future<StoredSignature?> load() async {
    final file = await _file;
    if (!await file.exists()) return null;
    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>?;
      if (json == null) return null;
      return StoredSignature.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Deletes the stored file.
  Future<void> delete() async {
    final file = await _file;
    if (await file.exists()) {
      await file.delete();
    }
  }
}
