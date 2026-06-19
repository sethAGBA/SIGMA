// lib/core/services/auth_service.dart
//
// Gère la session utilisateur côté Flutter.
// Mode hybride : tente l'API FastAPI en premier, bascule sur SQLite si absent.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';
import 'database_service.dart';
import 'api_service.dart';
import 'session_manager.dart';

class AuthService extends ChangeNotifier {
  // Singleton
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  UserAccount? _currentUser;
  bool _isInitialized = false;
  bool _isOnlineMode = false; // true = connecté au backend FastAPI
  int _sessionTimeoutMinutes = 15;
  static const String _prefKeyTimeout = 'session_timeout_minutes';

  /// Callback enregistré par main.dart pour nettoyer les notifiers au logout.
  /// Permet à AuthService de déclencher clearCache() sans dépendre du contexte
  /// Provider (Exigence 9.4).
  VoidCallback? onLogout;

  UserAccount? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isInitialized => _isInitialized;
  bool get isOnlineMode => _isOnlineMode;
  int get sessionTimeoutMinutes => _sessionTimeoutMinutes;

  SystemRole? get currentRole => _currentUser?.role;
  String get currentUsername => _currentUser?.username ?? '';
  String get currentUserId => _currentUser?.id ?? '';

  // ── Initialisation ────────────────────────────────────────────────────

  Future<void> init() async {
    await ApiService().init();
    final prefs = await SharedPreferences.getInstance();
    final savedUserId = prefs.getString('session_user_id');

    if (savedUserId != null) {
      try {
        final user = await DatabaseService().getUserById(savedUserId);
        if (user != null && user.isActive) {
          _currentUser = user;
        } else {
          await prefs.remove('session_user_id');
        }
      } catch (_) {
        await prefs.remove('session_user_id');
      }
    }

    _isInitialized = true;
    final timeout = prefs.getInt(_prefKeyTimeout);
    if (timeout != null && timeout >= 1 && timeout <= 480) {
      _sessionTimeoutMinutes = timeout;
    }
    notifyListeners();
  }

  // ── Timeout de session ────────────────────────────────────────────────

  Future<void> setSessionTimeout(int minutes) async {
    if (minutes < 1 || minutes > 480) return;
    _sessionTimeoutMinutes = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKeyTimeout, minutes);
    notifyListeners();
  }

  // ── Connexion (hybride API + SQLite) ────────────────────────────────────

  /// Authentifie un utilisateur.
  /// Essaie d'abord l'API FastAPI, bascule sur SQLite si indisponible.
  /// Retourne null si succès, un message d'erreur sinon.
  Future<String?> login(String username, String password) async {
    if (username.trim().isEmpty || password.isEmpty) {
      return 'Veuillez saisir votre identifiant et mot de passe.';
    }

    // ── Tentative via l'API FastAPI (mode réseau) ──
    final serverAvailable = await ApiService().isServerAvailable();
    if (serverAvailable) {
      final result = await ApiService().login(username.trim(), password);
      if (result != null) {
        // Créer un UserAccount local depuis la réponse API
        final userInfo = result['user'] as Map<String, dynamic>?;
        if (userInfo != null) {
          _currentUser = UserAccount(
            id: userInfo['id'] ?? '',
            agentId: userInfo['agent_id'] ?? '',
            username: userInfo['username'] ?? username,
            passwordHash: '',
            role: _roleFromString(userInfo['role'] ?? ''),
            isActive: true,
            createdAt: DateTime.now(),
            permissions: ['all'],
          );
          _isOnlineMode = true;
          await _persistSession(_currentUser!.id);
          notifyListeners();
          return null; // succès
        }
      }
      // Serveur disponible mais identifiants incorrects
      return 'Identifiant ou mot de passe incorrect.';
    }

    // ── Fallback SQLite local (mode offline) ──
    try {
      final user = await DatabaseService().authenticateUser(
        username: username.trim(),
        password: password,
      );

      if (user == null) return 'Identifiant ou mot de passe incorrect.';
      if (!user.isActive) return 'Ce compte est désactivé. Contactez votre administrateur.';

      _currentUser = user;
      _isOnlineMode = false;
      await _persistSession(user.id);
      notifyListeners();
      return null; // succès

    } catch (e) {
      return 'Erreur de connexion : $e';
    }
  }

  // ── Déconnexion ────────────────────────────────────────────────────────

  Future<void> logout() async {
    SessionManager().stop();
    if (_isOnlineMode) {
      await ApiService().post('/auth/logout', {});
      ApiService().clearToken();
    }
    _currentUser = null;
    _isOnlineMode = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_user_id');
    // Notifier les providers (ex. DashboardNotifier.clearCache) avant
    // notifyListeners() pour que l'UI soit cohérente (Exigence 9.4).
    onLogout?.call();
    notifyListeners();
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  Future<void> _persistSession(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_user_id', userId);
  }

  SystemRole _roleFromString(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
      case 'superadmin':
        return SystemRole.superAdmin;
      case 'directeur':
      case 'directeurgeneral':
        return SystemRole.directeurGeneral;
      case 'directeuroperations':
        return SystemRole.directeurOperations;
      case 'directeurfinancier':
        return SystemRole.directeurFinancier;
      case 'chef_agence':
      case 'chefagence':
        return SystemRole.chefAgence;
      default:
        return SystemRole.agentCredit;
    }
  }

  // ── Contrôle d'accès par rôle (RBAC) ──────────────────────────────────

  bool canAccess(String permission) {
    if (_currentUser == null) return false;
    final perms = _currentUser!.permissions;
    if (perms.contains('all') || perms.contains(permission)) return true;

    // Alias Phase 2 — permissions FAB dashboard
    switch (permission) {
      case 'create_client':
        return perms.any(
          (p) => const {
            'manage_clients',
            'supervise_agencies',
            'manage_agency_only',
          }.contains(p),
        );
      case 'create_loan':
        return perms.any(
          (p) => const {
            'create_loan_apps',
            'manage_loans',
            'validate_loans_lt_threshold',
            'validate_loans_gt_threshold',
            'validate_loans_all',
          }.contains(p),
        );
      case 'cash_operation':
        return perms.any(
          (p) => const {
            'manage_cash_treasury',
            'manage_agency_cash',
            'full_accounting',
          }.contains(p),
        );
      default:
        return false;
    }
  }

  @visibleForTesting
  void setCurrentUserForTesting(UserAccount? user) {
    _currentUser = user;
    notifyListeners();
  }

  @visibleForTesting
  void resetForTesting() {
    _currentUser = null;
    _isOnlineMode = false;
  }

  bool hasRole(List<SystemRole> roles) {
    if (_currentUser == null) return false;
    return roles.contains(_currentUser!.role);
  }

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

  /// Valide le PIN superviseur (4 chiffres) pour déblocages / ruptures DAT.
  Future<bool> validateSupervisorPin(String pin) async {
    if (pin.length < 4) return false;

    if (_isOnlineMode) {
      final response = await ApiService().post('/auth/validate-pin', {
        'pin': pin,
      });
      return response?.statusCode == 200;
    }

    final db = await DatabaseService().database;
    final supervisors = await db.query(
      'utilisateurs_systeme',
      where:
          "is_active = 1 AND role IN ('superAdmin','chefAgence','directeurGeneral','directeurOperations','directeurFinancier')",
    );
    return supervisors.any((row) => row['supervisor_pin'] == pin);
  }

  String get userInitials {
    if (_currentUser == null) return '?';
    final parts = _currentUser!.username.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return _currentUser!.username.substring(0, 2).toUpperCase();
  }
}
