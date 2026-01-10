import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/compte_comptable.dart';
import '../../models/ecriture_comptable.dart';
import '../../services/database_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'dart:typed_data';
import 'dart:io';

class TresorerieEntry {
  final EcritureComptable ecriture;
  double runningBalance;

  TresorerieEntry({required this.ecriture, required this.runningBalance});
}

class TresorerieScreen extends StatefulWidget {
  const TresorerieScreen({Key? key}) : super(key: key);

  @override
  _TresorerieScreenState createState() => _TresorerieScreenState();
}

class _TresorerieScreenState extends State<TresorerieScreen> {
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();
  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _currencyFormat = NumberFormat("#,##0.00", "fr_FR");

  List<TresorerieEntry> _entries = [];
  double _startBalance = 0.0;
  double _endBalance = 0.0;
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
    final tresorerieAccountCodes = allAccounts.where((acc) => acc.code.startsWith('5')).map((acc) => acc.code).toList();

    if (tresorerieAccountCodes.isEmpty) {
        setState(() {
            _isLoading = false;
            _startBalance = 0;
            _entries = [];
            _endBalance = 0;
        });
        return;
    }

    final allEcritures = (await db.getEcritures(end: _endDate)).map((m) => EcritureComptable.fromMap(m)).toList();

    final tresorerieEcritures = allEcritures.where((e) => tresorerieAccountCodes.contains(e.accountCode)).toList();

    double currentBalance = 0;
    for (final ecriture in tresorerieEcritures) {
      if (ecriture.date.isBefore(_startDate)) {
        currentBalance += ecriture.debit - ecriture.credit;
      }
    }
    final startBalance = currentBalance;

    final periodEcritures = tresorerieEcritures.where((e) => !e.date.isBefore(_startDate)).toList()..sort((a,b) => a.date.compareTo(b.date));

    final List<TresorerieEntry> entries = [];
    for (final ecriture in periodEcritures) {
      currentBalance += ecriture.debit - ecriture.credit;
      entries.add(TresorerieEntry(ecriture: ecriture, runningBalance: currentBalance));
    }

