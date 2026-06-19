// lib/screens/dashboard/dashboard_page.dart
// Phase 3 — Exigences 9.2, 9.3, 9.4
// Consomme DashboardNotifier via Provider pour un cache transparent.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/dashboard_data.dart';
import '../../widgets/dashboard/kpi_card.dart';
import '../../widgets/dashboard/portfolio_chart.dart';
import '../../widgets/dashboard/alerts_section.dart';
import '../../widgets/dashboard/top_agents_section.dart';
import '../../core/notifiers/dashboard_notifier.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/sync_service.dart';
import '../../core/services/api_service.dart';
import '../../widgets/dialogs/client_form_dialog.dart';
import '../prets/loan_request_form_dialog.dart';
import '../caisse/cash_miscellaneous_dialog.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    // Charge seulement si le cache est vide ; sinon affichage immédiat
    // (Exigence 9.2). postFrameCallback pour éviter un setState pendant build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<DashboardNotifier>().load();
        _checkConnectivity();
      }
    });
  }

  Future<void> _checkConnectivity() async {
    final online = await ApiService().isServerAvailable();
    if (mounted) setState(() => _isOnline = online);
    if (online) SyncService().flushPendingOperations();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<DashboardNotifier>(
      builder: (context, notifier, _) {
        final isLoading = notifier.isLoading && notifier.cachedData == null;
        final data = notifier.cachedData;

        // Afficher une erreur non bloquante en SnackBar si besoin
        if (notifier.error != null && data != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erreur de synchronisation: ${notifier.error}')),
              );
            }
          });
        }

        return Scaffold(
          backgroundColor: theme.colorScheme.surface,
          floatingActionButton: _buildQuickActionsFab(context),
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  // Exigence 9.3 : le refresh force le rechargement depuis la source
                  onRefresh: () async {
                    await notifier.refresh();
                    await _checkConnectivity();
                  },
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Welcome section
                        _buildWelcomeSection(theme),
                        const SizedBox(height: 24),

                        // KPI Cards Grid
                        _buildKPIGrid(data?.kpis ?? []),
                        const SizedBox(height: 24),

                        // Portfolio Chart
                        PortfolioChart(data: data?.portfolioData ?? []),
                        const SizedBox(height: 24),

                        // Alerts and Top Agents Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: AlertsSection(alerts: data?.alerts ?? []),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 2,
                              child: TopAgentsSection(agents: data?.topAgents ?? []),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
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
              '$greeting, ${AuthService().currentUser?.username ?? 'Utilisateur'} 👋', // Phase 2 OK
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
                .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: (_isOnline
                      ? const Color(0xFF10B981)
                      : Colors.orange)
                  .withValues(alpha: 0.3),
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
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
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

  Widget _buildKPIGrid(List<DashboardKPI> kpis) {
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

  // Phase 2 OK — FAB avec 3 actions, navigation réelle, désactivation RBAC (Exigences 3.1–3.5)
  Widget? _buildQuickActionsFab(BuildContext context) {
    final auth = AuthService();
    final hasAnyAction = auth.canAccess('create_client') ||
        auth.canAccess('create_loan') ||
        auth.canAccess('cash_operation');

    if (!hasAnyAction) return null;

    return FloatingActionButton.extended(
      heroTag: 'fab-dashboard',
      onPressed: () => _showQuickActionsMenu(context),
      icon: const Icon(Icons.bolt_rounded),
      label: const Text('Actions rapides'),
    );
  }

  void _showQuickActionsMenu(BuildContext context) {
    final auth = AuthService();
    final canClient = auth.canAccess('create_client');
    final canLoan = auth.canAccess('create_loan');
    final canCash = auth.canAccess('cash_operation');

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Actions rapides',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.person_add_rounded,
                color: canClient ? null : Colors.grey,
              ),
              title: Text(
                'Nouveau client',
                style: TextStyle(color: canClient ? null : Colors.grey),
              ),
              enabled: canClient,
              onTap: canClient
                  ? () {
                      Navigator.pop(sheetContext);
                      showDialog<void>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const ClientFormDialog(),
                      );
                    }
                  : null,
            ),
            ListTile(
              leading: Icon(
                Icons.request_quote_rounded,
                color: canLoan ? null : Colors.grey,
              ),
              title: Text(
                'Nouveau prêt',
                style: TextStyle(color: canLoan ? null : Colors.grey),
              ),
              enabled: canLoan,
              onTap: canLoan
                  ? () {
                      Navigator.pop(sheetContext);
                      showDialog<void>(
                        context: context,
                        builder: (_) => const LoanRequestFormDialog(),
                      );
                    }
                  : null,
            ),
            ListTile(
              leading: Icon(
                Icons.point_of_sale_rounded,
                color: canCash ? null : Colors.grey,
              ),
              title: Text(
                'Opération caisse',
                style: TextStyle(color: canCash ? null : Colors.grey),
              ),
              enabled: canCash,
              onTap: canCash
                  ? () {
                      Navigator.pop(sheetContext);
                      showDialog<void>(
                        context: context,
                        builder: (_) => const CashMiscellaneousDialog(),
                      );
                    }
                  : null,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
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
