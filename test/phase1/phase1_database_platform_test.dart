import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sigma/core/services/database_service.dart';
import 'package:sigma/core/services/key_derivation_service.dart';

import '../helpers/phase1_test_helpers.dart';

void main() {
  setUpAll(initPhase1TestBindings);

  tearDown(tearDownPhase1Services);

  group('DatabaseService — branchement plateforme (10.4)', () {
    test('force desktop → branche desktop', () {
      DatabaseService.forceMobilePlatformForTesting = false;
      expect(DatabaseService().platformBranchForTesting(), 'desktop');
    });

    test('force mobile → branche mobile', () {
      DatabaseService.forceMobilePlatformForTesting = true;
      expect(DatabaseService().platformBranchForTesting(), 'mobile');
    });

    test('force mobile + clé indisponible → exception propagée', () async {
      final svc = DatabaseService();
      DatabaseService.forceMobilePlatformForTesting = true;
      svc.databaseKeyProviderOverride = () async {
        throw EncryptionKeyException('clé indisponible');
      };
      svc.mobileOpenOverride =
          ({
            required String path,
            required String password,
            required int version,
            required Future<void> Function(Database db, int version) onCreate,
            required Future<void> Function(Database db, int oldVersion, int newVersion)
                onUpgrade,
          }) async {
            fail('openEncryptedDatabase ne doit pas être appelé');
          };

      expect(
        svc.openMobileDatabaseForTesting(inMemoryDatabasePath),
        throwsA(isA<EncryptionKeyException>()),
      );
    });

    test('force mobile + override ouverture → branche mobile', () async {
      final svc = DatabaseService();
      DatabaseService.forceMobilePlatformForTesting = true;
      svc.databaseKeyProviderOverride = () async => 'test-db-key';
      var opened = false;
      svc.mobileOpenOverride =
          ({
            required String path,
            required String password,
            required int version,
            required Future<void> Function(Database db, int version) onCreate,
            required Future<void> Function(Database db, int oldVersion, int newVersion)
                onUpgrade,
          }) async {
            opened = true;
            expect(password, 'test-db-key');
            return databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
          };

      await svc.openMobileDatabaseForTesting(inMemoryDatabasePath);
      expect(opened, isTrue);
    });
  });
}
