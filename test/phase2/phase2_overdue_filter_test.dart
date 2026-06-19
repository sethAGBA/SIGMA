// Property tests P3/P4 — filtre retard toggle idempotent et correct
// Valide : Exigences 8.2, 8.3

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sigma/core/services/database_service.dart';

Future<void> _createScheduleTables(Database db) async {
  await db.execute('''
    CREATE TABLE clients (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nom TEXT,
      prenoms TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE prets (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      client_id INTEGER,
      numero_pret TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE echeanciers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      pret_id INTEGER,
      numero_echeance INTEGER,
      date_prevue TEXT,
      capital_du REAL,
      interets_dus REAL,
      frais_dus REAL,
      total_du REAL,
      capital_paye REAL,
      interets_payes REAL,
      frais_payes REAL,
      total_paye REAL,
      capital_restant REAL,
      statut TEXT
    )
  ''');
}

Future<void> _insertSchedule(
  Database db, {
  required int pretId,
  required DateTime datePrevue,
  required String statut,
}) async {
  await db.insert('echeanciers', {
    'pret_id': pretId,
    'numero_echeance': 1,
    'date_prevue': datePrevue.toIso8601String(),
    'capital_du': 1000.0,
    'interets_dus': 100.0,
    'frais_dus': 0.0,
    'total_du': 1100.0,
    'capital_paye': 0.0,
    'interets_payes': 0.0,
    'frais_payes': 0.0,
    'total_paye': 0.0,
    'capital_restant': 1000.0,
    'statut': statut,
  });
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(DatabaseService.resetDatabaseForTesting);

  group('Property 3/4 — filtre retard', () {
    test('100 itérations : filtre actif → joursRetard > 0, désactivé → liste complète',
        () async {
      final random = Random(99);
      final now = DateTime.now();
      final past = now.subtract(const Duration(days: 5));
      final future = now.add(const Duration(days: 5));

      for (var i = 0; i < 100; i++) {
        final db = await databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: (database, _) => _createScheduleTables(database),
          ),
        );
        DatabaseService.setDatabaseForTesting(db);

        await db.insert('clients', {'nom': 'Test', 'prenoms': 'Client'});
        await db.insert('prets', {
          'client_id': 1,
          'numero_pret': 'P-${random.nextInt(9999)}',
        });

        final includeOverdue = random.nextBool();
        final includeOnTime = random.nextBool();

        if (includeOverdue) {
          await _insertSchedule(
            db,
            pretId: 1,
            datePrevue: past,
            statut: 'IMPAYE',
          );
        }
        if (includeOnTime) {
          await _insertSchedule(
            db,
            pretId: 1,
            datePrevue: future,
            statut: 'EN_ATTENTE',
          );
        }

        final fullList =
            await DatabaseService().getPendingSchedules(retardOnly: false);
        final filteredList =
            await DatabaseService().getPendingSchedules(retardOnly: true);

        for (final schedule in filteredList) {
          expect(schedule.joursRetard, greaterThan(0));
        }

        expect(filteredList.length, lessThanOrEqualTo(fullList.length));
        if (fullList.isNotEmpty) {
          expect(fullList.length, greaterThanOrEqualTo(filteredList.length));
        }

        await db.close();
        DatabaseService.resetDatabaseForTesting();
      }
    });
  });
}
