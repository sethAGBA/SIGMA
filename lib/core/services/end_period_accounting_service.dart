// lib/core/services/end_period_accounting_service.dart

import 'package:sqflite/sqflite.dart';
import '../../models/ecriture_comptable_model.dart';
import '../../models/loan_model.dart';
import '../../models/accounting_config_model.dart';
import 'database_service.dart';
import 'accounting_service.dart';

class EndPeriodAccountingService {
  final DatabaseService _databaseService = DatabaseService();
  final AccountingService _accountingService = AccountingService();

  /// Génère les écritures d'intérêts courus non échus (ICNE) pour le portefeuille de prêts
  Future<int> generateAccruedInterestEntries(DateTime periodEnd) async {
    final db = await _databaseService.database;
    final config = await _databaseService.getAccountingConfig();
    int count = 0;

    // 1. Récupérer tous les prêts actifs (À jour ou en retard mais non passés en perte)
    final loans = await _databaseService.getLoans();
    final activeLoans = loans
        .where((l) => l.statut != LoanStatus.perte && l.soldeRestant > 0)
        .toList();

    for (final loan in activeLoans) {
      // 2. Calculer les intérêts courus entre la date du dernier remboursement (ou déblocage) et periodEnd
      // Note: Dans un système réel, on regarderait l'échéancier et les paiements effectifs.
      // Ici, on fait une simplification basée sur le taux annuel et le solde actuel.

      final lastActivityDate = await _getLastActivityDate(loan);
      if (periodEnd.isBefore(lastActivityDate)) continue;

      final days = periodEnd.difference(lastActivityDate).inDays;
      if (days <= 0) continue;

      // Calcul prorata temporis (30/360)
      final annualRate = loan.produit?.tauxInteret ?? 0;
      final dailyRate = (annualRate / 100) / 360;
      final accruedAmount = loan.soldeRestant * dailyRate * days;

      if (accruedAmount >= 1) {
        // Seuils minimum 1 FCFA
        await _createAccruedInterestEntry(
          db,
          loan,
          accruedAmount,
          periodEnd,
          config,
        );
        count++;
      }
    }

    return count;
  }

  /// Génère les écritures de dotations aux provisions pour créances douteuses
  Future<int> generateProvisioningEntries(DateTime periodEnd) async {
    final db = await _databaseService.database;
    final config = await _databaseService.getAccountingConfig();
    int count = 0;

    // 1. Récupérer les prêts en retard
    final loans = await _databaseService.getLoans();
    final delinquentLoans = loans.where((l) => l.joursRetard > 0).toList();

    for (final loan in delinquentLoans) {
      double rate = 0;
      if (loan.joursRetard > 90) {
        rate = 1.0;
      } else if (loan.joursRetard > 60) {
        rate = 0.5;
      } else if (loan.joursRetard > 30) {
        rate = 0.25;
      } else {
        rate = 0.05; // Provision de précaution 5% pour 1-30 jours
      }

      final provisionAmount = loan.soldeRestant * rate;

      // Vérifier si une provision existe déjà pour ce prêt (simplification ici)
      // Dans l'idéal, on ajuste la provision (Dotation ou Reprise)

      if (provisionAmount > 0) {
        await _createProvisionEntry(
          db,
          loan,
          provisionAmount,
          periodEnd,
          config,
        );
        count++;
      }
    }

    return count;
  }

