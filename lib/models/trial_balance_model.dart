// lib/models/trial_balance_model.dart

/// Représente une ligne de la Balance Générale
class TrialBalanceEntry {
  final String compteNumero;
  final String compteLibelle;
  final double totalDebit;
  final double totalCredit;
  final double soldeDebiteur;
  final double soldeCrediteur;

  TrialBalanceEntry({
    required this.compteNumero,
    required this.compteLibelle,
    required this.totalDebit,
    required this.totalCredit,
    required this.soldeDebiteur,
    required this.soldeCrediteur,
  });

  factory TrialBalanceEntry.fromMap(Map<String, dynamic> map) {
    final totalDebit = (map['total_debit'] as num?)?.toDouble() ?? 0.0;
    final totalCredit = (map['total_credit'] as num?)?.toDouble() ?? 0.0;
    final solde = totalDebit - totalCredit;

    return TrialBalanceEntry(
      compteNumero: map['compte_numero'] as String,
      compteLibelle: map['compte_libelle'] as String,
      totalDebit: totalDebit,
      totalCredit: totalCredit,
      soldeDebiteur: solde > 0 ? solde : 0.0,
      soldeCrediteur: solde < 0 ? -solde : 0.0,
    );
  }
}

/// Représente la Balance Générale complète
class TrialBalance {
  final List<TrialBalanceEntry> entries;
  final double totalDebits;
  final double totalCredits;
  final double totalSoldesDebiteurs;
  final double totalSoldesCrediteurs;
  final bool isBalanced;

  TrialBalance({
    required this.entries,
    required this.totalDebits,
    required this.totalCredits,
    required this.totalSoldesDebiteurs,
    required this.totalSoldesCrediteurs,
  }) : isBalanced =
           (totalDebits - totalCredits).abs() < 0.01 &&
           (totalSoldesDebiteurs - totalSoldesCrediteurs).abs() < 0.01;
}
