import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import '../../models/user_model.dart';
import '../../models/agent_model.dart';
import 'package:intl/intl.dart';

class UsersRightsPage extends StatefulWidget {
  const UsersRightsPage({super.key});

  @override
  State<UsersRightsPage> createState() => _UsersRightsPageState();
}

class _UsersRightsPageState extends State<UsersRightsPage> {
  bool _isLoading = true;
  List<UserAccount> _users = [];
  List<Agent> _availableAgents = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final users = await DatabaseService().getUserAccounts();
      final agents = await DatabaseService().getAgents();
      setState(() {
        _users = users;
        _availableAgents = agents;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading users/agents: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showUserForm([UserAccount? user]) {
    final usernameController = TextEditingController(
      text: user?.username ?? '',
    );
    final passwordController = TextEditingController();
    SystemRole selectedRole = user?.role ?? SystemRole.agentCredit;
    Agent? selectedAgent;

    // If editing, find the current agent
    if (user != null) {
      try {
        selectedAgent = _availableAgents.firstWhere(
          (a) => a.id == user.agentId,
        );
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(user == null ? 'Nouveau Compte' : 'Modifier le Compte'),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (user == null) ...[
                  DropdownButtonFormField<Agent>(
                    value: selectedAgent,
                    decoration: const InputDecoration(
                      labelText: 'Sélectionner l\'Agent',
                    ),
                    items: _availableAgents.map((agent) {
                      return DropdownMenuItem(
                        value: agent,
                        child: Text(agent.fullName),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setDialogState(() => selectedAgent = val),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom d\'utilisateur',
                    hintText: 'ex: j.kouassi',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: user == null
                        ? 'Mot de passe'
                        : 'Nouveau mot de passe (optionnel)',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<SystemRole>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'Profil / Rôle'),
                  items: SystemRole.values.map((role) {
                    return DropdownMenuItem(
                      value: role,
                      child: Text(role.label),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedRole = val);
                  },
                ),
                const SizedBox(height: 16),
                _buildPermissionsPreview(selectedRole),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (usernameController.text.isEmpty ||
                    (user == null && passwordController.text.isEmpty) ||
                    (user == null && selectedAgent == null)) {
                  return;
                }

                final newUser = UserAccount(
                  id:
                      user?.id ??
                      DateTime.now().millisecondsSinceEpoch.toString(),
                  agentId: user?.agentId ?? selectedAgent!.id,
                  username: usernameController.text,
                  passwordHash: passwordController.text.isEmpty
                      ? (user?.passwordHash ?? '')
                      : passwordController.text, // Simplified hash
                  role: selectedRole,
                  isActive: user?.isActive ?? true,
                  createdAt: user?.createdAt ?? DateTime.now(),
                  permissions: selectedRole.defaultPermissions,
                );

                await DatabaseService().insertUserAccount(newUser);
                if (context.mounted) Navigator.pop(context);
                _loadData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text(
                'Enregistrer',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionsPreview(SystemRole role) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Droits inclus :',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 8),
          ...role.defaultPermissions.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 14,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Text(p, style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text(
          'Voulez-vous vraiment supprimer ce compte utilisateur ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseService().deleteUserAccount(id);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUserForm(),
        label: const Text('Ajouter un Utilisateur'),
        icon: const Icon(Icons.person_add_rounded),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 32),
                  Expanded(
                    child: _users.isEmpty
                        ? _buildEmptyState(isDark)
                        : _buildUsersList(isDark),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Utilisateurs & Droits d\'Accès',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        Text(
          'Gérez les comptes système, les profils et les permissions granulaires.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildUsersList(bool isDark) {
    return ListView.builder(
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        final agent = _availableAgents.firstWhere(
          (a) => a.id == user.agentId,
          orElse: () => Agent(
            id: '?',
            firstName: 'Agent',
            lastName: 'Inconnu',
            email: '',
            phone: '',
            role: AgentRole.loanOfficer,
            agencyId: '',
            isActive: false,
            hiredDate: DateTime.now(),
          ),
        );

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark ? Colors.white10 : Colors.grey[200]!,
            ),
          ),
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: Text(
                user.username.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Row(
              children: [
                Text(
                  user.username,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                _buildRoleBadge(user.role),
              ],
            ),
            subtitle: Text(
              'Agent: ${agent.fullName} • Créé le: ${DateFormat('dd/MM/yyyy').format(user.createdAt)}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => _showUserForm(user),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: Colors.red,
                  ),
                  onPressed: () => _deleteUser(user.id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoleBadge(SystemRole role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        role.label.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.admin_panel_settings_outlined,
            size: 64,
            color: isDark ? Colors.white10 : Colors.grey[200],
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucun compte utilisateur configuré',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
