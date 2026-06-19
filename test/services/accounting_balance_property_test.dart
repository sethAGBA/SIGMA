// test/services/accounting_balance_property_test.dart
//
// **Property test global — Équilibre comptable universel**
//
// Propriété : Pour toute opération financière avec un montant positif quelconque,
// sum(débit) == sum(crédit) sur toutes les lignes de l'écriture comptable générée.
//
// Opérations couvertes :
//   1. Déblocage prêt         (createLoanDisbursementEntry)
//   2. Remboursement capital  (createLoanRepaymentEntry — capital seulement)
//   3. Remboursement complet  (createLoanRepaymentEntry — capital + intérêts + pénalités)
//   4. Dépôt épargne          (createSavingsDepositEntry)
//   5. Retrait épargne        (createSavingsWithdrawalEntry)
//   6. Dotation aux provisions(createProvisionEntry)
//
// 100 itérations par opération avec montants générés aléatoirement.
// Seed fixe pour reproductibilité.
//
// **Validates: Requirements 1.1, 2.1, 3.1, 4.1**

import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sigma/core/services/automatic_accounting_service.dart';
import 'package:sigma/core/services/database_service.dart';
import 'package:sigma/models/loan_model.dart';
import 'package:sigma/models/repayment_model.dart';
import 'package:sigma/models/savings_transaction_model.dart';

// ---------------------------------------------------------------------------
// Constantes
// ---------------------------------------------------------------------------

/// Seed fixe pour la reproductibilité des tests
const int _kSeed = 42;

/// Nombre d'itérations par opération
const int _kIterations = 100;

/// Montant minimal généré (en unités FCFA)
const double _kMinAmount = 1000.0;

/// Montant maximal généré (en unités FCFA)
const double _kMaxAmount = 10000000.0;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Génère un montant positif dans [_kMinAmount, _kMaxAmount].
double _randomAmount(Random rng) {
  return _kMinAmount + rng.nextDouble() * (_kMaxAmount - _kMinAmount);
}

