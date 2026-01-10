import 'dart:io';

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

class BalanceData {
  final CompteComptable account;
  double startDebit = 0.0;
  double startCredit = 0.0;
  double moveDebit = 0.0;
  double moveCredit = 0.0;

  double get startBalance => startDebit - startCredit;
  double get endDebit => startDebit + moveDebit;
  double get endCredit => startCredit + moveCredit;
  double get endBalance => endDebit - endCredit;

  BalanceData({required this.account});
}

class BalanceGeneraleScreen extends StatefulWidget {
  const BalanceGeneraleScreen({Key? key}) : super(key: key);

  @override
  _BalanceGeneraleScreenState createState() => _BalanceGeneraleScreenState();
}

class _BalanceGeneraleScreenState extends State<BalanceGeneraleScreen> {
  DateTime _startDate = DateTime(DateTime.now().year, 1, 1);
  DateTime _endDate = DateTime.now();
  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _currencyFormat = NumberFormat("#,##0.00", "fr_FR");

  List<BalanceData> _balanceData = [];
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
    final accounts = (await db.getPlanComptable()).map((m) => CompteComptable.fromMap(m)).toList();
    final ecritures = (await db.getEcritures(end: _endDate)).map((m) => EcritureComptable.fromMap(m)).toList();

    final Map<String, BalanceData> dataMap = {
      for (var acc in accounts) acc.code: BalanceData(account: acc)
    };

    for (final ecriture in ecritures) {
      final data = dataMap[ecriture.accountCode];
      if (data == null) continue;

      if (ecriture.date.isBefore(_startDate)) {
        data.startDebit += ecriture.debit;
        data.startCredit += ecriture.credit;
      } else {
        data.moveDebit += ecriture.debit;
        data.moveCredit += ecriture.credit;
      }
    }

