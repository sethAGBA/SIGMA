// lib/screens/comptabilite/grand_livre_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/database_service.dart';
import '../../models/ledger_entry_model.dart';

class GrandLivrePage extends StatefulWidget {
  const GrandLivrePage({super.key});

  @override
  State<GrandLivrePage> createState() => _GrandLivrePageState();
}

class _GrandLivrePageState extends State<GrandLivrePage> {
  final DatabaseService _db = DatabaseService();
  final currencyFormat = NumberFormat.currency(
    symbol: 'FCFA',
    decimalDigits: 0,
    locale: 'fr_FR',
  );

  List<Map<String, dynamic>> _comptes = [];
  String? _selectedCompte;
  AccountLedger? _ledger;
  bool _isLoading = false;
  DateTime? _dateDebut;
  DateTime? _dateFin;

  @override
  void initState() {
    super.initState();
    _loadComptes();
  }

  Future<void> _loadComptes() async {
    setState(() => _isLoading = true);
    try {
      final comptes = await _db.getAccountsWithMovements();
      setState(() {
        _comptes = comptes;
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

  Future<void> _loadLedger() async {
    if (_selectedCompte == null) return;

    setState(() => _isLoading = true);
    try {
      final ledger = await _db.getAccountLedger(
        compteNumero: _selectedCompte!,
        dateDebut: _dateDebut,
        dateFin: _dateFin,
      );
      setState(() {
        _ledger = ledger;
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
      if (_selectedCompte != null) {
        _loadLedger();
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
        title: const Text('Grand Livre'),
        backgroundColor: bgColor,
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: _isLoading && _comptes.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Filtres
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.grey.shade300,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Filtres',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: _selectedCompte,
                                decoration: const InputDecoration(
                                  labelText: 'Compte',
                                  border: OutlineInputBorder(),
                                ),
                                items: _comptes.map((c) {
                                  return DropdownMenuItem(
                                    value: c['numero'] as String,
                                    child: Text(
                                      '${c['numero']} - ${c['libelle']}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() => _selectedCompte = val);
                                  _loadLedger();
                                },
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
                                        : 'Toutes',
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
                                        ? DateFormat(
                                            'dd/MM/yyyy',
                                          ).format(_dateFin!)
                                        : 'Toutes',
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
                                  if (_selectedCompte != null) {
                                    _loadLedger();
                                  }
                                },
                                tooltip: 'Effacer les dates',
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Résultats
                  if (_ledger != null)
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // En-tête
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Compte ${_ledger!.compteNumero}',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                    Text(
                                      _ledger!.compteLibelle,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.print),
                                      onPressed: () {
                                        // TODO: Imprimer
                                      },
                                      tooltip: 'Imprimer',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.download),
                                      onPressed: () {
                                        // TODO: Export Excel
                                      },
                                      tooltip: 'Exporter Excel',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Tableau
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    headingRowColor: MaterialStateProperty.all(
                                      isDark
                                          ? Colors.white.withOpacity(0.05)
                                          : Colors.grey.shade100,
                                    ),
                                    columns: const [
                                      DataColumn(label: Text('Date')),
                                      DataColumn(label: Text('Journal')),
                                      DataColumn(label: Text('N° Pièce')),
                                      DataColumn(label: Text('Libellé')),
                                      DataColumn(
                                        label: Text('Débit'),
                                        numeric: true,
                                      ),
                                      DataColumn(
                                        label: Text('Crédit'),
                                        numeric: true,
                                      ),
                                      DataColumn(
                                        label: Text('Solde'),
                                        numeric: true,
                                      ),
                                    ],
                                    rows: _ledger!.mouvements.map((m) {
                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            Text(
                                              DateFormat(
                                                'dd/MM/yyyy',
                                              ).format(m.dateComptable),
                                            ),
                                          ),
                                          DataCell(Text(m.journalCode)),
                                          DataCell(Text(m.numeroPiece)),
                                          DataCell(
                                            SizedBox(
                                              width: 250,
                                              child: Text(
                                                m.libelle,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              m.debit > 0
                                                  ? currencyFormat.format(
                                                      m.debit,
                                                    )
                                                  : '',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              m.credit > 0
                                                  ? currencyFormat.format(
                                                      m.credit,
                                                    )
                                                  : '',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              currencyFormat.format(m.solde),
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: m.solde >= 0
                                                    ? Colors.green
                                                    : Colors.red,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),

                            const Divider(height: 32),

                            // Totaux
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                _buildTotalItem(
                                  'Total Débit',
                                  _ledger!.totalDebit,
                                  Colors.blue,
                                ),
                                const SizedBox(width: 32),
                                _buildTotalItem(
                                  'Total Crédit',
                                  _ledger!.totalCredit,
                                  Colors.orange,
                                ),
                                const SizedBox(width: 32),
                                _buildTotalItem(
                                  'Solde Final',
                                  _ledger!.soldeFinal,
                                  _ledger!.soldeFinal >= 0
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_selectedCompte == null)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.account_balance_wallet,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Sélectionnez un compte pour afficher le grand livre',
                              style: TextStyle(color: Colors.grey),
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

  Widget _buildTotalItem(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(
          currencyFormat.format(value),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
