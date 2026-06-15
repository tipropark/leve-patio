import 'package:flutter_test/flutter_test.dart';
import 'package:leve_patio/features/sync/data/sync_engine.dart';

void main() {
  group('SyncEngine._proximaTentativa (via SyncEngine.proximaTentativaMs)', () {
    // _proximaTentativa is private; we expose a testable static via a thin
    // public wrapper only in test builds. Here we test the math directly
    // by calling the white-box helper exposed for tests.

    test('tentativa 0 → 2 min (2^1 = 2)', () {
      final ms = SyncEngine.proximaTentativaMs(0);
      final minutos = (ms - DateTime.now().millisecondsSinceEpoch) / 60000;
      expect(minutos, closeTo(2, 0.05));
    });

    test('tentativa 1 → 4 min (2^2 = 4)', () {
      final ms = SyncEngine.proximaTentativaMs(1);
      final minutos = (ms - DateTime.now().millisecondsSinceEpoch) / 60000;
      expect(minutos, closeTo(4, 0.05));
    });

    test('tentativa 2 → 8 min (2^3 = 8)', () {
      final ms = SyncEngine.proximaTentativaMs(2);
      final minutos = (ms - DateTime.now().millisecondsSinceEpoch) / 60000;
      expect(minutos, closeTo(8, 0.05));
    });

    test('tentativa 5 → 64 min → clampado em 60 min', () {
      final ms = SyncEngine.proximaTentativaMs(5);
      final minutos = (ms - DateTime.now().millisecondsSinceEpoch) / 60000;
      expect(minutos, closeTo(60, 0.05));
    });

    test('tentativa 99 → sempre 60 min (teto)', () {
      final ms = SyncEngine.proximaTentativaMs(99);
      final minutos = (ms - DateTime.now().millisecondsSinceEpoch) / 60000;
      expect(minutos, closeTo(60, 0.05));
    });
  });
}
