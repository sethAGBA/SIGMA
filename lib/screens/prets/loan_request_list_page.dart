// lib/screens/prets/loan_request_list_page.dart

import 'package:flutter/material.dart';
import '../../core/services/database_service.dart';
import '../../models/loan_request_model.dart';
import '../../core/theme/app_colors.dart';
import 'loan_request_form_dialog.dart';
import 'loan_request_detail_dialog.dart';

class LoanRequestListPage extends StatefulWidget {
  const LoanRequestListPage({super.key});

  @override
  State<LoanRequestListPage> createState() => _LoanRequestListPageState();
}

class _LoanRequestListPageState extends State<LoanRequestListPage> {
  late Future<List<LoanRequest>> _requestsFuture;
  String? _selectedStatus;
  String? _selectedAgent;
  String? _selectedAgency;

  @override
  void initState() {
    super.initState();
    _refreshRequests();
  }

  void _refreshRequests() {
    setState(() {
      _requestsFuture = DatabaseService().getLoanRequests(
        status: _selectedStatus,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildQuickStats(),
            const SizedBox(height: 24),
            _buildFiltersCard(),
            const SizedBox(height: 24),
            Expanded(child: _buildRequestsTable(theme)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewRequestDialog(),
        label: const Text('Nouveau Dossier'),
        icon: const Icon(Icons.add_task_rounded),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gestion des Demandes de Prêt',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            Text(
              'Workflow d\'approbation et montage des dossiers de crédit',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
        Row(
          children: [
            _buildHeaderActionButton(Icons.file_download_outlined, 'Exporter'),
            const SizedBox(width: 12),
            _buildHeaderActionButton(Icons.print_outlined, 'Imprimer'),
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderActionButton(IconData icon, String label) {
    return OutlinedButton.icon(
      onPressed: () {},
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildQuickStats() {
    return FutureBuilder<List<LoanRequest>>(
      future: _requestsFuture,
      builder: (context, snapshot) {
        final requests = snapshot.data ?? [];
        final soumises = requests
            .where((r) => r.statut == LoanRequestStatus.soumise)
            .length;
        final analyse = requests
            .where((r) => r.statut == LoanRequestStatus.enAnalyse)
            .length;
        final comite = requests
            .where((r) => r.statut == LoanRequestStatus.enComite)
            .length;
        final approuvees = requests
            .where((r) => r.statut == LoanRequestStatus.approuvee)
            .length;

        return Row(
          children: [
            _buildStatCard('Soumises', soumises.toString(), Colors.blue),
            const SizedBox(width: 16),
            _buildStatCard('En Analyse', analyse.toString(), Colors.orange),
            const SizedBox(width: 16),
            _buildStatCard('En Comité', comite.toString(), Colors.purple),
            const SizedBox(width: 16),
            _buildStatCard('Approuvées', approuvees.toString(), Colors.green),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filtres Avancés',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildFilterDropdown(
                    _selectedStatus,
                    'Statut workflow',
                    LoanRequestStatus.values
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.name,
                            child: Text(s.label),
                          ),
                        )
                        .toList(),
                    (v) => setState(() {
                      _selectedStatus = v;
                      _refreshRequests();
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildFilterDropdown(
                    _selectedAgency,
                    'Agence',
                    [
                      const DropdownMenuItem(
                        value: 'A1',
                        child: Text('Agence Centrale'),
                      ),
                      const DropdownMenuItem(
                        value: 'A2',
                        child: Text('Agence Nord'),
                      ),
                    ],
                    (v) => setState(() => _selectedAgency = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildFilterDropdown(
                    _selectedAgent,
                    'Agent de crédit',
                    [
                      const DropdownMenuItem(
                        value: 'G1',
                        child: Text('Jean KOUASSI'),
                      ),
                      const DropdownMenuItem(
                        value: 'G2',
                        child: Text('Marie DIALLO'),
                      ),
                    ],
                    (v) => setState(() => _selectedAgent = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Montant mini',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _selectedStatus = null;
                      _selectedAgency = null;
                      _selectedAgent = null;
                      _refreshRequests();
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Réinitialiser',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdown<T>(
    T? value,
    String label,
    List<DropdownMenuItem<T>> items,
    ValueChanged<T?> onChanged,
  ) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        DropdownMenuItem<T>(value: null, child: Text('Tous ($label)')),
        ...items,
      ],
      onChanged: onChanged,
    );
  }

  Widget _buildRequestsTable(ThemeData theme) {
    return FutureBuilder<List<LoanRequest>>(
      future: _requestsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        final requests = snapshot.data ?? [];
        if (requests.isEmpty) {
          return _buildEmptyState();
        }

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey[100]!),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: DataTable(
                headingRowHeight: 56,
                dataRowHeight: 64,
                headingRowColor: MaterialStateProperty.all(
                  theme.primaryColor.withOpacity(0.04),
                ),
                columns: const [
                  DataColumn(label: Text('CLIENT')),
                  DataColumn(label: Text('PRODUIT')),
                  DataColumn(label: Text('MONTANT')),
                  DataColumn(label: Text('AGENCE / AGENT')),
                  DataColumn(label: Text('SCORE')),
                  DataColumn(label: Text('STATUT')),
                  DataColumn(label: Text('ACTIONS')),
                ],
                rows: requests.map((r) => _buildDataRow(r)).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  DataRow _buildDataRow(LoanRequest request) {
    return DataRow(
      cells: [
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                request.client?.nomComplet ?? 'Inconnu',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                request.client?.numeroClient ?? '-',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
        DataCell(Text(request.produit?.nom ?? '-')),
        DataCell(
          Text(
            '${_formatAmount(request.montantDemande)} FCFA',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                request.client?.agence ?? 'Agence non spécifiée',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                request.client?.agentAffecte ?? 'Agent non affecté',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
        DataCell(_buildScoreBadge(request.client?.scoreCredit ?? 0)),
        DataCell(_buildStatusBadge(request.statut)),
        DataCell(
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.description_outlined,
                  size: 20,
                  color: Colors.blue,
                ),
                onPressed: () => _showDetailDialog(request),
                tooltip: 'Dossier complet',
              ),
              IconButton(
                icon: const Icon(Icons.history, size: 20, color: Colors.grey),
                onPressed: () => _showDetailDialog(request),
                tooltip: 'Circuit de décision',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScoreBadge(int score) {
    Color color = score > 70
        ? Colors.green
        : (score > 40 ? Colors.orange : Colors.red);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$score pts',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(LoanRequestStatus status) {
    Color color;
    switch (status) {
      case LoanRequestStatus.brouillon:
        color = Colors.grey;
        break;
      case LoanRequestStatus.soumise:
        color = Colors.blue;
        break;
      case LoanRequestStatus.enAnalyse:
        color = Colors.orange;
        break;
      case LoanRequestStatus.enComite:
        color = Colors.purple;
        break;
      case LoanRequestStatus.approuvee:
        color = Colors.green;
        break;
      case LoanRequestStatus.rejetee:
        color = Colors.red;
        break;
      case LoanRequestStatus.debloquee:
        color = AppColors.primary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 80, color: Colors.grey[200]),
          const SizedBox(height: 16),
          const Text(
            'Aucune demande en cours',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    return amount
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]} ',
        );
  }

  Future<void> _showNewRequestDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const LoanRequestFormDialog(),
    );
    if (result == true) _refreshRequests();
  }

  Future<void> _showDetailDialog(LoanRequest request) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => LoanRequestDetailDialog(request: request),
    );
    if (result == true) _refreshRequests();
  }
}
