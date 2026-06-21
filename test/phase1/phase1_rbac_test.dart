import 'package:flutter_test/flutter_test.dart';
import 'package:sigma/core/services/auth_service.dart';
import 'package:sigma/models/sidebar_module.dart';
import 'package:sigma/models/user_model.dart';

import '../helpers/test_user_factory.dart';

void main() {
  tearDown(clearAuthUser);

  group('Phase 1 — RBAC canAccessModule', () {
    test('Property 10 — matrice RBAC complète (6 rôles × 16 modules)', () {
      for (final role in SystemRole.values) {
        AuthService().setCurrentUserForTesting(buildTestUser(role: role));
        final allowed = AuthService.rbacMatrixForTesting[role] ?? {};
        for (final module in SidebarModule.values) {
          final expected =
              role == SystemRole.superAdmin || allowed.contains(module);
          expect(
            AuthService().canAccessModule(module),
            expected,
            reason: '$role → $module',
          );
        }
      }
    });

    test('superAdmin accède à tous les modules dont serveurConnexion', () {
      AuthService().setCurrentUserForTesting(
        buildTestUser(role: SystemRole.superAdmin),
      );
      for (final module in SidebarModule.values) {
        expect(
          AuthService().canAccessModule(module),
          isTrue,
          reason: 'superAdmin → $module',
        );
      }
    });

    test('agentCredit n\'accède pas à caisse ni comptabilite', () {
      AuthService().setCurrentUserForTesting(
        buildTestUser(
          username: 'agent',
          role: SystemRole.agentCredit,
          permissions: SystemRole.agentCredit.defaultPermissions,
        ),
      );
      expect(AuthService().canAccessModule(SidebarModule.caisse), isFalse);
      expect(AuthService().canAccessModule(SidebarModule.comptabilite), isFalse);
      expect(AuthService().canAccessModule(SidebarModule.clients), isTrue);
    });

    test('directeurFinancier accède à securiteAudit mais pas serveurConnexion', () {
      AuthService().setCurrentUserForTesting(
        buildTestUser(
          username: 'df',
          role: SystemRole.directeurFinancier,
          permissions: SystemRole.directeurFinancier.defaultPermissions,
        ),
      );
      expect(AuthService().canAccessModule(SidebarModule.securiteAudit), isTrue);
      expect(AuthService().canAccessModule(SidebarModule.serveurConnexion), isFalse);
    });
  });

  group('Phase 1 — RBAC canAccessIndex', () {
    test('cohérence index ↔ module pour chaque entrée de moduleIndexes', () {
      AuthService().setCurrentUserForTesting(
        buildTestUser(
          username: 'chef',
          role: SystemRole.chefAgence,
          permissions: SystemRole.chefAgence.defaultPermissions,
        ),
      );
      for (final entry in AuthService.moduleIndexes.entries) {
        final allowed = AuthService().canAccessModule(entry.key);
        for (final index in entry.value) {
          expect(
            AuthService().canAccessIndex(index),
            allowed,
            reason: 'index $index ↔ ${entry.key}',
          );
        }
      }
    });

    test('index 45 réservé superAdmin uniquement', () {
      AuthService().setCurrentUserForTesting(
        buildTestUser(role: SystemRole.directeurGeneral),
      );
      expect(AuthService().canAccessIndex(45), isFalse);

      AuthService().setCurrentUserForTesting(
        buildTestUser(role: SystemRole.superAdmin),
      );
      expect(AuthService().canAccessIndex(45), isTrue);
    });
  });
}
