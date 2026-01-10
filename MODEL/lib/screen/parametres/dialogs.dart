import 'package:afroforma/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'dart:convert'; // For utf8.encode
import 'package:crypto/crypto.dart'; // For sha256
import '../../models/user.dart';
import '../../services/database_service.dart'; // Import DatabaseService
import 'utils.dart'; // For getUserRoleString

class PlanComptableDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text(
        'Plan Comptable',
        style: TextStyle(color: Colors.white),
      ),
      content: const Text(
        'Gestion du plan comptable (placeholder)',
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}

class NewUserDialog extends StatefulWidget {
  final ValueChanged<User> onUserCreated;
  const NewUserDialog({Key? key, required this.onUserCreated})
    : super(key: key);
  @override
  _NewUserDialogState createState() => _NewUserDialogState();
}

class _NewUserDialogState extends State<NewUserDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  String? _passwordError;
  String? _confirmPasswordError;
  UserRole _role = UserRole.commercial;

  @override
  void initState() {
    super.initState();
    _password.addListener(_validatePassword);
    _confirmPassword.addListener(_validateConfirmPassword);
  }

  @override
  void dispose() {
    _password.removeListener(_validatePassword);
    _confirmPassword.removeListener(_validateConfirmPassword);
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _validatePassword() {
    setState(() {
      if (_password.text.length < 6) {
        _passwordError = 'Minimum 6 caractères.';
      } else {
        _passwordError = null;
      }
      _validateConfirmPassword(); // Re-validate confirm password if password changes
    });
  }

  void _validateConfirmPassword() {
    setState(() {
      if (_confirmPassword.text.isNotEmpty &&
          _password.text != _confirmPassword.text) {
        _confirmPasswordError = 'Les mots de passe ne correspondent pas.';
      } else {
        _confirmPasswordError = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text(
        'Nouvel utilisateur',
        style: TextStyle(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nom'),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'Email'),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _password,
            decoration: InputDecoration(
              labelText: 'Mot de passe',
              errorText: _passwordError,
              labelStyle: const TextStyle(color: Colors.white),
              border: const OutlineInputBorder(),
              suffixIcon: _passwordError == null && _password.text.isNotEmpty
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
            ),
            obscureText: true,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmPassword,
            decoration: InputDecoration(
              labelText: 'Confirmer mot de passe',
              errorText: _confirmPasswordError,
              labelStyle: const TextStyle(color: Colors.white),
              border: const OutlineInputBorder(),
              suffixIcon:
                  _confirmPasswordError == null &&
                      _confirmPassword.text.isNotEmpty
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
            ),
            obscureText: true,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 8),
          DropdownButton<UserRole>(
            value: _role,
            dropdownColor: const Color(0xFF1E293B),
            items: UserRole.values
                .map(
                  (r) => DropdownMenuItem(
                    value: r,
                    child: Text(
                      getUserRoleString(r),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _role = v ?? _role),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed:
              (_passwordError == null &&
                  _confirmPasswordError == null &&
                  _password.text.isNotEmpty &&
                  _confirmPassword.text.isNotEmpty)
              ? () {
                  final plainPassword = _password.text.trim();
                  final hashedPassword = sha256
                      .convert(utf8.encode(plainPassword))
                      .toString(); // Hashing the password

                  final user = User(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: _name.text.trim().isEmpty
                        ? 'Utilisateur'
                        : _name.text.trim(),
                    email: _email.text.trim(),
                    passwordHash: hashedPassword, // Pass the hashed password
                    role: _role,
                    permissions: [],
                    createdAt: DateTime.now(),
                    lastLogin: DateTime.now(),
                  );
                  widget.onUserCreated(user);
                  Navigator.pop(context);
                }
              : null,
          child: const Text('Créer'),
        ),
      ],
    );
  }
}

class EditUserDialog extends StatefulWidget {
  final User user;
  final ValueChanged<User> onUserUpdated;

  const EditUserDialog({Key? key, required this.user, required this.onUserUpdated}) : super(key: key);

  @override
  _EditUserDialogState createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<EditUserDialog> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();
  late UserRole _role;
  late bool _isActive;
  late bool _isLastAdmin = false; // Initialize to false

  String? _passwordError;
  String? _confirmPasswordError;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user.name);
    _email = TextEditingController(text: widget.user.email);
    _role = widget.user.role;
    _isActive = widget.user.isActive;

    _password.addListener(_validatePassword);
    _confirmPassword.addListener(_validateConfirmPassword);

    _checkIfLastAdmin();
  }

  Future<void> _checkIfLastAdmin() async {
    if (widget.user.role == UserRole.admin) {
      final activeAdminsCount = await DatabaseService().countActiveAdmins();
      setState(() {
        _isLastAdmin = activeAdminsCount <= 1;
      });
    } else {
      _isLastAdmin = false;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.removeListener(_validatePassword);
    _confirmPassword.removeListener(_validateConfirmPassword);
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _validatePassword() {
    setState(() {
      if (_password.text.isNotEmpty && _password.text.length < 6) {
        _passwordError = 'Minimum 6 caractères.';
      } else {
        _passwordError = null;
      }
      _validateConfirmPassword(); // Re-validate confirm password if password changes
    });
  }

  void _validateConfirmPassword() {
    setState(() {
      if (_confirmPassword.text.isNotEmpty && _password.text != _confirmPassword.text) {
        _confirmPasswordError = 'Les mots de passe ne correspondent pas.';
      } else {
        _confirmPasswordError = null;
      }
    });
  }

  bool get _isFormValid {
    final bool passwordFieldsNotEmpty = _password.text.isNotEmpty && _confirmPassword.text.isNotEmpty;
    final bool passwordValidationPasses = _passwordError == null && _confirmPasswordError == null;

    return passwordFieldsNotEmpty && passwordValidationPasses;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text('Modifier utilisateur', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nom'),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'Email'),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 8),
          DropdownButton<UserRole>(
            value: _role,
            dropdownColor: const Color(0xFF1E293B),
            items: UserRole.values
                .map(
                  (r) => DropdownMenuItem(
                    value: r,
                    child: Text(
                      getUserRoleString(r),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                )
                .toList(),
            onChanged: _isLastAdmin && widget.user.role == UserRole.admin ? null : (v) => setState(() => _role = v ?? _role),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Utilisateur actif', style: TextStyle(color: Colors.white)),
            value: _isActive,
            onChanged: (bool value) {
              setState(() {
                _isActive = value;
              });
            },
            activeColor: Colors.green,
            inactiveThumbColor: Colors.red,
            subtitle: Text(
              _isActive ? 'L\'utilisateur peut se connecter' : 'L\'utilisateur ne peut pas se connecter',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _password,
            decoration: InputDecoration(
              labelText: 'Nouveau mot de passe',
              errorText: _passwordError,
              labelStyle: const TextStyle(color: Colors.white),
              border: const OutlineInputBorder(),
              suffixIcon: _passwordError == null && _password.text.isNotEmpty
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
            ),
            obscureText: true,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmPassword,
            decoration: InputDecoration(
              labelText: 'Confirmer nouveau mot de passe',
              errorText: _confirmPasswordError,
              labelStyle: const TextStyle(color: Colors.white),
              border: const OutlineInputBorder(),
              suffixIcon: _confirmPasswordError == null &&
                      _confirmPassword.text.isNotEmpty
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
            ),
            obscureText: true,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _isFormValid
              ? () async {
                  // If editing an admin with 2FA enabled, require OTP verification
                  if (widget.user.role == UserRole.admin && widget.user.is2faEnabled && (widget.user.twoFaSecret != null && widget.user.twoFaSecret!.isNotEmpty)) {
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
                                    final valid = AuthService.verifyTotpSecret(widget.user.twoFaSecret!, codeCtrl.text);
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
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code 2FA invalide.')));
                      return;
                    }
                  }

                  final hashedPassword = sha256.convert(utf8.encode(_password.text.trim())).toString();

                  final updatedUser = widget.user.copyWith(
                    name: _name.text.trim(),
                    email: _email.text.trim(),
                    role: _role,
                    passwordHash: hashedPassword,
                    isActive: _isActive,
                  );
                  widget.onUserUpdated(updatedUser);
                  Navigator.pop(context);
                }
              : null,
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

class AuditDialog extends StatefulWidget {
  const AuditDialog({Key? key}) : super(key: key);

  @override
  _AuditDialogState createState() => _AuditDialogState();
}

class _AuditDialogState extends State<AuditDialog> {
  late Future<List<AuditLog>> _auditLogsFuture;

  @override
  void initState() {
    super.initState();
    _auditLogsFuture = DatabaseService().getAuditLogs();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text('Audit', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 500,
        child: FutureBuilder<List<AuditLog>>(
          future: _auditLogsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Erreur: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('Aucun log d\'audit trouvé.', style: TextStyle(color: Colors.white70)));
            } else {
              final auditLogs = snapshot.data!;
              return ListView.builder(
                shrinkWrap: true,
                itemCount: auditLogs.length,
                itemBuilder: (ctx, i) {
                  final e = auditLogs[i];
                  return ExpansionTile(
                    title: Text(
                      '${e.userName} — ${e.action}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      '${e.module} • ${e.timestamp}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    children: e.details.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 16.0, bottom: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${entry.key}: ',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            Expanded(
                              child: Text(
                                entry.value.toString(),
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              );
            }
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}

class PermissionsDialog extends StatefulWidget {
  final User user;
  final ValueChanged<User> onUserUpdated;

  const PermissionsDialog({Key? key, required this.user, required this.onUserUpdated}) : super(key: key);

  @override
  _PermissionsDialogState createState() => _PermissionsDialogState();
}

class _PermissionsDialogState extends State<PermissionsDialog> {
  late Set<String> _allowedModules;

  final List<String> _availableModules = [
    'Tableau de Bord',
    'Étudiants',
    'Formations',
    'Comptabilité',
    'Facturation',
    'Analyses',
  'Recherche certificats',
    'Paramètres',
  ];

  @override
  void initState() {
    super.initState();
    // Initialize the set of allowed modules from the user's permissions.
    // A user has permission for a module if a Permission object with the module name exists.
    _allowedModules = widget.user.permissions.map((p) => p.module).toSet();
  }

  void _onSave() {
    // Create a new list of Permission objects from the set of allowed modules.
    // For now, we grant all actions if the module is allowed.
    final newPermissions = _allowedModules
        .map((module) => Permission(module: module, actions: ['create', 'read', 'update', 'delete']))
        .toList();

    // Create a copy of the user with the updated permissions.
    final updatedUser = widget.user.copyWith(permissions: newPermissions);

    // Call the callback to notify the parent widget to update the user.
    widget.onUserUpdated(updatedUser);

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: Text('Permissions — ${widget.user.name}', style: const TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 400,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _availableModules.length,
          itemBuilder: (context, index) {
            final module = _availableModules[index];
            final bool isAllowed = _allowedModules.contains(module);

            return CheckboxListTile(
              title: Text(module, style: const TextStyle(color: Colors.white)),
              value: module == 'Paramètres' && widget.user.role == UserRole.admin ? true : isAllowed,
              onChanged: module == 'Paramètres' && widget.user.role == UserRole.admin ? null : (bool? value) {
                setState(() {
                  if (value == true) {
                    _allowedModules.add(module);
                  } else {
                    _allowedModules.remove(module);
                  }
                });
              },
              activeColor: Colors.green,
              checkColor: Colors.white,
              controlAffinity: ListTileControlAffinity.leading,
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _onSave,
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
