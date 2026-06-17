// lib/screens/caisse/cash_ledger_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import '../../models/cash_operation_model.dart';
import 'cash_closing_dialog.dart';
import 'cash_transfer_dialog.dart';
import 'cash_miscellaneous_dialog.dart';
import 'cash_operation_detail_dialog.dart';

class CashLedgerPage extends StatefulWidget {
  const CashLedgerPage({super.key});

  @override
  State<CashLedgerPage> createState() => _CashLedgerPageState();
}

class _CashLedgerPageState extends State<CashLedgerPage> {
  late Future<List<Map<String, dynamic>>> _operationsFuture;
  late Future<Map<String, double>> _totalsFuture;
  final currencyFormat = NumberFormat.currency(
    symbol: 'FCFA',
    decimalDigits: 0,
    locale: 'fr_FR',
  );
  final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
  final dayFormat = DateFormat('EEEE d MMMM yyyy', 'fr_FR');

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _operationsFuture = DatabaseService().getOperationsCaisse(
        startDate: _startDate,
        endDate: _endDate,
        searchQuery: _searchQuery,
      );
      _totalsFuture = DatabaseService().getDailyTotals(
        startDate: _startDate,
        endDate: _endDate,
      );
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
            const SizedBox(height: 16),
            _buildFilters(isDark),
            const SizedBox(height: 16),
            _buildSummaryCards(isDark),
            const SizedBox(height: 24),
            Expanded(child: _buildOperationList(isDark)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-caisse',
        onPressed: () async {
          final result = await showDialog<bool>(
            context: context,
            builder: (context) => const CashClosingDialog(),
          );
          if (result == true) _refresh();
        },
        label: const Text('CLÔTURER LA CAISSE'),
        icon: const Icon(Icons.lock_clock_rounded),
        backgroundColor: AppColors.primary,
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
              'Brouillard de Caisse',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              dayFormat.format(DateTime.now()),
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
        IconButton(
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded),
          color: AppColors.primary,
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () async {
            final result = await showDialog<bool>(
              context: context,
              builder: (context) => const CashTransferDialog(),
            );
            if (result == true) _refresh();
          },
          icon: const Icon(Icons.compare_arrows_rounded, size: 20),
          label: const Text('TRANSFERT / COFFRE'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () async {
            final result = await showDialog<bool>(
              context: context,
              builder: (context) => const CashMiscellaneousDialog(),
            );
            if (result == true) _refresh();
          },
          icon: const Icon(Icons.add_circle_outline_rounded),
          color: Colors.purple,
          tooltip: 'Opération Diverse',
        ),
      ],
    );
  }

  Widget _buildFilters(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher par libellé ou référence...',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
                _refresh();
              },
            ),
          ),
          const SizedBox(width: 16),
          _buildDateRangePicker(isDark),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {
              setState(() {
                _startDate = DateTime.now();
                _endDate = DateTime.now();
                _searchQuery = '';
                _searchController.clear();
              });
              _refresh();
            },
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Réinitialiser les filtres',
            color: Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangePicker(bool isDark) {
    String dateLabel = "";
    if (DateUtils.isSameDay(_startDate, DateTime.now()) &&
        DateUtils.isSameDay(_endDate, DateTime.now())) {
      dateLabel = "Aujourd'hui";
    } else {
      dateLabel = DateFormat('dd/MM/yyyy').format(_startDate);
      if (!DateUtils.isSameDay(_startDate, _endDate)) {
        dateLabel += ' - ${DateFormat('dd/MM/yyyy').format(_endDate)}';
      }
    }

    return InkWell(
      onTap: () async {
        final DateTimeRange? picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: isDark
                    ? const ColorScheme.dark(
                        primary: AppColors.primary,
                        onPrimary: Colors.white,
                        surface: AppColors.darkSurface,
                        onSurface: Colors.white,
                      )
                    : const ColorScheme.light(primary: AppColors.primary),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          setState(() {
            _startDate = picked.start;
            _endDate = picked.end;
          });
          _refresh();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.grey[300]!,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.date_range_rounded,
              size: 20,
              color: AppColors.primary,
            ),
            const SizedBox(width: 12),
            Text(
              dateLabel,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(bool isDark) {
    return FutureBuilder<Map<String, double>>(
      future: _totalsFuture,
      builder: (context, snapshot) {
        final totals = snapshot.data ?? {'entrees': 0.0, 'sorties': 0.0};
        final balance = totals['entrees']! - totals['sorties']!;

        return Row(
          children: [
            _summaryCard(
              'ENTRÉES DU JOUR',
              totals['entrees']!,
              Colors.green,
              Icons.add_circle_outline_rounded,
              isDark,
            ),
            const SizedBox(width: 16),
            _summaryCard(
              'SORTIES DU JOUR',
              totals['sorties']!,
              Colors.orange,
              Icons.remove_circle_outline_rounded,
              isDark,
            ),
            const SizedBox(width: 16),
            _summaryCard(
              'SOLDE NET DU JOUR',
              balance,
              AppColors.primary,
              Icons.account_balance_wallet_outlined,
              isDark,
            ),
          ],
        );
      },
    );
  }

  Widget _summaryCard(
    String title,
    double amount,
    Color color,
    IconData icon,
    bool isDark,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
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
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              currencyFormat.format(amount),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: amount < 0 ? Colors.red : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationList(bool isDark) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _operationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        final operations = snapshot.data ?? [];
        if (operations.isEmpty)
          return const Center(
            child: Text(
              'Aucune opération aujourd\'hui',
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
          child: Column(
            children: [
              _buildListHeader(isDark),
              Expanded(
                child: ListView.separated(
                  itemCount: operations.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: isDark ? AppColors.darkDivider : Colors.grey[100],
                  ),
                  itemBuilder: (context, index) => InkWell(
                    onTap: () => showDialog(
                      context: context,
                      builder: (context) => CashOperationDetailDialog(
                        operation: operations[index],
                      ),
                    ),
                    child: _buildOperationRow(operations[index], isDark),
                  ),
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
          Expanded(flex: 2, child: _headerCell('Heure')),
          Expanded(flex: 4, child: _headerCell('Libellé')),
          Expanded(flex: 2, child: _headerCell('Catégorie')),
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
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: Colors.grey,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildOperationRow(Map<String, dynamic> op, bool isDark) {
    final isEntree = op['type_operation'] == 'ENTREE';
    final date = DateTime.parse(op['date_operation']);
    final categorie = op['categorie'] ?? 'AUTRE';
    final montant = (op['montant'] as num).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              DateFormat('HH:mm:ss').format(date),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  op['libelle'] ?? 'Sans libellé',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                if (op['reference_externe'] != null)
                  Text(
                    'Réf: ${op['reference_externe']}',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                categorie,
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${isEntree ? '+' : '-'} ${currencyFormat.format(montant)}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: isEntree ? Colors.green : Colors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
