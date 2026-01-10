import 'package:sqflite/sqflite.dart';
import '../../models/accounting_account_model.dart';
import '../../models/journal_model.dart';
import '../../models/ecriture_comptable_model.dart';
import 'database_service.dart';

class AccountingService {
  final DatabaseService _databaseService = DatabaseService();

  Future<List<AccountingAccount>> getAccountingAccounts() async {
    final db = await _databaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'comptes_comptables',
      orderBy: 'numero ASC',
    );
    return List.generate(maps.length, (i) {
      return AccountingAccount.fromMap(maps[i]);
    });
  }

  Future<int> addAccount(AccountingAccount account) async {
    final db = await _databaseService.database;

    // Check for duplicates
    final List<Map<String, dynamic>> existing = await db.query(
      'comptes_comptables',
      where: 'numero = ?',
      whereArgs: [account.numero],
    );

    if (existing.isNotEmpty) {
      throw Exception('Un compte avec ce numéro existe déjà.');
    }

    return await db.insert(
      'comptes_comptables',
      account.toMap(),
      conflictAlgorithm: ConflictAlgorithm.fail, // Do not replace
    );
  }

  Future<int> updateAccount(AccountingAccount account) async {
    final db = await _databaseService.database;
    return await db.update(
      'comptes_comptables',
      account.toMap(),
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  Future<int> deleteAccount(int id) async {
    final db = await _databaseService.database;
    return await db.delete(
      'comptes_comptables',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Journaux ---

  Future<List<Journal>> getJournaux() async {
    final db = await _databaseService.database;
    final List<Map<String, dynamic>> maps = await db.query('journaux');
    return List.generate(maps.length, (i) => Journal.fromMap(maps[i]));
  }

  // --- Ecritures ---

  Future<void> createEcriture(
    EcritureComptable ecriture,
    List<LigneEcriture> lignes, {
    DatabaseExecutor? txn,
  }) async {
    final db = txn ?? await _databaseService.database;

    // Validate balance
    double totalDebit = 0;
    double totalCredit = 0;
    for (var l in lignes) {
      totalDebit += l.debit;
      totalCredit += l.credit;
    }

    if ((totalDebit - totalCredit).abs() > 0.01) {
      throw Exception('L\'écriture n\'est pas équilibrée (Débit != Crédit)');
    }

    // Si on a déjà un txn, on l'utilise directement sans ouvrir une nouvelle transaction
    if (txn != null) {
      await _executeEcriture(txn, ecriture, lignes);
    } else {
      // Sinon on ouvre une transaction sur la db globale
      final Database database = db as Database;
      await database.transaction((transaction) async {
        await _executeEcriture(transaction, ecriture, lignes);
      });
    }
  }

  Future<void> _executeEcriture(
    DatabaseExecutor txn,
    EcritureComptable ecriture,
    List<LigneEcriture> lignes,
  ) async {
    // Insert Header
    final ecritureId = await txn.insert('ecritures', ecriture.toMap());

    // Insert Lines
    for (var ligne in lignes) {
      await txn.insert('lignes_ecriture', {
        'ecriture_id': ecritureId,
        'compte_numero': ligne.compteNumero,
        'libelle_ligne': ligne.libelleLigne,
        'debit': ligne.debit,
        'credit': ligne.credit,
        'ref_externe': ligne.refExterne,
        'tiers': ligne.tiers,
        'ref_analytique': ligne.refAnalytique,
      });
    }
  }
}
