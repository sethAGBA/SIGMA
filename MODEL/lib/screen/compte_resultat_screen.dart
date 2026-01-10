import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart' as excel_lib;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/compte_comptable.dart';
import '../../models/ecriture_comptable.dart';
import '../../services/database_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'dart:typed_data';
import 'dart:io';

class ResultatEntry {
  final CompteComptable account;
  double total;
  ResultatEntry({required this.account, this.total = 0.0});
}

class CompteResultatScreen extends StatefulWidget {
  const CompteResultatScreen({Key? key}) : super(key: key);

  @override
  _CompteResultatScreenState createState() => _CompteResultatScreenState();
}

class _CompteResultatScreenState extends State<CompteResultatScreen> {
  DateTime _startDate = DateTime(DateTime.now().year, 1, 1);
  DateTime _endDate = DateTime.now();
  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _currencyFormat = NumberFormat("#,##0.00", "fr_FR");

  List<ResultatEntry> _produits = [];
  List<ResultatEntry> _charges = [];
  double _totalProduits = 0;
  double _totalCharges = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _generateReport();
  }

  Future<void> _generateReport() async {
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

    final List<ResultatEntry> produitsEntries = [];
    final List<ResultatEntry> chargesEntries = [];

    for (var account in allAccounts) {
      final total = movements[account.code] ?? 0.0;
      if (total == 0) continue;

      // Class 7 are Produits (Credits are positive, so we invert the balance)
      if (account.code.startsWith('7')) {
        produitsEntries.add(ResultatEntry(account: account, total: -total));
      }
      // Class 6 are Charges (Debits are positive)
      else if (account.code.startsWith('6')) {
        chargesEntries.add(ResultatEntry(account: account, total: total));
      }
    }

    setState(() {
      _produits = produitsEntries..sort((a,b) => a.account.code.compareTo(b.account.code));
      _charges = chargesEntries..sort((a,b) => a.account.code.compareTo(b.account.code));
      _totalProduits = _produits.fold(0, (sum, item) => sum + item.total);
      _totalCharges = _charges.fold(0, (sum, item) => sum + item.total);
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildResultatView(),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Text('Période du '),
                TextButton(child: Text(_dateFormat.format(_startDate)), onPressed: () => _pickDate(true)),
                Text(' au '),
                TextButton(child: Text(_dateFormat.format(_endDate)), onPressed: () => _pickDate(false)),
                const SizedBox(width: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.search),
                  label: const Text('Générer'),
                  onPressed: _generateReport,
                ),
              ]),
              Row(children: [
                Tooltip(
                  message: 'Exporter en CSV',
                  child: TextButton.icon(
                    onPressed: () async {
                      final totalProduits = _totalProduits;
                      final totalCharges = _totalCharges;
                      final resultat = totalProduits - totalCharges;
                      final sb = StringBuffer();
                      sb.writeln('Compte de Résultat');
                      sb.writeln('Produits,${NumberFormat('#,##0.00','fr_FR').format(totalProduits)}');
                      sb.writeln('Charges,${NumberFormat('#,##0.00','fr_FR').format(totalCharges)}');
                      sb.writeln('Résultat,${NumberFormat('#,##0.00','fr_FR').format(resultat)}');
                      final path = await FilePicker.platform.saveFile(dialogTitle: 'Exporter Compte de résultat (CSV)', fileName: 'compte_resultat.csv', type: FileType.custom, allowedExtensions: ['csv']);
                      if (path == null) return; await File(path).writeAsString(sb.toString());
                    },
                    icon: const Icon(Icons.insert_drive_file, size: 18),
                    label: const Text('CSV'),
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.resolveWith((s) => s.contains(MaterialState.hovered) ? Colors.white12 : Colors.transparent),
                      foregroundColor: MaterialStateProperty.all(Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Exporter en Excel',
                  child: TextButton.icon(
                    onPressed: () async {
                      final ex = excel_lib.Excel.createExcel();
                      final s = ex[ex.getDefaultSheet()!];
                      s.appendRow([excel_lib.TextCellValue('Ligne'), excel_lib.TextCellValue('Montant')]);
                      s.appendRow([excel_lib.TextCellValue('Produits'), excel_lib.TextCellValue(NumberFormat('#,##0.00','fr_FR').format(_totalProduits))]);
                      s.appendRow([excel_lib.TextCellValue('Charges'), excel_lib.TextCellValue(NumberFormat('#,##0.00','fr_FR').format(_totalCharges))]);
                      s.appendRow([excel_lib.TextCellValue('Résultat'), excel_lib.TextCellValue(NumberFormat('#,##0.00','fr_FR').format(_totalProduits - _totalCharges))]);
                      final bytes = ex.encode(); if (bytes == null) return;
                      final path = await FilePicker.platform.saveFile(dialogTitle: 'Exporter Compte de résultat (Excel)', fileName: 'compte_resultat.xlsx', type: FileType.custom, allowedExtensions: ['xlsx']);
                      if (path == null) return; await File(path).writeAsBytes(Uint8List.fromList(bytes));
                    },
                    icon: const Icon(Icons.table_chart, size: 18),
                    label: const Text('Excel'),
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.resolveWith((s) => s.contains(MaterialState.hovered) ? Colors.white12 : Colors.transparent),
                      foregroundColor: MaterialStateProperty.all(Colors.white),
                    ),
                  ),
                ),
                Tooltip(
                  message: 'Exporter en PDF',
                  child: TextButton.icon(
                    onPressed: () async {
                      final pdf = pw.Document();
                      final totalProduits = _totalProduits;
                      final totalCharges = _totalCharges;
                      final resultat = totalProduits - totalCharges;
                      pdf.addPage(pw.MultiPage(
                        pageFormat: PdfPageFormat.a4,
                        build: (ctx) => [
                          pw.Text('Compte de Résultat', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 10),
                          pw.Table.fromTextArray(
                            headers: ['Ligne','Montant'],
                            data: [
                              ['Produits', NumberFormat('#,##0.00','fr_FR').format(totalProduits)],
                              ['Charges', NumberFormat('#,##0.00','fr_FR').format(totalCharges)],
                              ['Résultat', NumberFormat('#,##0.00','fr_FR').format(resultat)],
                            ],
                            border: pw.TableBorder.all(color: PdfColors.grey),
                            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            cellAlignment: pw.Alignment.centerLeft,
                          ),
                        ],
                      ));
                      final bytes = await pdf.save();
                      final path = await FilePicker.platform.saveFile(dialogTitle: 'Exporter Compte de résultat (PDF)', fileName: 'compte_resultat.pdf', type: FileType.custom, allowedExtensions: ['pdf']);
                      if (path == null) return; await File(path).writeAsBytes(bytes);
                    },
                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                    label: const Text('PDF'),
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.resolveWith((s) => s.contains(MaterialState.hovered) ? Colors.white12 : Colors.transparent),
                      foregroundColor: MaterialStateProperty.all(Colors.white),
                    ),
                  ),
                ),
              ]),
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

  Widget _buildResultatView() {
    final double resultatNet = _totalProduits - _totalCharges;
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildSide('CHARGES', _charges, _totalCharges)),
              const VerticalDivider(width: 2, color: Colors.grey),
              Expanded(child: _buildSide('PRODUITS', _produits, _totalProduits)),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Résultat Net: ', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(
                _currencyFormat.format(resultatNet),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: resultatNet >= 0 ? Colors.greenAccent : Colors.redAccent,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSide(String title, List<ResultatEntry> entries, double total) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return ListTile(
                title: Text('${entry.account.code} - ${entry.account.title}'),
                trailing: Text(_currencyFormat.format(entry.total)),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total $title', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(_currencyFormat.format(total), style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }
}