  /// Récupère la date de la dernière activité (déblocage ou dernier paiement)
  Future<DateTime> _getLastActivityDate(Loan loan) async {
    final db = await _databaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'remboursements',
      where: 'pret_id = ?',
      whereArgs: [loan.id],
      orderBy: 'date_paiement DESC',
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return DateTime.parse(maps.first['date_paiement']);
    }
    return loan.dateDeblocage;
  }

  Future<void> _createAccruedInterestEntry(
    DatabaseExecutor txn,
    Loan loan,
    double amount,
    DateTime date,
    AccountingConfiguration config,
  ) async {
    final ecriture = EcritureComptable(
      dateComptable: date,
      libelle: 'ICNE - Prêt ${loan.numeroPret} - ${loan.client?.nom}',
      numeroPiece: AccountingConfiguration.generatePieceNumber(
        AccountingConfiguration.prefixAccruedInterest,
      ),
      journalCode: AccountingConfiguration.journalOperationsDiverses,
      agentSaisie: 'SYSTEM',
      dateSaisie: DateTime.now(),
    );

    final lignes = [
      LigneEcriture(
        compteNumero: config.compteInteretsCourusPrets,
        libelleLigne: 'Intérêts courus non échus',
        debit: amount,
        credit: 0,
      ),
      LigneEcriture(
        compteNumero: config.compteInterets,
        libelleLigne: 'Produits d\'intérêts',
        debit: 0,
        credit: amount,
      ),
    ];

    await _accountingService.createEcriture(ecriture, lignes, txn: txn);
  }

  Future<void> _createProvisionEntry(
    DatabaseExecutor txn,
    Loan loan,
    double amount,
    DateTime date,
    AccountingConfiguration config,
  ) async {
    final ecriture = EcritureComptable(
      dateComptable: date,
      libelle: 'Dotation provision - Prêt ${loan.numeroPret}',
      numeroPiece: AccountingConfiguration.generatePieceNumber(
        AccountingConfiguration.prefixProvisioning,
      ),
      journalCode: AccountingConfiguration.journalOperationsDiverses,
      agentSaisie: 'SYSTEM',
      dateSaisie: DateTime.now(),
    );

    final lignes = [
      LigneEcriture(
        compteNumero: config.compteDotationProvisions,
        libelleLigne: 'Dotation aux provisions',
        debit: amount,
        credit: 0,
      ),
      LigneEcriture(
        compteNumero: config.compteDepreciationPrets,
        libelleLigne: 'Dépréciation des prêts',
        debit: 0,
        credit: amount,
      ),
    ];

    await _accountingService.createEcriture(ecriture, lignes, txn: txn);
  }

  /// Clôture de l'exercice : solde les comptes 6 et 7 vers le compte 131
  Future<void> performYearEndClosing(int year) async {
    final db = await _databaseService.database;
    final config = await _databaseService.getAccountingConfig();
    final dateCloture = DateTime(year, 12, 31, 23, 59);

    await db.transaction((txn) async {
      // 1. Récupérer les soldes cumulés des classes 6 et 7
      final List<Map<String, dynamic>> result = await txn.rawQuery(
        '''
        SELECT compte_numero, 
               SUM(debit) as total_debit, 
               SUM(credit) as total_credit
        FROM lignes_ecriture le
        JOIN ecritures e ON le.ecriture_id = e.id
        WHERE strftime('%Y', e.date_comptable) = ?
        AND (compte_numero LIKE '6%' OR compte_numero LIKE '7%')
        GROUP BY compte_numero
      ''',
        [year.toString()],
      );

      if (result.isEmpty) return;

      double totalCharges = 0;
      double totalProduits = 0;
      List<LigneEcriture> lignesCloture = [];

      for (final row in result) {
        final double solde =
            (row['total_debit'] as num).toDouble() -
            (row['total_credit'] as num).toDouble();
        final String compteNum = row['compte_numero'];

        if (solde == 0) continue;

        if (compteNum.startsWith('6')) {
          totalCharges += solde;
          // Solde débiteur -> On crédite pour vider
          lignesCloture.add(
            LigneEcriture(
              compteNumero: compteNum,
              libelleLigne: 'Clôture charges $year',
              debit: 0,
              credit: solde,
            ),
          );
        } else {
          totalProduits -=
              solde; // solde est négatif pour les produits (crédit > débit)
          // Solde créditeur (négatif ici) -> On débite pour vider
          lignesCloture.add(
            LigneEcriture(
              compteNumero: compteNum,
              libelleLigne: 'Clôture produits $year',
              debit: -solde,
              credit: 0,
            ),
          );
        }
      }

      final double resultatNet = totalProduits - totalCharges;

      // Équilibrage avec le compte de résultat
      if (resultatNet >= 0) {
        // Bénéfice -> Crédit 131
        lignesCloture.add(
          LigneEcriture(
            compteNumero: config.compteResultatExercice,
            libelleLigne: 'Résultat net (Bénéfice) $year',
            debit: 0,
            credit: resultatNet,
          ),
        );
      } else {
        // Perte -> Débit 131
        lignesCloture.add(
          LigneEcriture(
            compteNumero: config.compteResultatExercice,
            libelleLigne: 'Résultat net (Perte) $year',
            debit: -resultatNet,
            credit: 0,
          ),
        );
      }

      final ecriture = EcritureComptable(
        dateComptable: dateCloture,
        libelle: 'Opérations de clôture exercice $year',
        numeroPiece: AccountingConfiguration.generatePieceNumber(
          AccountingConfiguration.prefixClosing,
        ),
        journalCode: AccountingConfiguration.journalOperationsDiverses,
        agentSaisie: 'SYSTEM',
        dateSaisie: DateTime.now(),
      );

      await _accountingService.createEcriture(
        ecriture,
        lignesCloture,
        txn: txn,
      );
    });
  }
}
