// test/services/database_migration_v30_test.dart
//
// Vérifie que la migration v29→v30 (Phase 4) ajoute correctement
// toutes les colonnes et tables attendues, et que ces colonnes
// acceptent des valeurs NULL.

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Recrée le schéma minimal simulant une base v29 (pré-Phase4),
/// puis applique la migration Phase 4 localement.
Future<void> _createV29Schema(dynamic db) async {
  await db.execute('''
    CREATE TABLE produits_financiers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nom TEXT NOT NULL,
      code TEXT UNIQUE NOT NULL,
      type TEXT NOT NULL,
      taux_interet REAL
    )
  ''');

  await db.execute('''
    CREATE TABLE prets (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      numero_pret TEXT UNIQUE NOT NULL,
      montant_initial REAL,
      statut TEXT
    )
  ''');

  await db.execute('''
    CREATE TABLE demandes_pret (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      client_id INTEGER,
      montant_demande REAL
    )
  ''');

  await db.execute('''
    CREATE TABLE comptes_epargne (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      client_id INTEGER NOT NULL,
      produit_id INTEGER NOT NULL,
      numero_compte TEXT UNIQUE NOT NULL,
      solde REAL DEFAULT 0.0,
      interets_acquis REAL DEFAULT 0.0,
      statut TEXT NOT NULL,
      date_ouverture TEXT NOT NULL,
      taux_interet_applique REAL
    )
  ''');

  await db.execute('''
    CREATE TABLE utilisateurs_systeme (
      id TEXT PRIMARY KEY,
      agent_id TEXT NOT NULL,
      username TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      role TEXT NOT NULL
    )
  ''');
}

