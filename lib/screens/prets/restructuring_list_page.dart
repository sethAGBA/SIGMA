import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/database_service.dart';

class RestructuringListPage extends StatefulWidget {
  const RestructuringListPage({super.key});

  @override
  State<RestructuringListPage> createState() => _RestructuringListPageState();
}

class _RestructuringListPageState extends State<RestructuringListPage> {
  final DatabaseService _db = DatabaseService();
  final currencyFormat = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: 'FCFA',
    decimalDigits: 0,
  );
  final dateFormat = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildHeader(isDark),
          Expanded(child: _buildRestructuredList(isDark)),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.sync_rounded, color: Colors.teal),
              ),
              const SizedBox(width: 16),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Restructurations',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'Suivi des prêts rééchelonnés et modifications de termes',
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
          _buildStatsSummary(isDark),
        ],
      ),
    );
  }

  Widget _buildStatsSummary(bool isDark) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _db.getRestructuredLoans(),
      builder: (context, snapshot) {
        int total = snapshot.hasData ? snapshot.data!.length : 0;
        double totalVolume = 0;
        if (snapshot.hasData) {
          for (var l in snapshot.data!) {
            totalVolume += (l['solde_restant'] as num?)?.toDouble() ?? 0;
          }
        }

        return Row(
          children: [
            _buildSmallStatCard(
              'Dossiers',
              total.toString(),
              Colors.teal,
              isDark,
            ),
            const SizedBox(width: 16),
            _buildSmallStatCard(
              'Volume Restructuré',
              currencyFormat.format(totalVolume),
              Colors.blue,
              isDark,
            ),
          ],
        );
      },
    );
  }

  Widget _buildSmallStatCard(
    String label,
    String value,
    Color color,
    bool isDark,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.grey.shade100,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.grey.shade500,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestructuredList(bool isDark) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _db.getRestructuredLoans(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(
            Icons.sync_disabled_rounded,
            'Aucune restructuration',
            'Aucun prêt n\'a été marqué comme restructuré pour le moment.',
          );
        }

        final loans = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: loans.length,
          itemBuilder: (context, index) {
            final loan = loans[index];
            return _buildRestructuredCard(loan, isDark);
          },
        );
      },
    );
  }

  Widget _buildRestructuredCard(Map<String, dynamic> loan, bool isDark) {
    final double initial = (loan['montant_initial'] as num?)?.toDouble() ?? 0;
    final double current = (loan['solde_restant'] as num?)?.toDouble() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.history_edu_rounded, color: Colors.teal),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loan['client_name'] ?? 'Client Inconnu',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${loan['produit_nom']} • Prêt #${loan['numero_pret']}',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildMiniInfo('Initial', currencyFormat.format(initial)),
                      const SizedBox(width: 24),
                      _buildMiniInfo('Encours', currencyFormat.format(current)),
                    ],
                  ),
                ],
              ),
            ),
            _buildStatusBadge(),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: Colors.grey.shade500,
            letterSpacing: 0.5,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.teal.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal.withOpacity(0.2)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 12, color: Colors.teal),
          SizedBox(width: 6),
          Text(
            'RESTRUCTURÉ',
            style: TextStyle(
              color: Colors.teal,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 80, color: Colors.teal.withOpacity(0.2)),
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
}
