// lib/widgets/dialogs/group_detail_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/database_service.dart';
import '../../core/theme/app_colors.dart';
import '../../models/client_model.dart';
import '../../models/groupe_solidaire_model.dart';
import '../../core/utils/dialog_utils.dart';
import 'group_form_dialog.dart';

class GroupDetailDialog extends StatefulWidget {
  final GroupeSolidaire group;

  const GroupDetailDialog({super.key, required this.group});

  @override
  State<GroupDetailDialog> createState() => _GroupDetailDialogState();
}

class _GroupDetailDialogState extends State<GroupDetailDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<Client>> _membersFuture;
  late GroupeSolidaire _group;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _tabController = TabController(length: 6, vsync: this);
    _refreshMembers();
  }

  void _refreshMembers() {
    setState(() {
      _membersFuture = DatabaseService().getGroupMembers(_group.id!);
    });
  }

  Future<void> _addMember() async {
    final allClients = await DatabaseService().getClients();
    final availableClients = allClients
        .where((c) => c.groupeSolidaireId == null)
        .toList();

    if (availableClients.isEmpty) {
      if (mounted) {
        DialogUtils.showErrorDialog(
          context: context,
          title: 'Aucun client disponible',
          message: 'Tous les clients sont déjà assignés à des groupes.',
        );
      }
      return;
    }

    if (mounted) {
      final selectedClient = await showDialog<Client>(
        context: context,
        builder: (context) => _buildAddMemberSearchDialog(availableClients),
      );

      if (selectedClient != null) {
        await DatabaseService().addClientToGroup(
          selectedClient.id!,
          _group.id!,
        );
        _refreshMembers();
      }
    }
  }

  Widget _buildAddMemberSearchDialog(List<Client> clients) {
    String searchQuery = '';
    return StatefulBuilder(
      builder: (context, setDialogState) {
        final filteredClients = clients.where((client) {
          final query = searchQuery.toLowerCase();
          return client.nom.toLowerCase().contains(query) ||
              client.prenoms.toLowerCase().contains(query) ||
              client.numeroClient.toLowerCase().contains(query) ||
              (client.telephone?.contains(query) ?? false);
        }).toList();

        return AlertDialog(
          title: const Text('Sélectionner un nouveau membre'),
          content: SizedBox(
            width: 450,
            height: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher par nom, code ou téléphone...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(
                      context,
                    ).colorScheme.surfaceVariant.withOpacity(0.3),
                  ),
                  onChanged: (value) {
                    setDialogState(() {
                      searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: filteredClients.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_search_rounded,
                                size: 48,
                                color: Colors.grey.withOpacity(0.5),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Aucun client trouvé',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: filteredClients.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final client = filteredClients[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primary.withOpacity(
                                  0.1,
                                ),
                                child: Text(
                                  client.nom[0],
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                '${client.nom} ${client.prenoms}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${client.numeroClient}${client.telephone != null ? ' • ${client.telephone}' : ''}',
                              ),
                              onTap: () => Navigator.pop(context, client),
                              hoverColor: AppColors.primary.withOpacity(0.05),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 800,
        height: 700,
        child: Column(
          children: [
            _buildHeader(theme),
            _buildTabBar(theme),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMembersTab(),
                  _buildLoansTab(),
                  _buildGuaranteeTab(),
                  _buildCollectiveSavingsTab(),
                  _buildPerformanceTab(),
                  _buildDocumentsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.groups_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Groupe : ${_group.nom}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Code : ${_group.code} • Créé le ${DateFormat('dd/MM/yyyy').format(_group.dateCreation)}',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _showMoreOptions(theme),
            icon: const Icon(Icons.more_horiz_rounded),
            tooltip: 'Plus d\'options',
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Fermer',
          ),
        ],
      ),
    );
  }

  void _showMoreOptions(ThemeData theme) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit_rounded, color: AppColors.primary),
            title: const Text('Modifier les informations'),
            onTap: () async {
              Navigator.pop(context);
              final result = await showDialog<bool>(
                context: context,
                builder: (context) => GroupFormDialog(group: _group),
              );
              if (result == true) {
                final updated = await DatabaseService().getGroupeById(
                  _group.id!,
                );
                if (updated != null) setState(() => _group = updated);
              }
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.do_not_disturb_on_rounded,
              color: Colors.orange,
            ),
            title: const Text('Basculer Inactif'),
            onTap: () => _updateGroupStatus(GroupStatus.inactive),
          ),
          ListTile(
            leading: const Icon(
              Icons.delete_forever_rounded,
              color: Colors.red,
            ),
            title: const Text('Dissoudre le groupe'),
            onTap: () async {
              Navigator.pop(context);
              final confirm = await DialogUtils.showConfirmDialog(
                context: context,
                title: 'Dissoudre le groupe',
                message:
                    'Êtes-vous sûr de vouloir dissoudre ce groupe ? Tous les membres seront détachés.',
                isDangerous: true,
                confirmText: 'Dissoudre',
              );
              if (confirm) {
                await _updateGroupStatus(GroupStatus.dissolved);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _updateGroupStatus(GroupStatus newStatus) async {
    final updated = GroupeSolidaire(
      id: _group.id,
      code: _group.code,
      nom: _group.nom,
      dateCreation: _group.dateCreation,
      statut: newStatus,
      description: _group.description,
      responsableId: _group.responsableId,
      tresorierId: _group.tresorierId,
    );
    await DatabaseService().updateGroupe(updated);
    setState(() => _group = updated);
    if (mounted && newStatus == GroupStatus.dissolved) {
      Navigator.pop(context, true); // Fermer le dialogue si dissous
    } else if (mounted) {
      Navigator.pop(context); // Fermer le menu
    }
  }

  Widget _buildTabBar(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        indicatorColor: AppColors.primary,
        tabs: const [
          Tab(text: 'Membres', icon: Icon(Icons.people_rounded)),
          Tab(
            text: 'Prêts collectifs',
            icon: Icon(Icons.account_balance_wallet_rounded),
          ),
          Tab(text: 'Caution solidaire', icon: Icon(Icons.security_rounded)),
          Tab(text: 'Épargne', icon: Icon(Icons.savings_rounded)),
          Tab(text: 'Performance', icon: Icon(Icons.trending_up_rounded)),
          Tab(text: 'Documents', icon: Icon(Icons.folder_shared_rounded)),
        ],
      ),
    );
  }

  Widget _buildMembersTab() {
    return FutureBuilder<List<Client>>(
      future: _membersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final members = snapshot.data ?? [];
        final theme = Theme.of(context);

        return Column(
          children: [
            _buildMembersActionHeader(members),
            Expanded(
              child: members.isEmpty
                  ? _buildNoMembersState()
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: members.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final member = members[index];
                        final isResponsable = member.id == _group.responsableId;
                        final isTresorier = member.id == _group.tresorierId;

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: _buildMemberAvatar(
                            member,
                            theme,
                            isResponsable,
                            isTresorier,
                          ),
                          title: Row(
                            children: [
                              Text(
                                '${member.nom} ${member.prenoms}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (isResponsable || isTresorier) ...[
                                const SizedBox(width: 8),
                                _buildRoleBadge(
                                  isResponsable ? 'RESPONSABLE' : 'TRÉSORIER',
                                  isResponsable ? Colors.amber : Colors.blue,
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            '${member.numeroClient} • Adhésion: ${DateFormat('dd/MM/yyyy').format(member.dateCreation)}',
                          ),
                          trailing: _buildMemberActions(member),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMembersActionHeader(List<Client> members) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${members.length} membres inscrits',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Performance moyenne: 100%',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: _addMember,
            icon: const Icon(Icons.person_add_rounded),
            label: const Text('Nouveau membre'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberAvatar(
    Client member,
    ThemeData theme,
    bool isResp,
    bool isTres,
  ) {
    return Stack(
      children: [
        CircleAvatar(
          backgroundColor: theme.colorScheme.surfaceVariant,
          child: Text(
            member.nom[0],
            style: TextStyle(color: theme.colorScheme.primary),
          ),
        ),
        if (isResp || isTres)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isResp ? Colors.amber : Colors.blue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(
                isResp
                    ? Icons.star_rounded
                    : Icons.account_balance_wallet_rounded,
                size: 10,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRoleBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMemberActions(Client member) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (value) async {
            if (value == 'responsable') {
              _toggleRole(member.id!, true);
            } else if (value == 'tresorier') {
              _toggleRole(member.id!, false);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'responsable',
              child: Row(
                children: [
                  const Icon(Icons.star_outline_rounded, size: 18),
                  const SizedBox(width: 12),
                  Text(
                    _group.responsableId == member.id
                        ? 'Retirer Responsable'
                        : 'Nommer Responsable',
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'tresorier',
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined, size: 18),
                  const SizedBox(width: 12),
                  Text(
                    _group.tresorierId == member.id
                        ? 'Retirer Trésorier'
                        : 'Nommer Trésorier',
                  ),
                ],
              ),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(
            Icons.remove_circle_outline_rounded,
            color: Colors.red,
          ),
          onPressed: () async {
            final confirm = await DialogUtils.showConfirmDialog(
              context: context,
              title: 'Retirer du groupe',
              message: 'Voulez-vous retirer ${member.nom} de ce groupe ?',
              isDangerous: true,
            );
            if (confirm) {
              await DatabaseService().removeClientFromGroup(member.id!);
              if (member.id == _group.responsableId ||
                  member.id == _group.tresorierId) {
                final updatedGroup = GroupeSolidaire(
                  id: _group.id,
                  code: _group.code,
                  nom: _group.nom,
                  dateCreation: _group.dateCreation,
                  statut: _group.statut,
                  description: _group.description,
                  responsableId: member.id == _group.responsableId
                      ? null
                      : _group.responsableId,
                  tresorierId: member.id == _group.tresorierId
                      ? null
                      : _group.tresorierId,
                );
                await DatabaseService().updateGroupe(updatedGroup);
                setState(() => _group = updatedGroup);
              }
              _refreshMembers();
            }
          },
        ),
      ],
    );
  }

  Future<void> _toggleRole(int memberId, bool isResponsable) async {
    final updatedGroup = GroupeSolidaire(
      id: _group.id,
      code: _group.code,
      nom: _group.nom,
      dateCreation: _group.dateCreation,
      statut: _group.statut,
      description: _group.description,
      responsableId: isResponsable
          ? (_group.responsableId == memberId ? null : memberId)
          : _group.responsableId,
      tresorierId: !isResponsable
          ? (_group.tresorierId == memberId ? null : memberId)
          : _group.tresorierId,
    );
    await DatabaseService().updateGroupe(updatedGroup);
    setState(() => _group = updatedGroup);
  }

  Widget _buildNoMembersState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 64,
            color: Colors.grey.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucun membre dans ce groupe',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildLoansTab() {
    return _buildTabContainer([
      _buildSectionHeader(
        'État des Prêts du Groupe',
        Icons.account_balance_wallet_rounded,
      ),
      _buildInfoGrid([
        _buildInfoItem('Prêts actifs', '0 dossiers'),
        _buildInfoItem('Encours total', '0 FCFA'),
        _buildInfoItem('Taux de remboursement', '100%'),
        _buildInfoItem('Capital restant dû', '0 FCFA'),
      ]),
      const SizedBox(height: 32),
      _buildSectionHeader('Répartition par membre', Icons.pie_chart_rounded),
      const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'Aucun prêt collectif enregistré',
            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
          ),
        ),
      ),
    ]);
  }

  Widget _buildGuaranteeTab() {
    return _buildTabContainer([
      _buildSectionHeader(
        'Mécanisme de Caution Solidaire',
        Icons.security_rounded,
      ),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.withOpacity(0.2)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Colors.blue),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'L\'engagement solidaire lie tous les membres du groupe. En cas de défaut d\'un membre, les autres sont tenus de couvrir la dette.',
                style: TextStyle(fontSize: 13, color: Colors.blueGrey),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 32),
      _buildSectionHeader(
        'Détails de l\'Engagement',
        Icons.assignment_turned_in_rounded,
      ),
      _buildInfoRow(
        'Contrat solidaire',
        'Signé le ${DateFormat('dd/MM/yyyy').format(_group.dateCreation)}',
      ),
      _buildInfoRow(
        'Cas d\'activation caution',
        'Défaut de paiement > 15 jours',
      ),
      _buildInfoRow('Historique interventions', '0 intervention'),
      _buildInfoRow('Montant garanti', '100% du capital restant'),
      const SizedBox(height: 32),
      _buildSectionHeader('Interventions récentes', Icons.history_rounded),
      const Center(
        child: Text(
          'Aucune intervention de caution enregistrée',
          style: TextStyle(color: Colors.grey),
        ),
      ),
    ]);
  }

  Widget _buildCollectiveSavingsTab() {
    return _buildTabContainer([
      _buildSectionHeader(
        'Épargne Collective du Groupe',
        Icons.savings_rounded,
      ),
      _buildInfoGrid([
        _buildInfoItem('Compte épargne groupe', 'GS-SAV-001'),
        _buildInfoItem('Solde disponible', '0 FCFA'),
        _buildInfoItem('Cotisations régulières', 'Hebdomadaire'),
        _buildInfoItem('Objectifs d\'épargne', '500,000 FCFA'),
      ]),
      const SizedBox(height: 32),
      _buildSectionHeader('Répartition par membre', Icons.donut_large_rounded),
      const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'Aucune épargne collective enregistrée',
            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
          ),
        ),
      ),
    ]);
  }

  Widget _buildPerformanceTab() {
    return _buildTabContainer([
      _buildSectionHeader('Performance & Indicateurs', Icons.analytics_rounded),
      _buildInfoGrid([
        _buildInfoItem('Taux remboursement global', '100%'),
        _buildInfoItem('Ancienneté du groupe', '3 mois'),
        _buildInfoItem('Stabilité membres', 'Excellente'),
        _buildInfoItem('Niveau de risque', 'Faible'),
      ]),
      const SizedBox(height: 32),
      _buildSectionHeader('Évolution du Groupe', Icons.show_chart_rounded),
      Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: const Center(
          child: Text(
            'Graphique de performance (En développement)',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
      ),
    ]);
  }

  Widget _buildDocumentsTab() {
    return _buildTabContainer([
      _buildSectionHeader('Documents & Réunions', Icons.folder_shared_rounded),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: AppColors.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Les réunions régulières doivent être documentées ici pour justifier du suivi et de la cohésion du groupe.',
                style: TextStyle(fontSize: 13, color: Colors.blueGrey),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 32),
      _buildSectionHeader(
        'Procès-verbaux de réunions',
        Icons.history_edu_rounded,
      ),
      _buildDocumentItem(
        'PV de réunion - 01/01/2026',
        'Validation premier prêt',
        '0.5 MB',
      ),
      _buildDocumentItem(
        'PV de constitution',
        'Signature acte solidaire',
        '1.2 MB',
      ),
      const SizedBox(height: 32),
      _buildSectionHeader('Contrats & Actes', Icons.assignment_rounded),
      _buildDocumentItem(
        'Engagement solidaire signé',
        'Tous membres',
        '2.4 MB',
      ),
      _buildDocumentItem(
        'Règlement intérieur du groupe',
        'Validé par l\'agence',
        '0.8 MB',
      ),
      const SizedBox(height: 32),
      Center(
        child: ElevatedButton.icon(
          onPressed: () {}, // Action future: upload
          icon: const Icon(Icons.upload_file_rounded),
          label: const Text('Ajouter un document / PV'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ),
    ]);
  }

  Widget _buildDocumentItem(String title, String subtitle, String size) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.picture_as_pdf_rounded,
          color: Colors.red,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Text('$subtitle • $size', style: const TextStyle(fontSize: 12)),
      trailing: IconButton(
        icon: const Icon(Icons.download_rounded, size: 20),
        onPressed: () {},
      ),
    );
  }

  Widget _buildTabContainer(List<Widget> children) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoGrid(List<Widget> items) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 4,
      children: items,
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
