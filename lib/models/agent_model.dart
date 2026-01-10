import 'agent_stats_model.dart';

enum AgentRole { direction, agencyManager, loanOfficer, cashier, backOffice }

extension AgentRoleExtension on AgentRole {
  String get label {
    switch (this) {
      case AgentRole.direction:
        return 'Direction';
      case AgentRole.agencyManager:
        return 'Chef d\'agence';
      case AgentRole.loanOfficer:
        return 'Agent de crédit';
      case AgentRole.cashier:
        return 'Caissier';
      case AgentRole.backOffice:
        return 'Back-office';
    }
  }
}

class Agent {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final AgentRole role;
  final String agencyId;
  final bool isActive;
  final String? photoUrl;
  final DateTime hiredDate;
  final String? associatedAccountId;
  final AgentStats stats;

  Agent({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.role,
    required this.agencyId,
    required this.isActive,
    required this.hiredDate,
    this.photoUrl,
    this.associatedAccountId,
    this.stats = const AgentStats(),
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'role': role.name, // Use .name for consistency and readability
      'agency_id': agencyId,
      'is_active': isActive ? 1 : 0,
      'photo_url': photoUrl,
      'hired_date': hiredDate.toIso8601String(),
      'associated_account_id': associatedAccountId,
    };
  }

  factory Agent.fromMap(Map<String, dynamic> map) {
    // Robust role parsing: handles index (legacy) or string name
    AgentRole parsedRole;
    final roleValue = map['role'];
    if (roleValue is int) {
      parsedRole = AgentRole.values[roleValue];
    } else if (roleValue is String) {
      parsedRole = AgentRole.values.firstWhere(
        (r) => r.name == roleValue,
        orElse: () => AgentRole.loanOfficer,
      );
    } else {
      parsedRole = AgentRole.loanOfficer;
    }

    return Agent(
      id: map['id'],
      firstName: map['first_name'],
      lastName: map['last_name'],
      email: map['email'],
      phone: map['phone'],
      role: parsedRole,
      agencyId: map['agency_id'],
      isActive: map['is_active'] == 1,
      hiredDate: DateTime.parse(map['hired_date']),
      photoUrl: map['photo_url'],
      associatedAccountId: map['associated_account_id'],
      stats: const AgentStats(), // Stats loaded separately
    );
  }

  String get fullName => '$firstName $lastName';
}
