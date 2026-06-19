import 'package:flutter_test/flutter_test.dart';
import 'package:sigma/core/services/auth_service.dart';
import 'package:sigma/models/user_model.dart';

import '../helpers/test_user_factory.dart';

void main() {
  tearDown(clearAuthUser);

  group('AuthService.canAccess — alias Phase 2 FAB', () {
    test('create_client via manage_clients', () {
      AuthService().setCurrentUserForTesting(
        buildTestUser(
          username: 'ops',
          role: SystemRole.directeurOperations,
          permissions: SystemRole.directeurOperations.defaultPermissions,
        ),
      );
      expect(AuthService().canAccess('create_client'), isTrue);
    });

    test('create_loan via create_loan_apps', () {
      AuthService().setCurrentUserForTesting(
        buildTestUser(
          username: 'agent',
          role: SystemRole.agentCredit,
          permissions: SystemRole.agentCredit.defaultPermissions,
        ),
      );
      expect(AuthService().canAccess('create_loan'), isTrue);
      expect(AuthService().canAccess('create_client'), isFalse);
    });

    test('cash_operation via manage_agency_cash', () {
      AuthService().setCurrentUserForTesting(
        buildTestUser(
          username: 'chef',
          role: SystemRole.chefAgence,
          permissions: SystemRole.chefAgence.defaultPermissions,
        ),
      );
      expect(AuthService().canAccess('cash_operation'), isTrue);
    });
  });
}
