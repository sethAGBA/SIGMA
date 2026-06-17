// lib/screens/clients/client_list_page.dart

import 'package:flutter/material.dart';
import '../../core/services/database_service.dart';
import '../../core/services/client_api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/dialog_utils.dart';
import '../../models/client_model.dart';
import '../../widgets/dialogs/client_form_dialog.dart';
import '../../widgets/dialogs/client_detail_dialog.dart';

class ClientListPage extends StatefulWidget {
  const ClientListPage({super.key});

  @override
  State<ClientListPage> createState() => _ClientListPageState();
}

class _ClientListPageState extends State<ClientListPage> {
  late Future<List<Client>> _clientsFuture;
  final TextEditingController _searchController = TextEditingController();
  ClientStatus? _selectedStatus;
  ClientRisk? _selectedRisk;

  // États pour la sélection multiple
  bool _isSelectionMode = false;
  final Set<int> _selectedClientIds = {};
  bool _isFilterExpanded = false;

  @override
  void initState() {
    super.initState();
    _refreshClients();
  }

  void _refreshClients() {
    setState(() {
      _clientsFuture = ClientApiService().searchClients(
        query: _searchController.text,
        status: _selectedStatus,
        riskLevel: _selectedRisk?.label,
      );
    });
  }

  Future<void> _showClientFormDialog({Client? client}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ClientFormDialog(client: client),
    );

