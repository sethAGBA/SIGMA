import 'dart:io' show File;

import 'package:excel/excel.dart' as excel_lib;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/compte_comptable.dart';
import '../../models/ecriture_comptable.dart';
import '../../services/database_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'dart:typed_data';
import 'dart:io';

class BilanEntry {
  final CompteComptable account;
  double balance;
  BilanEntry({required this.account, this.balance = 0.0});
}

class BilanScreen extends StatefulWidget {
  const BilanScreen({Key? key}) : super(key: key);

  @override
  _BilanScreenState createState() => _BilanScreenState();
}

class _BilanScreenState extends State<BilanScreen> {
  DateTime _endDate = DateTime.now();
  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _currencyFormat = NumberFormat("#,##0.00", "fr_FR");

  List<BilanEntry> _actif = [];
  List<BilanEntry> _passif = [];
  double _totalActif = 0;
  double _totalPassif = 0;
  bool _isLoading = false;
  final ButtonStyle _exportBtnStyle = ButtonStyle(
    backgroundColor: MaterialStateProperty.resolveWith((s) => s.contains(MaterialState.hovered) ? Colors.white12 : Colors.transparent),
    foregroundColor: MaterialStateProperty.all(Colors.white),
    padding: MaterialStateProperty.all(EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
    minimumSize: MaterialStateProperty.all(Size(88, 36)),
  );

  @override
  void initState() {
    super.initState();
    _generateReport();
  }

  Future<void> _generateReport() async {
    setState(() => _isLoading = true);

    final db = DatabaseService();
    final allAccounts = (await db.getPlanComptable()).map((m) => CompteComptable.fromMap(m)).toList();
    final allEcritures = (await db.getEcritures(end: _endDate)).map((m) => EcritureComptable.fromMap(m)).toList();

    final Map<String, double> balances = {};
    for (var acc in allAccounts) {
      balances[acc.code] = 0.0;
    }

    for (var ecriture in allEcritures) {
      balances.update(ecriture.accountCode, (value) => value + ecriture.debit - ecriture.credit, ifAbsent: () => ecriture.debit - ecriture.credit);
    }

    final List<BilanEntry> actifEntries = [];
    final List<BilanEntry> passifEntries = [];

    for (var account in allAccounts) {
      final balance = balances[account.code] ?? 0.0;
      if (balance == 0) continue;

      final entry = BilanEntry(account: account, balance: balance);

      // Classification based on SYSCOHADA classes (simplified)
      if (account.code.startsWith('2') || account.code.startsWith('3') || (account.code.startsWith('4') && balance > 0) || (account.code.startsWith('5') && balance > 0)) {
        actifEntries.add(entry);
      } else if (account.code.startsWith('1') || account.code.startsWith('4') || (account.code.startsWith('5') && balance < 0)) {
        // For passif, balances are typically credits (negative in our calculation), so we invert them for display
        entry.balance = -entry.balance;
        passifEntries.add(entry);
      }
    }

    setState(() {
      _actif = actifEntries..sort((a,b) => a.account.code.compareTo(b.account.code));
      _passif = passifEntries..sort((a,b) => a.account.code.compareTo(b.account.code));
      _totalActif = _actif.fold(0, (sum, item) => sum + item.balance);
      _totalPassif = _passif.fold(0, (sum, item) => sum + item.balance);
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
              : _buildBilanView(),
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
              Expanded(
                child: Row(
                  children: [
                    Text('Bilan à la date du '),
                    TextButton(child: Text(_dateFormat.format(_endDate)), onPressed: _pickDate),
                    const SizedBox(width: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.search),
                      label: const Text('Générer'),
                      onPressed: _generateReport,
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 36, color: Colors.white24),
              const SizedBox(width: 12),
              Row(
                children: [
                  Tooltip(
                    message: 'Exporter en CSV',
                    child: TextButton.icon(
                      onPressed: () async {
                        final sb = StringBuffer();
                        sb.writeln('ACTIF');
                        for (final e in _actif) { sb.writeln('${e.account.code},${e.account.title},${_currencyFormat.format(e.balance)}'); }
                        sb.writeln('Total Actif,${_currencyFormat.format(_totalActif)}');
                        sb.writeln();
                        sb.writeln('PASSIF');
                        for (final e in _passif) { sb.writeln('${e.account.code},${e.account.title},${_currencyFormat.format(e.balance)}'); }
                        sb.writeln('Total Passif,${_currencyFormat.format(_totalPassif)}');
                        final path = await FilePicker.platform.saveFile(dialogTitle: 'Exporter Bilan (CSV)', fileName: 'bilan.csv', type: FileType.custom, allowedExtensions: ['csv']);
                        if (path == null) return; await File(path).writeAsString(sb.toString());
                      },
                      icon: const Icon(Icons.insert_drive_file, size: 18),
                      label: const Text('CSV'),
                      style: _exportBtnStyle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'Exporter en Excel',
                    child: TextButton.icon(
                      onPressed: () async {
                        final ex = excel_lib.Excel.createExcel();
                        final s1 = ex['Actif'];
                        s1.appendRow([excel_lib.TextCellValue('Code'), excel_lib.TextCellValue('Intitulé'), excel_lib.TextCellValue('Montant')]);
                        for (final e in _actif) { s1.appendRow([excel_lib.TextCellValue(e.account.code), excel_lib.TextCellValue(e.account.title), excel_lib.TextCellValue(_currencyFormat.format(e.balance))]); }
                        s1.appendRow([excel_lib.TextCellValue('Total Actif'), excel_lib.TextCellValue(''), excel_lib.TextCellValue(_currencyFormat.format(_totalActif))]);
                        final s2 = ex['Passif'];
                        s2.appendRow([excel_lib.TextCellValue('Code'), excel_lib.TextCellValue('Intitulé'), excel_lib.TextCellValue('Montant')]);
                        for (final e in _passif) { s2.appendRow([excel_lib.TextCellValue(e.account.code), excel_lib.TextCellValue(e.account.title), excel_lib.TextCellValue(_currencyFormat.format(e.balance))]); }
                        s2.appendRow([excel_lib.TextCellValue('Total Passif'), excel_lib.TextCellValue(''), excel_lib.TextCellValue(_currencyFormat.format(_totalPassif))]);
                        final bytes = ex.encode(); if (bytes == null) return;
                        final path = await FilePicker.platform.saveFile(dialogTitle: 'Exporter Bilan (Excel)', fileName: 'bilan.xlsx', type: FileType.custom, allowedExtensions: ['xlsx']);
                        if (path == null) return; await File(path).writeAsBytes(Uint8List.fromList(bytes));
                      },
                      icon: const Icon(Icons.table_chart, size: 18),
                      label: const Text('Excel'),
                      style: _exportBtnStyle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(message: 'Exporter en PDF', child: TextButton.icon(onPressed: _exportPdf, icon: const Icon(Icons.picture_as_pdf, size: 18), label: const Text('PDF'), style: _exportBtnStyle)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _endDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  Widget _buildBilanView() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildSide('ACTIF', _actif, _totalActif)),
        const VerticalDivider(width: 2, color: Colors.grey),
        Expanded(child: _buildSide('PASSIF', _passif, _totalPassif)),
      ],
    );
  }

  Widget _buildSide(String title, List<BilanEntry> entries, double total) {
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
                trailing: Text(_currencyFormat.format(entry.balance)),
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

  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    final fontData = await rootBundle.load("assets/fonts/Nunito-Regular.ttf");
    final boldFontData = await rootBundle.load("assets/fonts/Nunito-Bold.ttf");
    final font = pw.Font.ttf(fontData);
    final bold = pw.Font.ttf(boldFontData);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Center(
              child: pw.Text(
                'Bilan Comptable',
                style: pw.TextStyle(font: bold, fontSize: 24),
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text(
                'Au ${_dateFormat.format(_endDate)}',
                style: pw.TextStyle(font: font, fontSize: 12),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('ACTIF', style: pw.TextStyle(font: bold, fontSize: 18)),
                      pw.Divider(),
                      ..._actif.map((entry) => pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('${entry.account.code} - ${entry.account.title}', style: pw.TextStyle(font: font, fontSize: 10)),
                          pw.Text(_currencyFormat.format(entry.balance), style: pw.TextStyle(font: font, fontSize: 10)),
                        ],
                      )),
                      pw.Divider(),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Total ACTIF', style: pw.TextStyle(font: bold, fontSize: 12)),
                          pw.Text(_currencyFormat.format(_totalActif), style: pw.TextStyle(font: bold, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('PASSIF', style: pw.TextStyle(font: bold, fontSize: 18)),
                      pw.Divider(),
                      ..._passif.map((entry) => pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('${entry.account.code} - ${entry.account.title}', style: pw.TextStyle(font: font, fontSize: 10)),
                          pw.Text(_currencyFormat.format(entry.balance), style: pw.TextStyle(font: font, fontSize: 10)),
                        ],
                      )),
                      pw.Divider(),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Total PASSIF', style: pw.TextStyle(font: bold, fontSize: 12)),
                          pw.Text(_currencyFormat.format(_totalPassif), style: pw.TextStyle(font: bold, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'bilan_comptable_${_dateFormat.format(_endDate)}.pdf');
  }
}
