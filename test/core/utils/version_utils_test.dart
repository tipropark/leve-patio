import 'package:flutter_test/flutter_test.dart';
import 'package:leve_patio/core/utils/version_utils.dart';

void main() {
  group('VersionUtils.isUpdateRequired', () {
    test('igual → não requer update', () {
      expect(VersionUtils.isUpdateRequired('1.0.0', '1.0.0'), isFalse);
    });

    test('current > min (patch) → não requer update', () {
      expect(VersionUtils.isUpdateRequired('1.0.1', '1.0.0'), isFalse);
    });

    test('current > min (minor) → não requer update', () {
      expect(VersionUtils.isUpdateRequired('1.2.0', '1.1.0'), isFalse);
    });

    test('current > min (major) → não requer update', () {
      expect(VersionUtils.isUpdateRequired('2.0.0', '1.9.9'), isFalse);
    });

    test('current < min (patch) → requer update', () {
      expect(VersionUtils.isUpdateRequired('1.0.0', '1.0.1'), isTrue);
    });

    test('current < min (minor) → requer update', () {
      expect(VersionUtils.isUpdateRequired('1.0.5', '1.1.0'), isTrue);
    });

    test('current < min (major) → requer update', () {
      expect(VersionUtils.isUpdateRequired('1.9.9', '2.0.0'), isTrue);
    });

    test('ignora sufixos extras na versão (1.0.0-beta)', () {
      expect(VersionUtils.isUpdateRequired('1.0.0-beta', '1.0.0'), isFalse);
    });

    test('versão com apenas major.minor (2 partes)', () {
      // Faltando patch → tratado como 0
      expect(VersionUtils.isUpdateRequired('1.1', '1.1.0'), isFalse);
      expect(VersionUtils.isUpdateRequired('1.0', '1.0.1'), isTrue);
    });
  });
}
