// lib/core/services/automatic_accounting_service.dart

import 'package:sqflite/sqflite.dart';
import '../../models/accounting_config_model.dart';
import '../../core/services/database_service.dart';
import '../../models/ecriture_comptable_model.dart';
import '../../models/loan_model.dart';
import '../../models/repayment_model.dart';
import '../../models/savings_transaction_model.dart';
import 'accounting_service.dart';

/// Service pour générer automatiquement les écritures comptables
/// lors des opérations de prêt et d'épargne
class AutomaticAccountingService {
  final AccountingService _accountingService = AccountingService();
  final DatabaseService _dbService = DatabaseService();

  /// Crée une écriture comptable pour un déblocage de prêt
  Future<void> createLoanDisbursementEntry({
    required Loan loan,
    required String agentName,
    DatabaseExecutor? txn,
  }) async {
    final config = await _dbService.getAccountingConfig();
    final numeroPiece = AccountingConfiguration.generatePieceNumber(
      AccountingConfiguration.prefixLoanDisbursement,
    );

    final ecriture = EcritureComptable(
      dateComptable: loan.dateDeblocage,
      journalCode: AccountingConfiguration.journalOperationsDiverses,
      numeroPiece: numeroPiece,
      libelle:
          'Déblocage prêt #${loan.numeroPret} - Client ID: ${loan.clientId}',
      agentSaisie: agentName,
      statut: 'VALIDE',
      dateSaisie: DateTime.now(),
    );

    final lignes = [
      // Débit: Prêts à la clientèle
      LigneEcriture(
        compteNumero: config.comptePrets,
        libelleLigne: 'Déblocage prêt #${loan.numeroPret}',
        debit: loan.montantInitial,
        credit: 0,
        refExterne: loan.numeroPret,
        tiers: 'Client ${loan.clientId}',
      ),
      // Crédit: Caisse
      LigneEcriture(
        compteNumero: config.compteCaisse,
        libelleLigne: 'Décaissement prêt #${loan.numeroPret}',
        debit: 0,
        credit: loan.montantInitial,
        refExterne: loan.numeroPret,
      ),
    ];

    await _accountingService.createEcriture(ecriture, lignes, txn: txn);
  }

  /// Crée une écriture comptable pour un remboursement de prêt
  Future<void> createLoanRepaymentEntry({
    required Repayment repayment,
    required String loanNumber,
    required int clientId,
    required String agentName,
    DatabaseExecutor? txn,
  }) async {
    final config = await _dbService.getAccountingConfig();
    final numeroPiece = AccountingConfiguration.generatePieceNumber(
      AccountingConfiguration.prefixLoanRepayment,
    );

    final ecriture = EcritureComptable(
      dateComptable: repayment.datePaiement,
      journalCode: AccountingConfiguration.journalOperationsDiverses,
      numeroPiece: numeroPiece,
      libelle: 'Remboursement prêt #$loanNumber - Reçu ${repayment.numeroRecu}',
      agentSaisie: agentName,
      statut: 'VALIDE',
      dateSaisie: DateTime.now(),
    );

    final lignes = <LigneEcriture>[
      // Débit: Caisse (montant total)
      LigneEcriture(
        compteNumero: config.compteCaisse,
        libelleLigne: 'Encaissement remboursement prêt #$loanNumber',
        debit: repayment.montantTotal,
        credit: 0,
        refExterne: repayment.numeroRecu,
        tiers: 'Client $clientId',
      ),
      // Crédit: Prêts (part capital)
      LigneEcriture(
        compteNumero: config.comptePrets,
        libelleLigne: 'Remboursement capital prêt #$loanNumber',
        debit: 0,
        credit: repayment.partCapital,
        refExterne: repayment.numeroRecu,
        tiers: 'Client $clientId',
      ),
    ];

    // Ajouter les intérêts si > 0
    if (repayment.partInterets > 0) {
      lignes.add(
        LigneEcriture(
          compteNumero: config.compteInterets,
          libelleLigne: 'Intérêts prêt #$loanNumber',
          debit: 0,
          credit: repayment.partInterets,
          refExterne: repayment.numeroRecu,
          tiers: 'Client $clientId',
        ),
      );
    }

    // Ajouter les pénalités si > 0
    if (repayment.partPenalites > 0) {
      lignes.add(
        LigneEcriture(
          compteNumero: config.comptePenalites,
          libelleLigne: 'Pénalités retard prêt #$loanNumber',
          debit: 0,
          credit: repayment.partPenalites,
          refExterne: repayment.numeroRecu,
          tiers: 'Client $clientId',
        ),
      );
    }

    await _accountingService.createEcriture(ecriture, lignes, txn: txn);
  }

