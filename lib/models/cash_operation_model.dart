// lib/models/cash_operation_model.dart

enum CashOperationType {
  entree('ENTREE'),
  sortie('SORTIE');

  final String value;
  const CashOperationType(this.value);

  static CashOperationType fromString(String value) {
    return CashOperationType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => CashOperationType.entree,
    );
  }

  String get label => this == CashOperationType.entree ? 'Entrée' : 'Sortie';
}

enum CashOperationCategory {
  remboursement('REMBOURSEMENT'),
  deblocage('DEBLOCAGE'),
  depot('DEPOT'),
  retrait('RETRAIT'),
  frais('FRAIS'),
  transfert('TRANSFERT'),
  autre('AUTRE');

  final String value;
  const CashOperationCategory(this.value);

  static CashOperationCategory fromString(String value) {
    return CashOperationCategory.values.firstWhere(
      (e) => e.value == value,
      orElse: () => CashOperationCategory.autre,
    );
  }

  String get label {
    switch (this) {
      case CashOperationCategory.remboursement:
        return 'Remboursement';
      case CashOperationCategory.deblocage:
        return 'Déblocage';
      case CashOperationCategory.depot:
        return 'Dépôt Épargne';
      case CashOperationCategory.retrait:
        return 'Retrait Épargne';
      case CashOperationCategory.frais:
        return 'Frais';
      case CashOperationCategory.transfert:
        return 'Transfert';
      default:
        return 'Autre';
    }
  }
}

class CashOperation {
  final int? id;
  final String? agenceId;
  final CashOperationType type;
  final CashOperationCategory categorie;
  final double montant;
  final String devise;
  final String? modePaiement;
  final String libelle;
  final String? referenceExterne;
  final String agentOperation;
  final DateTime dateOperation;

  CashOperation({
    this.id,
    this.agenceId,
    required this.type,
    required this.categorie,
    required this.montant,
    this.devise = 'FCFA',
    this.modePaiement,
    required this.libelle,
    this.referenceExterne,
    required this.agentOperation,
    required this.dateOperation,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'agence_id': agenceId,
      'type_operation': type.value,
      'categorie': categorie.value,
      'montant': montant,
      'devise': devise,
      'mode_paiement': modePaiement,
      'libelle': libelle,
      'reference_externe': referenceExterne,
      'agent_operation': agentOperation,
      'date_operation': dateOperation.toIso8601String(),
    };
  }

  factory CashOperation.fromMap(Map<String, dynamic> map) {
    return CashOperation(
      id: map['id'],
      agenceId: map['agence_id'],
      type: CashOperationType.fromString(map['type_operation'] ?? 'ENTREE'),
      categorie: CashOperationCategory.fromString(map['categorie'] ?? 'AUTRE'),
      montant: (map['montant'] as num).toDouble(),
      devise: map['devise'] ?? 'FCFA',
      modePaiement: map['mode_paiement'],
      libelle: map['libelle'] ?? '',
      referenceExterne: map['reference_externe'],
      agentOperation: map['agent_operation'] ?? '',
      dateOperation: DateTime.parse(map['date_operation']),
    );
  }
}
