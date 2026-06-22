// lib/screens/groupes/group_list_page.dart

import 'package:flutter/material.dart';
import '../../core/services/group_api_service.dart';
import '../../core/services/client_api_service.dart';
import '../../core/services/database_service.dart';
import '../../core/theme/app_colors.dart';
import '../../models/client_model.dart';
import '../../models/groupe_solidaire_model.dart';
import '../../widgets/dialogs/group_form_dialog.dart';
import '../../widgets/dialogs/group_detail_dialog.dart';

class GroupListPage extends StatefulWidget {
  const GroupListPage({super.key});

  @override
  State<GroupListPage> createState() => _GroupListPageState();
}

class _GroupListPageState extends State<GroupListPage> {
  late Future<List<GroupeSolidaire>> _groupsFuture;
  final TextEditingController _searchController = TextEditingController();

  GroupStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _refreshGroups();
  }

  void _refreshGroups() {
    setState(() {
      _groupsFuture = GroupApiService().searchGroupes(
        query: _searchController.text.trim(),
        status: _selectedStatus,
      );
    });
  }

  Future<void> _showGroupForm({GroupeSolidaire? group}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => GroupFormDialog(group: group),
    );

    if (result == true) {
      _refreshGroups();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: FutureBuilder<List<GroupeSolidaire>>(
              future: _groupsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erreur: ${snapshot.error}'));
                }
                final groups = snapshot.data ?? [];
                if (groups.isEmpty) {
                  return _buildEmptyState(context);
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(24),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    mainAxisExtent: 220,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                  ),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    return _buildGroupCard(context, groups[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-groupes',
        onPressed: () => _showGroupForm(),
        icon: const Icon(Icons.group_add_rounded),
        label: const Text('Nouveau Groupe'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher un groupe (nom ou code)...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          _refreshGroups();
                        },
                      )
                    : null,
                filled: true,
                fillColor: theme.colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
              ),
              onChanged: (value) => _refreshGroups(),
            ),
          ),
          const SizedBox(width: 12),
          _buildFilterChip(null, 'Tous'),
          const SizedBox(width: 8),
          _buildFilterChip(GroupStatus.active, 'Actifs'),
          const SizedBox(width: 8),
          _buildFilterChip(GroupStatus.inactive, 'Inactifs'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(GroupStatus? status, String label) {
    final theme = Theme.of(context);
    final isSelected = _selectedStatus == status;

    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedStatus = status;
          _refreshGroups();
        });
      },
      selectedColor: theme.colorScheme.primary.withOpacity(0.2),
      checkmarkColor: theme.colorScheme.primary,
    );
  }

  Widget _buildGroupCard(BuildContext context, GroupeSolidaire group) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? theme.dividerColor : Colors.grey.shade100,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            await showDialog(
              context: context,
              barrierDismissible: true,
              builder: (context) => GroupDetailDialog(group: group),
            );
            _refreshGroups();
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.groups_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.nom,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'REF: ${group.code}',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(group.statut),
                  ],
                ),
                const SizedBox(height: 16),
                _buildResponsableInfo(group),
                const Spacer(),
                const Divider(height: 1),
                const SizedBox(height: 12),
                _buildGroupMetrics(group),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResponsableInfo(GroupeSolidaire group) {
    return FutureBuilder<Client?>(
      future: group.responsableId != null
          ? ClientApiService().getClientById(group.responsableId!)
          : Future.value(null),
      builder: (context, snapshot) {
        final responsableName = snapshot.data != null
            ? '${snapshot.data!.nom} ${snapshot.data!.prenoms}'
            : 'Aucun responsable';
        return Row(
          children: [
            const Icon(
              Icons.person_outline_rounded,
              size: 14,
              color: Colors.grey,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                responsableName,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGroupMetrics(GroupeSolidaire group) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        DatabaseService().getGroupActiveLoansTotal(group.id!),
        DatabaseService().getGroupRepaymentRate(group.id!),
        ClientApiService().getGroupMembers(group.id!),
      ]),
      builder: (context, snapshot) {
        final memberCount = (snapshot.data?[2] as List?)?.length ?? 0;
        final encours = (snapshot.data?[0] as double?) ?? 0.0;
        final tauxRate = snapshot.data?[1] as double?;

        final encoursFmt = encours >= 1000000
            ? '${(encours / 1000000).toStringAsFixed(2)} M FCFA'
            : encours >= 1000
                ? '${(encours / 1000).toStringAsFixed(0)} K FCFA'
                : '${encours.toInt()} FCFA';

        final tauxColor = tauxRate == null
            ? Colors.grey
            : tauxRate >= 90
                ? AppColors.success
                : tauxRate >= 70
                    ? AppColors.warning
                    : AppColors.error;
        final tauxFmt = tauxRate == null ? 'N/A' : '${tauxRate.round()}%';

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildMetricItem('MEMBRES', memberCount.toString()),
            _buildMetricItem('ENCOURS', encoursFmt),
            _buildMetricItem('PERF.', tauxFmt, color: tauxColor),
          ],
        );
      },
    );
  }

  Widget _buildMetricItem(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: Colors.grey,
            letterSpacing: 0.5,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(GroupStatus status) {
    Color color;
    String label;
    switch (status) {
      case GroupStatus.active:
        color = AppColors.success;
        label = 'Actif';
        break;
      case GroupStatus.inactive:
        color = Colors.grey;
        label = 'Inactif';
        break;
      case GroupStatus.dissolved:
        color = AppColors.error;
        label = 'Dissous';
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

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.group_off_rounded,
            size: 80,
            color: theme.colorScheme.primary.withOpacity(0.2),
          ),
          const SizedBox(height: 24),
          const Text(
            'Aucun groupe solidaire',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Créez un groupe pour regrouper vos clients',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
