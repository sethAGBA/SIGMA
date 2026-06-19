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

  void start() {
    if (!AuthService().isLoggedIn) return;
    _active = true;
    _resetTimers();
  }

  void resetTimer() {
    if (!_active) return;
    // Si le warning est affiché, le fermer
    if (_warningShown) {
      navigatorKey?.currentState?.pop();
      _warningShown = false;
    }
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
      builder: (_) => const _WarningDialog(),
    ).then((_) => _warningShown = false);
  }

  void _onExpired() {
    if (!_active) return;
    stop();
    final state = navigatorKey?.currentState;
    if (state == null) return;
    // Fermer tous les dialogs ouverts
    state.popUntil((route) => route.isFirst);
    // Déconnecter
    AuthService().logout();
    // Naviguer vers LoginPage
    state.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }
}

// Widget dialog d'avertissement interne
class _WarningDialog extends StatelessWidget {
  const _WarningDialog();

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
          onPressed: () {
            Navigator.of(context).pop();
            SessionManager().resetTimer();
          },
          child: const Text('Rester connecté'),
        ),
      ],
    );
  }
}
