// lib/models/savings_transaction_model.dart

enum SavingsTransactionType {
  depot('Dépôt'),
  retrait('Retrait'),
  interet('Crédit Intérêt'),
  frais('Frais de tenue');

  final String label;
  const SavingsTransactionType(this.label);
}

class SavingsTransaction {
  final int? id;
  final int compteId;
  final SavingsTransactionType type;
  final double montant;
  final double soldeApres;
  final String? agentOperation;
  final DateTime dateOperation;
  final String? numeroPiece;
  final String? commentaire;

  SavingsTransaction({
    this.id,
    required this.compteId,
    required this.type,
    required this.montant,
    required this.soldeApres,
    this.agentOperation,
    required this.dateOperation,
    this.numeroPiece,
    this.commentaire,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'compte_id': compteId,
      'type_operation': type.name,
      'montant': montant,
      'solde_apres': soldeApres,
      'agent_operation': agentOperation,
      'date_operation': dateOperation.toIso8601String(),
      'numero_piece': numeroPiece,
      'commentaire': commentaire,
    };
  }

  factory SavingsTransaction.fromMap(Map<String, dynamic> map) {
    return SavingsTransaction(
      id: map['id'],
      compteId: map['compte_id'],
      type: SavingsTransactionType.values.firstWhere(
        (e) => e.name == map['type_operation'],
        orElse: () => SavingsTransactionType.depot,
      ),
      montant: (map['montant'] as num).toDouble(),
      soldeApres: (map['solde_apres'] as num).toDouble(),
      agentOperation: map['agent_operation'],
      dateOperation: DateTime.parse(map['date_operation']),
      numeroPiece: map['numero_piece'],
      commentaire: map['commentaire'],
    );
  }
}
