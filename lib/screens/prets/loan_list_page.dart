// lib/screens/prets/loan_list_page.dart

import 'package:flutter/material.dart';
import '../../core/services/agency_api_service.dart';
import '../../core/services/loan_api_service.dart';
import '../../models/loan_model.dart';
import '../../models/agent_model.dart';
import '../../models/agency_model.dart';
import '../remboursements/repayment_form_dialog.dart';
import '../../core/theme/app_colors.dart';
import 'loan_detail_dialog.dart';

class LoanListPage extends StatefulWidget {
  const LoanListPage({super.key});

  @override
  State<LoanListPage> createState() => _LoanListPageState();
}

class _LoanListPageState extends State<LoanListPage> {
  late Future<List<Loan>> _loansFuture;
  String _searchQuery = '';
  String? _selectedStatus;
  String? _selectedAgence;
  String? _selectedAgent;
  String? _selectedRisque;
  List<Agent> _agents = [];
  List<Agency> _agencies = [];

  @override
  void initState() {
    super.initState();
    _loadFilterOptions();
    _refreshLoans();
  }

  Future<void> _loadFilterOptions() async {
    final agents = await AgencyApiService().getAgents();
    final agencies = await AgencyApiService().getAgencies();
    if (mounted) {
      setState(() {
        _agents = agents.where((a) => a.isActive).toList();
        _agencies = agencies.where((a) => a.isActive).toList();
        final agentNames =
            _agents.map((a) => '${a.firstName} ${a.lastName}').toSet();
        final agencyNames = _agencies.map((a) => a.name).toSet();
        if (_selectedAgent != null && !agentNames.contains(_selectedAgent)) {
          _selectedAgent = null;
        }
        if (_selectedAgence != null && !agencyNames.contains(_selectedAgence)) {
          _selectedAgence = null;
        }
      });
    }
  }

