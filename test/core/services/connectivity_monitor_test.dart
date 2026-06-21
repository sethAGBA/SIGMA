// test/core/services/connectivity_monitor_test.dart
//
// Tests unitaires ConnectivityMonitor — Phase 0, tâche 4.3.
// Propriétés 8 à 12 (requirements 3.2–3.5, 3.7).

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sigma/core/services/connectivity_monitor.dart';
import 'package:sigma/core/services/sync_service.dart';

void main() {
  late ConnectivityMonitor monitor;

  setUp(() {
    ConnectivityMonitor.resetForTesting();
    monitor = ConnectivityMonitor();
  });

  tearDown(() {
    ConnectivityMonitor.resetForTesting();
  });

  group('Property 8 — événement none → offline immédiat', () {
    test('ConnectivityResult.none passe statusNotifier à offline sans ping', () async {
      monitor.statusNotifier.value = ConnectivityStatus.online;
      var serverChecked = false;
      monitor.isServerAvailableOverride = () async {
        serverChecked = true;
        return true;
      };

      await monitor.simulateConnectivityChanged([ConnectivityResult.none]);

      expect(monitor.statusNotifier.value, ConnectivityStatus.offline);
      expect(serverChecked, isFalse);
    });
  });

  group('Property 9 — événement non-none → vérification serveur immédiate', () {
    test('ConnectivityResult.wifi déclenche isServerAvailable()', () async {
      var checkCount = 0;
      monitor.isServerAvailableOverride = () async {
        checkCount++;
        return false;
      };

      await monitor.simulateConnectivityChanged([ConnectivityResult.wifi]);

      expect(checkCount, 1);
      expect(monitor.statusNotifier.value, ConnectivityStatus.offline);
    });
  });

  group('Property 10 — offline→online : syncing → flush → online', () {
    test('séquence stricte lors du retour réseau', () async {
      final transitions = <ConnectivityStatus>[];
      monitor.statusNotifier.addListener(() {
        transitions.add(monitor.statusNotifier.value);
      });

      var flushed = false;
      monitor.isServerAvailableOverride = () async => true;
      monitor.flushPendingOperationsOverride = () async {
        flushed = true;
        return SyncResult(success: true, synced: 2, failed: 0);
      };

      monitor.statusNotifier.value = ConnectivityStatus.offline;
      await monitor.simulateConnectivityChanged([ConnectivityResult.wifi]);

      expect(flushed, isTrue);
      expect(monitor.statusNotifier.value, ConnectivityStatus.online);
      expect(
        transitions,
        containsAll([
          ConnectivityStatus.syncing,
          ConnectivityStatus.online,
        ]),
      );
      expect(
        transitions.indexOf(ConnectivityStatus.syncing),
        lessThan(transitions.indexOf(ConnectivityStatus.online)),
      );
    });
  });

  group('Property 11 — un seul flush concurrent pendant syncing', () {
    test('N événements pendant syncing n\'appellent flush qu\'une fois', () async {
      final flushGate = Completer<SyncResult>();
      var flushCallCount = 0;

      monitor.isServerAvailableOverride = () async => true;
      monitor.flushPendingOperationsOverride = () {
        flushCallCount++;
        return flushGate.future;
      };

      monitor.statusNotifier.value = ConnectivityStatus.offline;

      final transition = monitor.simulateCheckAndTransition();

      await _waitUntil(() => monitor.statusNotifier.value == ConnectivityStatus.syncing);

      for (var i = 0; i < 5; i++) {
        unawaited(
          monitor.simulateConnectivityChanged([ConnectivityResult.wifi]),
        );
        unawaited(monitor.simulateCheckAndTransition());
      }

      flushGate.complete(SyncResult(success: true, synced: 1, failed: 0));
      await transition;

      expect(flushCallCount, 1);
      expect(monitor.statusNotifier.value, ConnectivityStatus.online);
    });
  });

  group('Property 12 — flush partiel → online quand même', () {
    test('failed > 0 laisse le statut final à online', () async {
      monitor.isServerAvailableOverride = () async => true;
      monitor.flushPendingOperationsOverride = () async =>
          SyncResult(success: false, synced: 1, failed: 3);

      monitor.statusNotifier.value = ConnectivityStatus.offline;
      await monitor.simulateCheckAndTransition();

      expect(monitor.statusNotifier.value, ConnectivityStatus.online);
    });
  });

  group('Cas limites', () {
    test('isServerAvailable lève une exception → offline', () async {
      monitor.isServerAvailableOverride = () async {
        throw Exception('network error');
      };

      await monitor.simulateCheckAndTransition();

      expect(monitor.statusNotifier.value, ConnectivityStatus.offline);
    });

    test('serveur indisponible → offline', () async {
      monitor.isServerAvailableOverride = () async => false;

      await monitor.simulateCheckAndTransition();

      expect(monitor.statusNotifier.value, ConnectivityStatus.offline);
    });

    test('déjà online et serveur OK → reste online sans flush', () async {
      var flushCalled = false;
      monitor.statusNotifier.value = ConnectivityStatus.online;
      monitor.isServerAvailableOverride = () async => true;
      monitor.flushPendingOperationsOverride = () async {
        flushCalled = true;
        return SyncResult(success: true, synced: 0, failed: 0);
      };

      await monitor.simulateCheckAndTransition();

      expect(flushCalled, isFalse);
      expect(monitor.statusNotifier.value, ConnectivityStatus.online);
    });
  });
}

Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Condition non satisfaite avant expiration du délai');
    }
    await Future<void>.delayed(Duration.zero);
  }
}
