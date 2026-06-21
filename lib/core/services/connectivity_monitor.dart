// lib/core/services/connectivity_monitor.dart
//
// Surveille la disponibilité du serveur via deux sources complémentaires :
//  1. Le stream connectivity_plus (événements système immédiats)
//  2. Un timer périodique de 30 s (vérification de fond)
// Déclenche automatiquement la synchronisation des opérations offline en
// attente lors du retour de la connexion.

import 'dart:async';
import 'dart:io' show Platform;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Surcharges injectables pour les tests unitaires (tâche 4.3).
  @visibleForTesting
  Future<bool> Function()? isServerAvailableOverride;

  @visibleForTesting
  Future<SyncResult> Function()? flushPendingOperationsOverride;

  /// Simule un événement connectivity_plus sans abonnement plateforme.
  @visibleForTesting
  Future<void> simulateConnectivityChanged(
    List<ConnectivityResult> results,
  ) =>
      _onConnectivityChanged(results);

  /// Simule un tick de vérification serveur (ping /health).
  @visibleForTesting
  Future<void> simulateCheckAndTransition() => _checkAndTransition();

  /// Réinitialise l'état singleton entre les tests.
  @visibleForTesting
  static void resetForTesting() {
    _instance.dispose();
    _instance.statusNotifier.value = ConnectivityStatus.offline;
    _instance.isServerAvailableOverride = null;
    _instance.flushPendingOperationsOverride = null;
  }

  // ── Cycle de vie ────────────────────────────────────────────────────────────

  /// Démarre la surveillance :
  ///  - Source 1 : abonnement au stream connectivity_plus (événements immédiats)
  ///  - Source 2 : ping périodique de 30 s (vérification de fond)
  /// Une première vérification est déclenchée immédiatement.
  ///
  /// Si connectivity_plus n'est pas disponible sur la plateforme (Linux, hot
  /// restart sans rebuild natif…), seul le timer de ping /health reste actif.
  void start() {
    _timer?.cancel();
    _connectivitySubscription?.cancel();

    unawaited(_subscribeConnectivityPlus());

    // Source 2 : ping périodique de 30 s
    _timer = Timer.periodic(const Duration(seconds: 30), _onTick);

    // Vérification immédiate au démarrage
    _onTick(Timer(Duration.zero, () {}));
  }

  /// Tente d'activer connectivity_plus ; échoue silencieusement si le plugin
  /// natif n'est pas enregistré (MissingPluginException).
  Future<void> _subscribeConnectivityPlus() async {
    if (!_platformSupportsConnectivityPlus) return;

    try {
      // Sonde : vérifie que le canal plateforme répond avant d'écouter le stream.
      await Connectivity().checkConnectivity();
    } on MissingPluginException catch (e) {
      debugPrint(
        '[ConnectivityMonitor] connectivity_plus indisponible — '
        'fallback ping /health uniquement: $e',
      );
      return;
    } catch (e) {
      debugPrint(
        '[ConnectivityMonitor] connectivity_plus indisponible — '
        'fallback ping /health uniquement: $e',
      );
      return;
    }

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _onConnectivityChanged,
      onError: (Object error, _) {
        debugPrint(
          '[ConnectivityMonitor] Erreur stream connectivity_plus — '
          'fallback ping /health uniquement: $error',
        );
        _connectivitySubscription?.cancel();
        _connectivitySubscription = null;
      },
    );
  }

  static bool get _platformSupportsConnectivityPlus =>
      Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isWindows;

  /// Arrête la surveillance et libère les ressources.
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  // ── Source 1 : événements connectivity_plus ─────────────────────────────────

  /// Appelé par connectivity_plus quand le type réseau change.
  Future<void> _onConnectivityChanged(List<ConnectivityResult> results) async {
    // Ne pas interférer avec une synchronisation en cours
    if (statusNotifier.value == ConnectivityStatus.syncing) return;

    final hasNetwork = results.any((r) => r != ConnectivityResult.none);

    if (!hasNetwork) {
      // Déconnexion système détectée → offline immédiat, sans attendre le timer
      statusNotifier.value = ConnectivityStatus.offline;
      return;
    }

    // Réseau disponible → vérifier si le serveur répond
    await _checkAndTransition();
  }

  // ── Source 2 : tick du timer ────────────────────────────────────────────────

  /// Appelé à chaque tick du timer de 30 s.
  Future<void> _onTick(Timer _) async {
    // Ne pas interférer avec une synchronisation en cours
    if (statusNotifier.value == ConnectivityStatus.syncing) return;
    await _checkAndTransition();
  }

  // ── Logique de transition commune ───────────────────────────────────────────

  /// Ping le serveur et gère les transitions de statut.
  /// Partagé entre _onConnectivityChanged et _onTick.
  Future<void> _checkAndTransition() async {
    bool available;
    try {
      available = await _isServerAvailable();
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
      await _flushPendingOperations();
      // Passer online même si certaines entrées ont échoué (req. 3.7)
      statusNotifier.value = ConnectivityStatus.online;
    } else {
      // Déjà online : confirmer le statut
      statusNotifier.value = ConnectivityStatus.online;
    }
  }

  Future<bool> _isServerAvailable() {
    final override = isServerAvailableOverride;
    if (override != null) return override();
    return ApiService().isServerAvailable();
  }

  Future<SyncResult> _flushPendingOperations() {
    final override = flushPendingOperationsOverride;
    if (override != null) return override();
    return SyncService().flushPendingOperations();
  }
}