    setState(() {
      _balanceData = dataMap.values.toList()..sort((a, b) => a.account.code.compareTo(b.account.code));
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
              : _buildBalanceTable(),
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
                        // Générer CSV à partir du tableau affiché
                        final sb = StringBuffer();
                        sb.writeln('Compte,Intitulé,Débit Initial,Crédit Initial,Mouv. Débit,Mouv. Crédit,Débit Final,Crédit Final');
                        for (final data in _balanceData) {
                          sb.writeln('${data.account.code},${data.account.title},${_currencyFormat.format(data.startBalance > 0 ? data.startBalance : 0)},${_currencyFormat.format(data.startBalance < 0 ? -data.startBalance : 0)},${_currencyFormat.format(data.moveDebit)},${_currencyFormat.format(data.moveCredit)},${_currencyFormat.format(data.endBalance > 0 ? data.endBalance : 0)},${_currencyFormat.format(data.endBalance < 0 ? -data.endBalance : 0)}');
                        }
                        final path = await FilePicker.platform.saveFile(dialogTitle: 'Exporter Balance (CSV)', fileName: 'balance_generale.csv', type: FileType.custom, allowedExtensions: ['csv']);
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
                        final sheet = ex[ex.getDefaultSheet()!];
                        sheet.appendRow([excel_lib.TextCellValue('Compte'), excel_lib.TextCellValue('Intitulé'), excel_lib.TextCellValue('Débit Initial'), excel_lib.TextCellValue('Crédit Initial'), excel_lib.TextCellValue('Mouv. Débit'), excel_lib.TextCellValue('Mouv. Crédit'), excel_lib.TextCellValue('Débit Final'), excel_lib.TextCellValue('Crédit Final')]);
                        for (final data in _balanceData) {
                          sheet.appendRow([
                            excel_lib.TextCellValue(data.account.code),
                            excel_lib.TextCellValue(data.account.title),
                            excel_lib.TextCellValue(_currencyFormat.format(data.startBalance > 0 ? data.startBalance : 0)),
                            excel_lib.TextCellValue(_currencyFormat.format(data.startBalance < 0 ? -data.startBalance : 0)),
                            excel_lib.TextCellValue(_currencyFormat.format(data.moveDebit)),
                            excel_lib.TextCellValue(_currencyFormat.format(data.moveCredit)),
                            excel_lib.TextCellValue(_currencyFormat.format(data.endBalance > 0 ? data.endBalance : 0)),
                            excel_lib.TextCellValue(_currencyFormat.format(data.endBalance < 0 ? -data.endBalance : 0)),
                          ]);
                        }
                        final bytes = ex.encode(); if (bytes == null) return;
                        final path = await FilePicker.platform.saveFile(dialogTitle: 'Exporter Balance (Excel)', fileName: 'balance_generale.xlsx', type: FileType.custom, allowedExtensions: ['xlsx']);
                        if (path == null) return; await File(path).writeAsBytes(Uint8List.fromList(bytes));
                      },
                      icon: const Icon(Icons.table_chart, size: 18),
                      label: const Text('Excel'),
                      style: _exportBtnStyle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'Exporter en PDF',
                    child: TextButton.icon(onPressed: _exportPdf, icon: const Icon(Icons.picture_as_pdf, size: 18), label: const Text('PDF'), style: _exportBtnStyle),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
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

  Widget _buildBalanceTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Compte')),
            DataColumn(label: Text('Intitulé')),
            DataColumn(label: Text('Débit Initial')),
            DataColumn(label: Text('Crédit Initial')),
            DataColumn(label: Text('Mouv. Débit')),
            DataColumn(label: Text('Mouv. Crédit')),
            DataColumn(label: Text('Débit Final')),
            DataColumn(label: Text('Crédit Final')),
          ],
          rows: _balanceData.map((data) {
            return DataRow(cells: [
              DataCell(Text(data.account.code)),
              DataCell(Text(data.account.title)),
              DataCell(Text(_currencyFormat.format(data.startBalance > 0 ? data.startBalance : 0))),
              DataCell(Text(_currencyFormat.format(data.startBalance < 0 ? -data.startBalance : 0))),
              DataCell(Text(_currencyFormat.format(data.moveDebit))),
              DataCell(Text(_currencyFormat.format(data.moveCredit))),
              DataCell(Text(_currencyFormat.format(data.endBalance > 0 ? data.endBalance : 0))),
              DataCell(Text(_currencyFormat.format(data.endBalance < 0 ? -data.endBalance : 0))),
            ]);
          }).toList(),
        ),
      ),
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
        pageFormat: PdfPageFormat.a4.landscape,
        maxPages: 100, // Augmenter la limite de pages
        build: (pw.Context context) {
          return [
            pw.Center(
              child: pw.Text(
                'Balance Générale',
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
            pw.Table.fromTextArray(
              headers: [
                'Compte', 'Intitulé',
                'Débit Initial', 'Crédit Initial',
                'Mouv. Débit', 'Mouv. Crédit',
                'Débit Final', 'Crédit Final',
              ],
              data: _balanceData.map((data) => [
                data.account.code,
                data.account.title,
                _currencyFormat.format(data.startBalance > 0 ? data.startBalance : 0),
                _currencyFormat.format(data.startBalance < 0 ? -data.startBalance : 0),
                _currencyFormat.format(data.moveDebit),
                _currencyFormat.format(data.moveCredit),
                _currencyFormat.format(data.endBalance > 0 ? data.endBalance : 0),
                _currencyFormat.format(data.endBalance < 0 ? -data.endBalance : 0),
              ]).toList(),
              border: pw.TableBorder.all(width: 0.5),
              headerStyle: pw.TextStyle(font: bold, fontSize: 9),
              cellStyle: pw.TextStyle(font: font, fontSize: 8),
              columnWidths: {
                0: const pw.FlexColumnWidth(1),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1.2),
                3: const pw.FlexColumnWidth(1.2),
                4: const pw.FlexColumnWidth(1.2),
                5: const pw.FlexColumnWidth(1.2),
                6: const pw.FlexColumnWidth(1.2),
                7: const pw.FlexColumnWidth(1.2),
              },
            ),
          ];
        },
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'balance_generale_${_dateFormat.format(_startDate)}-${_dateFormat.format(_endDate)}.pdf');
  }
}