  /// Crée une écriture comptable pour un dépôt d'épargne
  Future<void> createSavingsDepositEntry({
    required SavingsTransaction transaction,
    required String accountNumber,
    required int clientId,
    required String agentName,
    DatabaseExecutor? txn,
  }) async {
    final config = await _dbService.getAccountingConfig();
    final numeroPiece = AccountingConfiguration.generatePieceNumber(
      AccountingConfiguration.prefixSavingsDeposit,
    );

    final ecriture = EcritureComptable(
      dateComptable: transaction.dateOperation,
      journalCode: AccountingConfiguration.journalOperationsDiverses,
      numeroPiece: numeroPiece,
      libelle:
          'Dépôt épargne compte $accountNumber - ${transaction.numeroPiece ?? ""}',
      agentSaisie: agentName,
      statut: 'VALIDE',
      dateSaisie: DateTime.now(),
    );

    final lignes = [
      // Débit: Caisse
      LigneEcriture(
        compteNumero: config.compteCaisse,
        libelleLigne: 'Dépôt épargne compte $accountNumber',
        debit: transaction.montant,
        credit: 0,
        refExterne: transaction.numeroPiece,
        tiers: 'Client $clientId',
      ),
      // Crédit: Dépôts clientèle
      LigneEcriture(
        compteNumero: config.compteDepots,
        libelleLigne: 'Dépôt épargne compte $accountNumber',
        debit: 0,
        credit: transaction.montant,
        refExterne: transaction.numeroPiece,
        tiers: 'Client $clientId',
      ),
    ];

    await _accountingService.createEcriture(ecriture, lignes, txn: txn);
  }

  /// Crée une écriture comptable pour un retrait d'épargne
  Future<void> createSavingsWithdrawalEntry({
    required SavingsTransaction transaction,
    required String accountNumber,
    required int clientId,
    required String agentName,
    DatabaseExecutor? txn,
  }) async {
    final config = await _dbService.getAccountingConfig();
    final numeroPiece = AccountingConfiguration.generatePieceNumber(
      AccountingConfiguration.prefixSavingsWithdrawal,
    );

    final ecriture = EcritureComptable(
      dateComptable: transaction.dateOperation,
      journalCode: AccountingConfiguration.journalOperationsDiverses,
      numeroPiece: numeroPiece,
      libelle:
          'Retrait épargne compte $accountNumber - ${transaction.numeroPiece ?? ""}',
      agentSaisie: agentName,
      statut: 'VALIDE',
      dateSaisie: DateTime.now(),
    );

    final lignes = [
      // Débit: Dépôts clientèle
      LigneEcriture(
        compteNumero: config.compteDepots,
        libelleLigne: 'Retrait épargne compte $accountNumber',
        debit: transaction.montant,
        credit: 0,
        refExterne: transaction.numeroPiece,
        tiers: 'Client $clientId',
      ),
      // Crédit: Caisse
      LigneEcriture(
        compteNumero: config.compteCaisse,
        libelleLigne: 'Retrait épargne compte $accountNumber',
        debit: 0,
        credit: transaction.montant,
        refExterne: transaction.numeroPiece,
        tiers: 'Client $clientId',
      ),
    ];

    await _accountingService.createEcriture(ecriture, lignes, txn: txn);
  }

  /// Crée une écriture de dotation aux provisions
  Future<void> createProvisionEntry({
    required double amount,
    required String agentName,
    DatabaseExecutor? txn,
  }) async {
    final config = await _dbService.getAccountingConfig();
    final numeroPiece = AccountingConfiguration.generatePieceNumber(
      AccountingConfiguration.prefixProvisioning,
    );

    final ecriture = EcritureComptable(
      dateComptable: DateTime.now(),
      journalCode: AccountingConfiguration.journalOperationsDiverses,
      numeroPiece: numeroPiece,
      libelle: 'Dotation aux provisions sur créances douteuses',
      agentSaisie: agentName,
      statut: 'VALIDE',
      dateSaisie: DateTime.now(),
    );

    final lignes = [
      // Débit: Dotations aux provisions (Compte 6972)
      LigneEcriture(
        compteNumero: config.compteDotationProvisions,
        libelleLigne: 'Dotation aux provisions',
        debit: amount,
        credit: 0,
        refExterne: numeroPiece,
      ),
      // Crédit: Dépréciation des prêts (Compte 2971)
      LigneEcriture(
        compteNumero: config.compteDepreciationPrets,
        libelleLigne: 'Dépréciation des prêts',
        debit: 0,
        credit: amount,
        refExterne: numeroPiece,
      ),
    ];

    await _accountingService.createEcriture(ecriture, lignes, txn: txn);
  }
}
