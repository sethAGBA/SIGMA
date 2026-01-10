import 'package:afroforma/models/user.dart';
import 'package:afroforma/screen/login_2fa_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'main_screen.dart'; // Assuming this is your main application screen
import 'change_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;
  bool _isPasswordVisible = false;

  Future<void> _login() async {
    setState(() {
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Veuillez entrer votre email et mot de passe.';
      });
      return;
    }

    final emailRegex = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
    if (!emailRegex.hasMatch(email)) {
      setState(() {
        _errorMessage = 'Veuillez entrer un email valide.';
      });
      return;
    }

    final result = await AuthService.login(email, password);

    if (result.success) {
      if (result.requires2fa) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => Login2faScreen(user: result.user!)),
        );
      } else if (result.user!.mustChangePassword) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => ChangePasswordScreen(userId: result.user!.id)),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) =>  MainScreen()),
        );
      }
    } else {
      setState(() {
        _errorMessage = result.message ?? 'Email ou mot de passe incorrect.';
      });
    }
  }

  void _showResetAdminDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Réinitialiser l\'administrateur'),
          content: const Text('Cette action supprimera tous les utilisateurs et recréera le compte administrateur par défaut (admin@afroforma.com). Un mot de passe aléatoire sera généré et affiché. Êtes-vous sûr ?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Réinitialiser'),
              onPressed: () async {
                // Before resetting, if an active admin has 2FA, require OTP
                final db = DatabaseService();
                final users = await db.getUsers();
                final admins = users.where((u) => u.role == UserRole.admin && u.isActive).toList();
                final guard = admins.firstWhere(
                  (u) => u.is2faEnabled && (u.twoFaSecret != null && u.twoFaSecret!.isNotEmpty),
                  orElse: () => User(id: '', name: '', email: '', role: UserRole.admin, createdAt: DateTime.now(), lastLogin: DateTime.now()),
                );

                bool allowed = true;
                if (guard.id.isNotEmpty) {
                  allowed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) {
                          final codeCtrl = TextEditingController();
                          return AlertDialog(
                            title: const Text('Vérification 2FA requise'),
                            content: TextField(
                              controller: codeCtrl,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              decoration: const InputDecoration(labelText: 'Code à 6 chiffres'),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
                              TextButton(
                                onPressed: () {
                                  final ok = AuthService.verifyTotpSecret(guard.twoFaSecret!, codeCtrl.text);
                                  Navigator.of(ctx).pop(ok);
                                },
                                child: const Text('Vérifier'),
                              ),
                            ],
                          );
                        },
                      ) ??
                      false;
                }

                if (!allowed) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vérification 2FA requise ou invalide. Réinitialisation annulée.')),
                  );
                  return;
                }

                Navigator.of(context).pop();
                await _resetAdmin();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _resetAdmin() async {
    final dbService = DatabaseService();
    final result = await dbService.resetAdmin();
    final userId = result['id'];
    final password = result['password'];

  // local forceChange handled inside dialog

    // Show modal with password and options
    showDialog(
      context: context,
      builder: (c) {
        bool localForce = true;
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Admin réinitialisé'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Email: admin@afroforma.com'),
                const SizedBox(height: 8),
                SelectableText('Mot de passe: $password', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(value: localForce, onChanged: (v) { setStateDialog(() { localForce = v ?? true; }); }),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Forcer changement du mot de passe à la première connexion')),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(c).pop({'force': localForce, 'changeNow': false}),
                child: const Text('Fermer'),
              ),
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: password!));
                  Navigator.of(c).pop({'force': localForce, 'changeNow': false});
                },
                child: const Text('Copier'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(c).pop({'force': localForce, 'changeNow': true});
                },
                child: const Text('Changer maintenant'),
              ),
            ],
          );
        });
      }
    ).then((result) async {
      bool didForce = true;
      bool changeNow = false;
      if (result is Map) {
        didForce = (result['force'] as bool?) ?? true;
        changeNow = (result['changeNow'] as bool?) ?? false;
      } else if (result is bool) {
        didForce = result;
      }
      // Persist forceChange flag
      if (userId != null && userId.isNotEmpty) {
        await dbService.setMustChangePassword(userId, didForce);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le compte administrateur a été créé.')),
      );
      if (changeNow && userId != null && userId.isNotEmpty) {
        // Navigate directly to change password screen for the new admin
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => ChangePasswordScreen(userId: userId)),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark background
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Container(
            width: 400, // Constrain width for desktop
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B), // Slightly lighter dark for card
              borderRadius: BorderRadius.circular(16.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.account_circle, // Icon for login screen
                  size: 80,
                  color: Colors.white,
                ),
                const SizedBox(height: 16), // Spacing between icon and title
                const Text(
                  'Connexion',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    prefixIcon: const Icon(Icons.email, color: Colors.white54),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible, // Use state variable
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Mot de passe',
                            labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                            prefixIcon: const Icon(Icons.lock, color: Colors.white54),
                            suffixIcon: IconButton( // Add suffix icon
                              icon: Icon(
                                _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                color: Colors.white54,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                            ),
                            filled: true,
                            fillColor: Colors.black.withOpacity(0.15),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1), // Primary button color
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size(double.infinity, 50), // Full width button
                  ),
                  child: const Text(
                    'Se connecter',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _showResetAdminDialog,
                  child: Text(
                    'Réinitialiser l\'admin',
                    style: TextStyle(color: Colors.white.withOpacity(0.7)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
