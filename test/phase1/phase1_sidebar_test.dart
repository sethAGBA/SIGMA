import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sigma/core/services/auth_service.dart';
import 'package:sigma/models/sidebar_module.dart';
import 'package:sigma/models/user_model.dart';
import 'package:sigma/widgets/sidebar.dart';
import 'package:sigma/widgets/sidebar_config.dart';

import '../helpers/test_user_factory.dart';

Future<void> pumpSidebarIgnoringOverflow(
  WidgetTester tester,
  Sidebar sidebar,
) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    originalOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = originalOnError);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: sidebar),
    ),
  );
  await tester.pump();
}

void main() {
  tearDown(clearAuthUser);

  group('Property 8 — Visibilité RBAC Sidebar', () {
    testWidgets('agentCredit : clients visible, caisse absent', (tester) async {
      AuthService().setCurrentUserForTesting(
        buildTestUser(
          username: 'agent',
          role: SystemRole.agentCredit,
          permissions: SystemRole.agentCredit.defaultPermissions,
        ),
      );
      await pumpSidebarIgnoringOverflow(
        tester,
        Sidebar(selectedIndex: 0, onDestinationSelected: (_) {}),
      );

      expect(find.text('Registre des clients'), findsOneWidget);
      expect(find.text('Opérations de caisse'), findsNothing);
      expect(find.text('Plan comptable'), findsNothing);
    });

    test('superAdmin : entrée serveur présente dans les modules autorisés', () {
      AuthService().setCurrentUserForTesting(
        buildTestUser(username: 'admin', role: SystemRole.superAdmin),
      );
      final auth = AuthService();
      final labels = [
        kDashboardEntry,
        ...kAllSidebarSections.expand((s) => s.entries),
      ]
          .where((e) => auth.canAccessModule(e.module))
          .map((e) => e.label);

      expect(labels, contains('Serveur & Connexion'));
    });
  });

  group('Property 9 — Masquage titres de sections vides', () {
    testWidgets('directeurFinancier : pas de titre GESTION CLIENTS', (
      tester,
    ) async {
      AuthService().setCurrentUserForTesting(
        buildTestUser(
          username: 'df',
          role: SystemRole.directeurFinancier,
          permissions: SystemRole.directeurFinancier.defaultPermissions,
        ),
      );
      await pumpSidebarIgnoringOverflow(
        tester,
        Sidebar(selectedIndex: 0, onDestinationSelected: (_) {}),
      );

      expect(find.text('GESTION CLIENTS'), findsNothing);
      expect(find.text('Plan comptable'), findsOneWidget);
    });

    test('directeurFinancier : modules clients et prêts interdits', () {
      AuthService().setCurrentUserForTesting(
        buildTestUser(
          role: SystemRole.directeurFinancier,
          permissions: SystemRole.directeurFinancier.defaultPermissions,
        ),
      );
      final auth = AuthService();
      expect(auth.canAccessModule(SidebarModule.clients), isFalse);
      expect(auth.canAccessModule(SidebarModule.prets), isFalse);
      expect(auth.canAccessModule(SidebarModule.comptabilite), isTrue);
    });
  });
}