    setState(() {
      _isLoading = false;
      _startBalance = startBalance;
      _entries = entries;
      _endBalance = currentBalance;
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
              : _buildJournal(),
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
                ElevatedButton.icon(icon: const Icon(Icons.search), label: const Text('Générer'), onPressed: _generateReport),
              ]),
              Row(children: [
                Tooltip(
                  message: 'Exporter en CSV',
                  child: TextButton.icon(
                    onPressed: () async {
                      final sb = StringBuffer();
                      final cf = NumberFormat('#,##0.00','fr_FR');
                      sb.writeln('Date,Libellé,Encaissement,Décaissement,Solde');
                      sb.writeln(',Solde initial au ${_dateFormat.format(_startDate)},,,${cf.format(_startBalance)}');
                      for (final e in _entries) {
                        sb.writeln('${_dateFormat.format(e.ecriture.date)},${e.ecriture.label},${e.ecriture.debit>0?cf.format(e.ecriture.debit):''},${e.ecriture.credit>0?cf.format(e.ecriture.credit):''},${cf.format(e.runningBalance)}');
                      }
                      sb.writeln(',Solde final au ${_dateFormat.format(_endDate)},,,${cf.format(_endBalance)}');
                      final path = await FilePicker.platform.saveFile(dialogTitle: 'Exporter Trésorerie (CSV)', fileName: 'tresorerie.csv', type: FileType.custom, allowedExtensions: ['csv']);
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
                      final cf = NumberFormat('#,##0.00','fr_FR');
                      s.appendRow([excel_lib.TextCellValue('Date'), excel_lib.TextCellValue('Libellé'), excel_lib.TextCellValue('Encaissement'), excel_lib.TextCellValue('Décaissement'), excel_lib.TextCellValue('Solde')]);
                      s.appendRow([excel_lib.TextCellValue(''), excel_lib.TextCellValue('Solde initial au ${_dateFormat.format(_startDate)}'), excel_lib.TextCellValue(''), excel_lib.TextCellValue(''), excel_lib.TextCellValue(cf.format(_startBalance))]);
                      for (final e in _entries) {
                        s.appendRow([excel_lib.TextCellValue(_dateFormat.format(e.ecriture.date)), excel_lib.TextCellValue(e.ecriture.label), excel_lib.TextCellValue(e.ecriture.debit>0?cf.format(e.ecriture.debit):''), excel_lib.TextCellValue(e.ecriture.credit>0?cf.format(e.ecriture.credit):''), excel_lib.TextCellValue(cf.format(e.runningBalance))]);
                      }
                      s.appendRow([excel_lib.TextCellValue(''), excel_lib.TextCellValue('Solde final au ${_dateFormat.format(_endDate)}'), excel_lib.TextCellValue(''), excel_lib.TextCellValue(''), excel_lib.TextCellValue(cf.format(_endBalance))]);
                      final bytes = ex.encode(); if (bytes == null) return;
                      final path = await FilePicker.platform.saveFile(dialogTitle: 'Exporter Trésorerie (Excel)', fileName: 'tresorerie.xlsx', type: FileType.custom, allowedExtensions: ['xlsx']);
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
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Exporter en PDF',
                  child: TextButton.icon(
                    onPressed: () async {
                      final pdf = pw.Document();
                      final cf = NumberFormat('#,##0.00','fr_FR');
                      pdf.addPage(pw.MultiPage(
                        pageFormat: PdfPageFormat.a4,
                        build: (ctx) => [
                          pw.Text('Journal de Trésorerie', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 10),
                          pw.Table.fromTextArray(
                            headers: ['Date','Libellé','Encaissement','Décaissement','Solde'],
                            data: [
                              ['', 'Solde initial au ${_dateFormat.format(_startDate)}', '', '', cf.format(_startBalance)],
                              ..._entries.map((e) => [_dateFormat.format(e.ecriture.date), e.ecriture.label, e.ecriture.debit>0?cf.format(e.ecriture.debit):'', e.ecriture.credit>0?cf.format(e.ecriture.credit):'', cf.format(e.runningBalance)]),
                              ['', 'Solde final au ${_dateFormat.format(_endDate)}', '', '', cf.format(_endBalance)],
                            ],
                            border: pw.TableBorder.all(color: PdfColors.grey),
                            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            cellAlignment: pw.Alignment.centerLeft,
                          ),
                        ],
                      ));
                      final bytes = await pdf.save();
                      final path = await FilePicker.platform.saveFile(dialogTitle: 'Exporter Trésorerie (PDF)', fileName: 'tresorerie.pdf', type: FileType.custom, allowedExtensions: ['pdf']);
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

  Widget _buildJournal() {
    return SingleChildScrollView(
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Libellé')),
          DataColumn(label: Text('Encaissement')),
          DataColumn(label: Text('Décaissement')),
          DataColumn(label: Text('Solde')),
        ],
        rows: [
          DataRow(cells: [
            DataCell(Text('', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text('Solde initial au ${_dateFormat.format(_startDate)}', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text('')),
            DataCell(Text('')),
            DataCell(Text(_currencyFormat.format(_startBalance), style: const TextStyle(fontWeight: FontWeight.bold))),
          ]),
          ..._entries.map((entry) {
            return DataRow(cells: [
              DataCell(Text(_dateFormat.format(entry.ecriture.date))),
              DataCell(Text(entry.ecriture.label)),
              DataCell(Text(entry.ecriture.debit > 0 ? _currencyFormat.format(entry.ecriture.debit) : '')),
              DataCell(Text(entry.ecriture.credit > 0 ? _currencyFormat.format(entry.ecriture.credit) : '')),
              DataCell(Text(_currencyFormat.format(entry.runningBalance))),
            ]);
          }).toList(),
          DataRow(cells: [
            DataCell(Text('', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text('Solde final au ${_dateFormat.format(_endDate)}', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text('')),
            DataCell(Text('')),
            DataCell(Text(_currencyFormat.format(_endBalance), style: const TextStyle(fontWeight: FontWeight.bold))),
          ]),
        ],
      ),
    );
  }
}
