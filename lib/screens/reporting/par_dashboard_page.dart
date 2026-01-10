// lib/screens/reporting/par_dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import '../../core/services/pdf_export_service.dart';
import '../../models/par_stats_model.dart';
import 'delinquent_loan_detail_page.dart';

class PARDashboardPage extends StatefulWidget {
  const PARDashboardPage({super.key});

  @override
  State<PARDashboardPage> createState() => _PARDashboardPageState();
}

class _PARDashboardPageState extends State<PARDashboardPage> {
  final DatabaseService _db = DatabaseService();
  final PdfExportService _pdfService = PdfExportService();
  final currencyFormat = NumberFormat.currency(
    symbol: 'FCFA',
    decimalDigits: 0,
    locale: 'fr_FR',
  );

  PARStats? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _db.getPARStats();
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Qualité du Portefeuille (PAR)'),
        elevation: 0,
        backgroundColor: bgColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            onPressed: () => _pdfService.exportPARDashboard(_stats!),
            tooltip: 'Exporter PDF',
          ),
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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildMainHeader(isDark),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _buildMetricsGrid(isDark)),
                      const SizedBox(width: 24),
                      Expanded(flex: 2, child: _buildChartCard(isDark)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const SizedBox(height: 24),
                  _buildSegmentAnalysis(isDark),
                  const SizedBox(height: 24),
                  _buildClassificationSection(isDark),
                ],
              ),
            ),
    );
  }

  Widget _buildMainHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.primary.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'QUALITÉ DU PORTEFEUILLE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Situation au ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          _buildInfoPill(
            'Mise à jour temps réel',
            Icons.bolt_rounded,
            Colors.amber,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPill(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(bool isDark) {
    if (_stats == null) return const SizedBox.shrink();
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Encours total',
                _stats!.encoursTotal,
                Icons.account_balance_rounded,
                AppColors.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCard(
                'PAR 1 (1-30j)',
                _stats!.par1,
                Icons.history_rounded,
                Colors.orange,
                percentage: _stats!.tauxPAR1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'PAR 30 (31-90j)',
                _stats!.par30,
                Icons.warning_rounded,
                Colors.deepOrange,
                percentage: _stats!.tauxPAR30,
                alert: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCard(
                'PAR 90 (> 90j)',
                _stats!.par90,
                Icons.error_rounded,
                Colors.red,
                percentage: _stats!.tauxPAR90,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildSimpleMetricCard(
                'Taux remb.',
                '${_stats!.tauxRemboursement.toStringAsFixed(1)}%',
                Icons.check_circle_rounded,
                Colors.green,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSimpleMetricCard(
                'Prêts retard',
                '${_stats!.pretsEnRetard} / ${_stats!.totalPrets}',
                Icons.people_rounded,
                Colors.blueGrey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildSimpleMetricCard(
                'Pénalités dues',
                currencyFormat.format(_stats!.penalitesDues),
                Icons.money_off_csred_rounded,
                Colors.orangeAccent,
              ),
            ),
            const SizedBox(width: 16),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildSimpleMetricCard(
                'Provisions',
                currencyFormat.format(_stats!.provisionsConstituees),
                Icons.shield_rounded,
                Colors.purple,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSimpleMetricCard(
                'Taux couverture',
                '${_stats!.tauxCouverture.toStringAsFixed(0)}%',
                Icons.verified_user_rounded,
                Colors.indigo,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String title,
    double amount,
    IconData icon,
    Color color, {
    double? percentage,
    bool alert = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              if (alert)
                const Icon(
                  Icons.priority_high_rounded,
                  color: Colors.amber,
                  size: 20,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              currencyFormat.format(amount),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ),
          if (percentage != null) ...[
            const SizedBox(height: 8),
            Text(
              '${percentage.toStringAsFixed(2)}%',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSimpleMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: color.withOpacity(0.7), size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(bool isDark) {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Text(
            'Répartition du Risque',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: _stats!.encoursTotal > 0
                ? PieChart(
                    PieChartData(
                      sectionsSpace: 4,
                      centerSpaceRadius: 60,
                      sections: [
                        PieChartSectionData(
                          value: _stats!.parSains,
                          title: '',
                          color: Colors.green,
                          radius: 50,
                        ),
                        PieChartSectionData(
                          value: _stats!.par1,
                          title: '',
                          color: Colors.orange,
                          radius: 55,
                        ),
                        PieChartSectionData(
                          value: _stats!.par30,
                          title: '',
                          color: Colors.deepOrange,
                          radius: 60,
                        ),
                        PieChartSectionData(
                          value: _stats!.par90,
                          title: '',
                          color: Colors.red,
                          radius: 65,
                        ),
                        PieChartSectionData(
                          value: _stats!.par180,
                          title: '',
                          color: Colors.blueGrey,
                          radius: 70,
                        ),
                      ],
                    ),
                  )
                : Center(
                    child: Icon(
                      Icons.pie_chart_outline_rounded,
                      size: 80,
                      color: Colors.grey.withOpacity(0.2),
                    ),
                  ),
          ),
          const SizedBox(height: 24),
          _buildChartLegend('Sains', Colors.green),
          _buildChartLegend('Alerte (1-30j)', Colors.orange),
          _buildChartLegend('Retard (31-90j)', Colors.deepOrange),
          _buildChartLegend('Douteux (91-180j)', Colors.red),
          _buildChartLegend('Compromis (>180j)', Colors.blueGrey),
        ],
      ),
    );
  }

  Widget _buildChartLegend(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildClassificationSection(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Classification des crédits:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 32),
          _buildTreeItem(
            'Crédits sains (0 jour retard)',
            _stats!.nbSains,
            _stats!.parSains,
            Colors.green,
            subItems: [
              _buildTreeSubItem(
                'Encours',
                currencyFormat.format(_stats!.parSains),
              ),
              _buildTreeSubItem('Nombre', '${_stats!.nbSains}'),
              _buildTreeSubItem(
                '% du portefeuille',
                _stats!.encoursTotal > 0
                    ? '${(_stats!.parSains / _stats!.encoursTotal * 100).toStringAsFixed(2)}%'
                    : '0.00%',
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildTreeItem(
            'Crédits sous surveillance (1-30j)',
            _stats!.nb1,
            _stats!.par1,
            Colors.orange,
            subItems: [
              _buildTreeSubItem('Alerte précoce', 'Relance active'),
              _buildTreeSubItem('Actions préventives', 'Visite terrain'),
              _buildTreeSubItem(
                'Suivi rapproché',
                'Hebdomadaire',
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildTreeItem(
            'Crédits en retard (31-90j)',
            _stats!.nb30,
            _stats!.par30,
            Colors.deepOrange,
            subItems: [
              _buildTreeSubItem(
                'Recouvrement amiable intensif',
                'Actions renforcées',
              ),
              _buildTreeSubItem('Restructuration possible', 'Analyse dossier'),
              _buildTreeSubItem(
                'Provision 25%',
                currencyFormat.format(_stats!.par30 * 0.25),
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildTreeItem(
            'Crédits douteux (91-180j)',
            _stats!.nb90,
            _stats!.par90,
            Colors.red,
            subItems: [
              _buildTreeSubItem('Mise en demeure', 'Voie légale 1'),
              _buildTreeSubItem('Activation garanties', 'Phase 1'),
              _buildTreeSubItem('Négociation arrangement', 'Dernier recours'),
              _buildTreeSubItem(
                'Provision 50%',
                currencyFormat.format(_stats!.par90 * 0.5),
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildTreeItem(
            'Crédits compromis (> 180j)',
            _stats!.nb180,
            _stats!.par180,
            Colors.blueGrey,
            subItems: [
              _buildTreeSubItem('Procédures contentieuses', 'Expertise'),
              _buildTreeSubItem('Saisie garanties', 'Action forcée'),
              _buildTreeSubItem(
                'Provision 100%',
                currencyFormat.format(_stats!.par180),
              ),
              _buildTreeSubItem(
                'Passage en perte envisagé',
                'Validation CA',
                isLast: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTreeItem(
    String title,
    int count,
    double amount,
    Color color, {
    List<Widget>? subItems,
  }) {
    return InkWell(
      onTap: () => _navigateToDetail(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  border: Border.all(color: color.withOpacity(0.5), width: 2),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: color.withOpacity(0.8),
                  ),
                ),
              ),
            ],
          ),
          if (subItems != null)
            Padding(
              padding: const EdgeInsets.only(
                left: 5,
              ), // Align with center of circle
              child: Column(children: subItems),
            ),
        ],
      ),
    );
  }

  void _navigateToDetail() {
    showDialog(
      context: context,
      builder: (context) => const DelinquentLoanDetailPage(loanId: 1),
    );
  }

  Widget _buildSegmentAnalysis(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Analyse PAR par segment (>30j):',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 24,
            runSpacing: 24,
            children: [
              _buildSegmentCard(
                'Par Agence',
                _stats!.parParAgence,
                Colors.blue,
              ),
              _buildSegmentCard(
                'Par Agent',
                _stats!.parParAgent,
                Colors.purple,
              ),
              _buildSegmentCard(
                'Par Produit',
                _stats!.parParProduit,
                Colors.teal,
              ),
              _buildSegmentCard(
                'Par Secteur',
                _stats!.parParSecteur,
                Colors.orange,
              ),
              _buildSegmentCard(
                'Par Tranche',
                _stats!.parParTranche,
                Colors.indigo,
              ),
              _buildSegmentCard(
                'Groupes vs Indiv',
                _stats!.parGroupeVsIndiv,
                Colors.pink,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentCard(
    String title,
    Map<String, double> data,
    Color color,
  ) {
    if (data.isEmpty) return const SizedBox.shrink();

    // Convert to list and sort by value descending
    final sortedData = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Take top 5
    final displayData = sortedData.take(5).toList();
    final total = data.values.fold(0.0, (sum, val) => sum + val);

    return Container(
      width: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 16),
          ...displayData.map((e) {
            final percentage = total > 0 ? (e.value / total) : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          e.key,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        currencyFormat.format(e.value),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: percentage,
                      backgroundColor: color.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTreeSubItem(String label, String value, {bool isLast = false}) {
    return IntrinsicHeight(
      child: Row(
        children: [
          Container(
            width: 1,
            color: isLast ? Colors.transparent : Colors.grey.withOpacity(0.3),
            margin: const EdgeInsets.only(bottom: 0),
          ),
          Stack(
            children: [
              if (!isLast)
                Container(width: 1, color: Colors.grey.withOpacity(0.3)),
              Container(
                width: 16,
                height: 1,
                color: Colors.grey.withOpacity(0.3),
                margin: const EdgeInsets.only(top: 15),
              ),
              if (isLast)
                Container(
                  width: 1,
                  height: 15,
                  color: Colors.grey.withOpacity(0.3),
                ),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const Spacer(),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
