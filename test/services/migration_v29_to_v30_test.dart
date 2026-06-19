import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('migration v29 -> v30 ajoute colonnes et table (idempotent)', () async {
    // Ouvrir une base en mémoire simulant l'ancien schéma (pré-Phase4)
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 29,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE produits_financiers (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              nom TEXT,
              code TEXT,
              type TEXT,
              taux_interet REAL
            )
          ''');

          await db.execute('''
            CREATE TABLE prets (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              montant_initial REAL
            )
          ''');

          await db.execute('''
            CREATE TABLE comptes_epargne (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              client_id INTEGER,
              produit_id INTEGER,
              numero_compte TEXT
            )
          ''');

          await db.execute('''
            CREATE TABLE utilisateurs_systeme (
              id TEXT PRIMARY KEY,
              username TEXT
            )
          ''');
        },
      ),
    );

    // Helper: ajoute une colonne si inexistante (même logique que la prod)
    Future<void> addColumnIfNotExists(
        Database db, String table, String column, String definition) async {
      final info = await db.rawQuery('PRAGMA table_info($table)');
      final exists = info.any((row) => row['name'] == column);
      if (!exists) {
        await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
      }
    }

    // Appliquer la migration Phase 4 (copie de la logique attendue)
    Future<void> applyPhase4(Database db) async {
      await addColumnIfNotExists(db, 'produits_financiers', 'taux_assurance', 'REAL');
      await addColumnIfNotExists(db, 'produits_financiers', 'duree_max_differe_capital_mois', 'INTEGER');
      await addColumnIfNotExists(db, 'prets', 'mois_differe_capital', 'INTEGER DEFAULT 0');
      await addColumnIfNotExists(db, 'comptes_epargne', 'date_echeance_terme', 'TEXT');
      await addColumnIfNotExists(db, 'comptes_epargne', 'taux_penalite_rupture_ant', 'REAL');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS documents_clients (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          client_id INTEGER NOT NULL,
          type_document TEXT NOT NULL,
          nom_fichier TEXT NOT NULL,
          chemin_local TEXT NOT NULL,
          date_ajout TEXT NOT NULL
        )
      ''');
    }

    // Première application
    await applyPhase4(db);

    // Vérifier la présence des colonnes
    final prodInfo = await db.rawQuery('PRAGMA table_info(produits_financiers)');
    expect(prodInfo.any((r) => r['name'] == 'taux_assurance'), isTrue);
    expect(prodInfo.any((r) => r['name'] == 'duree_max_differe_capital_mois'), isTrue);

    final pretsInfo = await db.rawQuery('PRAGMA table_info(prets)');
    expect(pretsInfo.any((r) => r['name'] == 'mois_differe_capital'), isTrue);

    final comptesInfo = await db.rawQuery('PRAGMA table_info(comptes_epargne)');
    expect(comptesInfo.any((r) => r['name'] == 'date_echeance_terme'), isTrue);
    expect(comptesInfo.any((r) => r['name'] == 'taux_penalite_rupture_ant'), isTrue);

    // Vérifier la table documents_clients existe
    final docs = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='documents_clients'");
    expect(docs, isNotEmpty);

    // Ré-appliquer la migration — doit être idempotente (pas d'exception)
    await applyPhase4(db);

    await db.close();
  });
}
