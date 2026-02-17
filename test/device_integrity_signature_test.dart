import 'package:secure_device_signature/device_integrity_signature.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeviceIntegrityReport', () {
    test('fromMap round-trip', () {
      final report = DeviceIntegrityReport(
        signature: 'abc123',
        isCompromised: false,
        metadata: {'deviceModel': 'Test', 'osVersion': '1.0'},
      );
      final map = report.toMap();
      final restored = DeviceIntegrityReport.fromMap(
        map.map((k, v) => MapEntry<Object?, Object?>(k, v)),
      );
      expect(restored.signature, report.signature);
      expect(restored.isCompromised, report.isCompromised);
      expect(restored.metadata, report.metadata);
    });
  });

  group('SecurityException', () {
    test('toString with message', () {
      final e = SecurityException('rooted', 'Device is rooted');
      expect(e.toString(), contains('rooted'));
      expect(e.toString(), contains('Device is rooted'));
    });
    test('toString without message', () {
      final e = SecurityException('emulator');
      expect(e.reason, 'emulator');
      expect(e.message, isNull);
    });
  });
}
