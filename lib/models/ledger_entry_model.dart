// lib/models/ledger_entry_model.dart

/// Représente une ligne de mouvement dans le Grand Livre
class LedgerEntry {
  final int? ecritureId;
  final DateTime dateComptable;
  final String journalCode;
  final String numeroPiece;
  final String libelle;
  final double debit;
  final double credit;
  final double solde;
  final String? refExterne;
  final String? tiers;

  LedgerEntry({
    this.ecritureId,
    required this.dateComptable,
    required this.journalCode,
    required this.numeroPiece,
    required this.libelle,
    required this.debit,
    required this.credit,
    required this.solde,
    this.refExterne,
    this.tiers,
  });

  factory LedgerEntry.fromMap(Map<String, dynamic> map) {
    return LedgerEntry(
      ecritureId: map['ecriture_id'],
      dateComptable: DateTime.parse(map['date_comptable']),
      journalCode: map['journal_code'],
      numeroPiece: map['numero_piece'],
      libelle: map['libelle_ligne'],
      debit: (map['debit'] as num?)?.toDouble() ?? 0.0,
      credit: (map['credit'] as num?)?.toDouble() ?? 0.0,
      solde: (map['solde'] as num?)?.toDouble() ?? 0.0,
      refExterne: map['ref_externe'],
      tiers: map['tiers'],
    );
  }
}

/// Représente le Grand Livre d'un compte
class AccountLedger {
  final String compteNumero;
  final String compteLibelle;
  final double soldeInitial;
  final List<LedgerEntry> mouvements;
  final double totalDebit;
  final double totalCredit;
  final double soldeFinal;

  AccountLedger({
    required this.compteNumero,
    required this.compteLibelle,
    required this.soldeInitial,
    required this.mouvements,
    required this.totalDebit,
    required this.totalCredit,
    required this.soldeFinal,
  });
}
