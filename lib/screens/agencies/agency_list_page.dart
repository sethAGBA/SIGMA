import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/agency_model.dart';
import '../../widgets/dialogs/agency_detail_dialog.dart';
import 'package:intl/intl.dart';
import '../../core/services/database_service.dart';
import '../../widgets/dialogs/agency_form_dialog.dart';

class AgencyListPage extends StatefulWidget {
  const AgencyListPage({super.key});

  @override
  State<AgencyListPage> createState() => _AgencyListPageState();
}

class _AgencyListPageState extends State<AgencyListPage> {
  final currencyFormat = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: 'FCFA',
    decimalDigits: 0,
  );

  bool _isLoading = true;
  List<Agency> _agencies = [];

  @override
  void initState() {
    super.initState();
    _loadAgencies();
  }

  Future<void> _loadAgencies() async {
    setState(() => _isLoading = true);
    try {
      final agencies = await DatabaseService().getAgencies();
      setState(() {
        _agencies = agencies;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur de chargement: $e')));
      }
    }
  }

  void _openAgencyForm([Agency? agency]) async {
    final result = await showDialog(
      context: context,
      builder: (context) => AgencyFormDialog(agency: agency),
    );

    if (result == true) {
      _loadAgencies();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAgencyForm(),
        label: const Text('Nouvelle Agence'),
        icon: const Icon(Icons.add),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(isDark),
            const SizedBox(height: 32),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _agencies.isEmpty
                  ? _buildEmptyState(isDark)
                  : ListView.separated(
                      itemCount: _agencies.length,
                      separatorBuilder: (ctx, idx) =>
                          const SizedBox(height: 16),
                      itemBuilder: (ctx, idx) =>
                          _buildAgencyCard(_agencies[idx], isDark),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.not_listed_location_outlined,
            size: 64,
            color: isDark ? Colors.white24 : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune agence configurée',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cliquez sur le bouton "Nouvelle Agence" pour commencer.',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white38 : Colors.grey[500],
            ),
          ),
        ],
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
                Icons.account_balance_rounded,
                color: AppColors.primary,
                size: 32,
              ),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Réseau d\'agences',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Vue d\'ensemble de vos ${_agencies.length} points de service.',
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

  Widget _buildAgencyCard(Agency agency, bool isDark) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: InkWell(
        onTap: () {
          // Open detail or edit? Let's open detail for now, or edit via detail page?
          // Or just allow edit here for simplicity since detail needs updates too
          // _openAgencyForm(agency);

          showDialog(
            context: context,
            builder: (context) => AgencyDetailDialog(agency: agency),
          ).then((value) {
            if (value == true)
              _loadAgencies(); // Reload if updated in detail (future feature)
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Text(
                      agency.code.isNotEmpty
                          ? agency.code.split('-').last
                          : '?',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          agency.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: isDark ? Colors.white60 : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              agency.address,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white60 : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () => _openAgencyForm(agency),
                    tooltip: 'Modifier l\'agence',
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: agency.isActive
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: agency.isActive ? Colors.green : Colors.red,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      agency.isActive ? 'ACTIVE' : 'FERMÉE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: agency.isActive ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Divider(color: isDark ? Colors.white10 : Colors.grey[200]),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    'Clients Actifs',
                    '${agency.stats.activeClients}',
                    Icons.people,
                    isDark,
                  ),
                  _buildStatItem(
                    'Encours',
                    currencyFormat.format(agency.stats.totalOutstanding),
                    Icons.monetization_on,
                    isDark,
                  ),
                  _buildStatItem(
                    'PAR > 30j',
                    '${agency.stats.parRatio}%',
                    Icons.warning_amber,
                    isDark,
                    valueColor: agency.stats.parRatio > 5
                        ? Colors.red
                        : Colors.green,
                  ),
                  _buildStatItem(
                    'Staff',
                    '${agency.stats.totalStaff}',
                    Icons.badge,
                    isDark,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    bool isDark, {
    Color? valueColor,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: isDark ? Colors.white54 : Colors.grey),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: valueColor ?? (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ],
    );
  }
}
