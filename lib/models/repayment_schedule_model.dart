// lib/models/repayment_schedule_model.dart

enum RepaymentStatus {
  paye('Payé'),
  impaye('Impayé'),
  partiel('Partiel'),
  enAttente('En attente');

  final String label;
  const RepaymentStatus(this.label);
}

class RepaymentSchedule {
  final int? id;
  final int pretId;
  final int numeroEcheance;
  final DateTime datePrevue;
  final double capitalDu;
  final double interetsDus;
  final double fraisDus;
  final double totalDu;
  final double capitalPaye;
  final double interetsPayes;
  final double fraisPayes;
  final double totalPaye;
  final double capitalRestant;
  final RepaymentStatus statut;
  final DateTime? dateEffectuee;

  // Champs additionnels pour l'affichage (chargés via jointure)
  final String? clientName;
  final String? numeroPret;
  final int? joursRetard;

  RepaymentSchedule({
    this.id,
    required this.pretId,
    required this.numeroEcheance,
    required this.datePrevue,
    required this.capitalDu,
    required this.interetsDus,
    this.fraisDus = 0,
    required this.totalDu,
    this.capitalPaye = 0,
    this.interetsPayes = 0,
    this.fraisPayes = 0,
    this.totalPaye = 0,
    required this.capitalRestant,
    required this.statut,
    this.dateEffectuee,
    this.clientName,
    this.numeroPret,
    this.joursRetard,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pret_id': pretId,
      'numero_echeance': numeroEcheance,
      'date_prevue': datePrevue.toIso8601String(),
      'capital_du': capitalDu,
      'interets_dus': interetsDus,
      'frais_dus': fraisDus,
      'total_du': totalDu,
      'capital_paye': capitalPaye,
      'interets_payes': interetsPayes,
      'frais_payes': fraisPayes,
      'total_paye': totalPaye,
      'capital_restant': capitalRestant,
      'statut': statut.name,
      'date_effectuee': dateEffectuee?.toIso8601String(),
    };
  }

  factory RepaymentSchedule.fromMap(Map<String, dynamic> map) {
    return RepaymentSchedule(
      id: map['id'],
      pretId: map['pret_id'],
      numeroEcheance: map['numero_echeance'],
      datePrevue: DateTime.parse(map['date_prevue']),
      capitalDu: map['capital_du'],
      interetsDus: map['interets_dus'],
      fraisDus: map['frais_dus'] ?? 0,
      totalDu: map['total_du'],
      capitalPaye: map['capital_paye'] ?? 0,
      interetsPayes: map['interets_payes'] ?? 0,
      fraisPayes: map['frais_payes'] ?? 0,
      totalPaye: map['total_paye'] ?? 0,
      capitalRestant: map['capital_restant'],
      statut: RepaymentStatus.values.firstWhere(
        (e) => e.name == map['statut'],
        orElse: () => RepaymentStatus.enAttente,
      ),
      dateEffectuee: map['date_effectuee'] != null
          ? DateTime.parse(map['date_effectuee'])
          : null,
      clientName: map['client_name'],
      numeroPret: map['numero_pret'],
      joursRetard: map['jours_retard'],
    );
  }
}
