// lib/screens/prets/loan_detail_dialog.dart

import 'package:flutter/material.dart';
import '../../core/services/database_service.dart';
import '../../models/loan_model.dart';
import '../../models/repayment_schedule_model.dart';
import '../../core/theme/app_colors.dart';
import '../remboursements/repayment_form_dialog.dart';
import '../../models/repayment_model.dart';

class LoanDetailDialog extends StatefulWidget {
  final int loanId;

  const LoanDetailDialog({super.key, required this.loanId});

  @override
  State<LoanDetailDialog> createState() => _LoanDetailDialogState();
}

class _LoanDetailDialogState extends State<LoanDetailDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Loan? _loan;
  List<RepaymentSchedule> _schedule = [];
  List<Repayment> _repayments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final loan = await DatabaseService().getLoanById(widget.loanId);
    final schedule = await DatabaseService().getRepaymentSchedules(
      widget.loanId,
    );
    final repayments = await DatabaseService().getRepayments(widget.loanId);
    if (mounted) {
      setState(() {
        _loan = loan;
        _schedule = schedule;
        _repayments = repayments;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loan == null) {
      return const AlertDialog(
        title: Text('Erreur'),
        content: Text('Prêt introuvable'),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 1000,
        height: 800,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildTabBar(),
            const Divider(),
            Expanded(child: _buildTabContent()),
            const Divider(),
            _buildActionFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(
              Icons.account_balance_outlined,
              color: AppColors.primary,
              size: 28,
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prêt ${_loan!.numeroPret} - ${_loan!.client?.nomComplet ?? "Client"}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Débloqué le ${_formatDate(_loan!.dateDeblocage)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ],
        ),
        _buildStatusBadge(_loan!.statut),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      labelColor: AppColors.primary,
      unselectedLabelColor: Colors.grey,
      indicatorColor: AppColors.primary,
      tabs: const [
        Tab(text: 'Informations générales', icon: Icon(Icons.info_outline)),
        Tab(text: 'Échéancier', icon: Icon(Icons.calendar_month_outlined)),
        Tab(text: 'Remboursements', icon: Icon(Icons.history)),
        Tab(text: 'Suivi & Terrain', icon: Icon(Icons.map_outlined)),
      ],
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildGeneralInfo(),
        _buildScheduleTable(),
        _buildRepaymentHistory(),
        _buildFollowupTab(),
      ],
    );
  }

  Widget _buildGeneralInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Situation Financière'),
          Row(
            children: [
              Expanded(
                child: _buildMetricBox(
                  'Montant Initial',
                  _loan!.montantInitial,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricBox(
                  'Solde Restant',
                  _loan!.soldeRestant,
                  AppColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricBox(
                  'Retard Jours',
                  _loan!.joursRetard.toDouble(),
                  Colors.red,
                  isAmount: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _buildInfoRow('Produit de crédit', _loan!.produit?.nom ?? '-'),
          _buildInfoRow('Taux appliqué', '${_loan!.produit?.tauxInteret}%'),
          _buildInfoRow(
            'Pénalités calculées',
            '${_formatAmount(_loan!.calculatePenalties())} F',
            isWarning: _loan!.joursRetard > 0,
          ),
          _buildInfoRow('Date de déblocage', _formatDate(_loan!.dateDeblocage)),
          _buildInfoRow(
            'Échéance finale',
            _loan!.dateEcheanceProchaine != null
                ? _formatDate(_loan!.dateEcheanceProchaine!)
                : '-',
          ),
          _buildInfoRow('Agent gestionnaire', _loan!.agentGestionnaire ?? '-'),
          _buildInfoRow(
            'Agence de gestion',
            _loan!.agenceGestion ?? 'Agence Centrale',
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleTable() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: const [
                Expanded(
                  flex: 1,
                  child: Text(
                    'N°',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Date prévue',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Capital',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Intérêts',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Total dû',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Statut',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _schedule.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final row = _schedule[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 1, child: Text('${row.numeroEcheance}')),
                      Expanded(
                        flex: 2,
                        child: Text(_formatDate(row.datePrevue)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(_formatAmount(row.capitalDu)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(_formatAmount(row.interetsDus)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          _formatAmount(row.totalDu),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: _buildRepaymentStatusBadge(row.statut),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRepaymentHistory() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    if (_repayments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text(
              'Aucun remboursement enregistré pour le moment',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: const [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Date',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Montant',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'N° Reçu',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Mode',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Agent',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _repayments.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final r = _repayments[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(_formatDate(r.datePaiement)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          _formatAmount(r.montantTotal),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                      Expanded(flex: 2, child: Text(r.numeroRecu)),
                      Expanded(flex: 2, child: Text(r.modePaiement.label)),
                      Expanded(
                        flex: 2,
                        child: Text(r.agentCollecteur ?? 'Système'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowupTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Historique des Visites Terrain'),
          _buildFollowupItem(
            DateTime.now().subtract(const Duration(days: 5)),
            'Visite de Relance',
            'Client rencontré. Promesse de paiement pour le 15 du mois.',
            Icons.directions_walk,
          ),
          _buildFollowupItem(
            DateTime.now().subtract(const Duration(days: 15)),
            'Appel Téléphonique',
            'Difficultés passagères dues à une mévente. À suivre.',
            Icons.phone_outlined,
          ),
          const SizedBox(height: 32),
          _buildSectionTitle('Actions Automatisées'),
          _buildFollowupItem(
            DateTime.now().subtract(const Duration(days: 1)),
            'SMS de Rappel',
            'Envoi automatique SMS échéance J-1.',
            Icons.sms_outlined,
            color: Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildFollowupItem(
    DateTime date,
    String title,
    String description,
    IconData icon, {
    Color? color,
  }) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (color ?? AppColors.primary).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color ?? AppColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _formatDate(date),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildMetricBox(
    String label,
    double value,
    Color color, {
    bool isAmount = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            isAmount ? '${_formatAmount(value)} F' : value.toInt().toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isWarning = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isWarning ? Colors.red : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(LoanStatus status) {
    // Reutiliser la logique de LoanListPage pour plus de cohérence
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRepaymentStatusBadge(RepaymentStatus status) {
    Color color;
    switch (status) {
      case RepaymentStatus.paye:
        color = Colors.green;
        break;
      case RepaymentStatus.impaye:
        color = Colors.red;
        break;
      case RepaymentStatus.partiel:
        color = Colors.orange;
        break;
      case RepaymentStatus.enAttente:
        color = Colors.grey;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
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

  Widget _buildActionFooter() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _buildQuickAction(
            Icons.print_outlined,
            'Imprimer Échéancier',
            Colors.grey,
            () {},
          ),
          const SizedBox(width: 12),
          _buildQuickAction(
            Icons.sms_outlined,
            'Envoyer Rappel',
            Colors.blue,
            () {},
          ),
          const SizedBox(width: 12),
          _buildQuickAction(
            Icons.event_note_outlined,
            'Planifier Visite',
            Colors.orange,
            () {},
          ),
          const SizedBox(width: 12),
          _buildQuickAction(
            Icons.sync_problem_outlined,
            'Restructurer',
            Colors.deepOrange,
            () {},
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await showDialog<bool>(
                context: context,
                builder: (context) => RepaymentFormDialog(loan: _loan!),
              );
              if (result == true) _loadData();
            },
            icon: const Icon(Icons.add_card),
            label: const Text('ENREGISTRER PAIEMENT'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
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

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
