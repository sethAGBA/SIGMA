// test/notifiers/dashboard_notifier_test.dart
//
// Tests unitaires pour DashboardNotifier.
// Exigences couvertes : 9.1, 9.2, 9.3, 9.4
//
// NOTE : DashboardNotifier appelle DatabaseService.getHomeDashboardData()
// via une base SQLite en mémoire injectée par setDatabaseForTesting().
// ApiService.isServerAvailable() retourne false en environnement de test,
// donc le notifier utilise toujours le chemin offline (SQLite).

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sigma/core/notifiers/dashboard_notifier.dart';
import 'package:sigma/core/services/database_service.dart';

/// Crée les tables minimales nécessaires à getHomeDashboardData().
Future<void> _setupSchema(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS clients (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      statut TEXT DEFAULT 'Actif',
      date_creation TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS prets (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      montant_initial REAL DEFAULT 0,
      solde_restant REAL DEFAULT 0,
      date_deblocage TEXT,
      jours_retard INTEGER DEFAULT 0,
      statut TEXT DEFAULT 'Actif',
      agent_gestionnaire TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS remboursements (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      pret_id INTEGER,
      montant_total REAL DEFAULT 0,
      part_capital REAL DEFAULT 0,
      date_paiement TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS echeanciers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      pret_id INTEGER,
      date_prevue TEXT,
      statut TEXT DEFAULT 'impayé'
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS agents (
      id TEXT PRIMARY KEY,
      first_name TEXT NOT NULL DEFAULT '',
      last_name TEXT NOT NULL DEFAULT '',
      email TEXT,
      phone TEXT,
      role TEXT NOT NULL DEFAULT 'agent',
      agency_id TEXT,
      is_active INTEGER DEFAULT 1
    )
  ''');
}

/// Ouvre une base en mémoire isolée et l'injecte dans DatabaseService.
Future<Database> _openTestDb() async {
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) async => _setupSchema(db),
    ),
  );
  DatabaseService.setDatabaseForTesting(db);
  return db;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() {
    DatabaseService.resetDatabaseForTesting();
  });

  group('DashboardNotifier', () {
    // ── Cas 1 : load() remplit le cache (Exigence 9.1) ───────────────────────
    test('load() stocke les données en cache (Exigence 9.1)', () async {
      await _openTestDb();
      final notifier = DashboardNotifier();

      expect(notifier.cachedData, isNull);
      expect(notifier.isLoading, isFalse);

      await notifier.load();

      expect(notifier.cachedData, isNotNull,
          reason: 'Le cache doit être rempli après load()');
      expect(notifier.isLoading, isFalse);
      expect(notifier.error, isNull);
    });

    // ── Cas 2 : second load() retourne immédiatement (Exigence 9.2) ──────────
    test(
      'second load() ne recharge pas si cache non vide (Exigence 9.2)',
      () async {
        await _openTestDb();
        final notifier = DashboardNotifier();

        await notifier.load();
        final firstData = notifier.cachedData;
        expect(firstData, isNotNull);

        // Second appel — doit être un no-op
        await notifier.load();

        expect(
          notifier.cachedData,
          same(firstData),
          reason: 'Le cache ne doit pas être rechargé si déjà rempli',
        );
      },
    );

    // ── Cas 3 : refresh() vide le cache et recharge (Exigence 9.3) ───────────
    test('refresh() vide le cache puis recharge les données (Exigence 9.3)',
        () async {
      await _openTestDb();
      final notifier = DashboardNotifier();

      await notifier.load();
      final firstData = notifier.cachedData;
      expect(firstData, isNotNull);

      await notifier.refresh();

      expect(notifier.cachedData, isNotNull,
          reason: 'De nouvelles données doivent être disponibles après refresh()');
      expect(notifier.isLoading, isFalse);
      // Les nouvelles données sont une instance différente
      expect(
        notifier.cachedData,
        isNot(same(firstData)),
        reason: 'refresh() doit créer une nouvelle instance de HomeDashboardData',
      );
    });

    // ── Cas 4 : clearCache() remet _cachedData à null (Exigence 9.4) ─────────
    test('clearCache() remet cachedData à null (Exigence 9.4)', () async {
      await _openTestDb();
      final notifier = DashboardNotifier();

      await notifier.load();
      expect(notifier.cachedData, isNotNull);

      notifier.clearCache();

      expect(notifier.cachedData, isNull,
          reason: 'clearCache() doit vider le cache');
      expect(notifier.error, isNull);
    });

    // ── Cas 5 : clearCache() déclenche notifyListeners ────────────────────────
    test('clearCache() notifie les listeners', () async {
      await _openTestDb();
      final notifier = DashboardNotifier();
      await notifier.load();

      var notified = false;
      notifier.addListener(() => notified = true);

      notifier.clearCache();

      expect(notified, isTrue,
          reason: 'clearCache() doit appeler notifyListeners()');
    });

    // ── Cas 6 : isLoading est false après load() ──────────────────────────────
    test('isLoading est false après load()', () async {
      await _openTestDb();
      final notifier = DashboardNotifier();

      expect(notifier.isLoading, isFalse);
      await notifier.load();
      expect(notifier.isLoading, isFalse);
    });

    // ── Cas 7 : après clearCache() puis load(), cache rechargé ───────────────
    test('load() après clearCache() recharge les données', () async {
      await _openTestDb();
      final notifier = DashboardNotifier();

      await notifier.load();
      notifier.clearCache();
      expect(notifier.cachedData, isNull);

      await notifier.load();
      expect(notifier.cachedData, isNotNull,
          reason: 'load() doit recharger après clearCache()');
    });
  });
}
