// test/services/automatic_accounting_test.dart
//
// Tests unitaires pour AutomaticAccountingService — remboursement ET épargne
// Exigences : 2.1, 2.3, 2.4 (remboursement) | 3.1, 3.2 (épargne)
//
// Valide:
//   - Cas 1 : remboursement capital seulement → 2 lignes (Débit caisse / Crédit prêts)
//   - Cas 2 : capital + intérêts → 3 lignes
//   - Cas 3 : capital + intérêts + pénalités → 4 lignes
//   - Propriété : sum(débits) == sum(crédits) pour les 3 cas (équilibre comptable)
//
// Épargne :
//   - Dépôt  : Débit 571 (caisse) / Crédit 1651 (dépôts) + équilibre comptable
//   - Retrait : Débit 1651 (dépôts) / Crédit 571 (caisse) + équilibre comptable
//
// **Validates: Requirements 3.1, 3.2**

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sigma/core/services/automatic_accounting_service.dart';
import 'package:sigma/core/services/database_service.dart';
import 'package:sigma/models/repayment_model.dart';
import 'package:sigma/models/savings_transaction_model.dart';

/// Crée le schéma minimal nécessaire pour les tests du pont comptable.
Future<void> _setupSchema(Database db) async {
  // Table de configuration (pour getAccountingConfig)
  await db.execute('''
    CREATE TABLE configurations (
      key TEXT PRIMARY KEY,
      value TEXT
    )
  ''');

  // Table des écritures comptables
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ecritures (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date_comptable TEXT NOT NULL,
      journal_code TEXT,
      numero_piece TEXT,
      libelle TEXT,
      agent_saisie TEXT,
      statut TEXT DEFAULT 'BROUILLON',
      date_saisie TEXT NOT NULL,
      piece_jointe TEXT
    )
  ''');

  // Table des lignes d'écriture
  await db.execute('''
    CREATE TABLE IF NOT EXISTS lignes_ecriture (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      ecriture_id INTEGER,
      compte_numero TEXT,
      libelle_ligne TEXT,
      debit REAL DEFAULT 0,
      credit REAL DEFAULT 0,
      ref_externe TEXT,
      tiers TEXT,
      ref_analytique TEXT,
      FOREIGN KEY (ecriture_id) REFERENCES ecritures (id) ON DELETE CASCADE
    )
  ''');
}

/// Construit un Repayment de test avec les montants donnés.
Repayment _buildRepayment({
  required double capital,
  double interets = 0,
  double penalites = 0,
}) {
  final total = capital + interets + penalites;
  return Repayment(
    pretId: 1,
    montantTotal: total,
    partCapital: capital,
    partInterets: interets,
    partPenalites: penalites,
    datePaiement: DateTime(2024, 6, 15),
    modePaiement: RepaymentMode.especes,
    numeroRecu: 'RECU-TEST-001',
    agentCollecteur: 'Agent Test',
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() {
    DatabaseService.resetDatabaseForTesting();
  });

  group('AutomaticAccountingService.createLoanRepaymentEntry()', () {
    //
    // Cas 1 — Capital seulement (0 intérêts, 0 pénalités)
    // Attendu : 2 lignes — Débit 571 (caisse) + Crédit 271 (prêts)
    // Exigences : 2.1, 2.3, 2.4
    //
    test(
      'Cas 1 : capital seulement → 2 lignes, équilibre comptable (Exigences 2.1, 2.3, 2.4)',
      () async {
        final db = await databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, _) async => _setupSchema(db),
          ),
        );
        DatabaseService.setDatabaseForTesting(db);

        final repayment = _buildRepayment(capital: 50000.0);
        final service = AutomaticAccountingService();

        await service.createLoanRepaymentEntry(
          repayment: repayment,
          loanNumber: 'PRE-2024-001',
          clientId: 42,
          agentName: 'Agent Test',
        );

        // Vérifier l'écriture créée
        final ecritures = await db.query('ecritures');
        expect(ecritures.length, equals(1), reason: 'Une écriture doit être créée');

        final ecritureId = ecritures.first['id'] as int;
        final lignes = await db.query(
          'lignes_ecriture',
          where: 'ecriture_id = ?',
          whereArgs: [ecritureId],
        );

        // 2 lignes : Débit caisse + Crédit prêts
        expect(lignes.length, equals(2),
            reason: 'Capital seulement → exactement 2 lignes');

        // Propriété équilibre : sum(débits) == sum(crédits)
        final totalDebit = lignes.fold<double>(0, (s, l) => s + (l['debit'] as double));
        final totalCredit = lignes.fold<double>(0, (s, l) => s + (l['credit'] as double));
        expect(totalDebit, closeTo(totalCredit, 0.01),
            reason: 'Équilibre comptable : sum(débits) == sum(crédits)');

        // Vérifier les comptes
        final debitLine = lignes.firstWhere((l) => (l['debit'] as double) > 0);
        final creditLine = lignes.firstWhere((l) => (l['credit'] as double) > 0);
        expect(debitLine['compte_numero'], equals('571'),
            reason: 'Débit sur compte caisse (571)');
        expect(creditLine['compte_numero'], equals('271'),
            reason: 'Crédit sur compte prêts (271)');
        expect(debitLine['debit'], closeTo(50000.0, 0.01));
        expect(creditLine['credit'], closeTo(50000.0, 0.01));

        await db.close();
      },
    );

    //
    // Cas 2 — Capital + intérêts (0 pénalités)
    // Attendu : 3 lignes — Débit caisse + Crédit prêts + Crédit intérêts
    // Exigences : 2.1, 2.3
    //
    test(
      'Cas 2 : capital + intérêts → 3 lignes, équilibre comptable (Exigences 2.1, 2.3)',
      () async {
        final db = await databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, _) async => _setupSchema(db),
          ),
        );
        DatabaseService.setDatabaseForTesting(db);

        final repayment = _buildRepayment(
          capital: 45000.0,
          interets: 5000.0,
        );
        final service = AutomaticAccountingService();

        await service.createLoanRepaymentEntry(
          repayment: repayment,
          loanNumber: 'PRE-2024-002',
          clientId: 43,
          agentName: 'Agent Test',
        );

        final ecritures = await db.query('ecritures');
        final ecritureId = ecritures.first['id'] as int;
        final lignes = await db.query(
          'lignes_ecriture',
          where: 'ecriture_id = ?',
          whereArgs: [ecritureId],
        );

        // 3 lignes : Débit caisse + Crédit prêts + Crédit intérêts
        expect(lignes.length, equals(3),
            reason: 'Capital + intérêts → exactement 3 lignes');

        // Propriété équilibre
        final totalDebit = lignes.fold<double>(0, (s, l) => s + (l['debit'] as double));
        final totalCredit = lignes.fold<double>(0, (s, l) => s + (l['credit'] as double));
        expect(totalDebit, closeTo(totalCredit, 0.01),
            reason: 'Équilibre comptable : sum(débits) == sum(crédits)');

        // Vérifier le total débit = montant total (50 000)
        expect(totalDebit, closeTo(50000.0, 0.01));

        // Vérifier que le compte intérêts (7712) est bien présent en crédit
        final interetLine = lignes.where(
          (l) => l['compte_numero'] == '7712' && (l['credit'] as double) > 0,
        );
        expect(interetLine.length, equals(1),
            reason: 'Une ligne crédit sur compte intérêts 7712 doit être présente');
        expect(interetLine.first['credit'], closeTo(5000.0, 0.01));

        await db.close();
      },
    );

    //
    // Cas 3 — Capital + intérêts + pénalités
    // Attendu : 4 lignes — Débit caisse + Crédit prêts + Crédit intérêts + Crédit pénalités
    // Exigences : 2.1, 2.3, 2.4
    //
    test(
      'Cas 3 : capital + intérêts + pénalités → 4 lignes, équilibre comptable (Exigences 2.1, 2.3, 2.4)',
      () async {
        final db = await databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, _) async => _setupSchema(db),
          ),
        );
        DatabaseService.setDatabaseForTesting(db);

        final repayment = _buildRepayment(
          capital: 40000.0,
          interets: 4500.0,
          penalites: 1200.0,
        );
        final service = AutomaticAccountingService();

        await service.createLoanRepaymentEntry(
          repayment: repayment,
          loanNumber: 'PRE-2024-003',
          clientId: 44,
          agentName: 'Agent Test',
        );

        final ecritures = await db.query('ecritures');
        final ecritureId = ecritures.first['id'] as int;
        final lignes = await db.query(
          'lignes_ecriture',
          where: 'ecriture_id = ?',
          whereArgs: [ecritureId],
        );

        // 4 lignes
        expect(lignes.length, equals(4),
            reason: 'Capital + intérêts + pénalités → exactement 4 lignes');

        // Propriété équilibre
        final totalDebit = lignes.fold<double>(0, (s, l) => s + (l['debit'] as double));
        final totalCredit = lignes.fold<double>(0, (s, l) => s + (l['credit'] as double));
        expect(totalDebit, closeTo(totalCredit, 0.01),
            reason: 'Équilibre comptable : sum(débits) == sum(crédits)');

        // Total = 45 700
        expect(totalDebit, closeTo(45700.0, 0.01));

        // Ligne pénalités (7078) présente en crédit
        final penaliteLine = lignes.where(
          (l) => l['compte_numero'] == '7078' && (l['credit'] as double) > 0,
        );
        expect(penaliteLine.length, equals(1),
            reason: 'Une ligne crédit sur compte pénalités 7078 doit être présente');
        expect(penaliteLine.first['credit'], closeTo(1200.0, 0.01));

        await db.close();
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Groupe : Épargne — dépôt et retrait
  // Exigences : 3.1 (dépôt) et 3.2 (retrait)
  // Propriété : équilibre comptable sum(débits) == sum(crédits) pour les deux
  // ---------------------------------------------------------------------------
  group('AutomaticAccountingService — épargne (Exigences 3.1, 3.2)', () {
    /// Construit une SavingsTransaction de test.
    SavingsTransaction buildSavingsTransaction({
      required SavingsTransactionType type,
      required double montant,
    }) {
      return SavingsTransaction(
        compteId: 1,
        type: type,
        montant: montant,
        soldeApres: montant,
        agentOperation: 'Agent Test',
        dateOperation: DateTime(2024, 6, 20),
        numeroPiece: 'SAV-TEST-001',
      );
    }

    //
    // Dépôt épargne
    // Attendu : 2 lignes — Débit 571 (caisse) / Crédit 1651 (dépôts)
    // Exigence 3.1
    //
    test(
      'Dépôt épargne → 2 lignes Débit 571 / Crédit 1651, équilibre comptable (Exigence 3.1)',
      () async {
        final db = await databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, _) async => _setupSchema(db),
          ),
        );
        DatabaseService.setDatabaseForTesting(db);

        final transaction = buildSavingsTransaction(
          type: SavingsTransactionType.depot,
          montant: 25000.0,
        );
        final service = AutomaticAccountingService();

        await service.createSavingsDepositEntry(
          transaction: transaction,
          accountNumber: 'CEP-2024-001',
          clientId: 10,
          agentName: 'Agent Test',
        );

        final ecritures = await db.query('ecritures');
        expect(ecritures.length, equals(1),
            reason: 'Une écriture doit être créée');

        final ecritureId = ecritures.first['id'] as int;
        final lignes = await db.query(
          'lignes_ecriture',
          where: 'ecriture_id = ?',
          whereArgs: [ecritureId],
        );

        // 2 lignes : Débit caisse + Crédit dépôts
        expect(lignes.length, equals(2),
            reason: 'Dépôt épargne → exactement 2 lignes');

        // Propriété équilibre comptable : sum(débits) == sum(crédits)
        final totalDebit =
            lignes.fold<double>(0, (s, l) => s + (l['debit'] as double));
        final totalCredit =
            lignes.fold<double>(0, (s, l) => s + (l['credit'] as double));
        expect(totalDebit, closeTo(totalCredit, 0.01),
            reason: 'Équilibre comptable : sum(débits) == sum(crédits)');

        // Vérifier Débit sur compte caisse (571)
        final debitLine = lignes.firstWhere((l) => (l['debit'] as double) > 0);
        expect(debitLine['compte_numero'], equals('571'),
            reason: 'Débit sur compte caisse 571');
        expect(debitLine['debit'], closeTo(25000.0, 0.01));

        // Vérifier Crédit sur compte dépôts (1651)
        final creditLine =
            lignes.firstWhere((l) => (l['credit'] as double) > 0);
        expect(creditLine['compte_numero'], equals('1651'),
            reason: 'Crédit sur compte dépôts 1651');
        expect(creditLine['credit'], closeTo(25000.0, 0.01));

        await db.close();
      },
    );

    //
    // Retrait épargne
    // Attendu : 2 lignes — Débit 1651 (dépôts) / Crédit 571 (caisse)
    // Exigence 3.2
    //
    test(
      'Retrait épargne → 2 lignes Débit 1651 / Crédit 571, équilibre comptable (Exigence 3.2)',
      () async {
        final db = await databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, _) async => _setupSchema(db),
          ),
        );
        DatabaseService.setDatabaseForTesting(db);

        final transaction = buildSavingsTransaction(
          type: SavingsTransactionType.retrait,
          montant: 10000.0,
        );
        final service = AutomaticAccountingService();

        await service.createSavingsWithdrawalEntry(
          transaction: transaction,
          accountNumber: 'CEP-2024-002',
          clientId: 11,
          agentName: 'Agent Test',
        );

        final ecritures = await db.query('ecritures');
        expect(ecritures.length, equals(1),
            reason: 'Une écriture doit être créée');

        final ecritureId = ecritures.first['id'] as int;
        final lignes = await db.query(
          'lignes_ecriture',
          where: 'ecriture_id = ?',
          whereArgs: [ecritureId],
        );

        // 2 lignes : Débit dépôts + Crédit caisse
        expect(lignes.length, equals(2),
            reason: 'Retrait épargne → exactement 2 lignes');

        // Propriété équilibre comptable : sum(débits) == sum(crédits)
        final totalDebit =
            lignes.fold<double>(0, (s, l) => s + (l['debit'] as double));
        final totalCredit =
            lignes.fold<double>(0, (s, l) => s + (l['credit'] as double));
        expect(totalDebit, closeTo(totalCredit, 0.01),
            reason: 'Équilibre comptable : sum(débits) == sum(crédits)');

        // Vérifier Débit sur compte dépôts (1651)
        final debitLine = lignes.firstWhere((l) => (l['debit'] as double) > 0);
        expect(debitLine['compte_numero'], equals('1651'),
            reason: 'Débit sur compte dépôts 1651');
        expect(debitLine['debit'], closeTo(10000.0, 0.01));

        // Vérifier Crédit sur compte caisse (571)
        final creditLine =
            lignes.firstWhere((l) => (l['credit'] as double) > 0);
        expect(creditLine['compte_numero'], equals('571'),
            reason: 'Crédit sur compte caisse 571');
        expect(creditLine['credit'], closeTo(10000.0, 0.01));

        await db.close();
      },
    );
  });
}
