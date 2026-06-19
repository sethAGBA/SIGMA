// Property test P2 — continuité du solde de caisse entre clôtures
// Valide : Exigence 5.2

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sigma/core/services/database_service.dart';
import 'package:sigma/models/cash_closing_model.dart';

Future<void> _createCashClosingTable(Database db) async {
  await db.execute('''
    CREATE TABLE clotures_caisse (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date_cloture TEXT NOT NULL,
      agent_cloture TEXT NOT NULL,
      solde_initial REAL,
      total_entrees REAL,
      total_sorties REAL,
      solde_theorique REAL,
      solde_physique REAL,
      ecart REAL,
      observations TEXT,
      billetage TEXT
    )
  ''');
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(DatabaseService.resetDatabaseForTesting);

  group('Property 2 — continuité du solde de caisse', () {
    test('100 itérations : soldeInitial = soldePhysique de la clôture précédente',
        () async {
      final random = Random(7);

      for (var i = 0; i < 100; i++) {
        final db = await databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: (database, _) => _createCashClosingTable(database),
          ),
        );
        DatabaseService.setDatabaseForTesting(db);

        final soldePhysique = random.nextDouble() * 1_000_000 + 1;

        final c1 = CashClosing(
          dateCloture: DateTime(2024, 6, 14, 18),
          agentCloture: 'agent_test',
          soldeInitial: 0,
          totalEntrees: soldePhysique,
          totalSorties: 0,
          soldeTheorique: soldePhysique,
          soldePhysique: soldePhysique,
          ecart: 0,
        );
        await DatabaseService().insertCashClosing(c1);

        final last = await DatabaseService().getLastCashClosing();
        final soldeInitial = last?.soldePhysique ?? 0.0;

        expect(soldeInitial, closeTo(soldePhysique, 0.001));

        await db.close();
        DatabaseService.resetDatabaseForTesting();
      }
    });
  });
}
