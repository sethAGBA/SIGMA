class EcritureComptable {
  final int? id;
  final DateTime dateComptable;
  final String journalCode;
  final String numeroPiece;
  final String libelle;
  final String agentSaisie;
  final String statut; // BROUILLON, VALIDE
  final DateTime dateSaisie;

  final String? pieceJointe;

  EcritureComptable({
    this.id,
    required this.dateComptable,
    required this.journalCode,
    required this.numeroPiece,
    required this.libelle,
    required this.agentSaisie,
    this.statut = 'BROUILLON',
    required this.dateSaisie,
    this.pieceJointe,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date_comptable': dateComptable.toIso8601String(),
      'journal_code': journalCode,
      'numero_piece': numeroPiece,
      'libelle': libelle,
      'agent_saisie': agentSaisie,
      'statut': statut,
      'date_saisie': dateSaisie.toIso8601String(),
      'piece_jointe': pieceJointe,
    };
  }

  factory EcritureComptable.fromMap(Map<String, dynamic> map) {
    return EcritureComptable(
      id: map['id'],
      dateComptable: DateTime.parse(map['date_comptable']),
      journalCode: map['journal_code'],
      numeroPiece: map['numero_piece'],
      libelle: map['libelle'],
      agentSaisie: map['agent_saisie'],
      statut: map['statut'],
      dateSaisie: DateTime.parse(map['date_saisie']),
      pieceJointe: map['piece_jointe'],
    );
  }
}

class LigneEcriture {
  final int? id;
  final int? ecritureId;
  final String compteNumero;
  final String libelleLigne;
  final double debit;
  final double credit;
  final String? refExterne;
  final String? tiers;
  final String? refAnalytique;

  LigneEcriture({
    this.id,
    this.ecritureId,
    required this.compteNumero,
    required this.libelleLigne,
    required this.debit,
    required this.credit,
    this.refExterne,
    this.tiers,
    this.refAnalytique,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ecriture_id': ecritureId,
      'compte_numero': compteNumero,
      'libelle_ligne': libelleLigne,
      'debit': debit,
      'credit': credit,
      'ref_externe': refExterne,
      'tiers': tiers,
      'ref_analytique': refAnalytique,
    };
  }

  factory LigneEcriture.fromMap(Map<String, dynamic> map) {
    return LigneEcriture(
      id: map['id'],
      ecritureId: map['ecriture_id'],
      compteNumero: map['compte_numero'],
      libelleLigne: map['libelle_ligne'],
      debit: map['debit'],
      credit: map['credit'],
      refExterne: map['ref_externe'],
      tiers: map['tiers'],
      refAnalytique: map['ref_analytique'],
    );
  }
}
