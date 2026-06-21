import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/agency_api_service.dart';
import '../../core/services/database_service.dart';
import '../../models/agent_model.dart';
import '../../models/agent_stats_model.dart';
import 'agent_detail_dialog.dart';

class TeamPerformancePage extends StatefulWidget {
  const TeamPerformancePage({super.key});

  @override
  State<TeamPerformancePage> createState() => _TeamPerformancePageState();
}

class _TeamPerformancePageState extends State<TeamPerformancePage> {
  bool _isLoading = true;
  GlobalTeamStats _globalStats = GlobalTeamStats();
  List<Agent> _agents = [];
  List<Agent> _filteredAgents = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final globalStats = await DatabaseService().getGlobalTeamStats();
      final agents = await AgencyApiService().getAgents();

      // Sort agents by a score or PAR by default
      agents.sort((a, b) => a.stats.parRatio.compareTo(b.stats.parRatio));

      setState(() {
        _globalStats = globalStats;
        _agents = agents;
        _filteredAgents = agents;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading team performance data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _filterAgents(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredAgents = _agents;
      } else {
        _filteredAgents = _agents.where((agent) {
          final fullName = agent.fullName.toLowerCase();
          final agency = agent.agencyId.toLowerCase();
          final role = agent.role.name.toLowerCase();
          return fullName.contains(query.toLowerCase()) ||
              agency.contains(query.toLowerCase()) ||
              role.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(isDark),
                  const SizedBox(height: 32),
                  _buildKPICards(isDark),
                  const SizedBox(height: 32),
                  _buildFilterBar(isDark),
                  const SizedBox(height: 16),
                  Expanded(child: _buildAgentsTable(isDark)),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
                Icons.trending_up_rounded,
                color: AppColors.primary,
                size: 32,
              ),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Performance des Équipes',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Suivi de la productivité et de la qualité du portefeuille.',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKPICards(bool isDark) {
    final currencyFormat = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: 'FCFA',
      decimalDigits: 0,
    );

    return Row(
      children: [
        Expanded(
          child: _buildKPIItem(
            'Portefeuille Global',
            currencyFormat.format(_globalStats.totalOutstanding),
            Icons.account_balance_wallet_rounded,
            AppColors.primary,
            isDark,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _buildKPIItem(
            'Clients Actifs',
            '${_globalStats.totalActiveClients}',
            Icons.people_rounded,
            Colors.blue,
            isDark,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _buildKPIItem(
            'PAR Global (30j)',
            '${_globalStats.avgParRatio.toStringAsFixed(1)}%',
            Icons.warning_rounded,
            _globalStats.avgParRatio > 5 ? AppColors.error : AppColors.success,
            isDark,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _buildKPIItem(
            'Collecte (Mois)',
            currencyFormat.format(_globalStats.monthlyCollection),
            Icons.payments_rounded,
            Colors.orange,
            isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildKPIItem(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
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

  Widget _buildFilterBar(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: _filterAgents,
            decoration: InputDecoration(
              hintText: 'Rechercher un agent, une agence ou un rôle...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: isDark ? const Color(0xFF334155) : Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        _buildActionButton(Icons.filter_list, 'Filtrer', isDark),
        const SizedBox(width: 12),
        _buildActionButton(Icons.download, 'Exporter', isDark),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, bool isDark) {
    return OutlinedButton.icon(
      onPressed: () {},
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: isDark ? Colors.white24 : Colors.grey[300]!),
      ),
    );
  }

  Widget _buildAgentsTable(bool isDark) {
    final currencyFormat = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: 'FCFA',
      decimalDigits: 0,
    );

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
      ),
      child: Column(
        children: [
          _buildTableHeader(isDark),
          Expanded(
            child: _filteredAgents.isEmpty
                ? _buildEmptyState(isDark)
                : ListView.separated(
                    itemCount: _filteredAgents.length,
                    separatorBuilder: (ctx, idx) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final agent = _filteredAgents[idx];
                      return _buildAgentRow(agent, currencyFormat, isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF334155) : Colors.grey[50],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('AGENT', style: _headerStyle)),
          Expanded(flex: 2, child: Text('AGENCE', style: _headerStyle)),
          Expanded(
            flex: 2,
            child: Text(
              'PORTEFEUILLE',
              style: _headerStyle,
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'PAR 30',
              style: _headerStyle,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'RECOUVREMENT',
              style: _headerStyle,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'QUALITÉ',
              style: _headerStyle,
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(width: 48),
        ],
      ),
    );
  }

  static const _headerStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.bold,
    color: Colors.grey,
    letterSpacing: 1.0,
  );

  Widget _buildAgentRow(Agent agent, NumberFormat currencyFormat, bool isDark) {
    final par = agent.stats.parRatio * 100;
    Color parColor = AppColors.success;
    if (par > 10)
      parColor = AppColors.error;
    else if (par > 5)
      parColor = Colors.orange;

    return InkWell(
      onTap: () => _showAgentDetail(agent),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    backgroundImage: agent.photoUrl != null
                        ? FileImage(File(agent.photoUrl!)) as ImageProvider
                        : null,
                    child: agent.photoUrl == null
                        ? Text(
                            agent.firstName.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          agent.fullName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          agent.role.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                agent.agencyId,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                currencyFormat.format(agent.stats.outstandingAmount),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: parColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${par.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: parColor,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Center(
                child: Column(
                  children: [
                    Text(
                      '${(agent.stats.repaymentRate * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 60,
                      child: LinearProgressIndicator(
                        value: agent.stats.repaymentRate,
                        backgroundColor: Colors.grey.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          agent.stats.repaymentRate > 0.95
                              ? AppColors.success
                              : Colors.orange,
                        ),
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${agent.stats.qualityScore.toStringAsFixed(1)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const IconButton(
              onPressed: null, // Tap on row shows detail
              icon: Icon(Icons.chevron_right, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: Colors.grey.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun agent trouvé',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white54 : Colors.grey[400],
            ),
          ),
          if (_searchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Essayez un autre terme de recherche.',
                style: TextStyle(color: Colors.grey.withOpacity(0.7)),
              ),
            ),
        ],
      ),
    );
  }

  void _showAgentDetail(Agent agent) {
    showDialog(
      context: context,
      builder: (context) => AgentDetailDialog(agent: agent),
    );
  }
}
