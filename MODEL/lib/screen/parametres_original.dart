import 'package:flutter/material.dart';
import 'dart:io';

// Models
class User {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final List<Permission> permissions;
  final DateTime createdAt;
  final DateTime lastLogin;
  final bool isActive;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.permissions = const [],
    required this.createdAt,
    required this.lastLogin,
    this.isActive = true,
  });
}

enum UserRole { admin, comptable, commercial, secretaire }

class Permission {
  final String module;
  final List<String> actions; // create, read, update, delete

  Permission({required this.module, required this.actions});
}

class AuditLog {
  final String id;
  final String userId;
  final String userName;
  final String action;
  final String module;
  final DateTime timestamp;
  final Map<String, dynamic> details;

  AuditLog({
    required this.id,
    required this.userId,
    required this.userName,
    required this.action,
    required this.module,
    required this.timestamp,
    this.details = const {},
  });
}

class DocumentTemplate {
  final String id;
  final String name;
  final String type;
  final String content;
  final DateTime lastModified;

  DocumentTemplate({
    required this.id,
    required this.name,
    required this.type,
    required this.content,
    required this.lastModified,
  });
}

// Main Screen
class ParametresScreen extends StatefulWidget {
  @override
  _ParametresScreenState createState() => _ParametresScreenState();
}

