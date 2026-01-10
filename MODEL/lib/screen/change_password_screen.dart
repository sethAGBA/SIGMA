import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import 'main_screen.dart';

class ChangePasswordScreen extends StatefulWidget {
  final String userId;
  const ChangePasswordScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; });

    final pwd = _passwordController.text.trim();
    final hashed = sha256.convert(utf8.encode(pwd)).toString();

  final db = DatabaseService();
  // If the user has 2FA enabled, require OTP verification before changing password
  try {
    final users = await db.getUsers();
    final me = users.firstWhere((u) => u.id == widget.userId, orElse: () => users.firstWhere((_) => false));
    if (me.is2faEnabled && (me.twoFaSecret != null && me.twoFaSecret!.isNotEmpty)) {
      final ok = await showDialog<bool>(
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
                      final valid = AuthService.verifyTotpSecret(me.twoFaSecret!, codeCtrl.text);
                      Navigator.of(ctx).pop(valid);
                    },
                    child: const Text('Vérifier'),
                  ),
                ],
              );
            },
          ) ??
          false;
      if (!ok) {
        setState(() { _loading = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code 2FA invalide.')));
        return;
      }
    }
  } catch (_) {}
  // Update user password and clear mustChangePassword flag using raw update
  final database = await db.db;
    await database.update('users', {'passwordHash': hashed, 'mustChangePassword': 0}, where: 'id = ?', whereArgs: [widget.userId]);

    // reload user into AuthService if it's the current user
    final users = await db.getUsers();
    final me = users.where((u) => u.id == widget.userId).toList();
    if (me.isNotEmpty) {
      AuthService.setCurrentUser(me.first);
    }

    setState(() { _loading = false; });

  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mot de passe mis à jour.')));
  // After successful password change, navigate to MainScreen and clear history
  Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => MainScreen()), (r) => false);
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
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_reset, // Icon for password change
                    size: 80,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Changer le mot de passe',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Nouveau mot de passe',
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                      prefixIcon: const Icon(Icons.lock, color: Colors.white54),
                      suffixIcon: IconButton(
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
                    validator: (v) {
                      if (v == null || v.length < 6) return 'Le mot de passe doit contenir au moins 6 caractères.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmController,
                    obscureText: !_isConfirmPasswordVisible,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Confirmer le mot de passe',
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                      prefixIcon: const Icon(Icons.lock_outline, color: Colors.white54),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          color: Colors.white54,
                        ),
                        onPressed: () {
                          setState(() {
                            _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
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
                    validator: (v) {
                      if (v != _passwordController.text) return 'Les mots de passe ne correspondent pas.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _loading ? null : _changePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1), // Primary button color
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size(double.infinity, 50), // Full width button
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                          )
                        : const Text(
                            'Enregistrer',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
