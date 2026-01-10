// lib/screens/reporting/executive_dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/database_service.dart';
import '../../models/executive_stats_model.dart';
import '../../core/theme/app_colors.dart';
import 'package:fl_chart/fl_chart.dart';

class ExecutiveDashboardPage extends StatefulWidget {
  const ExecutiveDashboardPage({super.key});

  @override
  State<ExecutiveDashboardPage> createState() => _ExecutiveDashboardPageState();
}

class _ExecutiveDashboardPageState extends State<ExecutiveDashboardPage> {
  final DatabaseService _db = DatabaseService();
  final currencyFormat = NumberFormat.currency(
    symbol: 'FCFA',
    decimalDigits: 0,
    locale: 'fr_FR',
  );

  ExecutiveDashboardStats? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _db.getExecutiveStats();
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Tableau de Bord de Direction'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadStats,
            tooltip: 'Actualiser',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _stats == null
          ? const Center(child: Text('Aucune donnée disponible'))
          : _buildDashboardContent(isDark),
    );
  }

  Widget _buildDashboardContent(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildCategoryCard(
                  'Indicateurs d\'activité',
                  _buildActivityMetrics(),
                  isDark,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildCategoryCard(
                  'Portefeuille crédit',
                  _buildPortfolioMetrics(),
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildCategoryCard(
                  'Qualité du portefeuille',
                  _buildQualityMetrics(),
                  isDark,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildCategoryCard(
                  'Épargne mobilisée',
                  _buildSavingsMetrics(),
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildCategoryCard(
            'Performance financière',
            _buildFinancialMetrics(),
            isDark,
          ),
          const SizedBox(height: 24),
          _buildChartsSection(isDark),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(String title, List<Widget> children, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  List<Widget> _buildActivityMetrics() {
    final act = _stats!.activity;
    return [
      _buildMetricRow(
        'Nombre clients actifs',
        act.activeClientsCount.toString(),
        Icons.people_rounded,
      ),
      _buildMetricRow(
        'Nouveaux clients mois',
        act.newClientsMonth.toString(),
        Icons.person_add_rounded,
      ),
      _buildMetricRow(
        'Clients sortis',
        act.lapsedClients.toString(),
        Icons.person_remove_rounded,
      ),
      _buildMetricRow(
        'Taux de pénétration zone',
        '${act.penetrationRate}%',
        Icons.map_rounded,
      ),
      _buildMetricRow(
        'Fidélisation (%)',
        '${act.retentionRate}%',
        Icons.favorite_rounded,
      ),
    ];
  }

  List<Widget> _buildPortfolioMetrics() {
    final port = _stats!.portfolio;
    return [
      _buildMetricRow(
        'Encours total',
        currencyFormat.format(port.totalOutstanding),
        Icons.account_balance_wallet_rounded,
      ),
      _buildMetricRow(
        'Nombre prêts actifs',
        port.activeLoansCount.toString(),
        Icons.assignment_rounded,
      ),
      _buildMetricRow(
        'Montant moyen prêt',
        currencyFormat.format(port.averageLoanAmount),
        Icons.analytics_rounded,
      ),
      _buildMetricRow(
        'Croissance mensuelle (%)',
        '${port.monthlyGrowth}%',
        Icons.trending_up_rounded,
      ),
      _buildMetricRow(
        'Décaissements mois',
        currencyFormat.format(port.disbursementsMonth),
        Icons.output_rounded,
      ),
      _buildMetricRow(
        'Remboursements mois',
        currencyFormat.format(port.repaymentsMonth),
        Icons.input_rounded,
      ),
    ];
  }

  List<Widget> _buildQualityMetrics() {
    final qual = _stats!.quality;
    return [
      _buildMetricRow(
        'PAR 30 (%)',
        '${qual.par30Rate.toStringAsFixed(2)}%',
        Icons.warning_amber_rounded,
        color: Colors.orange,
      ),
      _buildMetricRow(
        'Taux de remboursement',
        '${qual.repaymentRate.toStringAsFixed(1)}%',
        Icons.check_circle_outline_rounded,
        color: Colors.green,
      ),
      _buildMetricRow(
        'Taux de perte (write-off)',
        '${qual.writeOffRate}%',
        Icons.delete_outline_rounded,
        color: Colors.red,
      ),
      _buildMetricRow(
        'Provisions / Encours',
        '${qual.provisionsOutstandingRatio}%',
        Icons.security_rounded,
      ),
      _buildMetricRow(
        'Créances douteuses',
        currencyFormat.format(qual.doubtfulDebts),
        Icons.error_outline_rounded,
        color: Colors.red,
      ),
    ];
  }

  List<Widget> _buildSavingsMetrics() {
    final sav = _stats!.savings;
    return [
      _buildMetricRow(
        'Total épargne collectée',
        currencyFormat.format(sav.totalSavings),
        Icons.savings_rounded,
      ),
      _buildMetricRow(
        'Nombre comptes',
        sav.accountsCount.toString(),
        Icons.account_balance_rounded,
      ),
      _buildMetricRow(
        'Épargne moyenne',
        currencyFormat.format(sav.averageSavings),
        Icons.query_stats_rounded,
      ),
      _buildMetricRow(
        'Croissance épargne',
        '${sav.savingsGrowth}%',
        Icons.trending_up_rounded,
      ),
      _buildMetricRow(
        'Ratio épargne/crédit',
        '${sav.savingsCreditRatio.toStringAsFixed(1)}%',
        Icons.compare_arrows_rounded,
      ),
      const Divider(),
      const Text(
        'Répartition par type:',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
      const SizedBox(height: 8),
      ...sav.savingsByType.entries.map(
        (e) => _buildMetricRow(
          e.key,
          currencyFormat.format(e.value),
          Icons.pie_chart_outline_rounded,
        ),
      ),
    ];
  }

  List<Widget> _buildFinancialMetrics() {
    final fin = _stats!.financial;
    return [
      _buildMetricRow(
        'Produit net d\'intérêts',
        currencyFormat.format(fin.netInterestIncome),
        Icons.account_balance_rounded,
      ),
      _buildMetricRow(
        'Produits de commissions',
        currencyFormat.format(fin.feeIncome),
        Icons.money_rounded,
      ),
      _buildMetricRow(
        'Charges d\'exploitation',
        currencyFormat.format(fin.operatingExpenses),
        Icons.trending_down_rounded,
        color: Colors.red,
      ),
      _buildMetricRow(
        'Résultat net',
        currencyFormat.format(fin.netIncome),
        Icons.account_balance_wallet_rounded,
        color: Colors.green,
      ),
      _buildMetricRow(
        'Rentabilité fonds propres (ROE)',
        '${fin.roe}%',
        Icons.analytics_rounded,
      ),
      _buildMetricRow(
        'Rentabilité actifs (ROA)',
        '${fin.roa}%',
        Icons.insights_rounded,
      ),
    ];
  }

  Widget _buildMetricRow(
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? Colors.grey),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection(bool isDark) {
    return Column(
      children: [
        _buildCategoryCard('Évolution de l\'encours sur 12 mois (M FCFA)', [
          _buildOutstanding12MonthChart(isDark),
        ], isDark),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _buildCategoryCard(
                'Courbe PAR et Taux de remboursement (%)',
                [_buildPARVsRepaymentChart(isDark)],
                isDark,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _buildCategoryCard('Répartition géographique (Volume)', [
                _buildGeographicBarChart(isDark),
              ], isDark),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: _buildCategoryCard('Top 10 Performance des Agents', [
                _buildTopAgentsTable(isDark),
              ], isDark),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 1,
              child: _buildCategoryCard('Produits les plus demandés', [
                _buildPopularProductsChart(isDark),
              ], isDark),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOutstanding12MonthChart(bool isDark) {
    final evolution = _stats!.outstanding12MonthEvolution;
    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() % 2 != 0) return const SizedBox();
                  if (value.toInt() < 0 || value.toInt() >= evolution.length)
                    return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      evolution[value.toInt()].label,
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: evolution
                  .asMap()
                  .entries
                  .map((e) => FlSpot(e.key.toDouble(), e.value.value))
                  .toList(),
              isCurved: true,
              color: const Color(0xFF10B981),
              barWidth: 4,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF10B981).withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPARVsRepaymentChart(bool isDark) {
    final parEvol = _stats!.quality.par12MonthEvolution;
    final rembEvol = _stats!.quality.repaymentRateEvolution;

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) => Text(
                  '${value.toInt()}%',
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() % 3 != 0) return const SizedBox();
                  if (value.toInt() < 0 || value.toInt() >= parEvol.length)
                    return const SizedBox();
                  return Text(
                    parEvol[value.toInt()].label,
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: parEvol
                  .asMap()
                  .entries
                  .map((e) => FlSpot(e.key.toDouble(), e.value.value))
                  .toList(),
              color: Colors.orange,
              barWidth: 2,
              dotData: const FlDotData(show: true),
            ),
            LineChartBarData(
              spots: rembEvol
                  .asMap()
                  .entries
                  .map((e) => FlSpot(e.key.toDouble(), e.value.value))
                  .toList(),
              color: Colors.green,
              barWidth: 2,
              dotData: const FlDotData(show: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeographicBarChart(bool isDark) {
    final geo = _stats!.geographicDistribution;
    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() < 0 || value.toInt() >= geo.length)
                    return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      geo[value.toInt()].region.length > 10
                          ? '${geo[value.toInt()].region.substring(0, 10)}...'
                          : geo[value.toInt()].region,
                      style: const TextStyle(fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: geo.asMap().entries.map((e) {
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value.volume / 1000000,
                  color: AppColors.primary,
                  width: 16,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTopAgentsTable(bool isDark) {
    return Column(
      children: [
        Row(
          children: const [
            Expanded(
              child: Text(
                'Agent',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            Expanded(
              child: Text(
                'Volume (M)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            Expanded(
              child: Text(
                'PAR %',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            Expanded(
              child: Text(
                'Collecte %',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
        const Divider(),
        ..._stats!.topAgents.map(
          (a) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(a.name, style: const TextStyle(fontSize: 12)),
                ),
                Expanded(
                  child: Text(
                    '${(a.volume / 1000000).toStringAsFixed(1)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Expanded(
                  child: Text(
                    '${a.parRate.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: a.parRate > 5 ? Colors.red : Colors.green,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '${a.collectionRate}%',
                    style: const TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPopularProductsChart(bool isDark) {
    final products = _stats!.popularProducts;
    return Column(
      children: products
          .take(5)
          .map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(p.name, style: const TextStyle(fontSize: 12)),
                      Text(
                        '${p.requestCount} dmd',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: p.requestCount / (products.first.requestCount),
                    backgroundColor: isDark
                        ? Colors.white10
                        : Colors.black.withOpacity(0.05),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary.withOpacity(0.7),
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
