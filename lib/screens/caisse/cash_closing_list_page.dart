// lib/screens/caisse/cash_closing_list_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import '../../models/cash_closing_model.dart';
import 'cash_closing_dialog.dart';

class CashClosingListPage extends StatefulWidget {
  const CashClosingListPage({super.key});

  @override
  State<CashClosingListPage> createState() => _CashClosingListPageState();
}

class _CashClosingListPageState extends State<CashClosingListPage> {
  late Future<List<CashClosing>> _closingsFuture;
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
      _closingsFuture = DatabaseService().getCashClosings(
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
            const SizedBox(height: 24),
            _buildFilters(isDark),
            const SizedBox(height: 24),
            Expanded(child: _buildClosingList(isDark)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await showDialog<bool>(
            context: context,
            builder: (context) => const CashClosingDialog(),
          );
          if (result == true) _refresh();
        },
        label: const Text('NOUVELLE CLÔTURE'),
        icon: const Icon(Icons.add_task_rounded),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Historique des Clôtures',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(
          'Suivi des arrêtés de caisse et des écarts',
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

  Widget _buildClosingList(bool isDark) {
    return FutureBuilder<List<CashClosing>>(
      future: _closingsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final closings = snapshot.data ?? [];
        if (closings.isEmpty) {
          return const Center(
            child: Text('Aucune clôture enregistrée sur cette période'),
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
            itemCount: closings.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: isDark ? AppColors.darkDivider : Colors.grey[100],
            ),
            itemBuilder: (context, index) {
              final closing = closings[index];
              return _buildClosingRow(closing, isDark);
            },
          ),
        );
      },
    );
  }

  Widget _buildClosingRow(CashClosing closing, bool isDark) {
    final bool hasEcart = closing.ecart != 0;
    final Color statusColor = closing.ecart == 0
        ? Colors.green
        : (closing.ecart < 0 ? Colors.red : Colors.blue);

    return InkWell(
      onTap: () {
        // Optionnel : Afficher un détail plus complet
      },
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                closing.ecart == 0
                    ? Icons.check_circle_outline_rounded
                    : Icons.warning_amber_rounded,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateFormat.format(closing.dateCloture),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Agent: ${closing.agentCloture}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Théorique: ${currencyFormat.format(closing.soldeTheorique)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    'Physique: ${currencyFormat.format(closing.soldePhysique)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 32),
            Container(
              width: 140,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    closing.ecart == 0
                        ? 'CONFORME'
                        : (closing.ecart < 0 ? 'MANQUANT' : 'EXCÉDENT'),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (hasEcart)
                    Text(
                      currencyFormat.format(closing.ecart.abs()),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