    if (result == true) {
      _refreshClients();
    }
  }

  Future<void> _showClientDetailDialog(Client client) async {
    await showDialog(
      context: context,
      builder: (context) => ClientDetailDialog(
        client: client,
        onEdit: () {
          Navigator.of(context).pop(); // Ferme le dialogue de détails
          _showClientFormDialog(
            client: client,
          ); // Ouvre le formulaire d'édition
        },
        onDelete: () async {
          await DatabaseService().deleteClient(client.id!);
          _refreshClients();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FutureBuilder<List<Client>>(
        future: _clientsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          final clients = snapshot.data ?? [];

          return Column(
            children: [
              _buildSearchBar(context),
              _buildFilterSection(context),
              if (_isSelectionMode) _buildBatchActionBar(context),
              Expanded(
                child: clients.isEmpty
                    ? _buildEmptyState(context)
                    : _buildClientsDataTable(context, clients),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Rechercher par nom, numéro ou téléphone...',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    _searchController.clear();
                    _refreshClients();
                  },
                )
              : null,
          filled: true,
          fillColor: theme.colorScheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: theme.dividerColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: theme.dividerColor),
          ),
        ),
        onChanged: (value) => _refreshClients(),
      ),
    );
  }

  Widget _buildFilterSection(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(null, 'Tous (Status)'),
                      const SizedBox(width: 8),
                      _buildFilterChip(ClientStatus.active, 'Actifs'),
                      const SizedBox(width: 8),
                      _buildFilterChip(ClientStatus.inactive, 'Inactifs'),
                      const SizedBox(width: 8),
                      _buildFilterChip(ClientStatus.blacklisted, 'Blacklistés'),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: () =>
                    setState(() => _isFilterExpanded = !_isFilterExpanded),
                icon: Icon(
                  _isFilterExpanded
                      ? Icons.filter_list_off_rounded
                      : Icons.filter_list_rounded,
                  color: _isFilterExpanded ? AppColors.primary : null,
                ),
                tooltip: 'Filtres avancés',
              ),
            ],
          ),
        ),
        if (_isFilterExpanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Row(
                children: [
                  const Text(
                    'Niveau de risque:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 16),
                  _buildRiskFilterChip(null, 'Tous'),
                  const SizedBox(width: 8),
                  _buildRiskFilterChip(ClientRisk.low, 'Faible'),
                  const SizedBox(width: 8),
                  _buildRiskFilterChip(ClientRisk.medium, 'Moyen'),
                  const SizedBox(width: 8),
                  _buildRiskFilterChip(ClientRisk.high, 'Élevé'),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRiskFilterChip(ClientRisk? risk, String label) {
    final theme = Theme.of(context);
    final isSelected = _selectedRisk == risk;

    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedRisk = risk;
          _refreshClients();
        });
      },
      selectedColor: theme.colorScheme.primary.withOpacity(0.2),
      checkmarkColor: theme.colorScheme.primary,
    );
  }

  Widget _buildFilterChip(ClientStatus? status, String label) {
    final theme = Theme.of(context);
    final isSelected = _selectedStatus == status;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedStatus = status;
          _refreshClients();
        });
      },
      selectedColor: theme.colorScheme.primary.withOpacity(0.2),
      checkmarkColor: theme.colorScheme.primary,
      labelStyle: TextStyle(
        color: isSelected
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildBatchActionBar(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            '${_selectedClientIds.length} sélectionné(s)',
            style: TextStyle(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () {
              // Simuler export
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Exportation des données en cours... (CSV)'),
                ),
              );
            },
            icon: const Icon(Icons.download_rounded),
            label: const Text('Exporter'),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Préparation de l\'envoi SMS groupé...'),
                ),
              );
            },
            icon: const Icon(Icons.sms_rounded),
            label: const Text('SMS'),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => _deleteSelectedClients(),
            icon: const Icon(Icons.delete_rounded),
            label: const Text('Supprimer'),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {
              setState(() {
                _isSelectionMode = false;
                _selectedClientIds.clear();
              });
            },
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Annuler',
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSelectedClients() async {
    final confirm = await DialogUtils.showConfirmDialog(
      context: context,
      title: 'Suppression groupée',
      message:
          'Voulez-vous vraiment supprimer ${_selectedClientIds.length} clients ?',
      confirmText: 'Supprimer tout',
      isDangerous: true,
    );

    if (confirm) {
      for (final id in _selectedClientIds) {
        await DatabaseService().deleteClient(id);
      }
      setState(() {
        _isSelectionMode = false;
        _selectedClientIds.clear();
      });
      _refreshClients();
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 80,
            color: theme.colorScheme.primary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text('Aucun client trouvé', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            _searchController.text.isNotEmpty || _selectedStatus != null
                ? 'Essayez de modifier vos filtres de recherche'
                : 'Utilisez le menu "Nouveau client" pour créer votre premier client',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildClientsDataTable(BuildContext context, List<Client> clients) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: DataTable(
              showCheckboxColumn: true,
              headingRowColor: MaterialStateProperty.all(
                theme.colorScheme.surfaceVariant.withOpacity(0.5),
              ),
              columns: const [
                DataColumn(label: Text('Client')),
                DataColumn(label: Text('N° Client')),
                DataColumn(label: Text('Téléphone')),
                DataColumn(label: Text('Risque')),
                DataColumn(label: Text('Score')),
                DataColumn(label: Text('Statut')),
                DataColumn(label: Text('Actions')),
              ],
              rows: clients.map((client) {
                final isSelected = _selectedClientIds.contains(client.id);
                return DataRow(
                  selected: isSelected,
                  onSelectChanged: (selected) {
                    setState(() {
                      if (selected == true) {
                        _selectedClientIds.add(client.id!);
                        _isSelectionMode = true;
                      } else {
                        _selectedClientIds.remove(client.id);
                        if (_selectedClientIds.isEmpty)
                          _isSelectionMode = false;
                      }
                    });
                  },
                  cells: [
                    DataCell(
                      Row(
                        children: [
                          _buildClientMiniAvatar(client),
                          const SizedBox(width: 12),
                          Text(
                            '${client.nom} ${client.prenoms}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      onTap: () => _showClientDetailDialog(client),
                    ),
                    DataCell(Text(client.numeroClient)),
                    DataCell(Text(client.telephone ?? 'N/A')),
                    DataCell(_buildRiskLevelBadge(client.niveauRisque)),
                    DataCell(_buildScoreText(client.scoreCredit)),
                    DataCell(_buildStatusBadge(client.statut)),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.visibility_rounded,
                              size: 18,
                            ),
                            onPressed: () => _showClientDetailDialog(client),
                            tooltip: 'Détails',
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            onPressed: () =>
                                _showClientFormDialog(client: client),
                            tooltip: 'Modifier',
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClientMiniAvatar(Client client) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          client.nom[0].toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildRiskLevelBadge(ClientRisk risk) {
    Color color;
    String label;
    switch (risk) {
      case ClientRisk.low:
        color = AppColors.success;
        label = 'Faible';
        break;
      case ClientRisk.medium:
        color = AppColors.warning;
        label = 'Moyen';
        break;
      case ClientRisk.high:
        color = AppColors.error;
        label = 'Élevé';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildScoreText(int score) {
    Color color = score > 70
        ? AppColors.success
        : (score < 40 ? AppColors.error : AppColors.warning);
    return Text(
      '$score',
      style: TextStyle(color: color, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildStatusBadge(ClientStatus status) {
    Color color;
    String label;
    switch (status) {
      case ClientStatus.active:
        color = AppColors.success;
        label = 'Actif';
        break;
      case ClientStatus.inactive:
        color = Colors.grey;
        label = 'Inactif';
        break;
      case ClientStatus.blacklisted:
        color = AppColors.error;
        label = 'Blacklisté';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
