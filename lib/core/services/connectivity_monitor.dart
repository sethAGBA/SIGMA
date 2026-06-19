// lib/core/services/connectivity_monitor.dart
//
// Surveille périodiquement la disponibilité du serveur et déclenche
// automatiquement la synchronisation des opérations offline en attente
// lors du retour de la connexion.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'sync_service.dart';

enum ConnectivityStatus { online, offline, syncing }

class ConnectivityMonitor {
  // Singleton
  static final ConnectivityMonitor _instance = ConnectivityMonitor._internal();
  factory ConnectivityMonitor() => _instance;
  ConnectivityMonitor._internal();

  /// Notifie les widgets de tout changement de statut de connexion.
  final ValueNotifier<ConnectivityStatus> statusNotifier =
      ValueNotifier(ConnectivityStatus.offline);

  Timer? _timer;

  // ── Cycle de vie ────────────────────────────────────────────────────────────

  /// Démarre la surveillance périodique (intervalle de 30 secondes).
  /// Une première vérification est déclenchée immédiatement.
  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), _onTick);
    // Vérification immédiate au démarrage
    _onTick(Timer(Duration.zero, () {}));
  }

  /// Arrête la surveillance et libère le timer.
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  // ── Logique de tick ─────────────────────────────────────────────────────────

  /// Appelé à chaque tick du timer.
  /// Vérifie la disponibilité du serveur et gère les transitions de statut.
  Future<void> _onTick(Timer _) async {
    // Ne pas interférer avec une synchronisation en cours
    if (statusNotifier.value == ConnectivityStatus.syncing) return;

    bool available;
    try {
      available = await ApiService().isServerAvailable();
    } catch (_) {
      statusNotifier.value = ConnectivityStatus.offline;
      return;
    }

    if (!available) {
      statusNotifier.value = ConnectivityStatus.offline;
      return;
    }

    // Le serveur est accessible
    if (statusNotifier.value == ConnectivityStatus.offline) {
      // Transition offline → online : vider la file de sync
      statusNotifier.value = ConnectivityStatus.syncing;
      await SyncService().flushPendingOperations();
      statusNotifier.value = ConnectivityStatus.online;
    } else {
      // Déjà online ou syncing : confirmer simplement le statut online
      statusNotifier.value = ConnectivityStatus.online;
    }
  }
}
