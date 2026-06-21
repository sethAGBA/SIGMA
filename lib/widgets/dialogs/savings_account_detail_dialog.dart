// lib/widgets/dialogs/savings_account_detail_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import '../../models/savings_account_model.dart';
import '../../models/savings_transaction_model.dart';
import '../../screens/epargne/savings_operation_dialog.dart';
import '../../core/services/savings_statement_service.dart';

class SavingsAccountDetailDialog extends StatefulWidget {
  final SavingsAccount account;

  const SavingsAccountDetailDialog({super.key, required this.account});

  @override
  State<SavingsAccountDetailDialog> createState() =>
      _SavingsAccountDetailDialogState();
}

class _SavingsAccountDetailDialogState extends State<SavingsAccountDetailDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<SavingsTransaction>> _transactionsFuture;
  late SavingsAccount _account;

  final currencyFormat = NumberFormat.currency(
    symbol: 'FCFA',
    decimalDigits: 0,
    locale: 'fr_FR',
  );
  final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _account = widget.account;
    _tabController = TabController(length: 4, vsync: this);
    _loadTransactions();
  }

  void _loadTransactions() {
    setState(() {
      _transactionsFuture = DatabaseService().getSavingsTransactions(
        _account.id!,
      );
    });
  }

  Future<void> _refreshAccount() async {
    final updatedAccount = await DatabaseService().getSavingsAccountById(
      _account.id!,
    );
    if (updatedAccount != null) {
      setState(() {
        _account = updatedAccount;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 1000,
        height: 800,
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    _buildAccountHeader(isDark),
                    const SizedBox(height: 24),
                    _buildTabBar(isDark),
                    const SizedBox(height: 24),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildInfoTab(isDark),
                          _buildTransactionsTab(isDark),
                          _buildInterestsTab(isDark),
                          const Center(
                            child: Text('Documents (Bientôt disponible)'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey[50],
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkDivider : Colors.grey[200]!,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.savings_rounded, color: AppColors.primary),
          const SizedBox(width: 16),
          const Text(
            'DOSSIER ÉPARGNE',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => _openOperation(SavingsTransactionType.depot),
            icon: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
            label: const Text(
              'DÉPÔT',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () => _openOperation(SavingsTransactionType.retrait),
            icon: const Icon(
              Icons.remove_rounded,
              size: 20,
              color: Colors.white,
            ),
            label: const Text(
              'RETRAIT',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () => _generateStatement(),
            icon: const Icon(
              Icons.picture_as_pdf_rounded,
              size: 20,
              color: Colors.white,
            ),
            label: const Text(
              'RELEVÉ',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
  }

  void _generateStatement() async {
    final now = DateTime.now();
    int selectedMonth = now.month;
    int selectedYear = now.year;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _MonthPickerDialog(
        initialMonth: selectedMonth,
        initialYear: selectedYear,
        onConfirm: (m, y) {
          selectedMonth = m;
          selectedYear = y;
        },
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final service = SavingsStatementService();
      await service.printStatement(_account.id!, selectedMonth, selectedYear);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur génération relevé : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openOperation(SavingsTransactionType type) async {    final result = await showDialog<bool>(
      context: context,
      builder: (context) =>
          SavingsOperationDialog(account: _account, initialType: type),
    );
    if (result == true) {
      await _refreshAccount();
      _loadTransactions();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Opération réussie')));
      }
    }
  }

  Widget _buildAccountHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_account.client?.nom} ${_account.client?.prenoms}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Compte ${_account.numeroCompte} • ${_account.produit?.nom}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'SOLDE DISPONIBLE',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                currencyFormat.format(_account.solde),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : Colors.grey[200]!,
        ),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: Colors.grey,
        indicatorColor: AppColors.primary,
        indicatorPadding: const EdgeInsets.symmetric(horizontal: 16),
        tabs: const [
          Tab(text: 'Informations'),
          Tab(text: 'Transactions'),
          Tab(text: 'Intérêts'),
          Tab(text: 'Documents'),
        ],
      ),
    );
  }

  Widget _buildInfoTab(bool isDark) {
    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: _infoSection('Détails du Compte', [
              _infoRow(
                'Date d\'ouverture',
                dateFormat.format(_account.dateOuverture),
              ),
              _infoRow('Numéro de compte', _account.numeroCompte),
              _infoRow(
                'Catégorie',
                _account.produit?.savingsCategory?.label ?? 'N/A',
              ),
              _infoRow('Statut', _account.statut.label),
              _infoRow(
                'Taux d\'intérêt annuel',
                '${_account.tauxInteretApplique ?? 0}%',
              ),
            ], isDark),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 1,
            child: _infoSection('Conditions', [
              _infoRow(
                'Solde minimum',
                currencyFormat.format(_account.produit?.soldeMinimum ?? 0),
              ),
              _infoRow(
                'Dépôt minimum',
                currencyFormat.format(_account.produit?.versementMinimum ?? 0),
              ),
            ], isDark),
          ),
        ],
      ),
    );
  }

  Widget _infoSection(String title, List<Widget> rows, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 16),
          ...rows,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsTab(bool isDark) {
    return FutureBuilder<List<SavingsTransaction>>(
      future: _transactionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        final transactions = snapshot.data ?? [];
        if (transactions.isEmpty)
          return const Center(
            child: Text(
              'Aucune transaction enregistrée',
              style: TextStyle(color: Colors.grey),
            ),
          );

        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkDivider : Colors.grey[200]!,
            ),
          ),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: transactions.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: isDark ? AppColors.darkDivider : Colors.grey[100],
            ),
            itemBuilder: (context, index) {
              final tx = transactions[index];
              final isDepot =
                  tx.type == SavingsTransactionType.depot ||
                  tx.type == SavingsTransactionType.interet;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isDepot ? Colors.green : Colors.orange).withOpacity(
                      0.1,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isDepot
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                    color: isDepot ? Colors.green : Colors.orange,
                    size: 20,
                  ),
                ),
                title: Text(
                  tx.type.label,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  dateFormat.format(tx.dateOperation),
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isDepot ? '+' : '-'} ${currencyFormat.format(tx.montant)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDepot ? Colors.green : Colors.orange,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Solde: ${currencyFormat.format(tx.soldeApres)}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildInterestsTab(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.auto_graph_rounded,
            size: 64,
            color: AppColors.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Intérêts cumulés: ${currencyFormat.format(_account.interetsAcquis)}',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const Text(
            'La capitalisation survient à la fin de chaque période.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// ── Dialog sélection mois/année ───────────────────────────────────────────

class _MonthPickerDialog extends StatefulWidget {
  final int initialMonth;
  final int initialYear;
  final void Function(int month, int year) onConfirm;

  const _MonthPickerDialog({
    required this.initialMonth,
    required this.initialYear,
    required this.onConfirm,
  });

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _month;
  late int _year;

  static const _months = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
  ];

  @override
  void initState() {
    super.initState();
    _month = widget.initialMonth;
    _year = widget.initialYear;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choisir la période'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<int>(
            value: _month,
            decoration: const InputDecoration(
              labelText: 'Mois',
              border: OutlineInputBorder(),
            ),
            items: List.generate(
              12,
              (i) => DropdownMenuItem(
                value: i + 1,
                child: Text(_months[i]),
              ),
            ),
            onChanged: (v) => setState(() => _month = v!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            value: _year,
            decoration: const InputDecoration(
              labelText: 'Année',
              border: OutlineInputBorder(),
            ),
            items: List.generate(
              10,
              (i) => DropdownMenuItem(
                value: DateTime.now().year - i,
                child: Text('${DateTime.now().year - i}'),
              ),
            ),
            onChanged: (v) => setState(() => _year = v!),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            widget.onConfirm(_month, _year);
            Navigator.pop(context, true);
          },
          child: const Text('Générer'),
        ),
      ],
    );
  }
}
