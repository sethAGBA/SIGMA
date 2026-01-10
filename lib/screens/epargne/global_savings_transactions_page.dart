// lib/screens/epargne/global_savings_transactions_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import '../../models/savings_transaction_model.dart';

class GlobalSavingsTransactionsPage extends StatefulWidget {
  const GlobalSavingsTransactionsPage({super.key});

  @override
  State<GlobalSavingsTransactionsPage> createState() =>
      _GlobalSavingsTransactionsPageState();
}

class _GlobalSavingsTransactionsPageState
    extends State<GlobalSavingsTransactionsPage> {
  late Future<List<Map<String, dynamic>>> _transactionsFuture;
  final currencyFormat = NumberFormat.currency(
    symbol: 'FCFA',
    decimalDigits: 0,
    locale: 'fr_FR',
  );
  final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _transactionsFuture = _loadGlobalTransactions();
    });
  }

  Future<List<Map<String, dynamic>>> _loadGlobalTransactions() async {
    final db = await DatabaseService().database;
    return await db.rawQuery('''
      SELECT te.*, ce.numero_compte, c.nom, c.prenoms
      FROM transactions_epargne te
      JOIN comptes_epargne ce ON te.compte_id = ce.id
      JOIN clients c ON ce.client_id = c.id
      ORDER BY te.date_operation DESC
    ''');
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
            Expanded(child: _buildTransactionList(isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Journal des Transactions',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              'Historique complet de tous les dépôts et retraits',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        IconButton(
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded),
          color: AppColors.primary,
        ),
      ],
    );
  }

  Widget _buildTransactionList(bool isDark) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _transactionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final transactions = snapshot.data ?? [];
        if (transactions.isEmpty) {
          return const Center(
            child: Text(
              'Aucune transaction enregistrée',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkDivider : Colors.grey[200]!,
            ),
          ),
          child: Column(
            children: [
              _buildListHeader(isDark),
              Expanded(
                child: ListView.separated(
                  itemCount: transactions.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: isDark ? AppColors.darkDivider : Colors.grey[100],
                  ),
                  itemBuilder: (context, index) =>
                      _buildTransactionRow(transactions[index], isDark),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildListHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey[50],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: _headerCell('Date')),
          Expanded(flex: 3, child: _headerCell('Client & Compte')),
          Expanded(flex: 2, child: _headerCell('Opération')),
          Expanded(
            flex: 2,
            child: _headerCell('Montant', align: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _headerCell(String label, {TextAlign align = TextAlign.left}) {
    return Text(
      label.toUpperCase(),
      textAlign: align,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: Colors.grey,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildTransactionRow(Map<String, dynamic> tx, bool isDark) {
    final type = SavingsTransactionType.values.firstWhere(
      (e) => e.name == tx['type_operation'],
    );
    final isDepot =
        type == SavingsTransactionType.depot ||
        type == SavingsTransactionType.interet;
    final date = DateTime.parse(tx['date_operation']);
    final montant = (tx['montant'] as num).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              dateFormat.format(date),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${tx['nom']} ${tx['prenoms']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  tx['numero_compte'],
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Icon(
                  isDepot
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: isDepot ? Colors.green : Colors.orange,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  type.label,
                  style: TextStyle(
                    color: isDepot ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${isDepot ? '+' : '-'} ${currencyFormat.format(montant)}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: isDepot ? Colors.green : Colors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
