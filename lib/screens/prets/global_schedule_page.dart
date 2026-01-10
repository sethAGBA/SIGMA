import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/database_service.dart';
import '../../core/theme/app_colors.dart';

class GlobalSchedulePage extends StatefulWidget {
  const GlobalSchedulePage({super.key});

  @override
  State<GlobalSchedulePage> createState() => _GlobalSchedulePageState();
}

class _GlobalSchedulePageState extends State<GlobalSchedulePage> {
  final DatabaseService _db = DatabaseService();
  final currencyFormat = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: 'FCFA',
    decimalDigits: 0,
  );
  final dateFormat = DateFormat('dd MMM yyyy', 'fr_FR');

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  String _selectedPeriod = 'PROCHAINS 30J';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildHeader(isDark),
          _buildFilters(isDark),
          Expanded(child: _buildScheduleList(isDark)),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Échéancier Global',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Prévisions de collecte et suivi des remboursements',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Spacer(),
          _buildHeaderStats(isDark),
        ],
      ),
    );
  }

  Widget _buildHeaderStats(bool isDark) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _db.getGlobalSchedule(
        startDate: DateTime.now(),
        endDate: DateTime.now(),
      ),
      builder: (context, snapshot) {
        double dueToday = 0;
        if (snapshot.hasData) {
          for (var item in snapshot.data!) {
            dueToday += (item['total_du'] as num?)?.toDouble() ?? 0;
          }
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currencyFormat.format(dueToday),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: AppColors.primary,
                ),
              ),
              const Text(
                'DÛ AUJOURD\'HUI',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilters(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          _buildPeriodChip('AUJOURD\'HUI', isDark),
          const SizedBox(width: 8),
          _buildPeriodChip('CETTE SEMAINE', isDark),
          const SizedBox(width: 8),
          _buildPeriodChip('PROCHAINS 30J', isDark),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.date_range_rounded,
                  size: 18,
                  color: Colors.grey,
                ),
                const SizedBox(width: 12),
                Text(
                  '${DateFormat('dd/MM/yy').format(_startDate)} - ${DateFormat('dd/MM/yy').format(_endDate)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String label, bool isDark) {
    final isSelected = _selectedPeriod == label;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedPeriod = label;
          final now = DateTime.now();
          if (label == 'AUJOURD\'HUI') {
            _startDate = DateTime(now.year, now.month, now.day);
            _endDate = _startDate;
          } else if (label == 'CETTE SEMAINE') {
            _startDate = DateTime(now.year, now.month, now.day);
            _endDate = _startDate.add(const Duration(days: 7));
          } else if (label == 'PROCHAINS 30J') {
            _startDate = DateTime(now.year, now.month, now.day);
            _endDate = _startDate.add(const Duration(days: 30));
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? Colors.white10 : Colors.grey.shade200),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white60 : Colors.black54),
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleList(bool isDark) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _db.getGlobalSchedule(startDate: _startDate, endDate: _endDate),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(
            Icons.event_available_rounded,
            'Aucune échéance',
            'Aucun remboursement n\'est prévu pour la période sélectionnée.',
          );
        }

        final schedule = snapshot.data!;

        // Group by date
        Map<String, List<Map<String, dynamic>>> grouped = {};
        for (var item in schedule) {
          final dateStr = item['date_prevue'];
          if (!grouped.containsKey(dateStr)) {
            grouped[dateStr] = [];
          }
          grouped[dateStr]!.add(item);
        }

        final sortedDates = grouped.keys.toList()..sort();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: sortedDates.length,
          itemBuilder: (context, index) {
            final dateStr = sortedDates[index];
            final items = grouped[dateStr]!;
            final date = DateTime.parse(dateStr);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDateSeparator(date, isDark),
                ...items.map((item) => _buildScheduleCard(item, isDark)),
                const SizedBox(height: 24),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDateSeparator(DateTime date, bool isDark) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 16),
      child: Row(
        children: [
          Text(
            dateFormat.format(date).toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: isToday
                  ? AppColors.primary
                  : (isDark ? Colors.white38 : Colors.grey.shade400),
            ),
          ),
          if (isToday) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'AUJOURD\'HUI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> item, bool isDark) {
    final double capital = (item['capital_du'] as num?)?.toDouble() ?? 0;
    final double interest = (item['interets_dus'] as num?)?.toDouble() ?? 0;
    final double total = (item['total_du'] as num?)?.toDouble() ?? 0;
    final status = item['statut'] ?? 'En attente';

    Color statusColor;
    if (status == 'Payé') {
      statusColor = AppColors.success;
    } else if (status == 'En retard') {
      statusColor = AppColors.error;
    } else {
      statusColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                status == 'Payé'
                    ? Icons.check_circle_outline_rounded
                    : Icons.pending_actions_rounded,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['client_name'] ?? 'Client Inconnu',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Prêt N° ${item['numero_pret']} • Échéance ${item['numero_echeance']}',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  currencyFormat.format(total),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  '(Cap: ${currencyFormat.format(capital)} + Int: ${currencyFormat.format(interest)})',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 80, color: Colors.blue.withOpacity(0.3)),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }
}
