import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/compte_comptable.dart';
import '../../models/ecriture_comptable.dart';
import '../../services/database_service.dart';

class DeclarationsFiscalesScreen extends StatefulWidget {
  const DeclarationsFiscalesScreen({Key? key}) : super(key: key);

  @override
  _DeclarationsFiscalesScreenState createState() => _DeclarationsFiscalesScreenState();
}

class _DeclarationsFiscalesScreenState extends State<DeclarationsFiscalesScreen> {
  DateTime _startDate = DateTime(DateTime.now().year, 1, 1);
  DateTime _endDate = DateTime.now();
  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _currencyFormat = NumberFormat("#,##0.00", "fr_FR");

  double _totalProduits = 0;
  double _totalCharges = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _generateSummary();
  }

  Future<void> _generateSummary() async {
    setState(() => _isLoading = true);

    final db = DatabaseService();
    final allAccounts = (await db.getPlanComptable()).map((m) => CompteComptable.fromMap(m)).toList();
    final ecritures = (await db.getEcritures(start: _startDate, end: _endDate)).map((m) => EcritureComptable.fromMap(m)).toList();

    final Map<String, double> movements = {};
    for (var acc in allAccounts) {
      movements[acc.code] = 0.0;
    }

    for (var ecriture in ecritures) {
      movements.update(ecriture.accountCode, (value) => value + ecriture.debit - ecriture.credit, ifAbsent: () => ecriture.debit - ecriture.credit);
    }

    double tempTotalProduits = 0;
    double tempTotalCharges = 0;

    for (var account in allAccounts) {
      final total = movements[account.code] ?? 0.0;
      if (total == 0) continue;

      // Class 7 are Produits (Credits are positive, so we invert the balance)
      if (account.code.startsWith('7')) {
        tempTotalProduits += -total;
      }
      // Class 6 are Charges (Debits are positive)
      else if (account.code.startsWith('6')) {
        tempTotalCharges += total;
      }
    }

    setState(() {
      _totalProduits = tempTotalProduits;
      _totalCharges = tempTotalCharges;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double resultatNet = _totalProduits - _totalCharges;

    return Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummaryCard('Total des Produits', _totalProduits, Colors.greenAccent),
                      const SizedBox(height: 16),
                      _buildSummaryCard('Total des Charges', _totalCharges, Colors.redAccent),
                      const SizedBox(height: 16),
                      _buildSummaryCard('Résultat Net', resultatNet, resultatNet >= 0 ? Colors.blueAccent : Colors.orangeAccent),
                      const SizedBox(height: 32),
                      Text('Documents Fiscaux (à implémenter)', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(child: Text('Zone de gestion des documents fiscaux')),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Génération des déclarations à implémenter.')),
                          );
                        },
                        icon: const Icon(Icons.download),
                        label: const Text('Télécharger les déclarations'),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        color: const Color(0xFF0F172A),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Text('Période du '),
              TextButton(child: Text(_dateFormat.format(_startDate)), onPressed: () => _pickDate(true)),
              Text(' au '),
              TextButton(child: Text(_dateFormat.format(_endDate)), onPressed: () => _pickDate(false)),
              const SizedBox(width: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.search),
                label: const Text('Générer'),
                onPressed: _generateSummary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(context: context, initialDate: isStart ? _startDate : _endDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Widget _buildSummaryCard(String title, double value, Color color) {
    return Card(
      color: const Color(0xFF1A202C),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(_currencyFormat.format(value), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
