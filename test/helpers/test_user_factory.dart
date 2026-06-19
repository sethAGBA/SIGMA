import 'package:sigma/core/utils/audit_field_utils.dart';
import 'package:sigma/core/services/auth_service.dart';
import 'package:sigma/models/user_model.dart';

export 'package:sigma/core/utils/audit_field_utils.dart' show auditFieldValue;

UserAccount buildTestUser({
  String username = 'test_user',
  List<String> permissions = const ['all'],
  SystemRole role = SystemRole.superAdmin,
}) {
  return UserAccount(
    id: 'test-${username.hashCode}',
    agentId: 'agent-1',
    username: username,
    passwordHash: 'hash',
    role: role,
    isActive: true,
    createdAt: DateTime(2024, 1, 1),
    permissions: permissions,
  );
}

void setAuthUser(String username, {List<String> permissions = const ['all']}) {
  AuthService().setCurrentUserForTesting(
    buildTestUser(username: username, permissions: permissions),
  );
}

void clearAuthUser() {
  AuthService().resetForTesting();
}
