// lib/models/recovery_action_model.dart

enum RecoveryActionType {
  sms('SMS Raport'),
  call('Appel téléphonique'),
  visit('Visite domicile/activité'),
  summons('Convocation agence'),
  commitment('Engagement écrit'),
  meeting('Réunion caution/groupe'),
  warning('Mise en demeure'),
  legal('Passage contentieux');

  final String label;
  const RecoveryActionType(this.label);
}

class RecoveryAction {
  final int? id;
  final int loanId;
  final DateTime date;
  final RecoveryActionType type;
  final String description;
  final String agentName;
  final String result;

  // Champs pour l'affichage (via jointure)
  final String? clientName;
  final String? numeroPret;

  RecoveryAction({
    this.id,
    required this.loanId,
    required this.date,
    required this.type,
    required this.description,
    required this.agentName,
    required this.result,
    this.clientName,
    this.numeroPret,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pret_id': loanId,
      'date_action': date.toIso8601String(),
      'type_action': type.name,
      'description': description,
      'agent_name': agentName,
      'resultat': result,
    };
  }

  factory RecoveryAction.fromMap(Map<String, dynamic> map) {
    return RecoveryAction(
      id: map['id'],
      loanId: map['pret_id'],
      date: DateTime.parse(map['date_action']),
      type: RecoveryActionType.values.firstWhere(
        (e) => e.name == map['type_action'],
        orElse: () => RecoveryActionType.call,
      ),
      description: map['description'] ?? '',
      agentName: map['agent_name'] ?? '',
      result: map['resultat'] ?? '',
      clientName: map['client_name'],
      numeroPret: map['numero_pret'],
    );
  }
}

class RecoveryStats {
  final int totalActions;
  final Map<RecoveryActionType, int> actionsByType;
  final Map<String, int> actionsByAgent;
  final int uniqueLoansImpacted;
  final int successfulActions; // Actions with a result that implies success

  RecoveryStats({
    required this.totalActions,
    required this.actionsByType,
    required this.actionsByAgent,
    required this.uniqueLoansImpacted,
    this.successfulActions = 0,
  });

  double get successRate =>
      totalActions > 0 ? (successfulActions / totalActions) * 100 : 0;
}
