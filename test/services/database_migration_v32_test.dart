// test/services/database_migration_v32_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> _applyPhase6Migration(dynamic db) async {
  final existing = await db.query(
    'configurations',
    where: 'key = ?',
    whereArgs: ['plan_comptable_type'],
  );
  if (existing.isEmpty) {
    await db.insert('configurations', {
      'key': 'plan_comptable_type',
      'value': 'syscohada',
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Migration v31→v32 (Phase 6)', () {
    late Database db;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 32,
          onCreate: (database, version) async {
            await database.execute('''
              CREATE TABLE configurations (
                key TEXT PRIMARY KEY,
                value TEXT
              )
            ''');
            await _applyPhase6Migration(database);
          },
          onUpgrade: (database, oldVersion, newVersion) async {
            if (oldVersion < 32) {
              await _applyPhase6Migration(database);
            }
          },
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('onCreate insère plan_comptable_type', () async {
      final rows = await db.query(
        'configurations',
        where: 'key = ?',
        whereArgs: ['plan_comptable_type'],
      );
      expect(rows.length, 1);
      expect(rows.first['value'], 'syscohada');
    });

    test('migration v31→v32 idempotente', () async {
      await _applyPhase6Migration(db);
      await _applyPhase6Migration(db);

      final rows = await db.query(
        'configurations',
        where: 'key = ?',
        whereArgs: ['plan_comptable_type'],
      );
      expect(rows.length, 1);
      expect(rows.first['value'], 'syscohada');
    });
  });
}
