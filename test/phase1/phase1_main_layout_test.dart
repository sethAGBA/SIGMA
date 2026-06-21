import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sigma/core/services/auth_service.dart';
import 'package:sigma/models/user_model.dart';
import 'package:sigma/widgets/sidebar.dart';

import '../helpers/test_user_factory.dart';

/// Harness léger : garde RBAC + Sidebar sans charger les 46 pages de MainLayout.
class RbacNavHarness extends StatefulWidget {
  const RbacNavHarness({super.key});

  @override
  State<RbacNavHarness> createState() => RbacNavHarnessState();
}

class RbacNavHarnessState extends State<RbacNavHarness> {
  int selectedIndex = 0;
  BuildContext? _messengerContext;

  int get selectedIndexForTesting => selectedIndex;

  void selectDestinationForTesting(int index) {
    if (!AuthService().canAccessIndex(index)) {
      setState(() => selectedIndex = 0);
      if (_messengerContext != null) {
        ScaffoldMessenger.of(_messengerContext!).showSnackBar(
          const SnackBar(
            content: Text(
              'Accès refusé. Vous n\'avez pas les droits pour ce module.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    setState(() => selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (ctx) {
          _messengerContext = ctx;
          return Scaffold(
            body: Sidebar(
              selectedIndex: selectedIndex,
              onDestinationSelected: selectDestinationForTesting,
            ),
          );
        },
      ),
    );
  }
}

void main() {
  tearDown(clearAuthUser);

  Future<GlobalKey<RbacNavHarnessState>> pumpHarness(WidgetTester tester) async {
    final key = GlobalKey<RbacNavHarnessState>();
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

    await tester.pumpWidget(RbacNavHarness(key: key));
    await tester.pump();
    return key;
  }

  group('MainLayout — garde RBAC (7.2)', () {
    testWidgets('index non autorisé → selectedIndex 0 + SnackBar', (
      tester,
    ) async {
      AuthService().setCurrentUserForTesting(
        buildTestUser(
          username: 'agent',
          role: SystemRole.agentCredit,
          permissions: SystemRole.agentCredit.defaultPermissions,
        ),
      );

      final key = await pumpHarness(tester);
      key.currentState!.selectDestinationForTesting(14);
      await tester.pump();

      expect(key.currentState!.selectedIndexForTesting, 0);
      expect(
        find.text('Accès refusé. Vous n\'avez pas les droits pour ce module.'),
        findsOneWidget,
      );
    });

    testWidgets('index autorisé → selectedIndex mis à jour', (tester) async {
      AuthService().setCurrentUserForTesting(
        buildTestUser(
          username: 'agent',
          role: SystemRole.agentCredit,
          permissions: SystemRole.agentCredit.defaultPermissions,
        ),
      );

      final key = await pumpHarness(tester);
      key.currentState!.selectDestinationForTesting(1);
      await tester.pump();

      expect(key.currentState!.selectedIndexForTesting, 1);
    });
  });
}
