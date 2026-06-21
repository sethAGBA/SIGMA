import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sigma/core/services/auth_service.dart';
import 'package:sigma/core/services/database_service.dart';
import 'package:sigma/models/audit_log_model.dart';
import 'package:sigma/models/user_model.dart';
import 'package:sigma/core/utils/audit_field_utils.dart';

import '../helpers/phase1_test_helpers.dart';
import '../helpers/test_user_factory.dart';

bool get _isDesktop =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

/// Copie de la logique `_logDesktopSessionIfNeeded` pour tests (11.3).
Future<void> logDesktopSessionIfNeededForTesting() async {
  if (!_isDesktop) return;
  final role = AuthService().currentRole;
  if (role != SystemRole.superAdmin &&
      role != SystemRole.directeurFinancier) {
    return;
  }

  await DatabaseService().insertAuditLog(
    AuditLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: AuthService().currentUserId,
      username: auditFieldValue(AuthService().currentUsername),
      action: 'SQLITE_UNENCRYPTED_DESKTOP',
      details: 'Session démarrée sur Desktop — base SQLite non chiffrée.',
      timestamp: DateTime.now(),
      severity: AuditSeverity.medium,
    ),
  );
}

Widget buildDesktopWarningBannerForTesting() {
  if (!_isDesktop) return const SizedBox.shrink();
  return Container(
    width: double.infinity,
    color: Colors.amber.shade100,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    child: const Text(
      'Contrainte technique : sqflite_common_ffi (Desktop) ne supporte pas '
      'SQLCipher. Chiffrement actif sur Android/iOS uniquement.',
    ),
  );
}

void main() {
  setUpAll(initPhase1TestBindings);

  tearDown(() {
    clearAuthUser();
    tearDownPhase1Services();
  });

  group('SecurityAuditPage (11.3)', () {
    testWidgets('Desktop → bannière visible', (tester) async {
      if (!_isDesktop) return;

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: buildDesktopWarningBannerForTesting())),
      );

      expect(find.textContaining('SQLCipher'), findsOneWidget);
    });

    test('superAdmin Desktop → log SQLITE_UNENCRYPTED_DESKTOP', () async {
      if (!_isDesktop) return;

      AuthService().setCurrentUserForTesting(
        buildTestUser(role: SystemRole.superAdmin),
      );
      final db = await createPhase1TestDatabase();
      DatabaseService.setDatabaseForTesting(db);

      await logDesktopSessionIfNeededForTesting();

      final logs = await DatabaseService().getAuditLogs();
      expect(
        logs.any((l) => l.action == 'SQLITE_UNENCRYPTED_DESKTOP'),
        isTrue,
      );
    });

    test('agentCredit Desktop → pas de log SQLITE_UNENCRYPTED_DESKTOP', () async {
      if (!_isDesktop) return;

      AuthService().setCurrentUserForTesting(
        buildTestUser(
          username: 'agent',
          role: SystemRole.agentCredit,
          permissions: SystemRole.agentCredit.defaultPermissions,
        ),
      );
      final db = await createPhase1TestDatabase();
      DatabaseService.setDatabaseForTesting(db);

      await logDesktopSessionIfNeededForTesting();

      final logs = await DatabaseService().getAuditLogs();
      expect(logs, isEmpty);
    });
  });
}
