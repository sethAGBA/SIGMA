import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import '../../widgets/dialogs/register_recovery_action_dialog.dart';
import 'delinquent_loan_detail_page.dart';

class DelinquentLoansListPage extends StatefulWidget {
  const DelinquentLoansListPage({Key? key}) : super(key: key);

  @override
  _DelinquentLoansListPageState createState() =>
      _DelinquentLoansListPageState();
}

class _DelinquentLoansListPageState extends State<DelinquentLoansListPage> {
  final DatabaseService _dbService = DatabaseService();
  final currencyFormat = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: 'FCFA',
    decimalDigits: 0,
  );

  List<Map<String, dynamic>> _loans = [];
  bool _isLoading = true;
  String _selectedCategory = 'Tous';
  final List<String> _categories = [
    'Tous',
    'PAR 1-30',
    'PAR 31-90',
    'PAR 91-180',
    'PAR 180+',
  ];

  @override
  void initState() {
    super.initState();
    _loadLoans();
  }

  Future<void> _loadLoans() async {
    setState(() => _isLoading = true);
    final loans = await _dbService.getDelinquentLoans(
      parCategory: _selectedCategory == 'Tous' ? null : _selectedCategory,
    );
    setState(() {
      _loans = loans;
      _isLoading = false;
    });
  }

  double get _totalBalance => _loans.fold(
    0.0,
    (sum, item) => sum + ((item['solde_restant'] as num?)?.toDouble() ?? 0),
  );
  int get _avgDays => _loans.isEmpty
      ? 0
      : (_loans.fold(
                  0,
                  (sum, item) => sum + (item['jours_retard'] as int? ?? 0),
                ) /
                _loans.length)
            .round();

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildStatsHeader(isDark),
          _buildFilterBar(isDark),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _loans.isEmpty
                ? _buildEmptyState(isDark)
                : _buildList(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Row(
        children: [
          _buildStatCard(
            'Volume en Souffrance',
            currencyFormat.format(_totalBalance),
            Icons.account_balance_wallet_rounded,
            Colors.red,
            isDark,
          ),
          const SizedBox(width: 16),
          _buildStatCard(
            'Retard Moyen',
            '$_avgDays jours',
            Icons.timer_rounded,
            Colors.orange,
            isDark,
          ),
          const SizedBox(width: 16),
          _buildStatCard(
            'Dossiers Actifs',
            '${_loans.length}',
            Icons.assignment_late_rounded,
            Colors.blue,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Text(
            'Filtrage PAR:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedCategory = cat);
                          _loadLoans();
                        }
                      },
                      selectedColor: AppColors.primary,
                      backgroundColor: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.grey.shade100,
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black87),
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 12,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline_rounded,
              size: 80,
              color: Colors.green.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Excellent ! Aucun impayé',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Toutes les créances pour cette catégorie sont à jour.',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _loans.length,
      itemBuilder: (context, index) {
        final loan = _loans[index];
        final int id = loan['id'];
        final String clientName = loan['client_name'] ?? 'Inconnu';
        final String numeroPret = loan['numero_pret'] ?? 'N/A';
        final double solde = (loan['solde_restant'] as num?)?.toDouble() ?? 0;
        final int jours = loan['jours_retard'] ?? 0;
        final Color riskColor = _getRiskColor(jours);

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey.shade100,
            ),
          ),
          child: InkWell(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => DelinquentLoanDetailPage(loanId: id), // Phase 2 OK
              ).then((_) => _loadLoans());
            },
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  _buildRiskBadge(jours, riskColor),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          clientName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: (isDark ? Colors.white : Colors.black)
                                    .withOpacity(0.05),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'N° $numeroPret',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white60
                                      : Colors.black54,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.access_time_filled_rounded,
                              size: 14,
                              color: riskColor.withOpacity(0.7),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$jours jours de retard',
                              style: TextStyle(
                                color: riskColor,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  _buildActionArea(id, clientName, numeroPret, solde),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRiskBadge(int jours, Color color) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber_rounded, color: color, size: 24),
            Text(
              'PAR',
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionArea(
    int id,
    String clientName,
    String numeroPret,
    double solde,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          currencyFormat.format(solde),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          'Capital Restant',
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => RegisterRecoveryActionDialog(
                loanId: id,
                clientName: clientName,
                numeroPret: numeroPret,
                onActionSaved: _loadLoans,
              ),
            );
          },
          icon: const Icon(Icons.send_rounded, size: 14),
          label: const Text('RELANCER'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Color _getRiskColor(int jours) {
    if (jours > 180) return Colors.blueGrey;
    if (jours > 90) return Colors.red.shade700;
    if (jours > 30) return Colors.deepOrange;
    return Colors.orange;
  }
}
