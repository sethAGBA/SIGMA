import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sigma/core/services/key_derivation_service.dart';

import '../helpers/phase1_test_helpers.dart';

void main() {
  setUpAll(initPhase1TestBindings);

  tearDown(tearDownPhase1Services);

  group('Property 12 — Dérivation de clé déterministe', () {
    test('100 itérations : deux appels successifs retournent la même clé', () async {
      const storage = FlutterSecureStorage();
      final service = KeyDerivationService();

      for (var i = 0; i < 100; i++) {
        resetPhase1SecureStorage({'sigma_db_key': 'secret-$i-fixed-hex-value-32chars'});
        final first = await service.getDatabaseKey();
        final second = await service.getDatabaseKey();
        expect(second, first);
        expect(await storage.read(key: 'sigma_db_key'), isNotNull);
      }
    });
  });
}
