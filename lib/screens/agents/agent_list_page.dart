import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/agent_model.dart';
import '../../core/services/agency_api_service.dart';
import 'agent_form_dialog.dart';
import 'agent_detail_dialog.dart';

class AgentListPage extends StatefulWidget {
  const AgentListPage({super.key});

  @override
  State<AgentListPage> createState() => _AgentListPageState();
}

class _AgentListPageState extends State<AgentListPage> {
  List<Agent> _agents = [];
  List<Agent> _filteredAgents = [];
  String _searchQuery = '';
  AgentRole? _selectedRole;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  Future<void> _loadAgents() async {
    setState(() => _isLoading = true);
    try {
      final agents = await AgencyApiService().getAgents();
      setState(() {
        _agents = agents;
        _filteredAgents = agents;
        _isLoading = false;
      });
      _filterAgents(); // Re-apply filters if any
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du chargement des agents: $e')),
        );
      }
    }
  }

  void _filterAgents() {
    setState(() {
      _filteredAgents = _agents.where((agent) {
        final matchesSearch =
            agent.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            agent.email.toLowerCase().contains(_searchQuery.toLowerCase());
        final matchesRole =
            _selectedRole == null || agent.role == _selectedRole;
        return matchesSearch && matchesRole;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(isDark),
            const SizedBox(height: 24),
            _buildFilters(isDark),
            const SizedBox(height: 24),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredAgents.isEmpty
                  ? Center(
                      child: Text(
                        'Aucun agent trouvé',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    )
                  : _buildAgentsTable(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gestion des Agents',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            Text(
              'Gérez votre équipe terrain : affectations, rôles et performances.',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.grey[700],
              ),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () async {
            final result = await showDialog(
              context: context,
              builder: (context) => const AgentFormDialog(),
            );
            if (result == true) {
              _loadAgents();
            }
          },
          icon: const Icon(Icons.add),
          label: const Text('Nouvel Agent'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilters(bool isDark) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Rechercher un agent...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            ),
            onChanged: (value) {
              _searchQuery = value;
              _filterAgents();
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 1,
          child: DropdownButtonFormField<AgentRole>(
            decoration: InputDecoration(
              hintText: 'Filtrer par rôle',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 0,
              ),
            ),
            value: _selectedRole,
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Tous les rôles'),
              ),
              ...AgentRole.values.map(
                (role) =>
                    DropdownMenuItem(value: role, child: Text(role.label)),
              ),
            ],
            onChanged: (value) {
              _selectedRole = value;
              _filterAgents();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAgentsTable(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ListView.separated(
          itemCount: _filteredAgents.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            color: isDark ? Colors.white10 : Colors.grey[200],
          ),
          itemBuilder: (context, index) {
            final agent = _filteredAgents[index];
            return ListTile(
              onTap: () async {
                await showDialog(
                  context: context,
                  builder: (context) => AgentDetailDialog(agent: agent),
                );
                // Optionally reload agents if details dialog allows editing that affects list
                // _loadAgents();
              },
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Text(
                  agent.firstName.isNotEmpty ? agent.firstName[0] : '?',
                  style: agent.isActive
                      ? const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        )
                      : const TextStyle(color: Colors.grey),
                ),
              ),
              title: Text(
                agent.fullName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(agent.email),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      agent.role.label,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () async {
                      final result = await showDialog(
                        context: context,
                        builder: (context) => AgentFormDialog(agent: agent),
                      );
                      if (result == true) {
                        _loadAgents();
                      }
                    },
                    tooltip: 'Modifier',
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
