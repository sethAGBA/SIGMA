// lib/models/accounting_config_model.dart

/// Configuration des comptes comptables pour les écritures automatiques
class AccountingConfiguration {
  // Instance variables with default SYSCOHADA values
  String comptePrets;
  String compteCaisse;
  String compteInterets;
  String comptePenalites;
  String compteInteretsCourusPrets;
  String compteDotationProvisions;
  String compteDepreciationPrets;
  String compteDepots;
  String compteInteretsAcquisEpargne;
  String compteChargeInteretEpargne;
  String compteResultatExercice;
  String compteBanque;
  String compteVenteServices;
  String compteProduitsFinanciers;

  AccountingConfiguration({
    this.comptePrets = '271',
    this.compteCaisse = '571',
    this.compteInterets = '7712',
    this.comptePenalites = '7078',
    this.compteInteretsCourusPrets = '2761',
    this.compteDotationProvisions = '6972',
    this.compteDepreciationPrets = '2971',
    this.compteDepots = '1651',
    this.compteInteretsAcquisEpargne = '1665',
    this.compteChargeInteretEpargne = '6741',
    this.compteResultatExercice = '131',
    this.compteBanque = '521',
    this.compteVenteServices = '706',
    this.compteProduitsFinanciers = '77',
  });

  // Factory constructor for default configuration (SYSCOHADA)
  factory AccountingConfiguration.defaultConfig() {
    return AccountingConfiguration();
  }

  // Create from Map (key-value pairs from DB)
  factory AccountingConfiguration.fromMap(Map<String, String> map) {
    return AccountingConfiguration(
      comptePrets: map['comptePrets'] ?? '271',
      compteCaisse: map['compteCaisse'] ?? '571',
      compteInterets: map['compteInterets'] ?? '7712',
      comptePenalites: map['comptePenalites'] ?? '7078',
      compteInteretsCourusPrets: map['compteInteretsCourusPrets'] ?? '2761',
      compteDotationProvisions: map['compteDotationProvisions'] ?? '6972',
      compteDepreciationPrets: map['compteDepreciationPrets'] ?? '2971',
      compteDepots: map['compteDepots'] ?? '1651',
      compteInteretsAcquisEpargne: map['compteInteretsAcquisEpargne'] ?? '1665',
      compteChargeInteretEpargne: map['compteChargeInteretEpargne'] ?? '6741',
      compteResultatExercice: map['compteResultatExercice'] ?? '131',
      compteBanque: map['compteBanque'] ?? '521',
      compteVenteServices: map['compteVenteServices'] ?? '706',
      compteProduitsFinanciers: map['compteProduitsFinanciers'] ?? '77',
    );
  }

  // Convert to Map (for DB creation/saving)
  Map<String, String> toMap() {
    return {
      'comptePrets': comptePrets,
      'compteCaisse': compteCaisse,
      'compteInterets': compteInterets,
      'comptePenalites': comptePenalites,
      'compteInteretsCourusPrets': compteInteretsCourusPrets,
      'compteDotationProvisions': compteDotationProvisions,
      'compteDepreciationPrets': compteDepreciationPrets,
      'compteDepots': compteDepots,
      'compteInteretsAcquisEpargne': compteInteretsAcquisEpargne,
      'compteChargeInteretEpargne': compteChargeInteretEpargne,
      'compteResultatExercice': compteResultatExercice,
      'compteBanque': compteBanque,
      'compteVenteServices': compteVenteServices,
      'compteProduitsFinanciers': compteProduitsFinanciers,
    };
  }

  // Static constants for Journals and Prefixes remain static
  static const String journalOperationsDiverses = 'OD';

  static const String prefixLoanDisbursement = 'AUTO-LOAN';
  static const String prefixLoanRepayment = 'AUTO-REPAY';
  static const String prefixSavingsDeposit = 'AUTO-SAV-DEP';
  static const String prefixSavingsWithdrawal = 'AUTO-SAV-RET';
  static const String prefixAccruedInterest = 'AUTO-ACCRUED';
  static const String prefixProvisioning = 'AUTO-PROV';
  static const String prefixClosing = 'AUTO-CLOSE';

  /// Génère un numéro de pièce unique
  static String generatePieceNumber(String prefix) {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch;
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    return '$prefix-$dateStr-$timestamp';
  }
}
