// lib/screens/caisse/cash_transfer_list_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import 'cash_transfer_dialog.dart';

class CashTransferListPage extends StatefulWidget {
  const CashTransferListPage({super.key});

  @override
  State<CashTransferListPage> createState() => _CashTransferListPageState();
}

class _CashTransferListPageState extends State<CashTransferListPage> {
  late Future<List<Map<String, dynamic>>> _transfersFuture;
  final currencyFormat = NumberFormat.currency(
    symbol: 'FCFA',
    decimalDigits: 0,
    locale: 'fr_FR',
  );
  final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _transfersFuture = DatabaseService().getOperationsCaisse(
        type: null, // Both ENTREE and SORTIE are transfers
        startDate: _startDate,
        endDate: _endDate,
        // We need to filter by category.
        // Since getOperationsCaisse doesn't filter by category yet,
        // I will either add it or filter in the view.
        // Let's add category filtering to getOperationsCaisse for better performance.
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
            const SizedBox(height: 24),
            _buildFilters(isDark),
            const SizedBox(height: 24),
            Expanded(child: _buildTransferList(isDark)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await showDialog<bool>(
            context: context,
            builder: (context) => const CashTransferDialog(),
          );
          if (result == true) _refresh();
        },
        label: const Text('NOUVEAU TRANSFERT'),
        icon: const Icon(Icons.compare_arrows_rounded),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Transferts de Fonds',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(
          'Mouvements entre coffre et caisses',
          style: TextStyle(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildFilters(bool isDark) {
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

    return Row(
      children: [
        InkWell(
          onTap: () async {
            final DateTimeRange? picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
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
              color: isDark ? AppColors.darkSurface : Colors.white,
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
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () {
            setState(() {
              _startDate = DateTime.now().subtract(const Duration(days: 30));
              _endDate = DateTime.now();
            });
            _refresh();
          },
          icon: const Icon(Icons.history_rounded),
          tooltip: 'Réinitialiser les filtres (30 derniers jours)',
          color: Colors.grey,
        ),
        const Spacer(),
        IconButton(
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded),
          color: AppColors.primary,
        ),
      ],
    );
  }

  Widget _buildTransferList(bool isDark) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _transfersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Manual filter for TRANSFERT category
        final transfers = (snapshot.data ?? [])
            .where((op) => op['categorie'] == 'TRANSFERT')
            .toList();

        if (transfers.isEmpty) {
          return const Center(
            child: Text('Aucun transfert enregistré sur cette période'),
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
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: transfers.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: isDark ? AppColors.darkDivider : Colors.grey[100],
            ),
            itemBuilder: (context, index) {
              final transfer = transfers[index];
              return _buildTransferRow(transfer, isDark);
            },
          ),
        );
      },
    );
  }

  Widget _buildTransferRow(Map<String, dynamic> op, bool isDark) {
    final bool isEntree = op['type_operation'] == 'ENTREE'; // Approvisionnement
    final Color color = isEntree ? Colors.blue : Colors.orange;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isEntree ? Icons.south_east_rounded : Icons.north_west_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  op['libelle'] ?? 'Transfert sans libellé',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  dateFormat.format(DateTime.parse(op['date_operation'])),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isEntree ? 'APPRO' : 'DÉGAGEMENT',
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 32),
          Text(
            currencyFormat.format(op['montant']),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
