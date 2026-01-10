import 'package:afroforma/services/auth_service.dart';
import 'package:flutter/material.dart';
import '../../models/user.dart';
import 'helpers.dart';
import 'dialogs.dart';
import 'utils.dart';
import '../../services/database_service.dart';

class UtilisateursTab extends StatefulWidget {
  @override
  _UtilisateursTabState createState() => _UtilisateursTabState();
}

class _UtilisateursTabState extends State<UtilisateursTab> {
  List<User> _users = [];
  String _selectedRole = 'Tous';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final loadedUsers = await DatabaseService().getUsers();
    setState(() {
      _users = loadedUsers;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _selectedRole == 'Tous' ? _users : _users.where((u) => getUserRoleString(u.role) == _selectedRole).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: buildDropdownField(
                  'Filtrer par rôle',
                  _selectedRole,
                  ['Tous', 'Admin', 'Comptable', 'Commercial', 'Secrétaire'],
                  (value) => setState(() => _selectedRole = value!),
                  Icons.filter_list,
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => showDialog(context: context, builder: (c) => NewUserDialog(onUserCreated: (u) async { await DatabaseService().insertUser(u); _loadUsers();
                  // Audit Log for New User
                  await DatabaseService().insertAuditLog(
                    AuditLog(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      userId: AuthService.currentUser?.id ?? 'system',
                      userName: AuthService.currentUser?.name ?? 'System',
                      action: 'Création utilisateur',
                      module: 'Utilisateurs',
                      timestamp: DateTime.now(),
                      details: {
                        'userId': u.id,
                        'userName': u.name,
                        'userEmail': u.email,
                        'userRole': u.role.toString().split('.').last,
                      },
                    ),
                  );
                })),
                icon: const Icon(Icons.person_add, color: Colors.white),
                label: const Text('Nouvel Utilisateur', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => showDialog(context: context, builder: (c) => const AuditDialog()),
                icon: const Icon(Icons.history, color: Colors.white),
                label: const Text('Audit', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Expanded(
          child: Container(
            decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.1))),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredUsers.length,
              itemBuilder: (context, index) => _buildUserCard(filteredUsers[index]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserCard(User user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.1))),
      child: Row(
        children: [
          CircleAvatar(radius: 30, backgroundColor: getRoleColor(user.role), child: Text(user.name.split(' ').map((n) => n[0]).take(2).join(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              Text(user.email, style: TextStyle(color: Colors.white.withOpacity(0.7))),
              const SizedBox(height: 4),
              Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: getRoleColor(user.role), borderRadius: BorderRadius.circular(8)), child: Text(getUserRoleString(user.role), style: const TextStyle(color: Colors.white, fontSize: 12))),
                const SizedBox(width: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: user.isActive ? Colors.green : Colors.red, borderRadius: BorderRadius.circular(8)), child: Text(user.isActive ? 'Actif' : 'Inactif', style: const TextStyle(color: Colors.white, fontSize: 12))),
              ]),
            ]),
          ),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: 'Modifier l\'utilisateur',
                child: IconButton(onPressed: () => _editUser(user), icon: const Icon(Icons.edit, color: Colors.blue)),
              ),
              Tooltip(
                message: 'Gérer les permissions',
                child: IconButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (c) => PermissionsDialog(
                      user: user,
                      onUserUpdated: (updatedUser) async {
                        // Safeguard: Prevent removing 'Paramètres' permission from an admin
                        if (updatedUser.role == UserRole.admin && !updatedUser.permissions.any((p) => p.module == 'Paramètres')) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Un administrateur doit toujours avoir accès aux paramètres.')),
                          );
                          return;
                        }

                        await DatabaseService().updateUser(updatedUser);
                        _loadUsers();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Permissions de ${updatedUser.name} mises à jour.')),
                        );
                        // Audit Log for Permissions Update
                        await DatabaseService().insertAuditLog(
                          AuditLog(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            userId: AuthService.currentUser?.id ?? 'system',
                            userName: AuthService.currentUser?.name ?? 'System',
                            action: 'Modification permissions utilisateur',
                            module: 'Utilisateurs',
                            timestamp: DateTime.now(),
                            details: {
                              'userId': updatedUser.id,
                              'userName': updatedUser.name,
                              'newPermissions': updatedUser.permissions.map((p) => p.module).toList(),
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  icon: const Icon(Icons.security, color: Colors.orange),
                ),
              ),
              Tooltip(
                message: user.isActive ? 'Désactiver l\'utilisateur' : 'Activer l\'utilisateur',
                child: IconButton(onPressed: () async {
                  if (user.role == UserRole.admin && user.isActive) { // Trying to deactivate an active admin
                    final activeAdminsCount = await DatabaseService().countActiveAdmins();
                    if (activeAdminsCount <= 1) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Impossible de désactiver le dernier administrateur actif.')),
                      );
                      return; // Block the action
                    }
                    // Require 2FA verification when deactivating an admin
                    if (user.is2faEnabled && (user.twoFaSecret != null && user.twoFaSecret!.isNotEmpty)) {
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
                                      final valid = AuthService.verifyTotpSecret(user.twoFaSecret!, codeCtrl.text);
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
                  }

                  final updatedUser = user.copyWith(isActive: !user.isActive);
                  await DatabaseService().updateUser(updatedUser);
                  _loadUsers();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${updatedUser.name} ${updatedUser.isActive ? 'activé' : 'désactivé'}')));
                  // Audit Log for Activate/Deactivate
                  await DatabaseService().insertAuditLog(
                    AuditLog(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      userId: AuthService.currentUser?.id ?? 'system',
                      userName: AuthService.currentUser?.name ?? 'System',
                      action: updatedUser.isActive ? 'Activation utilisateur' : 'Désactivation utilisateur',
                      module: 'Utilisateurs',
                      timestamp: DateTime.now(),
                      details: {
                        'userId': updatedUser.id,
                        'userName': updatedUser.name,
                        'status': updatedUser.isActive ? 'Actif' : 'Inactif',
                      },
                    ),
                  );
                }, icon: Icon(user.isActive ? Icons.block : Icons.check_circle, color: user.isActive ? Colors.red : Colors.green)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _editUser(User user) {
    showDialog(
      context: context,
      builder: (context) => EditUserDialog(
        user: user,
        onUserUpdated: (updatedUser) async {
          await DatabaseService().updateUser(updatedUser);
          _loadUsers();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Utilisateur ${updatedUser.name} mis à jour.')),
          );
          // Audit Log for User Update
          await DatabaseService().insertAuditLog(
            AuditLog(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              userId: AuthService.currentUser?.id ?? 'system',
              userName: AuthService.currentUser?.name ?? 'System',
              action: 'Modification utilisateur',
              module: 'Utilisateurs',
              timestamp: DateTime.now(),
              details: {
                'userId': updatedUser.id,
                'userName': updatedUser.name,
                'userEmail': updatedUser.email,
                'userRole': updatedUser.role.toString().split('.').last,
                'isActive': updatedUser.isActive,
              },
            ),
          );
        },
      ),
    );
  }
}
