import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:afroforma/models/inscription.dart';
import 'package:afroforma/services/database_service.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data'; // Added for Uint8List

class AnalysesScreen extends StatefulWidget {
  final Animation<double> fadeAnimation;
  const AnalysesScreen({Key? key, required this.fadeAnimation}) : super(key: key);

  @override
  State<AnalysesScreen> createState() => _AnalysesScreenState();
}

class _AnalysesScreenState extends State<AnalysesScreen> {
  DateTimeRange? _selectedDateRange;
  String selectedTemplate = 'Bilan pédagogique';
  bool autoSendEnabled = false;

  List<Map<String, String>> _reportWidgets = [];
  bool _isHovering = false;

  late Future<Map<String, dynamic>> _analyticsFuture;

  final NumberFormat _currencyFormat = NumberFormat('#,##0', 'fr_FR');

  @override
  void initState() {
    super.initState();
    _selectedDateRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now(),
    );
    _loadData();
  }

  void _loadData() {
    setState(() {
      _analyticsFuture = _loadAnalyticsData();
    });
  }

  Future<Map<String, dynamic>> _loadAnalyticsData() async {
    final db = DatabaseService();
    final formations = await db.getFormations();
    final recoveryRate = await db.getRecoveryRate();

    // Calculate CA par formation
    final caParFormation = formations.map((f) => {'title': f.title, 'revenue': f.revenue}).toList();

    // Calculate Evolution mensuelle (last 6 months)
    final now = DateTime.now();
    final monthlyEvolution = <Map<String, dynamic>>[];
    for (int i = 5; i >= 0; i--) {
      var date = DateTime(now.year, now.month - i, 1);
      final revenue = await db.sumPaymentsInMonth(date.year, date.month);
      monthlyEvolution.add({'month': date.month, 'year': date.year, 'revenue': revenue});
    }

    // Calculate Ratios
    final totalRevenue = formations.fold<double>(0.0, (prev, f) => prev + f.revenue);
    final totalDirectCosts = formations.fold<double>(0.0, (prev, f) => prev + f.directCosts);
    final totalIndirectCosts = formations.fold<double>(0.0, (prev, f) => prev + f.indirectCosts);
    final totalCosts = totalDirectCosts + totalIndirectCosts;
    final grossMargin = totalRevenue > 0 ? ((totalRevenue - totalCosts) / totalRevenue) * 100 : 0.0;
    final roi = totalCosts > 0 ? ((totalRevenue - totalCosts) / totalCosts) * 100 : 0.0;

    // Calculate Liquidity and Debt Ratios (Simplified for SYSCOHADA)
    // NOTE: These calculations are highly simplified and may not reflect a true balance sheet.
    // A proper implementation would require detailed account classification (assets/liabilities within Class 4, etc.)
    // and potentially a full balance sheet generation.

    final startMs = _selectedDateRange?.start.millisecondsSinceEpoch;
    final endMs = _selectedDateRange?.end.millisecondsSinceEpoch;

    // Current Assets (Simplified: Class 3, Class 4 (debit), Class 5 (debit))
    double currentAssets = await db.getAccountSum('3', isDebit: true, start: _selectedDateRange?.start, end: _selectedDateRange?.end);
    currentAssets += await db.getAccountSum('4', isDebit: true, start: _selectedDateRange?.start, end: _selectedDateRange?.end); // Assuming debit side of Class 4 are assets
    currentAssets += await db.getAccountSum('5', isDebit: true, start: _selectedDateRange?.start, end: _selectedDateRange?.end);

    // Current Liabilities (Simplified: Class 4 (credit), Class 5 (credit))
    double currentLiabilities = await db.getAccountSum('4', isDebit: false, start: _selectedDateRange?.start, end: _selectedDateRange?.end); // Assuming credit side of Class 4 are liabilities
    currentLiabilities += await db.getAccountSum('5', isDebit: false, start: _selectedDateRange?.start, end: _selectedDateRange?.end);

    final liquidityRatio = currentLiabilities > 0 ? (currentAssets / currentLiabilities) : 0.0;

    // Total Assets (Simplified: Class 2, 3, 4 (debit), 5 (debit))
    double totalAssets = await db.getAccountSum('2', isDebit: true, start: _selectedDateRange?.start, end: _selectedDateRange?.end);
    totalAssets += currentAssets; // Add current assets calculated above

    // Total Debt (Simplified: Class 1 (credit), Class 4 (credit), Class 5 (credit))
    double totalDebt = await db.getAccountSum('1', isDebit: false, start: _selectedDateRange?.start, end: _selectedDateRange?.end);
    totalDebt += currentLiabilities; // Add current liabilities calculated above

    final debtRatio = totalAssets > 0 ? (totalDebt / totalAssets) * 100 : 0.0;


    final companyInfo = await db.getCompanyInfo();
    final double targetObjective = companyInfo?.targetRevenue ?? 0.0; // Get from CompanyInfo, default to 0.0

    return {
      'formations': formations,
      'caParFormation': caParFormation,
      'monthlyEvolution': monthlyEvolution,
      'recoveryRate': recoveryRate,
      'grossMargin': grossMargin,
      'roi': roi,
      'totalRevenue': totalRevenue,
      'liquidityRatio': liquidityRatio,
      'debtRatio': debtRatio,
      'targetObjective': targetObjective, // Add the objective to the data map
    };
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: widget.fadeAnimation,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              FutureBuilder<Map<String, dynamic>>(
                future: _analyticsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Erreur: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('Aucune donnée disponible', style: TextStyle(color: Colors.white)));
                  }

                  final data = snapshot.data!;

                  return Column(
                    children: [
                      _buildFinancialDashboard(data),
                      const SizedBox(height: 24),
                      _buildCustomReports(),
                      const SizedBox(height: 24),
                      _buildReportGenerator(),
                      const SizedBox(height: 120),
                    ],
                  );
                },
              ),
            ],
          ),
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
              'Reporting & Analyses',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Tableaux de bord financiers et rapports personnalisables',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
        Row(
          children: [
            _buildExportButton(Icons.picture_as_pdf, 'PDF', Colors.red),
            const SizedBox(width: 8),
            _buildExportButton(Icons.table_chart, 'Excel', Colors.green),
            const SizedBox(width: 8),
            _buildExportButton(Icons.insert_drive_file, 'CSV', Colors.blue),
          ],
        ),
      ],
    );
  }

  Widget _buildExportButton(IconData icon, String label, Color color) {
    return ElevatedButton.icon(
      onPressed: () => _exportReport(label),
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(80, 36),
      ),
    );
  }

  Widget _buildFinancialDashboard(Map<String, dynamic> data) {
    return Card(
      color: const Color(0xFF0F172A),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.dashboard, color: Colors.blue, size: 24),
                SizedBox(width: 8),
                Text(
                  'Tableau de bord financier',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Widgets analytics en grille
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: [
                _buildCAParFormationChart(data['caParFormation'] as List<Map<String, dynamic>>),
                _buildEvolutionMensuelleChart(data['monthlyEvolution'] as List<Map<String, dynamic>>),
                _buildTauxRecouvrementGauge(data['recoveryRate'] as double),
                _buildObjectifsVsRealiseChart(data['totalRevenue'] as double, data['targetObjective'] as double),
              ],
            ),
            const SizedBox(height: 16),
            _buildRatiosFinanciers(data),
          ],
        ),
      ),
    );
  }

  Widget _buildCAParFormationChart(List<Map<String, dynamic>> caParFormation) {
    final totalRevenue = caParFormation.fold<double>(0.0, (sum, item) => sum + (item['revenue'] as double));
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red, Colors.teal];
    
    List<PieChartSectionData> sections = [];
    if (totalRevenue > 0) {
      final sortedFormations = List<Map<String, dynamic>>.from(caParFormation)..sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));
      final topFormations = sortedFormations.take(5);
      double otherRevenue = sortedFormations.skip(5).fold(0.0, (sum, item) => sum + (item['revenue'] as double));

      int colorIndex = 0;
      for (var item in topFormations) {
        final percentage = (item['revenue'] / totalRevenue) * 100;
        sections.add(
          PieChartSectionData(
            value: item['revenue'],
            color: colors[colorIndex % colors.length],
            title: '${percentage.toStringAsFixed(0)}%',
            radius: 40,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        );
        colorIndex++;
      }
      if (otherRevenue > 0) {
        final percentage = (otherRevenue / totalRevenue) * 100;
        sections.add(
          PieChartSectionData(
            value: otherRevenue,
            color: Colors.grey,
            title: '${percentage.toStringAsFixed(0)}%',
            radius: 40,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        );
      }
    } else {
      sections.add(
        PieChartSectionData(
          value: 1,
          color: Colors.grey,
          title: 'N/A',
          radius: 40,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pie_chart, color: Colors.orange, size: 20),
              SizedBox(width: 6),
              Text('CA par formation', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: PieChart(
              PieChartData(
                sections: sections,
                sectionsSpace: 2,
                centerSpaceRadius: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvolutionMensuelleChart(List<Map<String, dynamic>> monthlyEvolution) {
    List<FlSpot> spots = [];
    for (var i = 0; i < monthlyEvolution.length; i++) {
      spots.add(FlSpot(i.toDouble(), monthlyEvolution[i]['revenue']));
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.trending_up, color: Colors.green, size: 20),
              SizedBox(width: 6),
              Text('Évolution mensuelle', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Colors.green,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTauxRecouvrementGauge(double recoveryRate) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.speed, color: Colors.cyan, size: 20),
              SizedBox(width: 6),
              Text('Taux recouvrement', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      value: recoveryRate / 100,
                      strokeWidth: 8,
                      backgroundColor: Colors.grey[800],
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.cyan),
                    ),
                  ),
                  Text(
                    '${recoveryRate.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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

  Widget _buildObjectifsVsRealiseChart(double totalRevenue, double objective) {

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.track_changes, color: Colors.amber, size: 20),
              SizedBox(width: 6),
              Text('Objectifs vs Réalisé', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(x: 0, barRods: [
                    BarChartRodData(toY: totalRevenue, color: Colors.amber, width: 12, borderRadius: BorderRadius.circular(4)),
                    BarChartRodData(toY: objective, color: Colors.grey[800]!, width: 12, borderRadius: BorderRadius.circular(4)),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatiosFinanciers(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics, color: Colors.purple, size: 20),
              SizedBox(width: 8),
              Text('Ratios financiers clés', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildRatioItem('Marge brute', '${(data['grossMargin'] as double).toStringAsFixed(1)}%', Colors.green),
              _buildRatioItem('ROI', '${(data['roi'] as double).toStringAsFixed(1)}%', Colors.blue),
              _buildRatioItem('Liquidité', '${(data['liquidityRatio'] as double).toStringAsFixed(2)}', Colors.orange),
              _buildRatioItem('Endettement', '${(data['debtRatio'] as double).toStringAsFixed(1)}%', Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatioItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildCustomReports() {
    return Card(
      color: const Color(0xFF0F172A),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.report, color: Colors.green, size: 24),
                SizedBox(width: 8),
                Text(
                  'Rapports personnalisables',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTemplateSelector(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildPeriodSelector(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildAutoSendToggle(),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Templates prédéfinis', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: selectedTemplate,
            dropdownColor: const Color(0xFF1E293B),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            items: const [
              DropdownMenuItem(value: 'Bilan pédagogique', child: Text('📚 Bilan pédagogique')),
              DropdownMenuItem(value: 'Situation trésorerie', child: Text('💰 Situation trésorerie')),
              DropdownMenuItem(value: 'Rapport complet', child: Text('📊 Rapport complet')),
              DropdownMenuItem(value: 'Analyse mensuelle', child: Text('📈 Analyse mensuelle')),
            ],
            onChanged: (value) => setState(() => selectedTemplate = value ?? selectedTemplate),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  Widget _buildPeriodSelector() {
    final formatter = DateFormat('dd/MM/yyyy');
    final rangeText = _selectedDateRange != null
        ? '${formatter.format(_selectedDateRange!.start)} - ${formatter.format(_selectedDateRange!.end)}'
        : 'Sélectionner une période';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Période', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextButton.icon(
            icon: const Icon(Icons.calendar_today, color: Colors.white70, size: 16),
            label: Text(rangeText, style: const TextStyle(color: Colors.white)),
            onPressed: () => _selectDateRange(context),
          )
        ],
      ),
    );
  }

  Widget _buildAutoSendToggle() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Planification automatique', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              Text('Envoi automatique des rapports', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          Switch(
            value: autoSendEnabled,
            onChanged: (value) => setState(() => autoSendEnabled = value),
            activeColor: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildReportGenerator() {
    return Card(
      color: const Color(0xFF0F172A),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.build, color: Colors.orange, size: 24),
                SizedBox(width: 8),
                Text(
                  'Générateur de requêtes visuelles',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DragTarget<Map<String, String>>(
              onWillAccept: (data) {
                setState(() {
                  _isHovering = true;
                });
                return true;
              },
              onLeave: (data) {
                setState(() {
                  _isHovering = false;
                });
              },
              onAccept: (data) {
                setState(() {
                  _reportWidgets.add(data);
                  _isHovering = false;
                });
              },
              builder: (context, candidateData, rejectedData) {
                return Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _isHovering ? Colors.blue.withOpacity(0.1) : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _isHovering ? Colors.blue : Colors.white24),
                  ),
                  child: _reportWidgets.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.drag_indicator, color: Colors.white54, size: 48),
                              SizedBox(height: 8),
                              Text(
                                'Zone de construction visuelle',
                                style: TextStyle(color: Colors.white70, fontSize: 16),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Glissez-déposez les éléments pour créer votre rapport',
                                style: TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : ReorderableListView(
                          padding: const EdgeInsets.all(8.0),
                          children: [
                            for (int i = 0; i < _reportWidgets.length; i++)
                              Card(
                                key: ValueKey(_reportWidgets[i]),
                                color: const Color(0xFF334155),
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  leading: const Icon(Icons.drag_handle, color: Colors.white70),
                                  title: Text(_reportWidgets[i]['label']!,
                                      style: const TextStyle(color: Colors.white)),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                                    onPressed: () {
                                      setState(() {
                                        _reportWidgets.removeAt(i);
                                      });
                                    },
                                  ),
                                ),
                              ),
                          ],
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (newIndex > oldIndex) {
                                newIndex -= 1;
                              }
                              final item = _reportWidgets.removeAt(oldIndex);
                              _reportWidgets.insert(newIndex, item);
                            });
                          },
                        ),
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _buildDraggableElement('graph', '📊', 'Graphiques'),
                    const SizedBox(width: 8),
                    _buildDraggableElement('table', '📋', 'Tableaux'),
                    const SizedBox(width: 8),
                    _buildDraggableElement('kpi', '🎯', 'KPI'),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _generateReport, // Changed to _generateReport
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Générer le rapport'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraggableElement(String type, String icon, String label) {
    final data = {'type': type, 'label': label};
    return Draggable<Map<String, String>>(
      data: data,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF334155).withOpacity(0.8),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF334155),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  void _exportReport(String format) async {
    if (_selectedDateRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une période pour le rapport.'), backgroundColor: Colors.red),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Génération du rapport "${selectedTemplate}" en $format...'), backgroundColor: Colors.blue),
    );

    try {
      Uint8List? bytes;
      String fileExtension;

      if (format == 'PDF') {
        fileExtension = 'pdf';
        final pdf = pw.Document();
        late pw.Widget reportContentPdf;

        switch (selectedTemplate) {
          case 'Bilan pédagogique':
            reportContentPdf = await _buildBilanPedagogiquePdfContent(_selectedDateRange!);
            break;
          case 'Situation trésorerie':
            reportContentPdf = await _buildTresoreriePdfContent(_selectedDateRange!);
            break;
          default:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Le modèle de rapport "${selectedTemplate}" n est pas encore supporté pour l export PDF.'), backgroundColor: Colors.red),
            );
            return;
        }

        pdf.addPage(pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) => [
            pw.Center(child: pw.Text(selectedTemplate, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 20),
            reportContentPdf,
          ],
        ));
        bytes = await pdf.save();
      } else if (format == 'CSV') {
        fileExtension = 'csv';
        String? csvContent;
        switch (selectedTemplate) {
          case 'Bilan pédagogique':
            final db = DatabaseService();
            final inscriptions = await db.getInscriptionsByDateRange(
              _selectedDateRange!.start.millisecondsSinceEpoch,
              _selectedDateRange!.end.millisecondsSinceEpoch,
            );
            if (inscriptions.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Aucune inscription trouvée pour la période sélectionnée pour l export CSV.'), backgroundColor: Colors.orange),
              );
              return;
            }
            csvContent = _generateBilanPedagogiqueCsv(inscriptions);
            break;
          case 'Situation trésorerie':
            final db = DatabaseService();
            final payments = await db.getEcritures(
              start: _selectedDateRange!.start,
              end: _selectedDateRange!.end,
            );
            final filteredPayments = payments.where((e) => (e['debit'] as num? ?? 0) > 0).toList();
            if (filteredPayments.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Aucune transaction de trésorerie trouvée pour la période sélectionnée pour l export CSV.'), backgroundColor: Colors.orange),
              );
              return;
            }
            csvContent = _generateTresorerieCsv(filteredPayments);
            break;
          case 'Analyse mensuelle':
            final data = await _getAnalyseMensuelleData();
            csvContent = _generateAnalyseMensuelleCsv(data);
            if (csvContent.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Aucune donnée pour la période sélectionnée.'), backgroundColor: Colors.orange),
              );
              return;
            }
            break;
          default:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Le modèle de rapport "${selectedTemplate}" n est pas encore supporté pour l export CSV.'), backgroundColor: Colors.red),
            );
            return;
        }
        if (csvContent != null) {
          bytes = Uint8List.fromList(utf8.encode(csvContent));
        }
      } else if (format == 'Excel') {
        fileExtension = 'xlsx';
        switch (selectedTemplate) {
          case 'Bilan pédagogique':
            final db = DatabaseService();
            final inscriptions = await db.getInscriptionsByDateRange(
              _selectedDateRange!.start.millisecondsSinceEpoch,
              _selectedDateRange!.end.millisecondsSinceEpoch,
            );
            if (inscriptions.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Aucune inscription trouvée pour la période sélectionnée pour l export Excel.'), backgroundColor: Colors.orange),
              );
              return;
            }
            bytes = await _generateBilanPedagogiqueExcel(inscriptions);
            break;
          case 'Situation trésorerie':
            final db = DatabaseService();
            final payments = await db.getEcritures(
              start: _selectedDateRange!.start,
              end: _selectedDateRange!.end,
            );
            final filteredPayments = payments.where((e) => (e['debit'] as num? ?? 0) > 0).toList();
            if (filteredPayments.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Aucune transaction de trésorerie trouvée pour la période sélectionnée pour l export Excel.'), backgroundColor: Colors.orange),
              );
              return;
            }
            bytes = await _generateTresorerieExcel(filteredPayments);
            break;
          case 'Analyse mensuelle':
            final data = await _getAnalyseMensuelleData();
            bytes = await _generateAnalyseMensuelleExcel(data);
            if (bytes == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Aucune donnée pour la période sélectionnée.'), backgroundColor: Colors.orange),
              );
              return;
            }
            break;
          default:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Le modèle de rapport "${selectedTemplate}" n est pas encore supporté pour l export Excel.'), backgroundColor: Colors.red),
            );
            return;
        }
      } else {
        // Should not happen
        return;
      }

      if (bytes != null) {
        final fileName = '${selectedTemplate.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(_selectedDateRange!.start)}_${DateFormat('yyyyMMdd').format(_selectedDateRange!.end)}.$fileExtension';
        final filePath = await FilePicker.platform.saveFile(
          dialogTitle: 'Sauvegarder le rapport $format',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: [fileExtension],
        );

        if (filePath != null) {
          final file = File(filePath);
          await file.writeAsBytes(bytes);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rapport sauvegardé dans $filePath')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sauvegarde du rapport annulée.')));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur lors de la génération ou de la sauvegarde du rapport: $e'), backgroundColor: Colors.red));
    }
  }

  Future<Uint8List?> _generateBilanPedagogiqueExcel(List<Map<String, Object?>> inscriptions) async {
    final excel = excel_lib.Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet()!];

    // Add headers
    sheet.appendRow([ excel_lib.TextCellValue('Étudiant'),  excel_lib.TextCellValue('Formation'),  excel_lib.TextCellValue('Date Inscription'),  excel_lib.TextCellValue('Statut')]);

    // Add data rows
    for (final inscription in inscriptions) {
      final studentName = inscription['studentName'] as String? ?? 'N/A'; // This line is causing the error
      final formationTitle = inscription['formationTitle'] as String? ?? 'N/A';
      final inscriptionDateMs = inscription['inscriptionDate'] as int?;
      final inscriptionDate = inscriptionDateMs != null
          ? DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(inscriptionDateMs))
          : 'N/A';
      final status = inscription['inscriptionStatus'] as String? ?? 'N/A';
      sheet.appendRow([excel_lib.TextCellValue(studentName), excel_lib.TextCellValue(formationTitle), excel_lib.TextCellValue(inscriptionDate), excel_lib.TextCellValue(status)]);
    } // This line is causing the error

    final bytes = excel.encode();
    return bytes != null ? Uint8List.fromList(bytes) : null;
  }

  Future<Uint8List?> _generateTresorerieExcel(List<Map<String, Object?>> payments) async {
    final excel = excel_lib.Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet()!];

    // Add headers
    sheet.appendRow([ excel_lib.TextCellValue('Date'),  excel_lib.TextCellValue('Référence'),  excel_lib.TextCellValue('Libellé'),  excel_lib.TextCellValue('Montant')]);

    // Add data rows
    for (final payment in payments) {
      final dateMs = payment['date'] as int?;
      final date = dateMs != null
          ? DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(dateMs))
          : 'N/A';
      final reference = payment['reference'] as String? ?? 'N/A';
      final label = payment['label'] as String? ?? 'N/A';
      final amount = (payment['debit'] as num? ?? 0).toDouble(); // This line is causing the error
      sheet.appendRow([excel_lib.TextCellValue(date), excel_lib.TextCellValue(reference), excel_lib.TextCellValue(label), excel_lib.TextCellValue(_currencyFormat.format(amount))]);
    }

    final bytes = excel.encode();
    return bytes != null ? Uint8List.fromList(bytes) : null;
  }

  Future<Uint8List?> _generateAnalyseMensuelleExcel(Map<String, dynamic> data) async {
    final inscriptions = data['inscriptions'] as List<Map<String, Object?>>? ?? const [];
    final payments = data['payments'] as List<Map<String, Object?>>? ?? const [];
    final totalRevenue = (data['totalRevenue'] as num? ?? 0).toDouble();
    if (inscriptions.isEmpty && payments.isEmpty) return null;

    final excel = excel_lib.Excel.createExcel();
    final sheet1 = excel['Inscriptions'];
    sheet1.appendRow([excel_lib.TextCellValue('Étudiant'), excel_lib.TextCellValue('Formation'), excel_lib.TextCellValue('Date Inscription'), excel_lib.TextCellValue('Statut')]);
    for (final ins in inscriptions) {
      final studentName = ins['studentName'] as String? ?? 'N/A';
      final formationTitle = ins['formationTitle'] as String? ?? 'N/A';
      final dms = ins['inscriptionDate'] as int?;
      final date = dms != null ? DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(dms)) : 'N/A';
      final status = ins['inscriptionStatus'] as String? ?? 'N/A';
      sheet1.appendRow([excel_lib.TextCellValue(studentName), excel_lib.TextCellValue(formationTitle), excel_lib.TextCellValue(date), excel_lib.TextCellValue(status)]);
    }

    final sheet2 = excel['Encaissements'];
    sheet2.appendRow([excel_lib.TextCellValue('Date'), excel_lib.TextCellValue('Référence'), excel_lib.TextCellValue('Libellé'), excel_lib.TextCellValue('Montant')]);
    for (final p in payments) {
      final dms = p['date'] as int?;
      final date = dms != null ? DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(dms)) : 'N/A';
      final ref = p['reference'] as String? ?? 'N/A';
      final label = p['label'] as String? ?? 'N/A';
      final amount = (p['debit'] as num? ?? 0).toDouble();
      sheet2.appendRow([excel_lib.TextCellValue(date), excel_lib.TextCellValue(ref), excel_lib.TextCellValue(label), excel_lib.TextCellValue(_currencyFormat.format(amount))]);
    }

    final sheet3 = excel['Synthèse'];
    sheet3.appendRow([excel_lib.TextCellValue('Période'), excel_lib.TextCellValue('${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.end)}')]);
    sheet3.appendRow([excel_lib.TextCellValue('Total encaissements'), excel_lib.TextCellValue(_currencyFormat.format(totalRevenue))]);

    final bytes = excel.encode();
    return bytes != null ? Uint8List.fromList(bytes) : null;
  }

  // New methods to generate PDF content
  Future<pw.Widget> _buildBilanPedagogiquePdfContent(DateTimeRange dateRange) async {
    final db = DatabaseService();
    final inscriptions = await db.getInscriptionsByDateRange(
      dateRange.start.millisecondsSinceEpoch,
      dateRange.end.millisecondsSinceEpoch,
    );

    if (inscriptions.isEmpty) {
      return pw.Center(
        child: pw.Text('Aucune inscription trouvée pour la période sélectionnée.'),
      );
    }

    // Prepare table headers
    final headers = ['Étudiant', 'Formation', 'Date Inscription', 'Statut'];

    // Prepare table rows
    final data = inscriptions.map((inscription) {
      final studentName = inscription['studentName'] as String? ?? 'N/A';
      final formationTitle = inscription['formationTitle'] as String? ?? 'N/A';
      final inscriptionDateMs = inscription['inscriptionDate'] as int?;
      final inscriptionDate = inscriptionDateMs != null
          ? DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(inscriptionDateMs))
          : 'N/A';
      final status = inscription['inscriptionStatus'] as String? ?? 'N/A';
      return [studentName, formationTitle, inscriptionDate, status];
    }).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Bilan Pédagogique',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'Période: ${DateFormat('dd/MM/yyyy').format(dateRange.start)} - ${DateFormat('dd/MM/yyyy').format(dateRange.end)}',
          style: pw.TextStyle(fontSize: 12),
        ),
        pw.SizedBox(height: 20),
        pw.Table.fromTextArray(
          headers: headers,
          data: data,
          border: pw.TableBorder.all(color: PdfColors.grey),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellAlignment: pw.Alignment.centerLeft,
          cellPadding: const pw.EdgeInsets.all(5),
        ),
      ],
    );
  }

  Future<pw.Widget> _buildTresoreriePdfContent(DateTimeRange dateRange) async {
    final db = DatabaseService();
    final payments = await db.getEcritures(
      start: dateRange.start,
      end: dateRange.end,
      // Assuming 'journalId' can be used to filter for treasury-related entries,
      // or we might need a more specific method in DatabaseService for payments.
      // For now, I'll assume getEcritures can fetch relevant financial entries.
    );

    // Filter for actual payments if getEcritures returns all accounting entries
    // This might need refinement based on how payments are recorded in ecritures_comptables
    // For now, I'll assume 'debit' represents incoming payments for simplicity in this report.
    final filteredPayments = payments.where((e) => (e['debit'] as num? ?? 0) > 0).toList();

    if (filteredPayments.isEmpty) {
      return pw.Center(
        child: pw.Text('Aucune transaction de trésorerie trouvée pour la période sélectionnée.'),
      );
    }

    final totalEncaissements = filteredPayments.fold<double>(0.0, (sum, p) => sum + (p['debit'] as num? ?? 0).toDouble());

    // Prepare table headers
    final headers = ['Date', 'Référence', 'Libellé', 'Montant'];

    // Prepare table rows
    final data = filteredPayments.map((payment) {
      final dateMs = payment['date'] as int?;
      final date = dateMs != null
          ? DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(dateMs))
          : 'N/A';
      final reference = payment['reference'] as String? ?? 'N/A';
      final label = payment['label'] as String? ?? 'N/A';
      final amount = (payment['debit'] as num? ?? 0).toDouble();
      return [date, reference, label, '${_currencyFormat.format(amount)} FCFA'];
    }).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Situation de Trésorerie',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'Période: ${DateFormat('dd/MM/yyyy').format(dateRange.start)} - ${DateFormat('dd/MM/yyyy').format(dateRange.end)}',
          style: pw.TextStyle(fontSize: 12),
        ),
        pw.SizedBox(height: 20),
        pw.Text(
          'Total des encaissements: ${_currencyFormat.format(totalEncaissements)} FCFA',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Table.fromTextArray(
          headers: headers,
          data: data,
          border: pw.TableBorder.all(color: PdfColors.grey),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellAlignment: pw.Alignment.centerLeft,
          cellPadding: const pw.EdgeInsets.all(5),
        ),
      ],
    );
  }

  String _generateBilanPedagogiqueCsv(List<Map<String, Object?>> inscriptions) {
    final StringBuffer csvBuffer = StringBuffer();
    // Add CSV header
    csvBuffer.writeln('Etudiant,Formation,Date Inscription,Statut');

    // Add data rows
    for (final inscription in inscriptions) {
      final studentName = inscription['studentName'] as String? ?? 'N/A';
      final formationTitle = inscription['formationTitle'] as String? ?? 'N/A';
      final inscriptionDateMs = inscription['inscriptionDate'] as int?;
      final inscriptionDate = inscriptionDateMs != null ? DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(inscriptionDateMs)) : 'N/A';
      final status = inscription['inscriptionStatus'] as String? ?? 'N/A';
      csvBuffer.writeln('$studentName,$formationTitle,$inscriptionDate,$status');
    }
    return csvBuffer.toString();
  }

  String _generateTresorerieCsv(List<Map<String, Object?>> payments) {
    final StringBuffer csvBuffer = StringBuffer();
    // Add CSV header
    csvBuffer.writeln('Date,Reference,Libelle,Montant');

    // Add data rows
    for (final payment in payments) {
      final dateMs = payment['date'] as int?;
      final date = dateMs != null ? DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(dateMs)) : 'N/A';
      final reference = payment['reference'] as String? ?? 'N/A';
      final label = payment['label'] as String? ?? 'N/A';
      final amount = (payment['debit'] as num? ?? 0).toDouble();
      csvBuffer.writeln('$date,$reference,$label,${_currencyFormat.format(amount)}');
    }

    return csvBuffer.toString();
  }

  String _generateAnalyseMensuelleCsv(Map<String, dynamic> data) {
    final inscriptions = data['inscriptions'] as List<Map<String, Object?>>? ?? const [];
    final payments = data['payments'] as List<Map<String, Object?>>? ?? const [];
    final totalRevenue = (data['totalRevenue'] as num? ?? 0).toDouble();
    final StringBuffer csv = StringBuffer();
    // Section header
    csv.writeln('Analyse mensuelle');
    csv.writeln('Période,${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.end)}');
    csv.writeln('Total encaissements,${_currencyFormat.format(totalRevenue)}');
    csv.writeln();
    // Inscriptions
    csv.writeln('Inscriptions');
    csv.writeln('Étudiant,Formation,Date Inscription,Statut');
    for (final ins in inscriptions) {
      final studentName = ins['studentName'] as String? ?? 'N/A';
      final formationTitle = ins['formationTitle'] as String? ?? 'N/A';
      final dms = ins['inscriptionDate'] as int?;
      final date = dms != null ? DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(dms)) : 'N/A';
      final status = ins['inscriptionStatus'] as String? ?? 'N/A';
      csv.writeln('$studentName,$formationTitle,$date,$status');
    }
    csv.writeln();
    // Paiements
    csv.writeln('Encaissements');
    csv.writeln('Date,Référence,Libellé,Montant');
    for (final p in payments) {
      final dms = p['date'] as int?;
      final date = dms != null ? DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(dms)) : 'N/A';
      final ref = p['reference'] as String? ?? 'N/A';
      final label = p['label'] as String? ?? 'N/A';
      final amount = (p['debit'] as num? ?? 0).toDouble();
      csv.writeln('$date,$ref,$label,${_currencyFormat.format(amount)}');
    }
    return csv.toString();
  }


  void _generateReport() {
    if (_selectedDateRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner une période.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Widget reportContent;
    switch (selectedTemplate) {
      case 'Bilan pédagogique':
        reportContent = _buildBilanPedagogiquePreview();
        break;
      case 'Situation trésorerie':
        reportContent = _buildTresoreriePreview();
        break;
      case 'Analyse mensuelle':
        reportContent = _buildAnalyseMensuellePreview();
        break;
      case 'Rapport complet':
        reportContent = _buildRapportCompletPreview();
        break;
      default:
        reportContent = Text('Le modèle de rapport "$selectedTemplate" n est pas encore implémenté.');
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Aperçu du rapport: $selectedTemplate', style: const TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 800,
          height: 600,
          child: reportContent,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildBilanPedagogiquePreview([List<dynamic>? data]) { // data parameter is unused, can be removed
    return FutureBuilder<List<Map<String, Object?>>>(
      future: DatabaseService().getInscriptionsByDateRange(
        _selectedDateRange!.start.millisecondsSinceEpoch,
        _selectedDateRange!.end.millisecondsSinceEpoch,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Aucune inscription trouvée pour la période sélectionnée.', style: TextStyle(color: Colors.white)));
        }

        final inscriptions = snapshot.data!;

        return ListView.builder(
          itemCount: inscriptions.length,
          itemBuilder: (context, index) {
            final inscription = inscriptions[index];
            final studentName = inscription['studentName'] as String? ?? 'N/A';
            final formationTitle = inscription['formationTitle'] as String? ?? 'N/A';
            final status = inscription['inscriptionStatus'] as String? ?? 'N/A';

            return Card(
              color: const Color(0xFF334155),
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                title: Text(studentName, style: const TextStyle(color: Colors.white)),
                subtitle: Text(formationTitle, style: const TextStyle(color: Colors.white70)),
                trailing: Text(status, style: const TextStyle(color: Colors.cyan)),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTresoreriePreview([List<dynamic>? data]) { // data parameter is unused, can be removed
    return FutureBuilder<List<Map<String, Object?>>>(
      future: DatabaseService().getEcritures(
        start: _selectedDateRange!.start,
        end: _selectedDateRange!.end,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Aucune transaction de trésorerie trouvée pour la période sélectionnée.'),
          );
        }

        final payments = snapshot.data!;
        final filteredPayments = payments.where((e) => (e['debit'] as num? ?? 0) > 0).toList();
        final total = filteredPayments.fold<double>(0.0, (sum, p) => sum + (p['debit'] as num? ?? 0).toDouble());

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('Total des encaissements: ${NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA').format(total)}', 
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: filteredPayments.length,
                itemBuilder: (context, index) {
                  final payment = filteredPayments[index];
                  final date = payment['date'] != null
                      ? DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(payment['date'] as int))
                      : 'N/A';
                  final amount = (payment['debit'] as num? ?? 0).toDouble();
                  final label = payment['label'] as String? ?? 'N/A';
                  final reference = payment['reference'] as String? ?? 'N/A';

                  return Card(
                    color: const Color(0xFF334155),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text('${_currencyFormat.format(amount)} FCFA - $label', style: const TextStyle(color: Colors.white)),
                      subtitle: Text('Référence: $reference', style: const TextStyle(color: Colors.white70)),
                      trailing: Text(date, style: const TextStyle(color: Colors.white70)),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAnalyseMensuellePreview() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getAnalyseMensuelleData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Aucune donnée trouvée pour la période sélectionnée.', style: TextStyle(color: Colors.white)));
        }

        final data = snapshot.data!;
        final totalRevenue = data['totalRevenue'] as double;
        final inscriptions = data['inscriptions'] as List<Map<String, Object?>>;
        final payments = data['payments'] as List<Map<String, Object?>>;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Analyse Mensuelle', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildKpiCard('Chiffre d\'Affaires', '${_currencyFormat.format(totalRevenue)} FCFA', Icons.trending_up, Colors.green),
                  _buildKpiCard('Nouvelles Inscriptions', inscriptions.length.toString(), Icons.person_add, Colors.blue),
                ],
              ),
              const SizedBox(height: 16),
              Text('Détail des Encaissements', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
              const SizedBox(height: 8),
              _buildPaymentsList(payments),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRapportCompletPreview() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Rapport Complet', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white)),
          ),
          const Divider(color: Colors.white54),
          
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Bilan Pédagogique', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
          ),
          SizedBox(height: 300, child: _buildBilanPedagogiquePreview()),
          
          const Divider(color: Colors.white54),
          
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Situation de Trésorerie', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
          ),
          SizedBox(height: 300, child: _buildTresoreriePreview()),

          const Divider(color: Colors.white54),

          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Analyse Financière', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
          ),
          FutureBuilder<Map<String, dynamic>>(
            future: _analyticsFuture, // Reuse the main future
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Erreur: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('Aucune donnée disponible.', style: TextStyle(color: Colors.white)));
              }
              final data = snapshot.data!;
              return _buildRatiosFinanciers(data);
            },
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _getAnalyseMensuelleData() async {
    final db = DatabaseService();
    final inscriptions = await db.getInscriptionsByDateRange(
      _selectedDateRange!.start.millisecondsSinceEpoch,
      _selectedDateRange!.end.millisecondsSinceEpoch,
    );
    final payments = await db.getEcritures(
      start: _selectedDateRange!.start,
      end: _selectedDateRange!.end,
    );
    final filteredPayments = payments.where((e) => (e['debit'] as num? ?? 0) > 0).toList();
    final totalRevenue = filteredPayments.fold<double>(0.0, (sum, p) => sum + (p['debit'] as num? ?? 0).toDouble());

    return {
      'totalRevenue': totalRevenue,
      'inscriptions': inscriptions,
      'payments': filteredPayments,
    };
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Card(
      color: const Color(0xFF1E293B),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentsList(List<Map<String, Object?>> payments) {
    if (payments.isEmpty) {
      return const Center(child: Text('Aucun encaissement pour cette période.', style: TextStyle(color: Colors.white70)));
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: payments.length,
      itemBuilder: (context, index) {
        final payment = payments[index];
        final date = payment['date'] != null
            ? DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(payment['date'] as int))
            : 'N/A';
        final amount = (payment['debit'] as num? ?? 0).toDouble();
        final label = payment['label'] as String? ?? 'N/A';
        return Card(
          color: const Color(0xFF334155),
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: const Icon(Icons.payment, color: Colors.green),
            title: Text('${_currencyFormat.format(amount)} FCFA', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text(label, style: const TextStyle(color: Colors.white70)),
            trailing: Text(date, style: const TextStyle(color: Colors.white70)),
          ),
        );
      },
    );
  }
}
