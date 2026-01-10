import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/agency_model.dart';
import 'package:intl/intl.dart';
import '../../core/services/database_service.dart';

class AgencyDetailDialog extends StatefulWidget {
  final Agency agency;

  const AgencyDetailDialog({super.key, required this.agency});

  @override
  State<AgencyDetailDialog> createState() => _AgencyDetailDialogState();
}

class _AgencyDetailDialogState extends State<AgencyDetailDialog> {
  late AgencyStats _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _stats = widget.agency.stats; // Start with passed stats (likely empty)
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final updatedStats = await DatabaseService().getAgencyStats(
        widget.agency.id,
      );
      if (mounted) {
        setState(() {
          _stats = updatedStats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      print('Error loading stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 950,
          maxHeight: MediaQuery.of(context).size.height * 0.95,
        ),
        child: Column(
          children: [
            _buildHeader(context, isDark),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGeneralInfo(context, isDark),
                    const SizedBox(height: 32),
                    _buildTeamSection(context, isDark),
                    const SizedBox(height: 32),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildPortfolioSection(context, isDark),
                        ),
                        const SizedBox(width: 24),
                        Expanded(child: _buildSavingsSection(context, isDark)),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _buildPerformanceSection(context, isDark),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: Icon(
              Icons.account_balance,
              color: AppColors.primary,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.agency.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Code: ${widget.agency.code} • ${widget.agency.address}',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralInfo(BuildContext context, bool isDark) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Informations Générales', isDark),
        const SizedBox(height: 16),
        Wrap(
          spacing: 48,
          runSpacing: 16,
          children: [
            _buildInfoItem(
              'Téléphone',
              widget.agency.phone,
              Icons.phone_outlined,
              isDark,
            ),
            _buildInfoItem(
              'Email',
              widget.agency.email,
              Icons.email_outlined,
              isDark,
            ),
            _buildInfoItem(
              'Zone de couverture',
              widget.agency.coverageArea,
              Icons.map_outlined,
              isDark,
            ),
            _buildInfoItem(
              'Date d\'ouverture',
              dateFormat.format(widget.agency.openingDate),
              Icons.calendar_today_outlined,
              isDark,
            ),
            _buildInfoItem(
              'Statut',
              widget.agency.isActive ? 'Active' : 'Fermée',
              Icons.check_circle_outline,
              isDark,
              valueColor: widget.agency.isActive ? Colors.green : Colors.red,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTeamSection(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Équipe', isDark),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Manager is special
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chef d\'agence',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white60 : Colors.grey[700],
                        ),
                      ),
                      Text(
                        _stats.managerName.isNotEmpty
                            ? _stats.managerName
                            : 'Non assigné',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _buildTeamCount(
              'Agents Crédit',
              '${_stats.loanOfficersCount}',
              isDark,
            ),
            _buildTeamCount('Caissiers', '${_stats.cashiersCount}', isDark),
            _buildTeamCount('Back-office', '${_stats.backOfficeCount}', isDark),
            _buildTeamCount(
              'Total',
              '${_stats.totalStaff}',
              isDark,
              isTotal: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPortfolioSection(BuildContext context, bool isDark) {
    final currencyFormat = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: 'FCFA',
      decimalDigits: 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Portefeuille', isDark),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: _buildContainerDecoration(isDark),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    _buildRowItem(
                      'Clients actifs',
                      '${_stats.activeClients}',
                      isDark,
                    ),
                    _buildRowItem(
                      'Encours total',
                      currencyFormat.format(_stats.totalOutstanding),
                      isDark,
                    ),
                    _buildRowItem(
                      'Prêts actifs',
                      '${_stats.activeLoansCount}',
                      isDark,
                    ),
                    _buildRowItem(
                      'Montant moyen prêt',
                      currencyFormat.format(_stats.avgLoanAmount),
                      isDark,
                    ),
                    _buildPerformanceRow(
                      'PAR Agence',
                      '${_stats.parRatio.toStringAsFixed(1)}%',
                      isDark,
                      isPercentage: true,
                      inverseColor: true,
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildSavingsSection(BuildContext context, bool isDark) {
    final currencyFormat = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: 'FCFA',
      decimalDigits: 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Épargne', isDark),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: _buildContainerDecoration(isDark),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    _buildRowItem(
                      'Nombre comptes',
                      '${_stats.savingsAccountsCount}',
                      isDark,
                    ),
                    _buildRowItem(
                      'Solde total épargne',
                      currencyFormat.format(_stats.totalSavings),
                      isDark,
                    ),
                    _buildRowItem(
                      'Épargne moyenne',
                      currencyFormat.format(_stats.avgSavings),
                      isDark,
                    ),
                    _buildRowItem(
                      'Nouveaux cpt (mois)',
                      '${_stats.newAccountsMonth}',
                      isDark,
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildPerformanceSection(BuildContext context, bool isDark) {
    final currencyFormat = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: 'FCFA',
      decimalDigits: 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Performance', isDark),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: _buildContainerDecoration(isDark),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildVerticalStat(
                      'Produits Financiers',
                      currencyFormat.format(_stats.financialProductsAmount),
                      Colors.green,
                      isDark,
                    ),
                    _buildVerticalStat(
                      'Charges Fonctionnement',
                      currencyFormat.format(_stats.operationalExpensesAmount),
                      Colors.orange,
                      isDark,
                    ),
                    _buildVerticalStat(
                      'Résultat Agence',
                      currencyFormat.format(_stats.netResultAmount),
                      Colors.blue,
                      isDark,
                      isBold: true,
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(
    String label,
    String value,
    IconData icon,
    bool isDark, {
    Color? valueColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: AppColors.primary.withOpacity(0.7)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.grey[600],
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: valueColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTeamCount(
    String label,
    String count,
    bool isDark, {
    bool isTotal = false,
  }) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isTotal
                ? AppColors.primary
                : (isDark ? Colors.white : Colors.black87),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white54 : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildRowItem(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700]),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPerformanceRow(
    String label,
    String value,
    bool isDark, {
    bool isPercentage = false,
    bool inverseColor = false,
  }) {
    Color? valueColor;
    if (isPercentage) {
      final numVal = double.tryParse(value.replaceAll('%', ''));
      if (numVal != null) {
        if (inverseColor) {
          valueColor = numVal < 5
              ? AppColors.success
              : (numVal < 10 ? Colors.orange : AppColors.error);
        } else {
          valueColor = numVal > 95
              ? AppColors.success
              : (numVal > 90 ? Colors.orange : AppColors.error);
        }
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700]),
          ),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: valueColor),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalStat(
    String label,
    String value,
    Color color,
    bool isDark, {
    bool isBold = false,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.grey[600],
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: isDark ? Colors.white54 : Colors.grey[600],
      ),
    );
  }

  BoxDecoration _buildContainerDecoration(bool isDark) {
    return BoxDecoration(
      color: isDark ? const Color(0xFF2D3748) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
      boxShadow: isDark
          ? []
          : [
              BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
    );
  }
}