/// Crée le schéma SQLite minimal pour les tests comptables.
Future<void> _setupSchema(Database db) async {
  await db.execute('''
    CREATE TABLE configurations (
      key TEXT PRIMARY KEY,
      value TEXT
    )
  ''');

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

/// Ouvre une base SQLite en mémoire fraîche, enregistrée pour le test en cours.
Future<Database> _openFreshDb() async {
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

/// Calcule sum(débit) et sum(crédit) à partir des lignes d'écriture en DB.
Future<({double totalDebit, double totalCredit, int nbLignes})>
    _fetchBalance(Database db) async {
  final ecritures = await db.query('ecritures');
  expect(ecritures.length, equals(1),
      reason: 'Exactement une écriture doit être créée');

  final ecritureId = ecritures.first['id'] as int;
  final lignes = await db.query(
    'lignes_ecriture',
    where: 'ecriture_id = ?',
    whereArgs: [ecritureId],
  );

  final totalDebit =
      lignes.fold<double>(0, (s, l) => s + (l['debit'] as double));
  final totalCredit =
      lignes.fold<double>(0, (s, l) => s + (l['credit'] as double));

  return (
    totalDebit: totalDebit,
    totalCredit: totalCredit,
    nbLignes: lignes.length,
  );
}

/// Construit un Loan de test avec le montant fourni.
Loan _buildLoan(double montant, int index) {
  return Loan(
    demandePretId: index,
    clientId: index,
    produitId: 1,
    numeroPret: 'PRE-PROP-${index.toString().padLeft(4, '0')}',
    montantInitial: montant,
    soldeRestant: montant,
    dateDeblocage: DateTime(2024, 1, 1),
    statut: LoanStatus.aJour,
  );
}

/// Construit un Repayment avec décomposition pseudo-aléatoire du montant total.
Repayment _buildRepayment({
  required double capital,
  required double interets,
  required double penalites,
  required int index,
}) {
  return Repayment(
    pretId: index,
    montantTotal: capital + interets + penalites,
    partCapital: capital,
    partInterets: interets,
    partPenalites: penalites,
    datePaiement: DateTime(2024, 3, 1),
    modePaiement: RepaymentMode.especes,
    numeroRecu: 'RECU-PROP-${index.toString().padLeft(4, '0')}',
    agentCollecteur: 'Agent Test',
  );
}

/// Construit une SavingsTransaction de test.
SavingsTransaction _buildSavingsTransaction({
  required SavingsTransactionType type,
  required double montant,
  required int index,
}) {
  return SavingsTransaction(
    compteId: index,
    type: type,
    montant: montant,
    soldeApres: montant,
    agentOperation: 'Agent Test',
    dateOperation: DateTime(2024, 4, 1),
    numeroPiece: 'SAV-PROP-${index.toString().padLeft(4, '0')}',
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() {
    DatabaseService.resetDatabaseForTesting();
  });

  // -------------------------------------------------------------------------
  // 1. Déblocage prêt — Exigence 1.1
  // -------------------------------------------------------------------------
  group(
    'Propriété : équilibre comptable — Déblocage prêt (Exigence 1.1) — $_kIterations itérations',
    () {
      test('sum(débit) == sum(crédit) pour tout montant de déblocage', () async {
        final rng = Random(_kSeed);

        for (int i = 0; i < _kIterations; i++) {
          final montant = _randomAmount(rng);
          final db = await _openFreshDb();
          final service = AutomaticAccountingService();

          await service.createLoanDisbursementEntry(
            loan: _buildLoan(montant, i + 1),
            agentName: 'Agent Test',
          );

          final balance = await _fetchBalance(db);

          expect(
            balance.totalDebit,
            closeTo(balance.totalCredit, 0.01),
            reason:
                'Itération $i — montant=$montant — '
                'sum(débit)=${balance.totalDebit} != sum(crédit)=${balance.totalCredit}',
          );
          expect(balance.nbLignes, equals(2),
              reason:
                  'Déblocage prêt doit générer exactement 2 lignes (itération $i)');

          await db.close();
          DatabaseService.resetDatabaseForTesting();
        }
      });
    },
  );

  // -------------------------------------------------------------------------
  // 2. Remboursement capital seulement — Exigence 2.1
  // -------------------------------------------------------------------------
  group(
    'Propriété : équilibre comptable — Remboursement capital seul (Exigence 2.1) — $_kIterations itérations',
    () {
      test('sum(débit) == sum(crédit) pour tout montant de capital', () async {
        final rng = Random(_kSeed);

        for (int i = 0; i < _kIterations; i++) {
          final capital = _randomAmount(rng);
          final db = await _openFreshDb();
          final service = AutomaticAccountingService();

          await service.createLoanRepaymentEntry(
            repayment: _buildRepayment(
              capital: capital,
              interets: 0,
              penalites: 0,
              index: i + 1,
            ),
            loanNumber: 'PRE-PROP-${(i + 1).toString().padLeft(4, '0')}',
            clientId: i + 1,
            agentName: 'Agent Test',
          );

          final balance = await _fetchBalance(db);

          expect(
            balance.totalDebit,
            closeTo(balance.totalCredit, 0.01),
            reason:
                'Itération $i — capital=$capital — '
                'sum(débit)=${balance.totalDebit} != sum(crédit)=${balance.totalCredit}',
          );
          expect(balance.nbLignes, equals(2),
              reason:
                  'Remboursement capital seul doit générer 2 lignes (itération $i)');

          await db.close();
          DatabaseService.resetDatabaseForTesting();
        }
      });
    },
  );

  // -------------------------------------------------------------------------
  // 3. Remboursement capital + intérêts + pénalités — Exigence 2.1
  // -------------------------------------------------------------------------
  group(
    'Propriété : équilibre comptable — Remboursement complet (Exigence 2.1) — $_kIterations itérations',
    () {
      test(
        'sum(débit) == sum(crédit) pour capital + intérêts + pénalités aléatoires',
        () async {
          final rng = Random(_kSeed);

          for (int i = 0; i < _kIterations; i++) {
            // Décomposition aléatoire : capital = 60-80%, intérêts = 10-30%, pénalités = 5-15%
            final total = _randomAmount(rng);
            final capitalRatio = 0.60 + rng.nextDouble() * 0.20; // 60-80%
            final interetsRatio =
                0.10 + rng.nextDouble() * 0.10; // 10-20% du reste
            final capital = total * capitalRatio;
            final interets = total * interetsRatio;
            final penalites = total - capital - interets;

            final db = await _openFreshDb();
            final service = AutomaticAccountingService();

            await service.createLoanRepaymentEntry(
              repayment: _buildRepayment(
                capital: capital,
                interets: interets,
                penalites: penalites > 0 ? penalites : 0,
                index: i + 1,
              ),
              loanNumber: 'PRE-PROP-${(i + 1).toString().padLeft(4, '0')}',
              clientId: i + 1,
              agentName: 'Agent Test',
            );

            final balance = await _fetchBalance(db);

            expect(
              balance.totalDebit,
              closeTo(balance.totalCredit, 0.01),
              reason:
                  'Itération $i — total=$total, capital=$capital, '
                  'intérêts=$interets, pénalités=$penalites — '
                  'sum(débit)=${balance.totalDebit} != sum(crédit)=${balance.totalCredit}',
            );
            // 2 lignes (capital) + 1 ligne (intérêts) + 1 ligne (pénalités si > 0)
            expect(balance.nbLignes, greaterThanOrEqualTo(2),
                reason:
                    'Remboursement complet doit générer au moins 2 lignes (itération $i)');

            await db.close();
            DatabaseService.resetDatabaseForTesting();
          }
        },
      );
    },
  );

  // -------------------------------------------------------------------------
  // 4. Dépôt épargne — Exigence 3.1
  // -------------------------------------------------------------------------
  group(
    'Propriété : équilibre comptable — Dépôt épargne (Exigence 3.1) — $_kIterations itérations',
    () {
      test('sum(débit) == sum(crédit) pour tout montant de dépôt', () async {
        final rng = Random(_kSeed);

        for (int i = 0; i < _kIterations; i++) {
          final montant = _randomAmount(rng);
          final db = await _openFreshDb();
          final service = AutomaticAccountingService();

          await service.createSavingsDepositEntry(
            transaction: _buildSavingsTransaction(
              type: SavingsTransactionType.depot,
              montant: montant,
              index: i + 1,
            ),
            accountNumber: 'CEP-PROP-${(i + 1).toString().padLeft(4, '0')}',
            clientId: i + 1,
            agentName: 'Agent Test',
          );

          final balance = await _fetchBalance(db);

          expect(
            balance.totalDebit,
            closeTo(balance.totalCredit, 0.01),
            reason:
                'Itération $i — montant=$montant — '
                'sum(débit)=${balance.totalDebit} != sum(crédit)=${balance.totalCredit}',
          );
          expect(balance.nbLignes, equals(2),
              reason:
                  'Dépôt épargne doit générer exactement 2 lignes (itération $i)');

          await db.close();
          DatabaseService.resetDatabaseForTesting();
        }
      });
    },
  );

  // -------------------------------------------------------------------------
  // 5. Retrait épargne — Exigence 3.1
  // -------------------------------------------------------------------------
  group(
    'Propriété : équilibre comptable — Retrait épargne (Exigence 3.1) — $_kIterations itérations',
    () {
      test('sum(débit) == sum(crédit) pour tout montant de retrait', () async {
        final rng = Random(_kSeed);

        for (int i = 0; i < _kIterations; i++) {
          final montant = _randomAmount(rng);
          final db = await _openFreshDb();
          final service = AutomaticAccountingService();

          await service.createSavingsWithdrawalEntry(
            transaction: _buildSavingsTransaction(
              type: SavingsTransactionType.retrait,
              montant: montant,
              index: i + 1,
            ),
            accountNumber: 'CEP-PROP-${(i + 1).toString().padLeft(4, '0')}',
            clientId: i + 1,
            agentName: 'Agent Test',
          );

          final balance = await _fetchBalance(db);

          expect(
            balance.totalDebit,
            closeTo(balance.totalCredit, 0.01),
            reason:
                'Itération $i — montant=$montant — '
                'sum(débit)=${balance.totalDebit} != sum(crédit)=${balance.totalCredit}',
          );
          expect(balance.nbLignes, equals(2),
              reason:
                  'Retrait épargne doit générer exactement 2 lignes (itération $i)');

          await db.close();
          DatabaseService.resetDatabaseForTesting();
        }
      });
    },
  );

  // -------------------------------------------------------------------------
  // 6. Dotation aux provisions — Exigence 4.1
  // -------------------------------------------------------------------------
  group(
    'Propriété : équilibre comptable — Dotation aux provisions (Exigence 4.1) — $_kIterations itérations',
    () {
      test('sum(débit) == sum(crédit) pour tout montant de provision', () async {
        final rng = Random(_kSeed);

        for (int i = 0; i < _kIterations; i++) {
          final montant = _randomAmount(rng);
          final db = await _openFreshDb();
          final service = AutomaticAccountingService();

          await service.createProvisionEntry(
            amount: montant,
            agentName: 'Agent Test',
          );

          final balance = await _fetchBalance(db);

          expect(
            balance.totalDebit,
            closeTo(balance.totalCredit, 0.01),
            reason:
                'Itération $i — montant=$montant — '
                'sum(débit)=${balance.totalDebit} != sum(crédit)=${balance.totalCredit}',
          );
          expect(balance.nbLignes, equals(2),
              reason:
                  'Provision doit générer exactement 2 lignes (itération $i)');

          await db.close();
          DatabaseService.resetDatabaseForTesting();
        }
      });
    },
  );
}
