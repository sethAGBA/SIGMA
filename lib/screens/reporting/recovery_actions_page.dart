import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/database_service.dart';
import '../../models/recovery_action_model.dart';
import '../../widgets/dialogs/register_recovery_action_dialog.dart';
import '../../core/theme/app_colors.dart';

class RecoveryActionsPage extends StatefulWidget {
  const RecoveryActionsPage({super.key});

  @override
  State<RecoveryActionsPage> createState() => _RecoveryActionsPageState();
}

class _RecoveryActionsPageState extends State<RecoveryActionsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseService _db = DatabaseService();
  final currencyFormat = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: 'FCFA',
    decimalDigits: 0,
  );
  final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  // Search and Filters
  final TextEditingController _searchController = TextEditingController();
  RecoveryActionType? _filterType;
  String? _filterAgent;
  List<String> _agentsList = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAgents();
  }

  Future<void> _loadAgents() async {
    final agents = await _db.getAgents();
    setState(() {
      _agentsList = agents.map((a) => a.fullName).toList();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildTopNavigation(isDark),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildActionsToTakeTab(isDark),
                _buildActionHistoryTab(isDark),
                _buildStatsTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopNavigation(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.gavel_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hub de Recouvrement',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'Planification, tracking et analyse des impayés',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppColors.primary,
              ),
              labelColor: Colors.white,
              unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
              tabs: const [
                Tab(text: 'À MENER'),
                Tab(text: 'HISTORIQUE'),
                Tab(text: 'PERFORMANCE'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: ACTIONS À MENER ---

  Widget _buildActionsToTakeTab(bool isDark) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _db.getDelinquentLoans(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(
            Icons.check_circle_rounded,
            'Tout est sous contrôle',
            'Aucune action de recouvrement urgente n\'est requise.',
          );
        }

        final loans = snapshot.data!;
        // Sort by jours_retard descending for work queue priority
        loans.sort(
          (a, b) =>
              (b['jours_retard'] as int).compareTo(a['jours_retard'] as int),
        );

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: loans.length,
          itemBuilder: (context, index) {
            final loan = loans[index];
            final int jours = loan['jours_retard'] as int;
            final RecoveryActionType recommendation = _getRecommendedAction(
              jours,
            );

            return _buildPremiumActionCard(loan, recommendation, isDark);
          },
        );
      },
    );
  }

  Widget _buildPremiumActionCard(
    Map<String, dynamic> loan,
    RecoveryActionType recommendation,
    bool isDark,
  ) {
    final int jours = loan['jours_retard'] as int;
    final double solde = (loan['solde_restant'] as num?)?.toDouble() ?? 0;
    final Color actionColor = _getActionColor(recommendation);

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
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: actionColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                _getActionIcon(recommendation),
                color: actionColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        loan['client_name'] ?? 'Client Inconnu',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildPriorityTag(jours),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Solde: ${currencyFormat.format(solde)} • Prêt N° ${loan['numero_pret']}',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: actionColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 12,
                          color: actionColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'RECOMMANDÉ : ${recommendation.label.toUpperCase()}',
                          style: TextStyle(
                            color: actionColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
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
                  '$jours jours',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'RETARD',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => _registerAction(loan),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: actionColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  child: const Text(
                    'TRAITER',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityTag(int jours) {
    String label;
    Color color;
    if (jours > 90) {
      label = 'CRITIQUE';
      color = Colors.purple;
    } else if (jours > 30) {
      label = 'URGENT';
      color = Colors.red;
    } else {
      label = 'MODÉRÉ';
      color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // --- TAB 2: HISTORIQUE DES ACTIONS ---

  Widget _buildActionHistoryTab(bool isDark) {
    return Column(
      children: [
        _buildFiltersBar(isDark),
        Expanded(
          child: FutureBuilder<List<RecoveryAction>>(
            future: _db.getGlobalRecoveryActionsHistory(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildEmptyState(
                  Icons.history_rounded,
                  'Historique vide',
                  'Aucune action n\'a encore été enregistrée.',
                );
              }

              var actions = snapshot.data!;

              // Apply basic frontend filtering for demo (ideally filtered in DB)
              if (_searchController.text.isNotEmpty) {
                actions = actions
                    .where(
                      (a) =>
                          (a.clientName?.toLowerCase().contains(
                                _searchController.text.toLowerCase(),
                              ) ??
                              false) ||
                          (a.numeroPret?.toLowerCase().contains(
                                _searchController.text.toLowerCase(),
                              ) ??
                              false),
                    )
                    .toList();
              }
              if (_filterType != null) {
                actions = actions.where((a) => a.type == _filterType).toList();
              }
              if (_filterAgent != null) {
                actions = actions
                    .where((a) => a.agentName == _filterAgent)
                    .toList();
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                itemCount: actions.length,
                itemBuilder: (context, index) {
                  final action = actions[index];
                  return _buildHistoryPremiumCard(action, isDark);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFiltersBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.grey.shade200,
                ),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Rechercher un client...',
                  prefixIcon: Icon(Icons.search_rounded, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 16),
          _buildFilterChip(
            'Type',
            _filterType?.label ?? 'Tout',
            isDark,
            () => _showTypeFilter(),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            'Agent',
            _filterAgent ?? 'Tous',
            isDark,
            () => _showAgentFilter(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String value,
    bool isDark,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Text(
              '$label: ',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _showTypeFilter() {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: const Text('Tous les types'),
            onTap: () {
              setState(() => _filterType = null);
              Navigator.pop(context);
            },
          ),
          ...RecoveryActionType.values.map(
            (t) => ListTile(
              title: Text(t.label),
              onTap: () {
                setState(() => _filterType = t);
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAgentFilter() {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: const Text('Tous les agents'),
            onTap: () {
              setState(() => _filterAgent = null);
              Navigator.pop(context);
            },
          ),
          ..._agentsList.map(
            (a) => ListTile(
              title: Text(a),
              onTap: () {
                setState(() => _filterAgent = a);
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryPremiumCard(RecoveryAction action, bool isDark) {
    final Color color = _getActionColor(action.type);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_getActionIcon(action.type), color: color, size: 22),
        ),
        title: Text(
          action.clientName ?? 'Client Inconnu',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${action.result}',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${dateFormat.format(action.date)} • Par ${action.agentName}',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            action.type.label.split(' ')[0].toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  // --- TAB 3: STATISTIQUES ---

  Widget _buildStatsTab(bool isDark) {
    return FutureBuilder<RecoveryStats>(
      future: _db.getRecoveryStats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.totalActions == 0) {
          return _buildEmptyState(
            Icons.bar_chart_rounded,
            'Pas encore de données',
            'Les statistiques apparaîtront dès que les premières actions seront enregistrées.',
          );
        }

        final stats = snapshot.data!;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatsGrid(stats, isDark),
              const SizedBox(height: 32),
              _buildSectionHeader('Répartition par Type', isDark),
              const SizedBox(height: 16),
              _buildDistributionSection(stats, isDark),
              const SizedBox(height: 32),
              _buildSectionHeader('Performance par Agent', isDark),
              const SizedBox(height: 16),
              _buildAgentSection(stats, isDark),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
        color: isDark ? Colors.white38 : Colors.grey.shade400,
      ),
    );
  }

  Widget _buildStatsGrid(RecoveryStats stats, bool isDark) {
    return Row(
      children: [
        _buildStatCard(
          'Gavel',
          stats.totalActions.toString(),
          'Total Actions',
          Colors.blue,
          isDark,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          'TrendingUp',
          '${stats.successRate.toStringAsFixed(1)}%',
          'Taux de Succès',
          Colors.green,
          isDark,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          'People',
          stats.uniqueLoansImpacted.toString(),
          'Prêts Touchés',
          Colors.orange,
          isDark,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String iconName,
    String value,
    String label,
    Color color,
    bool isDark,
  ) {
    IconData icon;
    switch (iconName) {
      case 'Gavel':
        icon = Icons.gavel_rounded;
        break;
      case 'TrendingUp':
        icon = Icons.trending_up_rounded;
        break;
      default:
        icon = Icons.people_outline_rounded;
    }

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
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
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.grey.shade500,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionSection(RecoveryStats stats, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: stats.actionsByType.entries.map((entry) {
          final percentage = (entry.value / stats.totalActions);
          final color = _getActionColor(entry.key);
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.key.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '${(percentage * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: percentage,
                    minHeight: 10,
                    backgroundColor: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.grey.shade100,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAgentSection(RecoveryStats stats, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: stats.actionsByAgent.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
        ),
        itemBuilder: (context, index) {
          final entry = stats.actionsByAgent.entries.elementAt(index);
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 8,
            ),
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: Text(
                entry.key[0],
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              entry.key,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              '${entry.value} actions enregistrées',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Text(
              '${((entry.value / stats.totalActions) * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
          );
        },
      ),
    );
  }

  // --- HELPERS ---

  RecoveryActionType _getRecommendedAction(int joursRetard) {
    if (joursRetard >= 90) return RecoveryActionType.legal;
    if (joursRetard >= 60) return RecoveryActionType.warning;
    if (joursRetard >= 30) return RecoveryActionType.summons;
    if (joursRetard >= 15) return RecoveryActionType.visit;
    if (joursRetard >= 7) return RecoveryActionType.visit;
    if (joursRetard >= 3) return RecoveryActionType.call;
    return RecoveryActionType.sms;
  }

  IconData _getActionIcon(RecoveryActionType type) {
    switch (type) {
      case RecoveryActionType.sms:
        return Icons.sms_rounded;
      case RecoveryActionType.call:
        return Icons.phone_rounded;
      case RecoveryActionType.visit:
        return Icons.home_work_rounded;
      case RecoveryActionType.summons:
        return Icons.assignment_late_rounded;
      case RecoveryActionType.commitment:
        return Icons.edit_note_rounded;
      case RecoveryActionType.meeting:
        return Icons.groups_rounded;
      case RecoveryActionType.warning:
        return Icons.warning_amber_rounded;
      case RecoveryActionType.legal:
        return Icons.gavel_rounded;
    }
  }

  Color _getActionColor(RecoveryActionType type) {
    switch (type) {
      case RecoveryActionType.sms:
        return Colors.blue;
      case RecoveryActionType.call:
        return Colors.indigo;
      case RecoveryActionType.visit:
        return Colors.orange;
      case RecoveryActionType.summons:
        return Colors.deepOrange;
      case RecoveryActionType.commitment:
        return Colors.green;
      case RecoveryActionType.meeting:
        return Colors.teal;
      case RecoveryActionType.warning:
        return Colors.red;
      case RecoveryActionType.legal:
        return Colors.purple;
    }
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
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
            child: Icon(icon, size: 80, color: Colors.green.withOpacity(0.5)),
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

  void _registerAction(Map<String, dynamic> loan) {
    showDialog(
      context: context,
      builder: (context) => RegisterRecoveryActionDialog(
        loanId: loan['id'],
        clientName: loan['client_name'],
        numeroPret: loan['numero_pret'],
        onActionSaved: () => setState(() {}),
      ),
    );
  }
}
