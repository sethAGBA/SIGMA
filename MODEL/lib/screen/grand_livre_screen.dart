import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/compte_comptable.dart';
import '../../models/ecriture_comptable.dart';
import '../../services/database_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/services.dart';

class GrandLivreScreen extends StatefulWidget {
  const GrandLivreScreen({Key? key}) : super(key: key);

  @override
  _GrandLivreScreenState createState() => _GrandLivreScreenState();
}

class _GrandLivreScreenState extends State<GrandLivreScreen> {
  DateTime _startDate = DateTime(DateTime.now().year, 1, 1);
  DateTime _endDate = DateTime.now();
  final _dateFormat = DateFormat('dd/MM/yyyy');
  
  Map<String, List<EcritureComptable>> _ledgerData = {};
  List<CompteComptable> _accounts = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final accounts = await DatabaseService().getPlanComptable();
    setState(() {
      _accounts = accounts.map((map) => CompteComptable.fromMap(map)).toList();
    });
    _generateReport();
  }

  Future<void> _generateReport() async {
    setState(() {
      _isLoading = true;
      _ledgerData = {};
    });

    final ecritures = await DatabaseService().getEcritures(start: _startDate, end: _endDate);
    
    final Map<String, List<EcritureComptable>> groupedData = {};
    for (final ecriture in ecritures) {
      final model = EcritureComptable.fromMap(ecriture);
      if (groupedData.containsKey(model.accountCode)) {
        groupedData[model.accountCode]!.add(model);
      } else {
        groupedData[model.accountCode] = [model];
      }
    }

    // Sort entries by date within each account
    groupedData.forEach((key, value) {
      value.sort((a, b) => a.date.compareTo(b.date));
    });

    setState(() {
      _ledgerData = groupedData;
      _isLoading = false;
    });
  }

  CompteComptable? _getAccountByCode(String code) {
    try {
      return _accounts.firstWhere((acc) => acc.code == code);
    } catch (e) {
      return null;
    }
  }

  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    final fontData = await rootBundle.load("assets/fonts/Nunito-Regular.ttf");
    final boldFontData = await rootBundle.load("assets/fonts/Nunito-Bold.ttf");
    final font = pw.Font.ttf(fontData);
    final bold = pw.Font.ttf(boldFontData);
    final currencyFormat = NumberFormat("#,##0.00", "fr_FR");

    final sortedKeys = _ledgerData.keys.toList()..sort();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Center(
              child: pw.Text(
                'Grand Livre',
                style: pw.TextStyle(font: bold, fontSize: 24),
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text(
                'Période du ${_dateFormat.format(_startDate)} au ${_dateFormat.format(_endDate)}',
                style: pw.TextStyle(font: font, fontSize: 12),
              ),
            ),
            pw.SizedBox(height: 20),
            ...sortedKeys.map((code) {
              final entries = _ledgerData[code]!;
              final account = _getAccountByCode(code);
              double totalDebit = entries.fold(0, (sum, e) => sum + e.debit);
              double totalCredit = entries.fold(0, (sum, e) => sum + e.credit);
              double solde = totalDebit - totalCredit;

              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '${account?.code ?? code} - ${account?.title ?? 'Compte inconnu'}',
                    style: pw.TextStyle(font: bold, fontSize: 16),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Table.fromTextArray(
                    headers: ['Date', 'Libellé', 'Débit', 'Crédit'],
                    data: entries.map((e) => [
                      _dateFormat.format(e.date),
                      e.label,
                      e.debit > 0 ? currencyFormat.format(e.debit) : '',
                      e.credit > 0 ? currencyFormat.format(e.credit) : '',
                    ]).toList(),
                    border: pw.TableBorder.all(width: 0.5),
                    headerStyle: pw.TextStyle(font: bold, fontSize: 10),
                    cellStyle: pw.TextStyle(font: font, fontSize: 9),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(1.5),
                      1: const pw.FlexColumnWidth(3),
                      2: const pw.FlexColumnWidth(1.5),
                      3: const pw.FlexColumnWidth(1.5),
                    },
                  ),
                  pw.SizedBox(height: 5),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Text('Total Débit: ${currencyFormat.format(totalDebit)}', style: pw.TextStyle(font: bold, fontSize: 10)),
                      pw.SizedBox(width: 10),
                      pw.Text('Total Crédit: ${currencyFormat.format(totalCredit)}', style: pw.TextStyle(font: bold, fontSize: 10)),
                      pw.SizedBox(width: 10),
                      pw.Text('Solde: ${currencyFormat.format(solde)}', style: pw.TextStyle(font: bold, fontSize: 10, color: solde >= 0 ? PdfColors.green : PdfColors.red)),
                    ],
                  ),
                  pw.SizedBox(height: 20),
                ],
              );
            }).toList(),
          ];
        },
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'grand_livre_${_dateFormat.format(_startDate)}-${_dateFormat.format(_endDate)}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildLedger(),
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
              Row(
                children: [
                  Text('Période du '),
                  TextButton(
                    child: Text(_dateFormat.format(_startDate)),
                    onPressed: () async {
                      final picked = await showDatePicker(context: context, initialDate: _startDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                      if (picked != null && picked != _startDate) {
                        setState(() {
                          _startDate = picked;
                        });
                      }
                    },
                  ),
                  Text(' au '),
                  TextButton(
                    child: Text(_dateFormat.format(_endDate)),
                    onPressed: () async {
                      final picked = await showDatePicker(context: context, initialDate: _endDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                      if (picked != null && picked != _endDate) {
                        setState(() {
                          _endDate = picked;
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.search),
                    label: const Text('Générer'),
                    onPressed: _generateReport,
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                onPressed: _exportPdf,
                tooltip: 'Exporter en PDF',
              ),
              Row(children: [
                Tooltip(
                  message: 'Exporter en CSV',
                  child: TextButton.icon(
                    onPressed: () async {
                      final sb = StringBuffer();
                      sb.writeln('Compte,Intitulé,Date,Libellé,Débit,Crédit');
                      final cf = NumberFormat('#,##0.00','fr_FR');
                      final keys = _ledgerData.keys.toList()..sort();
                      for (final code in keys) {
                        final acc = _getAccountByCode(code);
                        for (final e in _ledgerData[code]!) {
                          sb.writeln('$code,${acc?.title ?? ''},${_dateFormat.format(e.date)},${e.label},${e.debit>0?cf.format(e.debit):''},${e.credit>0?cf.format(e.credit):''}');
                        }
                      }
                      final path = await FilePicker.platform.saveFile(dialogTitle: 'Exporter Grand livre (CSV)', fileName: 'grand_livre.csv', type: FileType.custom, allowedExtensions: ['csv']);
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
                      s.appendRow([excel_lib.TextCellValue('Compte'), excel_lib.TextCellValue('Intitulé'), excel_lib.TextCellValue('Date'), excel_lib.TextCellValue('Libellé'), excel_lib.TextCellValue('Débit'), excel_lib.TextCellValue('Crédit')]);
                      final cf = NumberFormat('#,##0.00','fr_FR');
                      final keys = _ledgerData.keys.toList()..sort();
                      for (final code in keys) {
                        final acc = _getAccountByCode(code);
                        for (final e in _ledgerData[code]!) {
                          s.appendRow([excel_lib.TextCellValue(code), excel_lib.TextCellValue(acc?.title ?? ''), excel_lib.TextCellValue(_dateFormat.format(e.date)), excel_lib.TextCellValue(e.label), excel_lib.TextCellValue(e.debit>0?cf.format(e.debit):''), excel_lib.TextCellValue(e.credit>0?cf.format(e.credit):'')]);
                        }
                      }
                      final bytes = ex.encode(); if (bytes == null) return;
                      final path = await FilePicker.platform.saveFile(dialogTitle: 'Exporter Grand livre (Excel)', fileName: 'grand_livre.xlsx', type: FileType.custom, allowedExtensions: ['xlsx']);
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
                    onPressed: _exportPdf,
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

  Widget _buildLedger() {
    if (_ledgerData.isEmpty) {
      return const Center(child: Text('Aucune donnée pour la période sélectionnée.'));
    }
    
    final accountCodes = _ledgerData.keys.toList()..sort();

    return ListView.builder(
      itemCount: accountCodes.length,
      itemBuilder: (context, index) {
        final code = accountCodes[index];
        final entries = _ledgerData[code]!;
        final account = _getAccountByCode(code);
        
        double totalDebit = entries.fold(0, (sum, e) => sum + e.debit);
        double totalCredit = entries.fold(0, (sum, e) => sum + e.credit);
        double solde = totalDebit - totalCredit;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF0F172A),
          child: ExpansionTile(
            title: Text('${account?.code ?? code} - ${account?.title ?? 'Compte inconnu'}', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Mouvements: ${entries.length} | Solde: ${solde.toStringAsFixed(2)}', style: TextStyle(color: solde >= 0 ? Colors.greenAccent : Colors.redAccent)),
            children: [
              DataTable(
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Libellé')),
                  DataColumn(label: Text('Débit')),
                  DataColumn(label: Text('Crédit')),
                ],
                rows: entries.map((e) => DataRow(
                  cells: [
                    DataCell(Text(_dateFormat.format(e.date))),
                    DataCell(Text(e.label)),
                    DataCell(Text(e.debit > 0 ? e.debit.toStringAsFixed(2) : '')),
                    DataCell(Text(e.credit > 0 ? e.credit.toStringAsFixed(2) : '')),
                  ]
                )).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}
