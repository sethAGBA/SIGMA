import 'dart:io';

import 'package:flutter/material.dart';
import '../widgets/stat_card.dart';
import '../widgets/chart_card.dart';
import '../services/database_service.dart';
import '../models/formation.dart';
import 'package:fl_chart/fl_chart.dart';

class DashboardScreen extends StatefulWidget {
  final Animation<double> fadeAnimation;

  const DashboardScreen({Key? key, required this.fadeAnimation}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<Formation>> _formationsFuture;
  late Future<Map<String, Object>> _metricsFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _formationsFuture = DatabaseService().getFormations();
    _metricsFuture = _loadMetrics();
  }

  Future<void> _showQuickNewStudentDialog(List<Formation> formations) async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String selectedFormation = formations.isNotEmpty ? formations.first.id : '';
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx2, setState2) {
        return AlertDialog(
          title: const Text('Nouvel étudiant (rapide)'),
          content: Form(
            key: formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nom'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email requis';
                    final re = RegExp(r"^[^\s@]+@[^\s@]+\.[^\s@]+$");
                    return re.hasMatch(v.trim()) ? null : 'Email invalide';
                  },
                ),
                const SizedBox(height: 8),
                if (formations.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: selectedFormation.isNotEmpty ? selectedFormation : null,
                    items: formations.map((f) => DropdownMenuItem(value: f.id, child: Text(f.title))).toList(),
                    onChanged: (v) => setState2(() => selectedFormation = v ?? ''),
                    decoration: const InputDecoration(labelText: 'Formation'),
                    validator: (v) => (v == null || v.isEmpty) ? 'Formation requise' : null,
                  ),
                if (formations.isEmpty)
                  const Text('Aucune formation disponible', style: TextStyle(color: Colors.orange)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                final name = nameCtrl.text.trim();
                final email = emailCtrl.text.trim();
                final studentId = DateTime.now().millisecondsSinceEpoch.toString();
                final studentNumber = 'ST${studentId}';
                final m = {
                  'id': studentId,
                  'studentNumber': studentNumber,
                  'name': name,
                  'photo': '',
                  'address': '',
                  'formation': selectedFormation,
                  'paymentStatus': 'Impayé',
                  'phone': '',
                  'email': email,
                };
                await DatabaseService().insertStudent(m);
                if (selectedFormation.isNotEmpty) {
                  final ins = {
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'studentId': studentId,
                    'formationId': selectedFormation,
                    'inscriptionDate': DateTime.now().millisecondsSinceEpoch,
                    'status': 'En cours',
                  };
                  await DatabaseService().addInscription(ins);
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      }),
    );

    if (saved == true) {
      _loadData();
      setState(() {});
    }
  }

  Future<void> _showNewPaymentDialog() async {
    final db = DatabaseService();
    final students = await db.getStudents();
    String? selectedStudentId = students.isNotEmpty ? students.first.id : null;
    List<Map<String, Object?>> inscriptions = [];
    String? selectedInscriptionId;
    final amountCtrl = TextEditingController();
    String method = 'Espèces';

    if (selectedStudentId != null) {
      final ins = await db.getInscriptionsForStudent(selectedStudentId);
      inscriptions = ins.map((i) => {'id': i.id, 'title': i.formationTitle ?? i.formationId}).toList();
      if (inscriptions.isNotEmpty) selectedInscriptionId = inscriptions.first['id'] as String?;
    }

    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx2, setState2) {
        return AlertDialog(
          title: const Text('Saisie paiement rapide'),
          content: Form(
            key: formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (students.isEmpty) const Text('Aucun étudiant trouvé.'),
                if (students.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: selectedStudentId,
                    items: students.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                    onChanged: (v) async {
                      selectedStudentId = v;
                      // load inscriptions for this student
                      final ins = await db.getInscriptionsForStudent(selectedStudentId!);
                      inscriptions = ins.map((i) => {'id': i.id, 'title': i.formationTitle ?? i.formationId}).toList();
                      selectedInscriptionId = inscriptions.isNotEmpty ? inscriptions.first['id'] as String? : null;
                      setState2(() {});
                    },
                    decoration: const InputDecoration(labelText: 'Étudiant'),
                    validator: (v) => (v == null || v.isEmpty) ? 'Étudiant requis' : null,
                  ),
                const SizedBox(height: 8),
                if (inscriptions.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: selectedInscriptionId,
                    items: inscriptions.map((i) => DropdownMenuItem(value: i['id'] as String?, child: Text(i['title'] as String))).toList(),
                    onChanged: (v) => selectedInscriptionId = v,
                    decoration: const InputDecoration(labelText: 'Inscription'),
                  ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: amountCtrl,
                  decoration: const InputDecoration(labelText: 'Montant'),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final a = double.tryParse(v ?? '');
                    if (a == null || a <= 0) return 'Montant requis (>0)';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: method,
                  items: ['Espèces', 'Carte', 'Mobile Money', 'Virement', 'Chèque', 'Autre'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (v) => method = v ?? method,
                  decoration: const InputDecoration(labelText: 'Méthode'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                final amount = double.tryParse(amountCtrl.text) ?? 0.0;
                if (selectedStudentId == null || amount <= 0) return;
                final payment = {
                  'id': DateTime.now().millisecondsSinceEpoch.toString(),
                  'studentId': selectedStudentId,
                  'inscriptionId': selectedInscriptionId ?? '',
                  'formationId': '',
                  'amount': amount,
                  'method': method,
                  'note': '',
                  'createdAt': DateTime.now().millisecondsSinceEpoch,
                };
                await db.insertPayment(payment);
                Navigator.pop(ctx, true);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      }),
    );

    if (saved == true) {
      _loadData();
      setState(() {});
    }
  }

  Future<void> _runQuickReport() async {
    try {
      final path = await DatabaseService().exportCSV();
      await showDialog(context: context, builder: (c) => AlertDialog(title: const Text('Rapport exporté'), content: Text(path), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK')), ElevatedButton(onPressed: () async { Navigator.pop(c); if (Platform.isMacOS) await Process.run('open', [path]); else if (Platform.isLinux) await Process.run('xdg-open', [path]); else if (Platform.isWindows) await Process.run('cmd', ['/c', 'start', '', path]); }, child: const Text('Ouvrir'))]));
    } catch (e) {
      await showDialog(context: context, builder: (c) => AlertDialog(title: const Text('Erreur'), content: Text(e.toString()), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))]));
    }
  }

  Future<Map<String, Object>> _loadMetrics() async {
    final db = DatabaseService();
    final now = DateTime.now();
    final students = await db.countStudents();
    final studentsDebt = await db.countStudentsInDebt();
    final sessionsAlmostFull = await db.countSessionsAlmostFull();
    final paymentsThisMonth = await db.countPaymentsInMonth(now.year, now.month);
    final revenueThisMonth = await db.sumPaymentsInMonth(now.year, now.month);
    final recoveryRate = await db.getRecoveryRate();

    return {
      'students': students,
      'studentsDebt': studentsDebt,
      'sessionsAlmostFull': sessionsAlmostFull,
      'paymentsThisMonth': paymentsThisMonth,
      'revenueThisMonth': revenueThisMonth,
      'recoveryRate': recoveryRate,
    };
  }

  String _formatNumber(Object n) => n.toString();

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: widget.fadeAnimation,
      child: FutureBuilder<List<Formation>>(
        future: _formationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }

          final formations = snapshot.data ?? [];
          final formationsCount = formations.length;
          final sessionsCount = formations.fold<int>(0, (acc, f) => acc + (f.sessions.length));
          final formateursCount = formations.fold<int>(0, (acc, f) => acc + (f.formateurs.length));
          final totalRevenue = formations.fold<double>(0.0, (acc, f) => acc + (f.revenue));
          final totalEnrollments = formations.fold<int>(0, (acc, f) => acc + (f.enrolledStudents));

          return Stack(
            children: [
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                // Top row: stats (quick actions moved to top-right overlay)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          // main stats — give them full available width so five cards are wider
                          Expanded(
                            child: Row(
                              children: [
                                StatCard(
                                  title: 'Chiffre d\'Affaires',
                                  value: '${_formatNumber(totalRevenue.toStringAsFixed(0))} FCFA',
                                  icon: Icons.trending_up,
                                  color: const Color(0xFF10B981),
                                  change: '',
                                ),
                                const SizedBox(width: 24),
                                StatCard(
                                  title: 'Inscriptions',
                                  value: _formatNumber(totalEnrollments),
                                  icon: Icons.people,
                                  color: const Color(0xFF06B6D4),
                                  change: '',
                                ),
                                const SizedBox(width: 24),
                                StatCard(
                                  title: 'Formations',
                                  value: _formatNumber(formationsCount),
                                  icon: Icons.school,
                                  color: const Color(0xFF8B5CF6),
                                  change: '',
                                ),
                                const SizedBox(width: 24),
                                StatCard(
                                  title: 'Sessions',
                                  value: _formatNumber(sessionsCount),
                                  icon: Icons.event,
                                  color: const Color(0xFF06B6D4),
                                  change: '',
                                ),
                                const SizedBox(width: 24),
                                StatCard(
                                  title: 'Formateurs',
                                  value: _formatNumber(formateursCount),
                                  icon: Icons.person,
                                  color: const Color(0xFFEF4444),
                                  change: '',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                FutureBuilder<Map<String, Object>>(
                  future: _metricsFuture,
                  builder: (ctx, mSnap) {
                    if (mSnap.connectionState != ConnectionState.done) {
                      return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
                    }
                    final m = mSnap.data ?? {};
                    final students = m['students'] as int? ?? 0;
                    final studentsDebt = m['studentsDebt'] as int? ?? 0;
                    final sessionsAlmostFull = m['sessionsAlmostFull'] as int? ?? 0;
                    final paymentsThisMonth = m['paymentsThisMonth'] as int? ?? 0;
                    final revenueThisMonth = m['revenueThisMonth'] as double? ?? 0.0;
                    final recoveryRate = m['recoveryRate'] as double? ?? 0.0;

                    return Column(
                      children: [
                        Row(
                          children: [
                            StatCard(
                              title: 'Étudiants',
                              value: _formatNumber(students),
                              icon: Icons.school_outlined,
                              color: const Color(0xFF6366F1),
                              change: '',
                            ),
                            const SizedBox(width: 24),
                            StatCard(
                              title: 'Transactions (mois)',
                              value: _formatNumber(paymentsThisMonth),
                              icon: Icons.receipt_long,
                              color: const Color(0xFF10B981),
                              change: '',
                            ),
                            const SizedBox(width: 24),
                            StatCard(
                              title: 'Taux de recouvrement',
                              value: '${recoveryRate.toStringAsFixed(0)}%',
                              icon: Icons.pie_chart,
                              color: const Color(0xFF059669),
                              change: '',
                            ),
                            const SizedBox(width: 24),
                            StatCard(
                              title: 'Sessions presque pleines',
                              value: _formatNumber(sessionsAlmostFull),
                              icon: Icons.event_available,
                              color: const Color(0xFF8B5CF6),
                              change: '',
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Row(
                          children: [
                          StatCard(
                            title: 'CA du mois',
                            value: '${revenueThisMonth.toStringAsFixed(0)} FCFA',
                            icon: Icons.calendar_month,
                            color: const Color(0xFF10B981),
                            change: '',
                          ),
                          const SizedBox(width: 24),
                          StatCard(
                            title: 'Encaissements',
                            value: '${revenueThisMonth.toStringAsFixed(0)} FCFA',
                            icon: Icons.attach_money,
                            color: const Color(0xFF06B6D4),
                            change: '',
                          ),
                          const SizedBox(width: 24),
                          StatCard(
                            title: 'Étudiants en impayés',
                            value: _formatNumber(studentsDebt),
                            icon: Icons.warning,
                            color: const Color(0xFFEF4444),
                            change: '',
                          ),
                          const SizedBox(width: 24),
                          StatCard(
                            title: 'Sessions presque pleines',
                            value: _formatNumber(sessionsAlmostFull),
                            icon: Icons.event_busy,
                            color: const Color(0xFF8B5CF6),
                            change: '',
                          ),
                          ],
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Charts Row — left chart now renders a simple revenue bar chart based on formations
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: ChartCard(
                        title: 'Évolution du Chiffre d\'Affaires',
                        chart: _RevenueBarChart(formations: formations),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: ChartCard(
                        title: 'Répartition par Formation',
                        chart: _FormationPieChart(formations: formations),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 120), // leave space for FAB
              ],
                ),
              ),

              // Floating action button (Nouvelle inscription)
              Positioned(
                right: 24,
                bottom: 24,
                child: FloatingActionButton.extended(
                  onPressed: () async {
                            final forms = await DatabaseService().getFormations();
                            await _showQuickNewStudentDialog(forms);
                          },
                  label: const Text('Nouvelle inscription'),
                  icon: const Icon(Icons.person_add),
                  backgroundColor: const Color(0xFF10B981),
                ),
              ),
              // Quick action buttons overlay at top-right
              Positioned(
                right: 24,
                top: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            final forms = await DatabaseService().getFormations();
                            await _showQuickNewStudentDialog(forms);
                          },
                          icon: const Icon(Icons.person_add),
                          label: const Text('Nouvelle inscription'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () async {
                            await _showNewPaymentDialog();
                          },
                          icon: const Icon(Icons.payment),
                          label: const Text('Nouveau paiement'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () async {
                            await _runQuickReport();
                          },
                          icon: const Icon(Icons.assessment),
                          label: const Text('Rapport express'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Simple data-driven bar chart using core widgets. It's intentionally lightweight
// to avoid new dependencies. Each formation renders a horizontal bar proportional
// to its revenue relative to the max revenue in the list.
class _RevenueBarChart extends StatelessWidget {
  final List<Formation> formations;

  const _RevenueBarChart({Key? key, required this.formations}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (formations.isEmpty) {
      return Container(
        height: 300,
        alignment: Alignment.center,
        child: const Text('Aucune donnée', style: TextStyle(color: Colors.white54)),
      );
    }

    final top = formations.toList();
    top.sort((a, b) => b.revenue.compareTo(a.revenue));
    final items = top.take(6).toList();

    final maxRevenue = items.fold<double>(0.0, (p, e) => e.revenue > p ? e.revenue : p);

    return SizedBox(
      height: 300,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceBetween,
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= items.length) return const SizedBox.shrink();
                  final label = items[idx].title;
                  return SideTitleWidget(meta: meta, child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)));
                },
                reservedSize: 80,
              ),
            ),
          ),
          barGroups: List.generate(items.length, (i) {
            final r = items[i].revenue;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: r,
                  color: const Color(0xFF6366F1),
                  width: 18,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            );
          }),
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          maxY: maxRevenue * 1.1,
        ),
      ),
    );
  }
}

class _FormationPieChart extends StatelessWidget {
  final List<Formation> formations;

  const _FormationPieChart({Key? key, required this.formations}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (formations.isEmpty) {
      return Container(height: 300, alignment: Alignment.center, child: const Text('Aucune donnée', style: TextStyle(color: Colors.white54)));
    }

    final entries = formations.map((f) => MapEntry(f.title, f.revenue)).toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(6).toList();
    final others = entries.skip(6).fold<double>(0.0, (p, e) => p + e.value);
    if (others > 0) top.add(MapEntry('Autres', others));
    final total = top.fold<double>(0.0, (p, e) => p + e.value);

    final sections = List.generate(top.length, (i) {
      final value = top[i].value;
      final pct = total > 0 ? (value / total) * 100 : 0.0;
      return PieChartSectionData(
        value: value,
        color: _pieColors[i % _pieColors.length],
        title: '${pct.toStringAsFixed(0)}%',
        radius: 60,
        titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
      );
    });

    return SizedBox(
      height: 300,
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 24,
                sectionsSpace: 2,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 160,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: top.asMap().entries.map((entry) {
                final i = entry.key;
                final e = entry.value;
                final pct = total > 0 ? (e.value / total) * 100 : 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(width: 12, height: 12, color: _pieColors[i % _pieColors.length]),
                      const SizedBox(width: 8),
                      Expanded(child: Text(e.key, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70))),
                      const SizedBox(width: 8),
                      Text('${pct.toStringAsFixed(0)}%', style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

const _pieColors = [
  Color(0xFF6366F1),
  Color(0xFF10B981),
  Color(0xFF8B5CF6),
  Color(0xFF06B6D4),
  Color(0xFFEF4444),
  Color(0xFFF59E0B),
];

// removed custom painter: using fl_chart instead