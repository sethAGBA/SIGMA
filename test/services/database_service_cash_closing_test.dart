// test/services/database_service_cash_closing_test.dart
//
// Tests unitaires pour DatabaseService.getLastCashClosing()
// Exigences : 5.1 (interroger la table clotures_caisse), 5.3 (retourner null si vide)

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sigma/core/services/database_service.dart';
import 'package:sigma/models/cash_closing_model.dart';

/// Crée la table `clotures_caisse` dans la base en mémoire fournie.
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

/// Insère une clôture de test dans la base.
Future<void> _insertCashClosing(Database db, CashClosing closing) async {
  await db.insert('clotures_caisse', closing.toMap());
}

void main() {
  // Initialiser sqflite_common_ffi pour les tests desktop/unit
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() {
    // Réinitialiser la base injectée après chaque test
    DatabaseService.resetDatabaseForTesting();
  });

  group('DatabaseService.getLastCashClosing()', () {
    test(
      'Cas 1 : table vide → retourne null (Exigence 5.3)',
      () async {
        // Arrange : base en mémoire avec table vide
        final db = await databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
          options: OpenDatabaseOptions(version: 1, onCreate: (db, _) async {
            await _createCashClosingTable(db);
          }),
        );
        DatabaseService.setDatabaseForTesting(db);

        // Act
        final result = await DatabaseService().getLastCashClosing();

        // Assert
        expect(result, isNull);

        await db.close();
      },
    );

    test(
      'Cas 2 : une clôture présente → retourne la bonne valeur (Exigence 5.1)',
      () async {
        // Arrange : base en mémoire avec une clôture insérée
        final db = await databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
          options: OpenDatabaseOptions(version: 1, onCreate: (db, _) async {
            await _createCashClosingTable(db);
          }),
        );
        DatabaseService.setDatabaseForTesting(db);

        final closing = CashClosing(
          dateCloture: DateTime(2024, 6, 15, 18, 0),
          agentCloture: 'test_agent',
          soldeInitial: 100000.0,
          totalEntrees: 50000.0,
          totalSorties: 20000.0,
          soldeTheorique: 130000.0,
          soldePhysique: 129500.0,
          ecart: -500.0,
          observations: 'Clôture test',
        );
        await _insertCashClosing(db, closing);

        // Act
        final result = await DatabaseService().getLastCashClosing();

        // Assert
        expect(result, isNotNull);
        expect(result!.agentCloture, equals('test_agent'));
        expect(result.soldePhysique, equals(129500.0));
        expect(result.totalEntrees, equals(50000.0));
        expect(result.totalSorties, equals(20000.0));
        expect(result.ecart, equals(-500.0));

        await db.close();
      },
    );

    test(
      'Cas 3 : plusieurs clôtures → retourne la plus récente (Exigence 5.1)',
      () async {
        // Arrange : base en mémoire avec deux clôtures à des dates différentes
        final db = await databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
          options: OpenDatabaseOptions(version: 1, onCreate: (db, _) async {
            await _createCashClosingTable(db);
          }),
        );
        DatabaseService.setDatabaseForTesting(db);

        final ancienne = CashClosing(
          dateCloture: DateTime(2024, 6, 14, 18, 0),
          agentCloture: 'agent_1',
          soldeInitial: 80000.0,
          totalEntrees: 30000.0,
          totalSorties: 10000.0,
          soldeTheorique: 100000.0,
          soldePhysique: 99000.0,
          ecart: -1000.0,
        );

        final recente = CashClosing(
          dateCloture: DateTime(2024, 6, 15, 18, 0),
          agentCloture: 'agent_2',
          soldeInitial: 99000.0,
          totalEntrees: 45000.0,
          totalSorties: 15000.0,
          soldeTheorique: 129000.0,
          soldePhysique: 128000.0,
          ecart: -1000.0,
        );

        await _insertCashClosing(db, ancienne);
        await _insertCashClosing(db, recente);

        // Act
        final result = await DatabaseService().getLastCashClosing();

        // Assert : doit retourner la clôture la plus récente
        expect(result, isNotNull);
        expect(result!.agentCloture, equals('agent_2'));
        expect(result.soldePhysique, equals(128000.0));

        await db.close();
      },
    );
  });
}