class _ParametresScreenState extends State<ParametresScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header avec onglets
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paramètres & Administration',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Configuration système et gestion des utilisateurs',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 24),
              
              // Onglets
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  indicator: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  tabs: const [
                    Tab(icon: Icon(Icons.business), text: 'Entreprise'),
                    Tab(icon: Icon(Icons.people), text: 'Utilisateurs'),
                    Tab(icon: Icon(Icons.description), text: 'Templates'),
                    Tab(icon: Icon(Icons.security), text: 'Sécurité'),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Contenu des onglets
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              EntrepriseTab(),
              UtilisateursTab(),
              TemplatesTab(),
              SecurityTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// Onglet Configuration Entreprise
class EntrepriseTab extends StatefulWidget {
  @override
  _EntrepriseTabState createState() => _EntrepriseTabState();
}

class _EntrepriseTabState extends State<EntrepriseTab> {
  final _formKey = GlobalKey<FormState>();
  final _raisonSocialeController = TextEditingController(text: 'AfroForma SARL');
  final _rccmController = TextEditingController(text: 'TG-LOM-01-B-123456');
  final _nifController = TextEditingController(text: '12345678901');
  final _adresseController = TextEditingController(text: '123 Avenue de la Paix, Lomé');
  final _telephoneController = TextEditingController(text: '+228 22 12 34 56');
  final _emailController = TextEditingController(text: 'contact@afroforma.com');
  final _siteWebController = TextEditingController(text: 'www.afroforma.com');
  final _exerciceController = TextEditingController(text: DateTime.now().year.toString());
  
  String? _logoPath;
  String _monnaie = 'FCFA';
  String _planComptable = 'SYSCOHADA';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Informations société
          Expanded(
            flex: 2,
            child: _buildSection(
              'Informations Société',
              Icons.business,
              Column(
                children: [
                  _buildLogoUpload(),
                  const SizedBox(height: 20),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildTextField(_raisonSocialeController, 'Raison Sociale', Icons.business_center),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildTextField(_rccmController, 'RCCM', Icons.assignment)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildTextField(_nifController, 'NIF', Icons.receipt_long)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(_adresseController, 'Adresse', Icons.location_on, maxLines: 2),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildTextField(_telephoneController, 'Téléphone', Icons.phone)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildTextField(_emailController, 'Email', Icons.email)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(_siteWebController, 'Site Web', Icons.web),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(width: 24),
          
          // Paramètres comptables
          Expanded(
            child: Column(
              children: [
                _buildSection(
                  'Paramètres Comptables',
                  Icons.calculate,
                  Column(
                    children: [
                      _buildDropdownField(
                        'Plan Comptable',
                        _planComptable,
                        ['SYSCOHADA', 'PCG', 'Personnalisé'],
                        (value) => setState(() => _planComptable = value!),
                        Icons.account_balance,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(_exerciceController, 'Exercice Comptable', Icons.calendar_today),
                      const SizedBox(height: 16),
                      _buildDropdownField(
                        'Monnaie',
                        _monnaie,
                        ['FCFA', 'EUR', 'USD'],
                        (value) => setState(() => _monnaie = value!),
                        Icons.monetization_on,
                      ),
                      const SizedBox(height: 20),
                      _buildActionButton(
                        'Configurer Plan Comptable',
                        Icons.settings,
                        const Color(0xFF8B5CF6),
                        () => _configurePlanComptable(),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Actions
                _buildSection(
                  'Actions',
                  Icons.save,
                  Column(
                    children: [
                      _buildActionButton(
                        'Enregistrer les Modifications',
                        Icons.save,
                        const Color(0xFF10B981),
                        () => _saveConfiguration(),
                      ),
                      const SizedBox(height: 12),
                      _buildActionButton(
                        'Réinitialiser',
                        Icons.refresh,
                        const Color(0xFFEF4444),
                        () => _resetConfiguration(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoUpload() {
    return GestureDetector(
      onTap: () => _pickLogo(),
      child: Container(
        width: 150,
        height: 150,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
        ),
        child: _logoPath != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(File(_logoPath!), fit: BoxFit.cover),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.business, color: Colors.white.withOpacity(0.5), size: 40),
                  const SizedBox(height: 8),
                  Text(
                    'Logo Entreprise',
                    style: TextStyle(color: Colors.white.withOpacity(0.7)),
                  ),
                  Text(
                    'Cliquer pour changer',
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                  ),
                ],
              ),
      ),
    );
  }

  void _pickLogo() {
    // TODO: Implémenter la sélection de logo
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sélection de logo à implémenter')),
    );
  }

  void _configurePlanComptable() {
    showDialog(
      context: context,
      builder: (context) => PlanComptableDialog(),
    );
  }

  void _saveConfiguration() {
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuration sauvegardée avec succès'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  void _resetConfiguration() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Réinitialiser', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Êtes-vous sûr de vouloir réinitialiser la configuration ?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Reset configuration
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Réinitialiser', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// Onglet Gestion des Utilisateurs
class UtilisateursTab extends StatefulWidget {
  @override
  _UtilisateursTabState createState() => _UtilisateursTabState();
}

class _UtilisateursTabState extends State<UtilisateursTab> {
  final List<User> _users = _generateSampleUsers();
  String _selectedRole = 'Tous';

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _selectedRole == 'Tous' 
        ? _users 
        : _users.where((u) => _getUserRoleString(u.role) == _selectedRole).toList();

    return Column(
      children: [
        // Header avec filtres et actions
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              // Filtre par rôle
              Expanded(
                child: _buildDropdownField(
                  'Filtrer par rôle',
                  _selectedRole,
                  ['Tous', 'Admin', 'Comptable', 'Commercial', 'Secrétaire'],
                  (value) => setState(() => _selectedRole = value!),
                  Icons.filter_list,
                ),
              ),
              const SizedBox(width: 16),
              
              // Bouton nouvel utilisateur
              ElevatedButton.icon(
                onPressed: () => _showNewUserDialog(),
                icon: const Icon(Icons.person_add, color: Colors.white),
                label: const Text('Nouvel Utilisateur', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(width: 12),
              
              // Bouton audit
              ElevatedButton.icon(
                onPressed: () => _showAuditDialog(),
                icon: const Icon(Icons.history, color: Colors.white),
                label: const Text('Audit', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Liste des utilisateurs
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredUsers.length,
              itemBuilder: (context, index) {
                return _buildUserCard(filteredUsers[index]);
              },
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
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 30,
            backgroundColor: _getRoleColor(user.role),
            child: Text(
              user.name.split(' ').map((n) => n[0]).take(2).join(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Informations
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  user.email,
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getRoleColor(user.role),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getUserRoleString(user.role),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: user.isActive ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        user.isActive ? 'Actif' : 'Inactif',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => _editUser(user),
                icon: const Icon(Icons.edit, color: Colors.blue),
                tooltip: 'Modifier',
              ),
              IconButton(
                onPressed: () => _managePermissions(user),
                icon: const Icon(Icons.security, color: Colors.orange),
                tooltip: 'Permissions',
              ),
              IconButton(
                onPressed: () => _toggleUserStatus(user),
                icon: Icon(
                  user.isActive ? Icons.block : Icons.check_circle,
                  color: user.isActive ? Colors.red : Colors.green,
                ),
                tooltip: user.isActive ? 'Désactiver' : 'Activer',
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showNewUserDialog() {
    showDialog(
      context: context,
      builder: (context) => NewUserDialog(
        onUserCreated: (user) {
          setState(() {
            _users.add(user);
          });
        },
      ),
    );
  }

  void _showAuditDialog() {
    showDialog(
      context: context,
      builder: (context) => AuditDialog(),
    );
  }

  void _editUser(User user) {
    // TODO: Implémenter l'édition d'utilisateur
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Édition de ${user.name}')),
    );
  }

  void _managePermissions(User user) {
    showDialog(
      context: context,
      builder: (context) => PermissionsDialog(user: user),
    );
  }

  void _toggleUserStatus(User user) {
    setState(() {
      // TODO: Update in database
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${user.name} ${user.isActive ? 'désactivé' : 'activé'}'),
      ),
    );
  }
}

// Onglet Templates de Documents
class TemplatesTab extends StatefulWidget {
  @override
  _TemplatesTabState createState() => _TemplatesTabState();
}

class _TemplatesTabState extends State<TemplatesTab> {
  final List<DocumentTemplate> _templates = [
    DocumentTemplate(
      id: '1',
      name: 'Facture Standard',
      type: 'facture',
      content: 'Template facture...',
      lastModified: DateTime.now().subtract(const Duration(days: 5)),
    ),
    DocumentTemplate(
      id: '2',
      name: 'Reçu de Paiement',
      type: 'recu',
      content: 'Template reçu...',
      lastModified: DateTime.now().subtract(const Duration(days: 2)),
    ),
    DocumentTemplate(
      id: '3',
      name: 'Attestation de Formation',
      type: 'attestation',
      content: 'Template attestation...',
      lastModified: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Templates de Documents',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Gérez les modèles de factures, reçus et attestations',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showNewTemplateDialog(),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Nouveau Template', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Grille des templates
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.2,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
            ),
            itemCount: _templates.length,
            itemBuilder: (context, index) {
              return _buildTemplateCard(_templates[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateCard(DocumentTemplate template) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getTemplateIcon(template.type),
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const Spacer(),
                PopupMenuButton(
                  icon: Icon(Icons.more_vert, color: Colors.white.withOpacity(0.7)),
                  color: const Color(0xFF334155),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text('Modifier', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'duplicate',
                      child: Row(
                        children: [
                          Icon(Icons.copy, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text('Dupliquer', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 18),
                          SizedBox(width: 8),
                          Text('Supprimer', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) => _handleTemplateAction(template, value),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Text(
              template.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getTemplateColor(template.type),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                template.type.toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
            
            const Spacer(),
            
            Text(
              'Modifié le ${_formatDate(template.lastModified)}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTemplateIcon(String type) {
    switch (type) {
      case 'facture': return Icons.receipt_long;
      case 'recu': return Icons.receipt;
      case 'attestation': return Icons.verified;
      default: return Icons.description;
    }
  }

  Color _getTemplateColor(String type) {
    switch (type) {
      case 'facture': return Colors.blue;
      case 'recu': return Colors.green;
      case 'attestation': return Colors.purple;
      default: return Colors.grey;
    }
  }

  void _showNewTemplateDialog() {
    // TODO: Implémenter la création de template
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Création de template à implémenter')),
    );
  }

  void _handleTemplateAction(DocumentTemplate template, dynamic action) {
    switch (action) {
      case 'edit':
        // TODO: Éditer template
        break;
      case 'duplicate':
        // TODO: Dupliquer template
        break;
      case 'delete':
        // TODO: Supprimer template
        break;
    }
  }
}

// Onglet Sécurité et Sauvegarde
class SecurityTab extends StatefulWidget {
  @override
  _SecurityTabState createState() => _SecurityTabState();
}

class _SecurityTabState extends State<SecurityTab> {
  bool _autoBackup = true;
  String _backupFrequency = 'Quotidienne';
  int _retentionDays = 30;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sauvegarde
          Expanded(
            child: _buildSection(
              'Sauvegarde & Restauration',
              Icons.backup,
              Column(
                children: [
                  // Configuration auto-backup
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Sauvegarde Automatique',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Switch(
                              value: _autoBackup,
                              onChanged: (value) => setState(() => _autoBackup = value),
                              activeColor: const Color(0xFF10B981),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_autoBackup) ...[
                          _buildDropdownField(
                            'Fréquence',
                            _backupFrequency,
                            ['Quotidienne', 'Hebdomadaire', 'Mensuelle'],
                            (value) => setState(() => _backupFrequency = value!),
                            Icons.schedule,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Text(
                                'Rétention (jours)',
                                style: TextStyle(color: Colors.white, fontSize: 16),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Slider(
                                  value: _retentionDays.toDouble(),
                                  min: 7,
                                  max: 90,
                                  divisions: 83,
                                  label: '$_retentionDays jours',
                                  onChanged: (value) => setState(() => _retentionDays = value.toInt()),
                                  activeColor: const Color(0xFF10B981),
                                  inactiveColor: Colors.white24,
                                ),
                              ),
                              Text(
                                '$_retentionDays',
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Actions de sauvegarde/restauration
                  _buildActionButton(
                    'Sauvegarder Maintenant',
                    Icons.backup,
                    const Color(0xFF10B981),
                    () => _performBackup(),
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    'Restaurer une Sauvegarde',
                    Icons.restore,
                    const Color(0xFF6366F1),
                    () => _showRestoreDialog(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _performBackup() {
    // Placeholder backup implementation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sauvegarde déclenchée (placeholder)')),
    );
  }

  Future<void> _showRestoreDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Restaurer une sauvegarde', style: TextStyle(color: Colors.white)),
        content: const Text('Fonction de restauration à implémenter. (placeholder)', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
        ],
      ),
    );
  }
}

// ---------------------- Helpers et Dialogs (stubs) ----------------------

Widget _buildSection(String title, IconData icon, Widget child) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withOpacity(0.06)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

Widget _buildTextField(TextEditingController controller, String label, IconData icon, {int maxLines = 1}) {
  return TextField(
    controller: controller,
    maxLines: maxLines,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
      prefixIcon: Icon(icon, color: Colors.white54),
      filled: true,
      fillColor: Colors.black.withOpacity(0.15),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
    ),
  );
}

Widget _buildDropdownField(String label, String value, List<String> items, ValueChanged<String?> onChanged, IconData icon) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(0.15),
      borderRadius: BorderRadius.circular(8),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        onChanged: onChanged,
        isExpanded: true,
        dropdownColor: const Color(0xFF1E293B),
        items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(color: Colors.white)))).toList(),
        hint: Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7))),
        icon: Icon(icon, color: Colors.white54),
        style: const TextStyle(color: Colors.white),
      ),
    ),
  );
}

Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
  return SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}

List<User> _generateSampleUsers() {
  final now = DateTime.now();
  return [
    User(id: 'u1', name: 'Admin Principal', email: 'admin@afroforma.com', role: UserRole.admin, permissions: [], createdAt: now.subtract(const Duration(days: 365)), lastLogin: now.subtract(const Duration(hours: 5))),
    User(id: 'u2', name: 'Comptable', email: 'compta@afroforma.com', role: UserRole.comptable, permissions: [], createdAt: now.subtract(const Duration(days: 200)), lastLogin: now.subtract(const Duration(days: 1))),
    User(id: 'u3', name: 'Commercial', email: 'sales@afroforma.com', role: UserRole.commercial, permissions: [], createdAt: now.subtract(const Duration(days: 90)), lastLogin: now.subtract(const Duration(days: 2))),
  ];
}

String _getUserRoleString(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return 'Admin';
    case UserRole.comptable:
      return 'Comptable';
    case UserRole.commercial:
      return 'Commercial';
    case UserRole.secretaire:
      return 'Secrétaire';
  }
}

Color _getRoleColor(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return const Color(0xFF6366F1);
    case UserRole.comptable:
      return const Color(0xFF10B981);
    case UserRole.commercial:
      return const Color(0xFFF59E0B);
    case UserRole.secretaire:
      return const Color(0xFF06B6D4);
  }
}

String _formatDate(DateTime dt) {
  return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

// Simple Plan Comptable dialog stub
class PlanComptableDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text('Plan Comptable', style: TextStyle(color: Colors.white)),
      content: const Text('Gestion du plan comptable (placeholder)', style: TextStyle(color: Colors.white70)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
      ],
    );
  }
}

// NewUserDialog stub with callback
class NewUserDialog extends StatefulWidget {
  final ValueChanged<User> onUserCreated;

  const NewUserDialog({Key? key, required this.onUserCreated}) : super(key: key);

  @override
  _NewUserDialogState createState() => _NewUserDialogState();
}

class _NewUserDialogState extends State<NewUserDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  UserRole _role = UserRole.commercial;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text('Nouvel utilisateur', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nom'), style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 8),
          TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email'), style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 8),
          DropdownButton<UserRole>(
            value: _role,
            dropdownColor: const Color(0xFF1E293B),
            items: UserRole.values.map((r) => DropdownMenuItem(value: r, child: Text(_getUserRoleString(r), style: const TextStyle(color: Colors.white)))).toList(),
            onChanged: (v) => setState(() => _role = v ?? _role),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: () {
            final user = User(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: _name.text.trim().isEmpty ? 'Utilisateur' : _name.text.trim(),
              email: _email.text.trim(),
              role: _role,
              permissions: [],
              createdAt: DateTime.now(),
              lastLogin: DateTime.now(),
            );
            widget.onUserCreated(user);
            Navigator.pop(context);
          },
          child: const Text('Créer'),
        ),
      ],
    );
  }
}

// Audit dialog stub
class AuditDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final sample = [
      AuditLog(id: 'a1', userId: 'u1', userName: 'Admin', action: 'Connexion', module: 'Auth', timestamp: DateTime.now().subtract(const Duration(hours: 2)), details: {}),
      AuditLog(id: 'a2', userId: 'u2', userName: 'Comptable', action: 'Modification', module: 'Comptabilité', timestamp: DateTime.now().subtract(const Duration(days: 1)), details: {}),
    ];
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text('Audit', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 500,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: sample.length,
          itemBuilder: (ctx, i) {
            final e = sample[i];
            return ListTile(
              title: Text('${e.userName} — ${e.action}', style: const TextStyle(color: Colors.white)),
              subtitle: Text('${e.module} • ${_formatDate(e.timestamp)}', style: const TextStyle(color: Colors.white70)),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
      ],
    );
  }
}

// Permissions dialog stub
class PermissionsDialog extends StatefulWidget {
  final User user;

  const PermissionsDialog({Key? key, required this.user}) : super(key: key);

  @override
  _PermissionsDialogState createState() => _PermissionsDialogState();
}

class _PermissionsDialogState extends State<PermissionsDialog> {
  late List<Permission> _perms;

  @override
  void initState() {
    super.initState();
    _perms = widget.user.permissions.isNotEmpty
        ? widget.user.permissions.map((p) => Permission(module: p.module, actions: List.from(p.actions))).toList()
        : [Permission(module: 'Comptabilité', actions: ['read'])];
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
          itemCount: _perms.length,
          itemBuilder: (ctx, i) {
            final p = _perms[i];
            return ListTile(
              title: Text(p.module, style: const TextStyle(color: Colors.white)),
              subtitle: Text(p.actions.join(', '), style: const TextStyle(color: Colors.white70)),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Enregistrer')),
      ],
    );
  }
}