import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import '../../core/services/automatic_accounting_service.dart';
import '../../models/par_stats_model.dart';

class ProvisionsPage extends StatefulWidget {
  const ProvisionsPage({super.key});

  @override
  State<ProvisionsPage> createState() => _ProvisionsPageState();
}

class _ProvisionsPageState extends State<ProvisionsPage> {
  final DatabaseService _db = DatabaseService();
  final AutomaticAccountingService _autoAccounting =
      AutomaticAccountingService();
  final currencyFormat = NumberFormat.currency(
    symbol: 'FCFA',
    decimalDigits: 0,
    locale: 'fr_FR',
  );

  PARStats? _stats;
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _db.getPARStats();
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _generateProvisionEntry(double amount) async {
    if (amount <= 0) return;

    setState(() => _isProcessing = true);
    try {
      await _autoAccounting.createProvisionEntry(
        amount: amount,
        agentName: 'ADMIN', // Temporaire en attendant le login
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Écriture de provision générée avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _loadData(); // Recharger pour voir la mise à jour des provisions constatées
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la génération : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _stats == null
          ? const Center(child: Text('Aucune donnée disponible'))
          : _buildContent(isDark),
    );
  }

  Widget _buildContent(bool isDark) {
    // Calculs théoriques
    final prov31_90 = _stats!.par30 * 0.25;
    final prov91_180 = _stats!.par90 * 0.50;
    final prov180plus = _stats!.par180 * 1.0;
    final totalTheorique = prov31_90 + prov91_180 + prov180plus;
    final ecart = totalTheorique - _stats!.provisionsConstituees;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isDark),
          const SizedBox(height: 40),
          _buildSummaryCards(
            totalTheorique,
            _stats!.provisionsConstituees,
            ecart,
            isDark,
          ),
          const SizedBox(height: 32),
          _buildCalculationTable(
            prov31_90,
            prov91_180,
            prov180plus,
            totalTheorique,
            isDark,
          ),
          const SizedBox(height: 32),
          if (ecart > 0) _buildActionSection(ecart, isDark),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.shield_rounded,
                color: Colors.purple,
                size: 32,
              ),
            ),
            const SizedBox(width: 20),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gestion des Provisions',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Calcul et comptabilisation des dépréciations sur créances douteuses.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        IconButton(
          onPressed: _loadData,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Actualiser',
        ),
      ],
    );
  }

  Widget _buildSummaryCards(
    double theorique,
    double constatee,
    double ecart,
    bool isDark,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Besoin Théorique',
            currencyFormat.format(theorique),
            Icons.calculate_rounded,
            Colors.blue,
            isDark,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _buildSummaryCard(
            'Dépréciation au Bilan',
            currencyFormat.format(constatee),
            Icons.account_balance_rounded,
            Colors.green,
            isDark,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _buildSummaryCard(
            'Écart de Provision',
            currencyFormat.format(ecart),
            ecart > 0
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline_rounded,
            ecart > 0 ? Colors.orange : Colors.teal,
            isDark,
            subtitle: ecart > 0
                ? 'Dotation à prévoir'
                : 'Provisions suffisantes',
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isDark, {
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCalculationTable(
    double p25,
    double p50,
    double p100,
    double total,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Détail du calcul par catégorie de retard',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(1.5),
              2: FlexColumnWidth(1),
              3: FlexColumnWidth(1.5),
            },
            children: [
              _buildTableHeader(isDark),
              _buildTableRow(
                'Retard 31-90 jours',
                _stats!.par30,
                '25%',
                p25,
                isDark,
              ),
              _buildTableRow(
                'Retard 91-180 jours',
                _stats!.par90,
                '50%',
                p50,
                isDark,
              ),
              _buildTableRow(
                'Retard > 180 jours',
                _stats!.par180,
                '100%',
                p100,
                isDark,
              ),
              _buildTableFooter('TOTAL THÉORIQUE', total, isDark),
            ],
          ),
        ],
      ),
    );
  }

  TableRow _buildTableHeader(bool isDark) {
    return TableRow(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.02)
            : Colors.grey.withOpacity(0.05),
      ),
      children: const [
        Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Catégorie',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Encours (PAR)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(16),
          child: Text('Taux', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Provision',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  TableRow _buildTableRow(
    String cat,
    double encours,
    String taux,
    double prov,
    bool isDark,
  ) {
    return TableRow(
      children: [
        Padding(padding: const EdgeInsets.all(16), child: Text(cat)),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(currencyFormat.format(encours)),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            taux,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            currencyFormat.format(prov),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  TableRow _buildTableFooter(String label, double total, bool isDark) {
    return TableRow(
      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.05)),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
        const Padding(padding: EdgeInsets.all(16), child: SizedBox.shrink()),
        const Padding(padding: EdgeInsets.all(16), child: SizedBox.shrink()),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            currencyFormat.format(total),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionSection(double ecart, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.primary,
            size: 40,
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Régularisation comptable requise',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Une dotation de ${currencyFormat.format(ecart)} est nécessaire pour couvrir le risque actuel du portefeuille conformément aux politiques prudentielles.',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 32),
          ElevatedButton.icon(
            onPressed: _isProcessing
                ? null
                : () => _generateProvisionEntry(ecart),
            icon: _isProcessing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.auto_fix_high_rounded),
            label: const Text('Générer la dotation (OD)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}
