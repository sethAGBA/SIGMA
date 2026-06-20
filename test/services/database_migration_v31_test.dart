// test/services/database_migration_v31_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> _createV30Schema(dynamic db) async {
  await db.execute('''
    CREATE TABLE demandes_pret (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      client_id INTEGER,
      montant_demande REAL,
      photos_visite TEXT
    )
  ''');

  await db.execute('''
    CREATE TABLE remboursements (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      pret_id INTEGER,
      montant_total REAL,
      numero_recu TEXT
    )
  ''');
}

Future<void> _applyPhase5Migration(dynamic db) async {
  Future<void> addIfMissing(
    String table,
    String column,
    String definition,
  ) async {
    final info = await db.rawQuery('PRAGMA table_info($table)') as List;
    if (!info.any((r) => r['name'] == column)) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  await addIfMissing('demandes_pret', 'latitude_visite', 'REAL');
  await addIfMissing('demandes_pret', 'longitude_visite', 'REAL');
  await addIfMissing('remboursements', 'latitude', 'REAL');
  await addIfMissing('remboursements', 'longitude', 'REAL');
  await addIfMissing('remboursements', 'photo_justificatif_path', 'TEXT');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS sync_conflicts (
      id TEXT PRIMARY KEY,
      sync_queue_id TEXT NOT NULL,
      entity_type TEXT NOT NULL,
      entity_id TEXT,
      local_payload TEXT NOT NULL,
      server_payload TEXT NOT NULL,
      local_updated_at TEXT,
      server_updated_at TEXT,
      resolution TEXT NOT NULL DEFAULT 'pending',
      created_at TEXT NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS field_snapshot_meta (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      agent_id TEXT NOT NULL,
      snapshot_date TEXT NOT NULL,
      created_at TEXT NOT NULL,
      client_count INTEGER DEFAULT 0,
      schedule_count INTEGER DEFAULT 0,
      request_count INTEGER DEFAULT 0
    )
  ''');
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Migration v30→v31', () {
    late dynamic db;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (d, _) async => _createV30Schema(d),
        ),
      );
      await _applyPhase5Migration(db);
    });

    tearDown(() async => db.close());

    test('colonnes GPS et photo présentes', () async {
      final demandes =
          await db.rawQuery('PRAGMA table_info(demandes_pret)') as List;
      expect(demandes.any((r) => r['name'] == 'latitude_visite'), isTrue);
      expect(demandes.any((r) => r['name'] == 'longitude_visite'), isTrue);

      final remb =
          await db.rawQuery('PRAGMA table_info(remboursements)') as List;
      expect(remb.any((r) => r['name'] == 'latitude'), isTrue);
      expect(remb.any((r) => r['name'] == 'longitude'), isTrue);
      expect(remb.any((r) => r['name'] == 'photo_justificatif_path'), isTrue);
    });

    test('tables sync_conflicts et field_snapshot_meta existent', () async {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' "
        "AND name IN ('sync_conflicts', 'field_snapshot_meta')",
      ) as List;
      expect(tables.length, 2);
    });

    test('migration idempotente', () async {
      await expectLater(_applyPhase5Migration(db), completes);
    });
  });
}
