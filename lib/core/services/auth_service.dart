// lib/core/services/auth_service.dart
//
// Gère la session utilisateur côté Flutter.
// Mode hybride : tente l'API FastAPI en premier, bascule sur SQLite si absent.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';
import '../../models/sidebar_module.dart';
import '../../screens/auth/login_page.dart';
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
  Timer? _serverMonitor;

  static const Map<SidebarModule, List<int>> moduleIndexes = {
    SidebarModule.dashboard: [0],
    SidebarModule.clients: [1, 2, 3],
    SidebarModule.groupesSolidaires: [2],
    SidebarModule.prets: [4, 5, 6, 7],
    SidebarModule.remboursements: [8, 9, 10],
    SidebarModule.epargne: [11, 12, 13],
    SidebarModule.caisse: [14, 15, 16, 17],
    SidebarModule.comptabilite: [22, 23, 24, 25, 26, 27],
    SidebarModule.reporting: [18, 19, 20, 21, 28, 29, 30],
    SidebarModule.agencesAgents: [31, 32, 33],
    SidebarModule.communications: [34, 35, 36],
    SidebarModule.documents: [37, 38, 39],
    SidebarModule.configuration: [40, 41, 42],
    SidebarModule.utilisateursDroits: [43],
    SidebarModule.securiteAudit: [44],
    SidebarModule.serveurConnexion: [45],
  };

  static const Map<SystemRole, Set<SidebarModule>> _rbacMatrix = {
    SystemRole.superAdmin: {
      SidebarModule.dashboard,
      SidebarModule.clients,
      SidebarModule.groupesSolidaires,
      SidebarModule.prets,
      SidebarModule.remboursements,
      SidebarModule.epargne,
      SidebarModule.caisse,
      SidebarModule.comptabilite,
      SidebarModule.reporting,
      SidebarModule.agencesAgents,
      SidebarModule.communications,
      SidebarModule.documents,
      SidebarModule.configuration,
      SidebarModule.utilisateursDroits,
      SidebarModule.securiteAudit,
      SidebarModule.serveurConnexion,
    },
    SystemRole.directeurGeneral: {
      SidebarModule.dashboard,
      SidebarModule.clients,
      SidebarModule.groupesSolidaires,
      SidebarModule.prets,
      SidebarModule.remboursements,
      SidebarModule.epargne,
      SidebarModule.caisse,
      SidebarModule.comptabilite,
      SidebarModule.reporting,
      SidebarModule.agencesAgents,
      SidebarModule.communications,
      SidebarModule.documents,
      SidebarModule.configuration,
      SidebarModule.securiteAudit,
    },
    SystemRole.directeurOperations: {
      SidebarModule.dashboard,
      SidebarModule.clients,
      SidebarModule.groupesSolidaires,
      SidebarModule.prets,
      SidebarModule.remboursements,
      SidebarModule.epargne,
      SidebarModule.caisse,
      SidebarModule.reporting,
      SidebarModule.agencesAgents,
      SidebarModule.communications,
      SidebarModule.documents,
    },
    SystemRole.directeurFinancier: {
      SidebarModule.dashboard,
      SidebarModule.epargne,
      SidebarModule.caisse,
      SidebarModule.comptabilite,
      SidebarModule.reporting,
      SidebarModule.documents,
      SidebarModule.securiteAudit,
    },
    SystemRole.chefAgence: {
      SidebarModule.dashboard,
      SidebarModule.clients,
      SidebarModule.groupesSolidaires,
      SidebarModule.prets,
      SidebarModule.remboursements,
      SidebarModule.epargne,
      SidebarModule.caisse,
      SidebarModule.reporting,
      SidebarModule.agencesAgents,
      SidebarModule.communications,
      SidebarModule.documents,
    },
    SystemRole.agentCredit: {
      SidebarModule.dashboard,
      SidebarModule.clients,
      SidebarModule.groupesSolidaires,
      SidebarModule.prets,
      SidebarModule.remboursements,
      SidebarModule.epargne,
      SidebarModule.documents,
    },
  };

  @visibleForTesting
  static Map<SystemRole, Set<SidebarModule>> get rbacMatrixForTesting =>
      _rbacMatrix;

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
    ApiService().onSessionExpired = _handleSessionExpired;

    final prefs = await SharedPreferences.getInstance();

    await _tryRestoreOnlineSession(prefs);

    if (_currentUser == null) {
      final savedUserId = prefs.getString('session_user_id');
      if (savedUserId != null) {
        try {
          final user = await DatabaseService().getUserById(savedUserId);
          if (user != null && user.isActive) {
            _currentUser = user;
            _isOnlineMode = false;
          } else {
            await prefs.remove('session_user_id');
          }
        } catch (_) {
          await prefs.remove('session_user_id');
        }
      }
    }

    if (_currentUser != null && _isOnlineMode) {
      _startServerMonitor();
    }

    _isInitialized = true;
    final timeout = prefs.getInt(_prefKeyTimeout);
    if (timeout != null && timeout >= 1 && timeout <= 480) {
      _sessionTimeoutMinutes = timeout;
    }
    notifyListeners();
  }

  Future<void> _handleSessionExpired() async {
    await logout();
    _navigateToLogin();
  }

  void _navigateToLogin() {
    SessionManager().navigatorKey?.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
        );
  }

  Future<void> _tryRestoreOnlineSession(SharedPreferences prefs) async {
    final serverAvailable = await ApiService().isServerAvailable();
    if (!serverAvailable) return;

    final access = ApiService().currentAccessToken;
    if (access != null && !ApiService.isJwtExpired(access)) {
      if (await _restoreUserFromSession(prefs)) {
        _isOnlineMode = true;
      }
      return;
    }

    final refresh = await ApiService().readRefreshToken();
    if (refresh != null) {
      final refreshed = await ApiService().tryRefresh(refresh);
      if (refreshed && await _restoreUserFromSession(prefs)) {
        _isOnlineMode = true;
      } else {
        await _clearSecureStorage();
      }
    }
  }

  Future<bool> _restoreUserFromSession(SharedPreferences prefs) async {
    final savedUserId = prefs.getString('session_user_id');
    if (savedUserId != null) {
      try {
        final user = await DatabaseService().getUserById(savedUserId);
        if (user != null && user.isActive) {
          _currentUser = user;
          return true;
        }
      } catch (_) {}
    }

    final response = await ApiService().get('/auth/me');
    final data = ApiService.decodeResponse(response);
    if (data is Map<String, dynamic>) {
      _currentUser = UserAccount(
        id: data['id']?.toString() ?? '',
        agentId: data['agent_id']?.toString() ?? '',
        username: data['username']?.toString() ?? '',
        passwordHash: '',
        role: _roleFromString(data['role']?.toString() ?? ''),
        isActive: true,
        createdAt: DateTime.now(),
        permissions: ['all'],
      );
      await _persistSession(_currentUser!.id);
      return true;
    }
    return false;
  }

  Future<void> _clearSecureStorage() async {
    await ApiService().clearSecureTokens();
  }

  void _startServerMonitor() {
    _serverMonitor?.cancel();
    _serverMonitor = Timer.periodic(const Duration(seconds: 60), (_) async {
      if (!isLoggedIn) return;
      final available = await ApiService().isServerAvailable();
      if (!available) {
        if (_isOnlineMode) {
          _isOnlineMode = false;
          notifyListeners();
        }
        return;
      }
      if (!_isOnlineMode) {
        final refreshed = await ApiService().tryRefresh();
        if (refreshed) {
          _isOnlineMode = true;
          notifyListeners();
        }
      }
    });
  }

  void _stopServerMonitor() {
    _serverMonitor?.cancel();
    _serverMonitor = null;
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
  /// Essaie d'abord l'API FastAPI, bascule sur SQLite si l'API échoue ou est indisponible.
  /// Retourne null si succès, un message d'erreur sinon.
  Future<String?> login(String username, String password) async {
    if (username.trim().isEmpty || password.isEmpty) {
      return 'Veuillez saisir votre identifiant et mot de passe.';
    }

    final trimmed = username.trim();

    // ── Tentative via l'API FastAPI (mode réseau) ──
    if (await ApiService().isServerAvailable()) {
      final result = await ApiService().login(trimmed, password);
      final userInfo = result?['user'];
      if (userInfo is Map<String, dynamic>) {
        return _completeOnlineLogin(userInfo, trimmed);
      }
      // Serveur joignable mais login API refusé ou endpoint incorrect → SQLite local
    }

    return _loginOffline(trimmed, password);
  }

  Future<String?> _completeOnlineLogin(
    Map<String, dynamic> userInfo,
    String fallbackUsername,
  ) async {
    _currentUser = UserAccount(
      id: userInfo['id']?.toString() ?? '',
      agentId: userInfo['agent_id']?.toString() ?? '',
      username: userInfo['username']?.toString() ?? fallbackUsername,
      passwordHash: '',
      role: _roleFromString(userInfo['role']?.toString() ?? ''),
      isActive: true,
      createdAt: DateTime.now(),
      permissions: ['all'],
    );
    _isOnlineMode = true;
    await _persistSession(_currentUser!.id);
    _startServerMonitor();
    notifyListeners();
    return null;
  }

  Future<String?> _loginOffline(String username, String password) async {
    try {
      final user = await DatabaseService().authenticateUser(
        username: username,
        password: password,
      );

      if (user == null) return 'Identifiant ou mot de passe incorrect.';
      if (!user.isActive) {
        return 'Ce compte est désactivé. Contactez votre administrateur.';
      }

      _currentUser = user;
      _isOnlineMode = false;
      await _persistSession(user.id);
      notifyListeners();
      return null;
    } catch (e) {
      return 'Erreur de connexion : $e';
    }
  }

  // ── Déconnexion ────────────────────────────────────────────────────────

  Future<void> logout() async {
    SessionManager().stop();
    _stopServerMonitor();
    if (_isOnlineMode) {
      await ApiService().post('/auth/logout', {});
    }
    await _clearSecureStorage();
    _currentUser = null;
    _isOnlineMode = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_user_id');
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
      case 'super_admin':
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

  bool canAccessModule(SidebarModule module) {
    final role = _currentUser?.role;
    if (role == null) return false;
    if (role == SystemRole.superAdmin) return true;
    return _rbacMatrix[role]?.contains(module) ?? false;
  }

  bool canAccessIndex(int index) {
    for (final entry in moduleIndexes.entries) {
      if (entry.value.contains(index)) {
        return canAccessModule(entry.key);
      }
    }
    return false;
  }

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
    _serverMonitor?.cancel();
    _serverMonitor = null;
    _currentUser = null;
    _isOnlineMode = false;
    _isInitialized = false;
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
