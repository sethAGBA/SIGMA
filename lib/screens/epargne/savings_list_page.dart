// lib/screens/epargne/savings_list_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import '../../models/savings_account_model.dart';
import 'open_savings_account_dialog.dart';
import '../../widgets/dialogs/savings_account_detail_dialog.dart';

class SavingsListPage extends StatefulWidget {
  const SavingsListPage({super.key});

  @override
  State<SavingsListPage> createState() => _SavingsListPageState();
}

class _SavingsListPageState extends State<SavingsListPage> {
  late Future<List<SavingsAccount>> _accountsFuture;
  final currencyFormat = NumberFormat.currency(
    symbol: 'FCFA',
    decimalDigits: 0,
    locale: 'fr_FR',
  );
  final dateFormat = DateFormat('dd/MM/yyyy');
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _accountsFuture = DatabaseService().getSavingsAccounts();
    });
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
            const SizedBox(height: 24),
            _buildStatsCards(isDark),
            const SizedBox(height: 24),
            _buildSearchBar(isDark),
            const SizedBox(height: 16),
            Expanded(child: _buildAccountList(isDark)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-epargne',
        onPressed: () async {
          final result = await showDialog<bool>(
            context: context,
            builder: (context) => const OpenSavingsAccountDialog(),
          );
          if (result == true) _refresh();
        },
        label: const Text('OUVRIR UN COMPTE'),
        icon: const Icon(Icons.add_card_rounded),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gestion de l\'Épargne',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        Text(
          'Suivi des livrets, dépôts et retraits clients',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildStatsCards(bool isDark) {
    return FutureBuilder<List<SavingsAccount>>(
      future: _accountsFuture,
      builder: (context, snapshot) {
        double totalEpargne = 0;
        int activeAccounts = 0;
        if (snapshot.hasData) {
          totalEpargne = snapshot.data!.fold(
            0,
            (sum, item) => sum + item.solde,
          );
          activeAccounts = snapshot.data!
              .where((a) => a.statut == SavingsAccountStatus.actif)
              .length;
        }

        return Row(
          children: [
            _statCard(
              'Encours Total Épargne',
              currencyFormat.format(totalEpargne),
              Icons.account_balance_wallet_rounded,
              AppColors.primary,
              isDark,
            ),
            const SizedBox(width: 24),
            _statCard(
              'Comptes Actifs',
              activeAccounts.toString(),
              Icons.people_alt_rounded,
              AppColors.secondary,
              isDark,
            ),
            const SizedBox(width: 24),
            _statCard(
              'Collecte du Mois',
              currencyFormat.format(0), // Placeholder
              Icons.trending_up_rounded,
              Colors.green,
              isDark,
            ),
          ],
        );
      },
    );
  }

  Widget _statCard(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.darkDivider : Colors.grey[200]!,
          ),
          boxShadow: [
            if (!isDark)
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
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : Colors.grey[200]!,
        ),
      ),
      child: TextField(
        onChanged: (value) =>
            setState(() => _searchQuery = value.toLowerCase()),
        decoration: const InputDecoration(
          icon: Icon(Icons.search, color: Colors.grey),
          hintText: 'Rechercher par client, N° compte ou téléphone...',
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildAccountList(bool isDark) {
    return FutureBuilder<List<SavingsAccount>>(
      future: _accountsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        final filtered = (snapshot.data ?? []).where((account) {
          final clientName = '${account.client?.nom} ${account.client?.prenoms}'
              .toLowerCase();
          return clientName.contains(_searchQuery) ||
              account.numeroCompte.toLowerCase().contains(_searchQuery) ||
              (account.client?.telephone ?? '').contains(_searchQuery);
        }).toList();

        if (filtered.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open_rounded, size: 64, color: Colors.grey),
                Text(
                  'Aucun compte trouvé',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkDivider : Colors.grey[200]!,
            ),
          ),
          child: Column(
            children: [
              _buildListHeader(isDark),
              Expanded(
                child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: isDark ? AppColors.darkDivider : Colors.grey[100],
                  ),
                  itemBuilder: (context, index) =>
                      _buildAccountRow(filtered[index], isDark),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildListHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey[50],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: _headerCell('N° Compte')),
          Expanded(flex: 3, child: _headerCell('Client')),
          Expanded(flex: 2, child: _headerCell('Produit')),
          Expanded(
            flex: 2,
            child: _headerCell('Solde', align: TextAlign.right),
          ),
          Expanded(
            flex: 1,
            child: _headerCell('Statut', align: TextAlign.center),
          ),
        ],
      ),
    );
  }

  Widget _headerCell(String label, {TextAlign align = TextAlign.left}) {
    return Text(
      label.toUpperCase(),
      textAlign: align,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: Colors.grey,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildAccountRow(SavingsAccount account, bool isDark) {
    return InkWell(
      onTap: () async {
        await showDialog(
          context: context,
          builder: (context) => SavingsAccountDetailDialog(account: account),
        );
        _refresh();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                account.numeroCompte,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${account.client?.nom} ${account.client?.prenoms}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    account.client?.telephone ?? 'Pas de téléphone',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                account.produit?.nom ?? 'N/A',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                currencyFormat.format(account.solde),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: AppColors.secondary,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Center(child: _statusBadge(account.statut)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(SavingsAccountStatus statut) {
    Color color;
    switch (statut) {
      case SavingsAccountStatus.actif:
        color = Colors.green;
        break;
      case SavingsAccountStatus.bloque:
        color = Colors.orange;
        break;
      case SavingsAccountStatus.ferme:
        color = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        statut.label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
