import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:otp/otp.dart';
import '../models/user.dart';
import 'database_service.dart';

class AuthService {
  static User? _currentUser;

  static User? get currentUser => _currentUser;

  // IMPORTANT: In a real app, this key should be stored securely (e.g., using flutter_secure_storage)
  // and not hardcoded. For this example, we'll keep it here.
  static const String _encryptionKey = '_aVerySecretKeyFor2FAEncryption_';

  static Future<LoginResult> login(String email, String password) async {
    final db = DatabaseService();
    final users = await db.getUsers();

    final user = users.firstWhere(
      (u) => u.email == email,
      orElse: () => User(id: '', name: '', email: '', role: UserRole.admin, createdAt: DateTime.now(), lastLogin: DateTime.now(), isActive: false),
    );

    if (user.id.isEmpty || !user.isActive) {
      await db.insertAuditLog(_buildAuditLog(user, email, 'Utilisateur non trouvé ou inactif'));
      return LoginResult(success: false, message: 'Utilisateur non trouvé ou inactif.');
    }

    final hashedPassword = sha256.convert(utf8.encode(password)).toString();

    if (user.passwordHash == hashedPassword) {
      if (user.is2faEnabled) {
        return LoginResult(success: true, requires2fa: true, user: user);
      }

      _currentUser = user.copyWith(lastLogin: DateTime.now());
      await db.updateUser(_currentUser!);
      await db.insertAuditLog(_buildAuditLog(_currentUser!, email, 'Connexion réussie'));
      return LoginResult(success: true, user: _currentUser);
    } else {
      await db.insertAuditLog(_buildAuditLog(user, email, 'Mot de passe incorrect'));
      return LoginResult(success: false, message: 'Mot de passe incorrect.');
    }
  }

  static Future<bool> verify2faCode(String userId, String code) async {
    final db = DatabaseService();
    final users = await db.getUsers(); // Inefficient, should have a getUserById
    final user = users.firstWhere((u) => u.id == userId, orElse: () => User(id: '', name: '', email: '', role: UserRole.admin, createdAt: DateTime.now(), lastLogin: DateTime.now()));

    if (user.id.isEmpty || user.twoFaSecret == null) {
      return false;
    }
    final ok = verifyTotpSecret(user.twoFaSecret!, code);
    if (ok) {
      _currentUser = user.copyWith(lastLogin: DateTime.now());
      await db.updateUser(_currentUser!);
      await db.insertAuditLog(_buildAuditLog(_currentUser!, _currentUser!.email, 'Connexion 2FA réussie'));
      return true;
    }
    return false;
  }

  static void logout() {
    _currentUser = null;
  }

  // Pure TOTP verification without DB side-effects (±30s window)
  static bool verifyTotpSecret(String secret, String code) {
    final trimmed = code.replaceAll(' ', '');
    if (trimmed.length != 6) return false;
    final normSecret = secret.replaceAll(' ', '').toUpperCase();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    for (int offset = -1; offset <= 1; offset++) {
      try {
        final generated = OTP.generateTOTPCodeString(
          normSecret,
          nowMs + offset * 30 * 1000,
          interval: 30,
          length: 6,
          algorithm: Algorithm.SHA1,
          isGoogle: true,
        );
        if (generated == trimmed) return true;
      } catch (_) {}
    }
    return false;
  }

  static void setCurrentUser(User user) {
    _currentUser = user;
  }

  static Future<bool> checkLoggedIn() async {
    return _currentUser != null;
  }

  static AuditLog _buildAuditLog(User user, String email, String reason) {
    return AuditLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: user.id.isEmpty ? 'unknown' : user.id,
      userName: user.name.isEmpty ? email : user.name,
      action: 'Tentative de connexion échouée',
      module: 'Authentification',
      timestamp: DateTime.now(),
      details: {
        'email': email,
        'reason': reason,
      },
    );
  }
}

class LoginResult {
  final bool success;
  final bool requires2fa;
  final User? user;
  final String? message;

  LoginResult({required this.success, this.requires2fa = false, this.user, this.message});
}


// Helper to check permissions
bool hasPermission(User? user, String module, String action) {
  if (user == null) return false;
  if (user.role == UserRole.admin) return true; // Admins can do everything

  final permission = user.permissions.firstWhere(
    (p) => p.module == module,
    orElse: () => Permission(module: module, actions: []),
  );

  return permission.actions.contains(action);
}
