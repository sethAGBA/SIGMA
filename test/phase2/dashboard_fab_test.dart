import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sigma/core/notifiers/dashboard_notifier.dart';
import 'package:sigma/core/services/auth_service.dart';
import 'package:sigma/models/user_model.dart';
import 'package:sigma/screens/dashboard/dashboard_page.dart';

import '../helpers/test_user_factory.dart';

Future<void> _pumpDashboard(WidgetTester tester) async {
  // Taille large pour éviter les overflow de rendu sur la barre de navigation
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ChangeNotifierProvider<DashboardNotifier>(
      create: (_) => DashboardNotifier(),
      child: const MaterialApp(home: Scaffold(body: DashboardPage())),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
}

Future<void> _openFabMenu(WidgetTester tester) async {
  await tester.tap(find.text('Actions rapides'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  tearDown(clearAuthUser);

  group('Dashboard FAB — Exigences 3.1, 3.5', () {
    testWidgets('affiche les 3 options du menu actions rapides', (tester) async {
      setAuthUser('admin_test');
      await _pumpDashboard(tester);

      expect(find.text('Actions rapides'), findsOneWidget);
      await _openFabMenu(tester);

      expect(find.text('Nouveau client'), findsOneWidget);
      expect(find.text('Nouveau prêt'), findsOneWidget);
      expect(find.text('Opération caisse'), findsOneWidget);
    });

    testWidgets('désactive les options sans permission', (tester) async {
      AuthService().setCurrentUserForTesting(
        buildTestUser(
          username: 'agent_limite',
          role: SystemRole.agentCredit,
          permissions: SystemRole.agentCredit.defaultPermissions,
        ),
      );

      await _pumpDashboard(tester);
      await _openFabMenu(tester);

      final clientTile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'Nouveau client'),
      );
      final loanTile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'Nouveau prêt'),
      );
      final cashTile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'Opération caisse'),
      );

      expect(clientTile.enabled, isFalse);
      expect(loanTile.enabled, isTrue);
      expect(cashTile.enabled, isFalse);
    });

    testWidgets('masque le FAB si aucune permission', (tester) async {
      AuthService().setCurrentUserForTesting(
        buildTestUser(
          username: 'lecteur',
          permissions: const ['read_all'],
        ),
      );

      await _pumpDashboard(tester);

      expect(find.text('Actions rapides'), findsNothing);
    });
  });
}
