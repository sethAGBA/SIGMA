// lib/screens/comptabilite/balance_generale_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/database_service.dart';
import '../../core/services/regulatory_export_service.dart';
import '../../models/trial_balance_model.dart';

class BalanceGeneralePage extends StatefulWidget {
  const BalanceGeneralePage({super.key});

  @override
  State<BalanceGeneralePage> createState() => _BalanceGeneralePageState();
}

class _BalanceGeneralePageState extends State<BalanceGeneralePage> {
  final DatabaseService _db = DatabaseService();
  final RegulatoryExportService _exportService = RegulatoryExportService();
  final currencyFormat = NumberFormat.currency(
    symbol: 'FCFA',
    decimalDigits: 0,
    locale: 'fr_FR',
  );

  TrialBalance? _balance;
  bool _isLoading = false;
  DateTime? _dateDebut;
  DateTime? _dateFin;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    setState(() => _isLoading = true);
    try {
      final balance = await _db.getTrialBalance(
        dateDebut: _dateDebut,
        dateFin: _dateFin,
      );
      setState(() {
        _balance = balance;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  Future<void> _selectDate(bool isStartDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? (_dateDebut ?? DateTime.now())
          : (_dateFin ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _dateDebut = picked;
        } else {
          _dateFin = picked;
        }
      });
      _loadBalance();
    }
  }

  Future<void> _exportBalance() async {
    if (_balance == null) return;
    try {
      final path = await _exportService.exportTrialBalanceCsv(
        balance: _balance!,
        dateDebut: _dateDebut,
        dateFin: _dateFin,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Balance exportée : $path')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur export : $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F5F5);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Balance Générale'),
        backgroundColor: bgColor,
        foregroundColor: textColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () {
              // TODO: Imprimer
            },
            tooltip: 'Imprimer',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _balance == null ? null : _exportBalance,
            tooltip: 'Exporter Excel',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Filtres de date
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Période:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(true),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Date début',
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.calendar_today),
                              ),
                              child: Text(
                                _dateDebut != null
                                    ? DateFormat(
                                        'dd/MM/yyyy',
                                      ).format(_dateDebut!)
                                    : 'Depuis le début',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(false),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Date fin',
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.calendar_today),
                              ),
                              child: Text(
                                _dateFin != null
                                    ? DateFormat('dd/MM/yyyy').format(_dateFin!)
                                    : 'Jusqu\'à aujourd\'hui',
                              ),
                            ),
                          ),
                        ),
                        if (_dateDebut != null || _dateFin != null)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _dateDebut = null;
                                _dateFin = null;
                              });
                              _loadBalance();
                            },
                            tooltip: 'Effacer les dates',
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Indicateur d'équilibre
                  if (_balance != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _balance!.isBalanced
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _balance!.isBalanced
                              ? Colors.green
                              : Colors.red,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _balance!.isBalanced
                                ? Icons.check_circle
                                : Icons.error,
                            color: _balance!.isBalanced
                                ? Colors.green
                                : Colors.red,
                            size: 32,
                          ),
                          const SizedBox(width: 16),
                          Text(
                            _balance!.isBalanced
                                ? 'BALANCE ÉQUILIBRÉE'
                                : 'BALANCE DÉSÉQUILIBRÉE',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _balance!.isBalanced
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Tableau de balance
                  if (_balance != null)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark
                                ? Colors.white10
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Column(
                          children: [
                            // En-tête
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Balance Générale',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                Text(
                                  '${_balance!.entries.length} comptes',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Tableau
                            Expanded(
                              child: SingleChildScrollView(
                                child: DataTable(
                                  headingRowColor: MaterialStateProperty.all(
                                    isDark
                                        ? Colors.white.withOpacity(0.05)
                                        : Colors.grey.shade100,
                                  ),
                                  columnSpacing: 24,
                                  columns: const [
                                    DataColumn(label: Text('N° Compte')),
                                    DataColumn(label: Text('Libellé')),
                                    DataColumn(
                                      label: Text('Total Débit'),
                                      numeric: true,
                                    ),
                                    DataColumn(
                                      label: Text('Total Crédit'),
                                      numeric: true,
                                    ),
                                    DataColumn(
                                      label: Text('Solde Débiteur'),
                                      numeric: true,
                                    ),
                                    DataColumn(
                                      label: Text('Solde Créditeur'),
                                      numeric: true,
                                    ),
                                  ],
                                  rows: _balance!.entries.map((entry) {
                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          Text(
                                            entry.compteNumero,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: 200,
                                            child: Text(
                                              entry.compteLibelle,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            currencyFormat.format(
                                              entry.totalDebit,
                                            ),
                                            style: const TextStyle(
                                              color: Colors.blue,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            currencyFormat.format(
                                              entry.totalCredit,
                                            ),
                                            style: const TextStyle(
                                              color: Colors.orange,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            entry.soldeDebiteur > 0
                                                ? currencyFormat.format(
                                                    entry.soldeDebiteur,
                                                  )
                                                : '',
                                            style: const TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            entry.soldeCrediteur > 0
                                                ? currencyFormat.format(
                                                    entry.soldeCrediteur,
                                                  )
                                                : '',
                                            style: const TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),

                            const Divider(height: 32, thickness: 2),

                            // Totaux
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildTotalCard(
                                  'Total Débits',
                                  _balance!.totalDebits,
                                  Colors.blue,
                                  isDark,
                                ),
                                _buildTotalCard(
                                  'Total Crédits',
                                  _balance!.totalCredits,
                                  Colors.orange,
                                  isDark,
                                ),
                                _buildTotalCard(
                                  'Soldes Débiteurs',
                                  _balance!.totalSoldesDebiteurs,
                                  Colors.green,
                                  isDark,
                                ),
                                _buildTotalCard(
                                  'Soldes Créditeurs',
                                  _balance!.totalSoldesCrediteurs,
                                  Colors.red,
                                  isDark,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildTotalCard(String label, double value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            currencyFormat.format(value),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
