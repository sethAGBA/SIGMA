// lib/core/services/session_manager.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'auth_service.dart';
import '../../screens/auth/login_page.dart';

class SessionManager {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  Timer? _inactivityTimer;
  Timer? _warningTimer;
  bool _warningShown = false;
  bool _active = false;

  // NavigatorKey injecté depuis main.dart
  GlobalKey<NavigatorState>? navigatorKey;

  bool get isActive => _active;

  void start() {
    if (!AuthService().isLoggedIn) return;
    _active = true;
    _resetTimers();
  }

  /// Appelé quand l'utilisateur interagit ou clique "Rester connecté".
  /// Ne fait rien si la session a déjà expiré (_active == false).
  void resetTimer() {
    if (!_active) return;
    _resetTimers();
  }

  void stop() {
    _active = false;
    _inactivityTimer?.cancel();
    _warningTimer?.cancel();
    _inactivityTimer = null;
    _warningTimer = null;
    _warningShown = false;
  }

  void _resetTimers() {
    _inactivityTimer?.cancel();
    _warningTimer?.cancel();

    final timeoutSec = AuthService().sessionTimeoutMinutes * 60;
    final warningSec = timeoutSec - 60;

    // Timer d'avertissement (1 min avant expiration)
    if (warningSec > 0) {
      _warningTimer = Timer(Duration(seconds: warningSec), _onWarning);
    }

    // Timer d'expiration
    _inactivityTimer = Timer(Duration(seconds: timeoutSec), _onExpired);
  }

  void _onWarning() {
    if (!_active || _warningShown) return;
    final ctx = navigatorKey?.currentContext;
    if (ctx == null) return;
    _warningShown = true;
    showDialog(
      context: ctx,
      barrierDismissible: false,
      // Passer onStayConnected en callback pour éviter toute interaction
      // avec le Navigator après expiration de la session.
      builder: (_) => _WarningDialog(onStayConnected: _handleStayConnected),
    ).then((_) {
      // Le dialog est fermé (quelle qu'en soit la raison)
      _warningShown = false;
    });
  }

  /// Callback invoqué par le bouton "Rester connecté" du dialog.
  ///
  /// On ferme le dialog via le navigatorKey global (pas via le context du
  /// dialog qui peut être détaché si _onExpired s'est exécuté entre-temps),
  /// puis on réinitialise les timers uniquement si la session est encore active.
  void _handleStayConnected() {
    // Fermer le dialog en toute sécurité via le navigatorKey global
    final state = navigatorKey?.currentState;
    if (state != null && state.canPop()) {
      state.pop();
    }
    // Ne relancer les timers que si la session n'a pas encore expiré
    if (_active) {
      _resetTimers();
    }
  }

  void _onExpired() {
    if (!_active) return;
    stop(); // annule les timers, met _active = false
    final state = navigatorKey?.currentState;
    if (state == null) return;

    // Fermer le dialog de warning s'il est encore affiché
    if (state.canPop()) {
      state.popUntil((route) => route.isFirst);
    }
    // Déconnecter
    AuthService().logout();
    // Remplacer toute la pile par LoginPage
    state.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }
}

// Widget dialog d'avertissement interne
class _WarningDialog extends StatelessWidget {
  /// Callback invoqué quand l'utilisateur clique "Rester connecté".
  /// N'utilise PAS Navigator.of(context) directement pour éviter
  /// l'écran noir si la session expire pendant que le dialog est ouvert.
  final VoidCallback onStayConnected;

  const _WarningDialog({required this.onStayConnected});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.access_time, color: Colors.orange),
          SizedBox(width: 8),
          Text('Session sur le point d\'expirer'),
        ],
      ),
      content: const Text(
        'Votre session expire dans 1 minute.\nTouchez l\'écran pour rester connecté.',
      ),
      actions: [
        ElevatedButton(
          onPressed: onStayConnected,
          child: const Text('Rester connecté'),
        ),
      ],
    );
  }
}