/// Réplique la logique de `DatabaseService._addColumnIfNotExists` +
/// `DatabaseService._applyPhase4Schema`.
Future<void> _applyPhase4Migration(dynamic db) async {
  Future<void> addIfMissing(
      String table, String column, String definition) async {
    final info =
        await db.rawQuery('PRAGMA table_info($table)') as List<Map>;
    final exists = info.any((r) => r['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  await addIfMissing('produits_financiers', 'taux_assurance', 'REAL');
  await addIfMissing(
      'produits_financiers', 'duree_max_differe_capital_mois', 'INTEGER');
  await addIfMissing('prets', 'mois_differe_capital', 'INTEGER DEFAULT 0');
  await addIfMissing('prets', 'contrat_signe', 'INTEGER DEFAULT 0');
  await addIfMissing(
      'demandes_pret', 'mois_differe_capital', 'INTEGER DEFAULT 0');
  await addIfMissing(
      'comptes_epargne', 'date_echeance_terme', 'TEXT');
  await addIfMissing(
      'comptes_epargne', 'taux_penalite_rupture_ant', 'REAL');
  await addIfMissing('utilisateurs_systeme', 'supervisor_pin', 'TEXT');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS documents_clients (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      client_id INTEGER NOT NULL,
      type_document TEXT NOT NULL,
      nom_fichier TEXT NOT NULL,
      chemin_local TEXT NOT NULL,
      date_ajout TEXT NOT NULL,
      FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE CASCADE
    )
  ''');
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // ---------------------------------------------------------------------------
  // 1. Présence des colonnes Phase 4
  // ---------------------------------------------------------------------------

  group('Migration v29→v30 — présence des colonnes', () {
    late dynamic db;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (d, _) async => await _createV29Schema(d),
        ),
      );
      await _applyPhase4Migration(db);
    });

    tearDown(() async => await db.close());

    test('produits_financiers a taux_assurance', () async {
      final info =
          await db.rawQuery('PRAGMA table_info(produits_financiers)') as List;
      expect(info.any((r) => r['name'] == 'taux_assurance'), isTrue,
          reason: 'La colonne taux_assurance doit exister');
    });

    test('produits_financiers a duree_max_differe_capital_mois', () async {
      final info =
          await db.rawQuery('PRAGMA table_info(produits_financiers)') as List;
      expect(
          info.any((r) => r['name'] == 'duree_max_differe_capital_mois'),
          isTrue,
          reason:
              'La colonne duree_max_differe_capital_mois doit exister');
    });

    test('prets a mois_differe_capital', () async {
      final info =
          await db.rawQuery('PRAGMA table_info(prets)') as List;
      expect(info.any((r) => r['name'] == 'mois_differe_capital'), isTrue,
          reason: 'La colonne mois_differe_capital doit exister dans prets');
    });

    test('prets a contrat_signe', () async {
      final info =
          await db.rawQuery('PRAGMA table_info(prets)') as List;
      expect(info.any((r) => r['name'] == 'contrat_signe'), isTrue,
          reason: 'La colonne contrat_signe doit exister dans prets');
    });

    test('comptes_epargne a date_echeance_terme', () async {
      final info =
          await db.rawQuery('PRAGMA table_info(comptes_epargne)') as List;
      expect(
          info.any((r) => r['name'] == 'date_echeance_terme'), isTrue,
          reason: 'La colonne date_echeance_terme doit exister');
    });

    test('comptes_epargne a taux_penalite_rupture_ant', () async {
      final info =
          await db.rawQuery('PRAGMA table_info(comptes_epargne)') as List;
      expect(
          info.any((r) => r['name'] == 'taux_penalite_rupture_ant'),
          isTrue,
          reason: 'La colonne taux_penalite_rupture_ant doit exister');
    });

    test('table documents_clients existe', () async {
      final tables = await db.rawQuery(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='documents_clients'")
          as List;
      expect(tables, isNotEmpty,
          reason: 'La table documents_clients doit être créée');
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Les nouvelles colonnes acceptent NULL
  // ---------------------------------------------------------------------------

  group('Migration v29→v30 — colonnes acceptent NULL', () {
    late dynamic db;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (d, _) async => await _createV29Schema(d),
        ),
      );
      await _applyPhase4Migration(db);
    });

    tearDown(() async => await db.close());

    test('INSERT dans produits_financiers avec taux_assurance NULL', () async {
      await expectLater(
        db.insert('produits_financiers', {
          'nom': 'Test',
          'code': 'TST',
          'type': 'credit',
          'taux_interet': 10.0,
          'taux_assurance': null,
          'duree_max_differe_capital_mois': null,
        }),
        completes,
      );
    });

    test('INSERT dans prets avec mois_differe_capital NULL', () async {
      await expectLater(
        db.insert('prets', {
          'numero_pret': 'P001',
          'montant_initial': 100000.0,
          'statut': 'actif',
          'mois_differe_capital': null,
        }),
        completes,
      );
    });

    test(
        'INSERT dans comptes_epargne avec date_echeance_terme et '
        'taux_penalite_rupture_ant NULL', () async {
      await expectLater(
        db.insert('comptes_epargne', {
          'client_id': 1,
          'produit_id': 1,
          'numero_compte': 'CEP-1-202501',
          'solde': 0.0,
          'interets_acquis': 0.0,
          'statut': 'actif',
          'date_ouverture': DateTime.now().toIso8601String(),
          'taux_interet_applique': null,
          'date_echeance_terme': null,
          'taux_penalite_rupture_ant': null,
        }),
        completes,
      );
    });

    test('INSERT dans documents_clients réussit', () async {
      await expectLater(
        db.insert('documents_clients', {
          'client_id': 1,
          'type_document': 'CNI',
          'nom_fichier': 'cni.pdf',
          'chemin_local': '/path/to/cni.pdf',
          'date_ajout': DateTime.now().toIso8601String(),
        }),
        completes,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Idempotence — réappliquer la migration ne lève aucune exception
  // ---------------------------------------------------------------------------

  group('Migration v29→v30 — idempotence', () {
    test('réappliquer la migration ne lève pas d\'exception', () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (d, _) async => await _createV29Schema(d),
        ),
      );

      await _applyPhase4Migration(db);
      // Deuxième application — doit être silencieuse
      await expectLater(_applyPhase4Migration(db), completes);

      await db.close();
    });
  });
}
