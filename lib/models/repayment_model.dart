// lib/models/repayment_model.dart

enum RepaymentMode {
  especes('Espèces'),
  mobileMoney('Mobile Money'),
  virement('Virement'),
  cheque('Chèque');

  final String label;
  const RepaymentMode(this.label);
}

class Repayment {
  final int? id;
  final int pretId;
  final int? echeanceId; // Peut être nul si paiement libre/anticipé
  final double montantTotal;
  final double partCapital;
  final double partInterets;
  final double partPenalites;
  final DateTime datePaiement;
  final RepaymentMode modePaiement;
  final String numeroRecu;
  final String? agentCollecteur;
  final String? commentaire;
  final double? latitude;
  final double? longitude;
  final String? photoJustificatifPath;

  Repayment({
    this.id,
    required this.pretId,
    this.echeanceId,
    required this.montantTotal,
    required this.partCapital,
    required this.partInterets,
    required this.partPenalites,
    required this.datePaiement,
    required this.modePaiement,
    required this.numeroRecu,
    this.agentCollecteur,
    this.commentaire,
    this.latitude,
    this.longitude,
    this.photoJustificatifPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pret_id': pretId,
      'echeance_id': echeanceId,
      'montant_total': montantTotal,
      'part_capital': partCapital,
      'part_interets': partInterets,
      'part_penalites': partPenalites,
      'date_paiement': datePaiement.toIso8601String(),
      'mode_paiement': modePaiement.name,
      'numero_recu': numeroRecu,
      'agent_collecteur': agentCollecteur,
      'commentaire': commentaire,
      'latitude': latitude,
      'longitude': longitude,
      'photo_justificatif_path': photoJustificatifPath,
    };
  }

  factory Repayment.fromMap(Map<String, dynamic> map) {
    return Repayment(
      id: map['id'],
      pretId: map['pret_id'],
      echeanceId: map['echeance_id'],
      montantTotal: map['montant_total'],
      partCapital: map['part_capital'],
      partInterets: map['part_interets'],
      partPenalites: map['part_penalites'],
      datePaiement: DateTime.parse(map['date_paiement']),
      modePaiement: RepaymentMode.values.firstWhere(
        (e) => e.name == map['mode_paiement'],
        orElse: () => RepaymentMode.especes,
      ),
      numeroRecu: map['numero_recu'],
      agentCollecteur: map['agent_collecteur'],
      commentaire: map['commentaire'],
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      photoJustificatifPath: map['photo_justificatif_path'],
    );
  }

  Repayment copyWith({int? id, String? photoJustificatifPath}) {
    return Repayment(
      id: id ?? this.id,
      pretId: pretId,
      echeanceId: echeanceId,
      montantTotal: montantTotal,
      partCapital: partCapital,
      partInterets: partInterets,
      partPenalites: partPenalites,
      datePaiement: datePaiement,
      modePaiement: modePaiement,
      numeroRecu: numeroRecu,
      agentCollecteur: agentCollecteur,
      commentaire: commentaire,
      latitude: latitude,
      longitude: longitude,
      photoJustificatifPath: photoJustificatifPath ?? this.photoJustificatifPath,
    );
  }
}
