import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../models/agent_model.dart';
import '../../core/services/database_service.dart';
import '../../models/agency_model.dart';

class AgentDetailDialog extends StatefulWidget {
  final Agent agent;

  const AgentDetailDialog({super.key, required this.agent});

  @override
  State<AgentDetailDialog> createState() => _AgentDetailDialogState();
}

class _AgentDetailDialogState extends State<AgentDetailDialog> {
  String _agencyName = 'Chargement...';

  @override
  void initState() {
    super.initState();
    _loadAgency();
  }

  Future<void> _loadAgency() async {
    try {
      final agencies = await DatabaseService().getAgencies();
      final agency = agencies.firstWhere(
        (a) => a.id == widget.agent.agencyId,
        orElse: () => Agency(
          id: '',
          name: 'Agence Inconnue',
          code: '',
          address: '',
          phone: '',
          email: '',
          latitude: 0,
          longitude: 0,
          coverageArea: '',
          openingDate: DateTime.now(),
          isActive: false,
          stats: AgencyStats(
            activeClients: 0,
            totalOutstanding: 0,
            parRatio: 0,
            totalStaff: 0,
          ),
          team: AgencyTeam(
            managerName: '',
            loanOfficersCount: 0,
            cashiersCount: 0,
            backOfficeCount: 0,
          ),
        ),
      );
      if (mounted) {
        setState(() {
          _agencyName = agency.name;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _agencyName = 'Erreur chargement';
        });
      }
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
                    _buildPersonalInfo(context, isDark),
                    const SizedBox(height: 32),
                    _buildPortfolioSection(context, isDark),
                    const SizedBox(height: 32),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildMonthlyActivity(context, isDark),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 4,
                          child: _buildPerformanceSection(context, isDark),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _buildObjectivesSection(context, isDark),
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
            radius: 36,
            backgroundColor: AppColors.primary,
            child: Text(
              widget.agent.firstName.isNotEmpty
                  ? widget.agent.firstName[0]
                  : '',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.agent.fullName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.agent.role.label} • $_agencyName',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
            tooltip: 'Fermer',
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfo(BuildContext context, bool isDark) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Informations Personnelles', isDark),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: _buildContainerDecoration(isDark),
          child: Wrap(
            spacing: 60,
            runSpacing: 20,
            children: [
              _buildInfoItem(
                'Email',
                widget.agent.email,
                Icons.email_outlined,
                isDark,
              ),
              _buildInfoItem(
                'Téléphone',
                widget.agent.phone,
                Icons.phone_outlined,
                isDark,
              ),
              _buildInfoItem(
                'Date d\'embauche',
                dateFormat.format(widget.agent.hiredDate),
                Icons.calendar_today_outlined,
                isDark,
              ),
              _buildInfoItem(
                'Agence d\'affectation',
                _agencyName,
                Icons.location_city_outlined,
                isDark,
              ),
              _buildInfoItem(
                'Statut',
                widget.agent.isActive ? 'Actif' : 'Inactif',
                Icons.verified_user_outlined,
                isDark,
              ),
            ],
          ),
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
        _buildSectionTitle('Portefeuille Géré', isDark),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildStatCard(
              'Clients Assignés',
              '${widget.agent.stats.assignedClients}',
              Icons.people,
              isDark,
              Colors.blue,
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              'Encours Total',
              currencyFormat.format(widget.agent.stats.outstandingAmount),
              Icons.account_balance_wallet,
              isDark,
              Colors.orange,
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              'Prêts Actifs',
              '${widget.agent.stats.activeLoansCount}',
              Icons.description,
              isDark,
              Colors.purple,
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              'PAR > 30j',
              '${(widget.agent.stats.parRatio * 100).toStringAsFixed(1)}%',
              Icons.warning,
              isDark,
              AppColors.error,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMonthlyActivity(BuildContext context, bool isDark) {
    final currencyFormat = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: 'FCFA',
      decimalDigits: 0,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Activité Mensuelle', isDark),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: _buildContainerDecoration(isDark),
          child: Column(
            children: [
              _buildRowItem(
                'Nouveaux clients',
                '${widget.agent.stats.newClients}',
                isDark,
              ),
              _buildRowItem(
                'Prêts débloqués',
                '${widget.agent.stats.loansDisbursedCount}',
                isDark,
              ),
              _buildRowItem(
                'Montant décaissé',
                currencyFormat.format(widget.agent.stats.disbursedAmount),
                isDark,
              ),
              _buildRowItem(
                'Collecte réalisée',
                currencyFormat.format(widget.agent.stats.collectedAmount),
                isDark,
              ),
              _buildRowItem(
                'Visites effectuées',
                '${widget.agent.stats.visitsCount}',
                isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceSection(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Performance', isDark),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: _buildContainerDecoration(isDark),
          child: Column(
            children: [
              _buildPerformanceRow(
                'PAR du portefeuille',
                '${(widget.agent.stats.parRatio * 100).toStringAsFixed(1)}%',
                isDark,
                isPercentage: true,
                inverseColor: true,
              ),
              _buildPerformanceRow(
                'Taux de remboursement',
                '${(widget.agent.stats.repaymentRate * 100).toStringAsFixed(1)}%',
                isDark,
                isPercentage: true,
              ),
              _buildRowItem(
                'Productivité (prêts/mois)',
                '${widget.agent.stats.productivityRate.toStringAsFixed(1)}',
                isDark,
              ),
              _buildRowItem(
                'Qualité instruction',
                '${widget.agent.stats.qualityScore.toStringAsFixed(0)}/100',
                isDark,
              ),
              _buildRowItem(
                'Délai traitement',
                '${widget.agent.stats.processingTimeDays} jours',
                isDark,
              ),
              _buildPerformanceRow(
                'Satisfaction clients',
                '${widget.agent.stats.clientSatisfactionScore}/5',
                isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildObjectivesSection(BuildContext context, bool isDark) {
    final currencyFormat = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: 'FCFA',
      decimalDigits: 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Objectifs & Primes', isDark),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: _buildContainerDecoration(isDark),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Objectifs Mensuels',
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currencyFormat.format(
                        widget.agent.stats.monthlyObjectiveAmount,
                      ),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Réalisation',
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '${(widget.agent.stats.objectiveAchievementRate * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: widget.agent.stats.objectiveAchievementRate,
                            color: AppColors.success,
                            backgroundColor: isDark
                                ? Colors.black26
                                : Colors.grey[200],
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Primes sur performance',
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currencyFormat.format(widget.agent.stats.bonusEarned),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  BoxDecoration _buildContainerDecoration(bool isDark) {
    return BoxDecoration(
      color: isDark
          ? const Color(0xFF2D3748)
          : Colors.white, // Lighter background for cards
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

  Widget _buildInfoItem(
    String label,
    String value,
    IconData icon,
    bool isDark,
  ) {
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
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    bool isDark,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D3748) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.grey[200]!,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.grey[600],
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRowItem(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.grey[700],
              fontSize: 15,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
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
      // Simple logic: if inverse (like PAR), lower is better. If normal (repayment), higher is better.
      // This is just visual sugar
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
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.grey[700],
              fontSize: 15,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: valueColor,
            ),
          ),
        ],
      ),
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
}
