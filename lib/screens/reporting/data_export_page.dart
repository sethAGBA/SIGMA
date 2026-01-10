import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';

class DataExportPage extends StatefulWidget {
  const DataExportPage({super.key});

  @override
  State<DataExportPage> createState() => _DataExportPageState();
}

class _DataExportPageState extends State<DataExportPage> {
  bool _isExporting = false;

  Future<void> _exportToCSV(String entity) async {
    setState(() => _isExporting = true);

    try {
      final db = await DatabaseService().database;
      List<Map<String, dynamic>> data = [];
      String fileName = "";

      switch (entity) {
        case 'Clients':
          data = await db.query('clients');
          fileName = "clients_export";
          break;
        case 'Prêts':
          data = await db.query('prets');
          fileName = "prets_export";
          break;
        case 'Épargne':
          data = await db.query('transactions_epargne');
          fileName = "transactions_epargne_export";
          break;
        case 'Remboursements':
          data = await db.query('remboursements');
          fileName = "remboursements_export";
          break;
        default:
          throw "Entité inconnue";
      }

      if (data.isEmpty) {
        throw "Aucune donnée à exporter pour $entity";
      }

      // Generate CSV string
      final headers = data.first.keys.join(';');
      final rows = data
          .map((row) => row.values.map((v) => '"$v"').join(';'))
          .join('\n');
      final csvContent = "$headers\n$rows";

      // Save file
      final directory = await getDownloadsDirectory();
      if (directory == null)
        throw "Impossible d'accéder au dossier Téléchargements";

      final filePath =
          "${directory.path}/${fileName}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv";
      final file = File(filePath);
      await file.writeAsString(csvContent);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exportation réussie : $filePath'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur d\'exportation : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(isDark),
            const SizedBox(height: 40),
            _buildExportGrid(isDark),
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
                Icons.download_rounded,
                color: AppColors.primary,
                size: 32,
              ),
            ),
            const SizedBox(width: 20),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Exportation de Données',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Extrayez vos données opérationnelles au format CSV pour analyse externe.',
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
      ],
    );
  }

  Widget _buildExportGrid(bool isDark) {
    return Wrap(
      spacing: 24,
      runSpacing: 24,
      children: [
        _buildExportCard(
          'Registre des Clients',
          'Liste complète des clients avec informations d\'identification et contact.',
          Icons.people_alt_rounded,
          Colors.blue,
          () => _exportToCSV('Clients'),
          isDark,
        ),
        _buildExportCard(
          'Portefeuille de Prêts',
          'Détails de tous les prêts octroyés, encours et statuts.',
          Icons.account_balance_wallet_rounded,
          Colors.orange,
          () => _exportToCSV('Prêts'),
          isDark,
        ),
        _buildExportCard(
          'Transactions d\'Épargne',
          'Historique des dépôts et retraits sur les comptes épargne.',
          Icons.savings_rounded,
          Colors.teal,
          () => _exportToCSV('Épargne'),
          isDark,
        ),
        _buildExportCard(
          'Journal des Remboursements',
          'Toutes les opérations de remboursement effectuées par les clients.',
          Icons.receipt_long_rounded,
          Colors.green,
          () => _exportToCSV('Remboursements'),
          isDark,
        ),
      ],
    );
  }

  Widget _buildExportCard(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onExport,
    bool isDark,
  ) {
    return Container(
      width: 350,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isExporting ? null : onExport,
              icon: _isExporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.file_download_rounded),
              label: Text(_isExporting ? 'Exportation...' : 'Exporter en CSV'),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