  void _refreshLoans() {
    setState(() {
      _loansFuture = LoanApiService().getLoans();
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

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
            _buildFilters(),
            const SizedBox(height: 16),
            Expanded(child: _buildLoanList(isDark)),
          ],
        ),
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
              'Gestion des Prêts (Encours)',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            Text(
              'Suivi du portefeuille et des remboursements actifs',
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
            _buildHeaderActionButton(
              Icons.file_download_outlined,
              'Export PAR',
            ),
            const SizedBox(width: 12),
            _buildHeaderActionButton(Icons.history, 'Historique Collecte'),
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
    return FutureBuilder<List<Loan>>(
      future: _loansFuture,
      builder: (context, snapshot) {
        final loans = snapshot.data ?? [];
        double totalEncours = loans.fold(0, (sum, l) => sum + l.soldeRestant);
        int retardCount = loans.where((l) => l.joursRetard > 0).length;
        double par30 = loans.isNotEmpty
            ? (loans
                          .where((l) => l.joursRetard > 30)
                          .fold(0.0, (sum, l) => sum + l.soldeRestant) /
                      totalEncours) *
                  100
            : 0;

        return Row(
          children: [
            _buildStatCard(
              'Encours Total',
              '${_formatAmount(totalEncours)} FCFA',
              AppColors.primary,
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              'Prêts Actifs',
              loans.length.toString(),
              Colors.blue,
            ),
            const SizedBox(width: 16),
            _buildStatCard('En Retard', retardCount.toString(), Colors.orange),
            const SizedBox(width: 16),
            _buildStatCard(
              'PAR > 30j',
              '${par30.toStringAsFixed(1)}%',
              Colors.red,
            ),
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
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Rechercher un prêt (N°, Client)...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Statut du prêt',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: ['Tous', 'À jour', 'Alerte', 'Retard', 'Contentieux']
                        .map(
                          (s) => DropdownMenuItem(
                            value: s == 'Tous' ? null : s,
                            child: Text(s),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedStatus = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: _selectedAgence,
                    decoration: InputDecoration(
                      labelText: 'Agence',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Toutes'),
                      ),
                      ..._agencies.map(
                        (a) => DropdownMenuItem<String?>(
                          value: a.name,
                          child: Text(a.name),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _selectedAgence = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: _selectedAgent,
                    decoration: InputDecoration(
                      labelText: 'Agent Gestionnaire',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Tous agents'),
                      ),
                      ..._agents.map(
                        (a) => DropdownMenuItem<String?>(
                          value: '${a.firstName} ${a.lastName}',
                          child: Text('${a.firstName} ${a.lastName}'),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _selectedAgent = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Risque (Scoring)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: ['Tous niveaux', 'Faible', 'Moyen', 'Élevé']
                        .map(
                          (s) => DropdownMenuItem(
                            value: s == 'Tous niveaux' ? null : s,
                            child: Text(s),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedRisque = v),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoanList(bool isDark) {
    return FutureBuilder<List<Loan>>(
      future: _loansFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final loans = snapshot.data ?? [];
        final filteredLoans = loans.where((l) {
          final matchesQuery =
              l.numeroPret.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (l.client?.nomComplet.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ) ??
                  false);
          final matchesStatus =
              _selectedStatus == null || l.statut.label == _selectedStatus;
          final matchesAgence =
              _selectedAgence == null || l.agenceGestion == _selectedAgence;
          final matchesAgent =
              _selectedAgent == null || l.agentGestionnaire == _selectedAgent;
          final matchesRisque =
              _selectedRisque == null ||
              (l.client?.niveauRisque ?? 'Faible') == _selectedRisque;
          return matchesQuery &&
              matchesStatus &&
              matchesAgence &&
              matchesAgent &&
              matchesRisque;
        }).toList();

        if (filteredLoans.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 64,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Aucun prêt actif trouvé',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return Card(
          child: Column(
            children: [
              _buildTableHeader(isDark),
              Expanded(
                child: ListView.separated(
                  itemCount: filteredLoans.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      _buildLoanRow(filteredLoans[index], isDark),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTableHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey[50],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          _headerCell('N° Prêt', flex: 2),
          _headerCell('Client', flex: 3),
          _headerCell('Produit', flex: 2),
          _headerCell('Montant', flex: 2),
          _headerCell('Solde', flex: 2),
          _headerCell('Retard', flex: 1),
          _headerCell('Statut', flex: 2),
          const SizedBox(width: 100), // Actions
        ],
      ),
    );
  }

  Widget _headerCell(String label, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildLoanRow(Loan loan, bool isDark) {
    return InkWell(
      onTap: () => _showDetailDialog(loan),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                loan.numeroPret,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loan.client?.nomComplet ?? 'Client inconnu',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    loan.client?.numeroClient ?? '-',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Expanded(flex: 2, child: Text(loan.produit?.nom ?? '-')),
            Expanded(
              flex: 2,
              child: Text('${_formatAmount(loan.montantInitial)}'),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '${_formatAmount(loan.soldeRestant)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                '${loan.joursRetard} j',
                style: TextStyle(
                  color: loan.joursRetard > 0 ? Colors.red : Colors.green,
                ),
              ),
            ),
            Expanded(flex: 2, child: _buildStatusBadge(loan.statut)),
            SizedBox(
              width: 100,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.payment,
                      size: 20,
                      color: Colors.blue,
                    ),
                    tooltip: 'Encaisser un paiement',
                    onPressed: () async {
                      final result = await showDialog<bool>(
                        context: context,
                        builder: (context) => RepaymentFormDialog(loan: loan),
                      );
                      if (result == true) _refreshLoans();
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.visibility_outlined,
                      size: 20,
                      color: Colors.grey,
                    ),
                    tooltip: 'Détails',
                    onPressed: () => _showDetailDialog(loan),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(LoanStatus status) {
    Color color;
    switch (status) {
      case LoanStatus.aJour:
        color = Colors.green;
        break;
      case LoanStatus.alerte:
        color = Colors.orange;
        break;
      case LoanStatus.retard:
        color = Colors.deepOrange;
        break;
      case LoanStatus.contentieux:
        color = Colors.red;
        break;
      case LoanStatus.perte:
        color = Colors.black;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailDialog(Loan loan) {
    showDialog(
      context: context,
      builder: (context) => LoanDetailDialog(loanId: loan.id!),
    ).then((_) => _refreshLoans());
  }

  String _formatAmount(double amount) {
    return amount
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]} ',
        );
  }
}
