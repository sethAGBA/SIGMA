// lib/screens/caisse/vault_management_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/cash_api_service.dart';
import '../../core/services/database_service.dart';
import 'cash_transfer_dialog.dart';

class VaultManagementPage extends StatefulWidget {
  const VaultManagementPage({super.key});

  @override
  State<VaultManagementPage> createState() => _VaultManagementPageState();
}

class _VaultManagementPageState extends State<VaultManagementPage> {
  late Future<Map<String, double>> _vaultStatsFuture;
  late Future<List<Map<String, dynamic>>> _recentTransfersFuture;

  final currencyFormat = NumberFormat.currency(
    symbol: 'FCFA',
    decimalDigits: 0,
    locale: 'fr_FR',
  );
  final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _vaultStatsFuture = _loadVaultStats();
      _recentTransfersFuture = CashApiService().getOperationsCaisse(
        limit: 10,
        // Manual filter for transfers category will be done in UI
      );
    });
  }

  Future<Map<String, double>> _loadVaultStats() async {
    final db = DatabaseService();

    // Total cash in columns (all ENTREE - all SORTIE)
    final globalBalance = await db.getCashBalance();

    // Let's assume vault is what's left after subtracting "active" cash desks.
    // For now, let's simplify and show Global vs Desk.
    // In a real scenario, we'd have a specific account for Vault.

    return {
      'global_balance': globalBalance,
      'vault_balance':
          globalBalance * 0.7, // Mocking vault as 70% of total for demo
      'desks_balance':
          globalBalance * 0.3, // Mocking desk total as 30% for demo
    };
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            _buildSummaryCards(isDark),
            const SizedBox(height: 32),
            const Text(
              'FLUX RÉCENTS (COFFRE <-> CAISSES)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.grey,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildRecentTransfers(isDark)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-vault',
        onPressed: () async {
          final result = await showDialog<bool>(
            context: context,
            builder: (context) => const CashTransferDialog(),
          );
          if (result == true) _refresh();
        },
        label: const Text('OPÉRATION COFFRE'),
        icon: const Icon(Icons.shield_outlined),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gestion du Coffre-Fort',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(
          'Liquidité globale et réserve institutionnelle',
          style: TextStyle(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(bool isDark) {
    return FutureBuilder<Map<String, double>>(
      future: _vaultStatsFuture,
      builder: (context, snapshot) {
        final stats =
            snapshot.data ??
            {'global_balance': 0.0, 'vault_balance': 0.0, 'desks_balance': 0.0};

        return Row(
          children: [
            _statCard(
              'SOLDE TOTAL DISPONIBLE',
              stats['global_balance']!,
              AppColors.primary,
              Icons.account_balance_rounded,
              isDark,
            ),
            const SizedBox(width: 20),
            _statCard(
              'DISPONIBLE EN COFFRE',
              stats['vault_balance']!,
              Colors.indigo,
              Icons.shield_rounded,
              isDark,
            ),
            const SizedBox(width: 20),
            _statCard(
              'TOTAL EN CAISSES',
              stats['desks_balance']!,
              Colors.teal,
              Icons.point_of_sale_rounded,
              isDark,
            ),
          ],
        );
      },
    );
  }

  Widget _statCard(
    String title,
    double amount,
    Color color,
    IconData icon,
    bool isDark,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppColors.darkDivider : Colors.grey[200]!,
          ),
          boxShadow: [
            if (!isDark)
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              currencyFormat.format(amount),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransfers(bool isDark) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _recentTransfersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allOps = snapshot.data ?? [];
        final transfers = allOps
            .where((op) => op['categorie'] == 'TRANSFERT')
            .toList();

        if (transfers.isEmpty) {
          return const Center(child: Text('Aucun mouvement récent enregistré'));
        }

        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkDivider : Colors.grey[200]!,
            ),
          ),
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: transfers.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: isDark ? AppColors.darkDivider : Colors.grey[100],
            ),
            itemBuilder: (context, index) {
              final op = transfers[index];
              final isAppro = op['type_operation'] == 'ENTREE';

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (isAppro ? Colors.blue : Colors.orange).withOpacity(
                      0.1,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isAppro ? Icons.download_rounded : Icons.upload_rounded,
                    color: isAppro ? Colors.blue : Colors.orange,
                  ),
                ),
                title: Text(
                  op['libelle'] ?? 'Transfert',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  dateFormat.format(DateTime.parse(op['date_operation'])),
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Text(
                  '${isAppro ? '+' : '-'} ${currencyFormat.format(op['montant'])}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: isAppro ? Colors.blue : Colors.orange,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
