// lib/models/groupe_solidaire_model.dart

enum GroupStatus { active, inactive, dissolved }

class GroupeSolidaire {
  final int? id;
  final String code; // Code unique du groupe
  final String nom;
  final int? responsableId; // ID du client responsable
  final int? tresorierId; // ID du client trésorier
  final DateTime dateCreation;
  final GroupStatus statut;
  final String? description;

  GroupeSolidaire({
    this.id,
    required this.code,
    required this.nom,
    this.responsableId,
    this.tresorierId,
    required this.dateCreation,
    this.statut = GroupStatus.active,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'nom': nom,
      'responsable_id': responsableId,
      'tresorier_id': tresorierId,
      'date_creation': dateCreation.toIso8601String(),
      'statut': statusToLabel(statut),
      'description': description,
    };
  }

  factory GroupeSolidaire.fromMap(Map<String, dynamic> map) {
    return GroupeSolidaire(
      id: map['id'],
      code: map['code'],
      nom: map['nom'],
      responsableId: map['responsable_id'],
      tresorierId: map['tresorier_id'],
      dateCreation: DateTime.parse(map['date_creation']),
      statut: labelToStatus(map['statut']),
      description: map['description'],
    );
  }

  static String statusToLabel(GroupStatus status) {
    switch (status) {
      case GroupStatus.active:
        return 'Actif';
      case GroupStatus.inactive:
        return 'Inactif';
      case GroupStatus.dissolved:
        return 'Dissous';
    }
  }

  static GroupStatus labelToStatus(String? label) {
    switch (label) {
      case 'Inactif':
        return GroupStatus.inactive;
      case 'Dissous':
        return GroupStatus.dissolved;
      default:
        return GroupStatus.active;
    }
  }
}
