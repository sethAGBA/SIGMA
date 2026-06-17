// lib/screens/dashboard/dashboard_page.dart

import 'package:flutter/material.dart';
import '../../models/dashboard_data.dart';
import '../../widgets/dashboard/kpi_card.dart';
import '../../widgets/dashboard/portfolio_chart.dart';
import '../../widgets/dashboard/alerts_section.dart';
import '../../widgets/dashboard/top_agents_section.dart';
import '../../core/services/database_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/api_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<DashboardKPI> kpis = [];
  List<PortfolioDataPoint> portfolioData = [];
  List<AlertItem> alerts = [];
  List<AgentPerformance> topAgents = [];
  bool isLoading = true;
  bool _isOnline = false; // indicateur mode serveur

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      // 1. OFFLINE-FIRST : afficher immédiatement les données locales (SQLite)
      final localData = await DatabaseService().getHomeDashboardData();
      if (mounted) {
        setState(() {
          kpis = localData.kpis;
          portfolioData = localData.portfolioData;
          alerts = localData.alerts;
          topAgents = localData.topAgents;
          isLoading = false;
          _isOnline = false;
        });
      }

      // 2. Vérifier la disponibilité du serveur
      final serverAvailable = await ApiService().isServerAvailable();
      if (!mounted) return;
      setState(() => _isOnline = serverAvailable);

      // 3. Si serveur disponible, enrichir les KPIs avec les données consolidées
      if (serverAvailable) {
        final apiData = await _loadFromApi();
        if (apiData != null && mounted) {
          setState(() {
            // KPIs depuis le serveur (agrégation centralisée de tous les postes)
            kpis = apiData.kpis;
            // Alertes : combiner locale + serveur
            final allAlerts = [...localData.alerts, ...apiData.alerts];
            alerts = allAlerts.toSet().toList(); // dédoublonner
            // Graphique et agents : garder local (plus riche)
            portfolioData = localData.portfolioData;
            topAgents = localData.topAgents;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement: $e')),
        );
      }
    }
  }

  Future<HomeDashboardData?> _loadFromApi() async {
    final response = await ApiService().get('/reporting/dashboard');
    final data = ApiService.decodeResponse(response);
    if (data == null) return null;

    // Construire les KPIs depuis la réponse API
    final kpis = <DashboardKPI>[
      DashboardKPI(
        title: 'Clients Actifs',
        value: '${data['clients_actifs'] ?? 0}',
        variation: '+0',
        isPositive: true,
        icon: Icons.people_rounded,
        color: const Color(0xFF3B82F6),
      ),
      DashboardKPI(
        title: 'Encours Total',
        value: _formatAmount((data['encours_total'] as num?)?.toDouble() ?? 0),
        variation: '+0%',
        isPositive: true,
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xFF10B981),
      ),
      DashboardKPI(
        title: 'PAR > 30j',
        value: '${data['taux_remboursement'] ?? 0}%',
        variation: 'Normal',
        isPositive: true,
        icon: Icons.trending_down_rounded,
        color: const Color(0xFFF59E0B),
      ),
      DashboardKPI(
        title: 'Prêts Actifs',
        value: '${data['prets_actifs'] ?? 0}',
        variation: '0',
        isPositive: true,
        icon: Icons.payments_rounded,
        color: const Color(0xFF8B5CF6),
      ),
    ];

    // Alertes
    final alerts = <AlertItem>[];
    final pretsEnRetard = (data['prets_en_retard'] as num?)?.toInt() ?? 0;
    if (pretsEnRetard > 0) {
      alerts.add(AlertItem(
        title: '$pretsEnRetard prêts en retard',
        description: 'Actions de recouvrement requises',
        level: AlertLevel.warning,
        icon: Icons.warning_rounded,
      ));
    }

    return HomeDashboardData(
      kpis: kpis,
      portfolioData: [],
      alerts: alerts,
      topAgents: [],
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}k';
    return amount.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome section
                    _buildWelcomeSection(theme),
                    const SizedBox(height: 24),

                    // KPI Cards Grid
                    _buildKPIGrid(),
                    const SizedBox(height: 24),

                    // Portfolio Chart
                    PortfolioChart(data: portfolioData),
                    const SizedBox(height: 24),

                    // Alerts and Top Agents Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: AlertsSection(alerts: alerts)),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 2,
                          child: TopAgentsSection(agents: topAgents),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWelcomeSection(ThemeData theme) {
    final now = DateTime.now();
    final hour = now.hour;
    String greeting;

    if (hour < 12) {
      greeting = 'Bonjour';
    } else if (hour < 18) {
      greeting = 'Bon après-midi';
    } else {
      greeting = 'Bonsoir';
    }

    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$greeting, ${AuthService().currentUser?.username ?? 'Utilisateur'} 👋',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Voici un aperçu de vos activités aujourd\'hui',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const Spacer(),
        // Indicateur mode online/offline
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: (_isOnline
                    ? const Color(0xFF10B981)
                    : Colors.orange)
                .withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: (_isOnline
                      ? const Color(0xFF10B981)
                      : Colors.orange)
                  .withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _isOnline ? const Color(0xFF10B981) : Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _isOnline ? 'Serveur connecté' : 'Mode hors ligne',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _isOnline ? const Color(0xFF10B981) : Colors.orange,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                _formatDate(now),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKPIGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive grid: 4 columns on large screens, 2 on medium, 1 on small
        int crossAxisCount = 4;
        if (constraints.maxWidth < 1200) {
          crossAxisCount = 2;
        }
        if (constraints.maxWidth < 600) {
          crossAxisCount = 1;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.8,
          ),
          itemCount: kpis.length,
          itemBuilder: (context, index) {
            return KpiCard(kpi: kpis[index]);
          },
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Janvier',
      'Février',
      'Mars',
      'Avril',
      'Mai',
      'Juin',
      'Juillet',
      'Août',
      'Septembre',
      'Octobre',
      'Novembre',
      'Décembre',
    ];
    const days = [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche',
    ];

    final dayName = days[date.weekday - 1];
    final day = date.day;
    final month = months[date.month - 1];
    final year = date.year;

    return '$dayName $day $month $year';
  }
}
