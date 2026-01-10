enum SystemRole {
  superAdmin,
  directeurGeneral,
  directeurOperations,
  directeurFinancier,
  chefAgence,
  agentCredit,
}

extension SystemRoleExtension on SystemRole {
  String get label {
    switch (this) {
      case SystemRole.superAdmin:
        return 'Super Administrateur';
      case SystemRole.directeurGeneral:
        return 'Directeur Général';
      case SystemRole.directeurOperations:
        return 'Directeur Opérations';
      case SystemRole.directeurFinancier:
        return 'Directeur Financier';
      case SystemRole.chefAgence:
        return 'Chef d\'agence';
      case SystemRole.agentCredit:
        return 'Agent de crédit';
    }
  }

  List<String> get defaultPermissions {
    switch (this) {
      case SystemRole.superAdmin:
        return ['all'];
      case SystemRole.directeurGeneral:
        return [
          'read_all',
          'validate_loans_all',
          'view_reporting_full',
          'manage_institution_params',
          'validate_budgets',
        ];
      case SystemRole.directeurOperations:
        return [
          'manage_clients',
          'manage_loans',
          'supervise_agencies',
          'validate_loans_gt_threshold',
          'view_portfolio',
          'view_reporting_ops',
        ];
      case SystemRole.directeurFinancier:
        return [
          'full_accounting',
          'view_financial_statements',
          'manage_cash_treasury',
          'management_control',
          'view_reporting_fin',
        ];
      case SystemRole.chefAgence:
        return [
          'manage_agency_only',
          'validate_loans_lt_threshold',
          'supervise_agents',
          'manage_agency_cash',
          'view_reporting_agency',
        ];
      case SystemRole.agentCredit:
        return [
          'view_assigned_clients',
          'create_loan_apps',
          'field_visits',
          'followup_assigned_loans',
        ];
    }
  }
}

class UserAccount {
  final String id;
  final String agentId;
  final String username;
  final String passwordHash; // In a real app, this should be properly hashed
  final SystemRole role;
  final bool isActive;
  final DateTime createdAt;
  final List<String> permissions;

  UserAccount({
    required this.id,
    required this.agentId,
    required this.username,
    required this.passwordHash,
    required this.role,
    this.isActive = true,
    required this.createdAt,
    this.permissions = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'agent_id': agentId,
      'username': username,
      'password_hash': passwordHash,
      'role': role.name,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'permissions': permissions.join(','),
    };
  }

  factory UserAccount.fromMap(Map<String, dynamic> map) {
    return UserAccount(
      id: map['id'],
      agentId: map['agent_id'],
      username: map['username'],
      passwordHash: map['password_hash'],
      role: SystemRole.values.firstWhere(
        (r) => r.name == map['role'],
        orElse: () => SystemRole.agentCredit,
      ),
      isActive: map['is_active'] == 1,
      createdAt: DateTime.parse(map['created_at']),
      permissions:
          (map['permissions'] as String?)
              ?.split(',')
              .where((p) => p.isNotEmpty)
              .toList() ??
          [],
    );
  }
}
