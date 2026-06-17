// lib/core/services/auth_service.dart
//
// Gère la session utilisateur côté Flutter.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';
import 'database_service.dart';

class AuthService extends ChangeNotifier {
  // Singleton
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  UserAccount? _currentUser;
  bool _isInitialized = false;

  UserAccount? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isInitialized => _isInitialized;

  SystemRole? get currentRole => _currentUser?.role;
  String get currentUsername => _currentUser?.username ?? '';
  String get currentUserId => _currentUser?.id ?? '';

  // ── Initialisation ────────────────────────────────────────────────────

  /// Vérifie si une session persistante existe au démarrage de l'app.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUserId = prefs.getString('session_user_id');

    if (savedUserId != null) {
      try {
        final user = await DatabaseService().getUserById(savedUserId);
        if (user != null && user.isActive) {
          _currentUser = user;
        } else {
          // Session expirée ou utilisateur désactivé
          await prefs.remove('session_user_id');
        }
      } catch (_) {
        await prefs.remove('session_user_id');
      }
    }

    _isInitialized = true;
    notifyListeners();
  }

  // ── Connexion ──────────────────────────────────────────────────────────

  /// Authentifie un utilisateur par username/password.
  /// Retourne null si succès, un message d'erreur sinon.
  Future<String?> login(String username, String password) async {
    if (username.trim().isEmpty || password.isEmpty) {
      return 'Veuillez saisir votre identifiant et mot de passe.';
    }

    try {
      final user = await DatabaseService().authenticateUser(
        username: username.trim(),
        password: password,
      );

      if (user == null) {
        return 'Identifiant ou mot de passe incorrect.';
      }

      if (!user.isActive) {
        return 'Ce compte est désactivé. Contactez votre administrateur.';
      }

      _currentUser = user;

      // Persister la session
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_user_id', user.id);

      notifyListeners();
      return null; // null = succès

    } catch (e) {
      return 'Erreur de connexion : $e';
    }
  }

  // ── Déconnexion ────────────────────────────────────────────────────────

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_user_id');
    notifyListeners();
  }

  // ── Contrôle d'accès par rôle (RBAC) ──────────────────────────────────

  /// Vérifie si l'utilisateur courant peut accéder à un module.
  bool canAccess(String permission) {
    if (_currentUser == null) return false;
    final perms = _currentUser!.permissions;
    return perms.contains('all') || perms.contains(permission);
  }

  /// Retourne true si le rôle courant est dans la liste fournie.
  bool hasRole(List<SystemRole> roles) {
    if (_currentUser == null) return false;
    return roles.contains(_currentUser!.role);
  }

  /// Raccourcis rôles
  bool get isAdmin => hasRole([SystemRole.superAdmin]);
  bool get isDirecteur => hasRole([
    SystemRole.superAdmin,
    SystemRole.directeurGeneral,
    SystemRole.directeurOperations,
    SystemRole.directeurFinancier,
  ]);
  bool get isChefAgence => hasRole([
    SystemRole.superAdmin,
    SystemRole.directeurGeneral,
    SystemRole.chefAgence,
  ]);
  bool get isAgentCredit => hasRole([SystemRole.agentCredit]);

  // ── Initiales pour l'avatar ────────────────────────────────────────────

  String get userInitials {
    if (_currentUser == null) return '?';
    final parts = _currentUser!.username.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return _currentUser!.username.substring(0, 2).toUpperCase();
  }
}
