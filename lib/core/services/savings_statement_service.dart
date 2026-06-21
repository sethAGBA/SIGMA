// lib/core/services/savings_statement_service.dart
//
// Génère les relevés mensuels d'épargne en PDF.
// Utilise InstitutionPdfBranding pour l'en-tête institution.
//
// Exigences : 6.1, 6.2

import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/configuration_model.dart';
import 'database_service.dart';
import 'institution_pdf_branding.dart';

class SavingsStatementService {
  final _currFmt = NumberFormat('#,##0', 'fr_FR');
  final _dateFmt = DateFormat('dd/MM/yyyy');
  final _monthFmt = DateFormat('MMMM yyyy', 'fr_FR');

  // ── API publique ──────────────────────────────────────────────────────────

  /// Génère le PDF du relevé mensuel et retourne les bytes.
  /// [accountId] — ID du compte épargne
  /// [month] — mois (1–12)
  /// [year] — année (ex: 2025)
  Future<Uint8List> generateMonthlyStatement(
    int accountId,
    int month,
    int year,
  ) async {
    final db = DatabaseService();

    // Compte + client
    final account = await db.getSavingsAccountById(accountId);
    if (account == null) throw 'Compte introuvable : $accountId';

    // Branding institution
    LegalInformation legal;
    try {
      legal = await db.getLegalInformation();
    } catch (_) {
      legal = LegalInformation(
        raisonSociale: 'SIGMA Micro-Finance',
        numeroAgrement: '',
        numeroFiscal: '',
        adresseSiege: '',
        contactsOfficiels: '',
      );
    }

    // Transactions du mois
    final transactions = await db.getSavingsTransactions(accountId);
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0, 23, 59, 59);
    final monthly = transactions
        .where((t) =>
            !t.dateOperation.isBefore(start) &&
            !t.dateOperation.isAfter(end))
        .toList()
      ..sort((a, b) => a.dateOperation.compareTo(b.dateOperation));

    // Solde initial = solde avant le 1er du mois
    final before = transactions
        .where((t) => t.dateOperation.isBefore(start))
        .toList()
      ..sort((a, b) => a.dateOperation.compareTo(b.dateOperation));

    final soldeInitial = before.isNotEmpty ? before.last.soldeApres : 0.0;
    final soldeFinal = monthly.isNotEmpty
        ? monthly.last.soldeApres
        : soldeInitial;
    final totalDebits = monthly
        .where((t) => ['retrait', 'frais'].contains(t.type.name))
        .fold(0.0, (s, t) => s + t.montant);
    final totalCredits = monthly
        .where((t) => ['depot', 'interet'].contains(t.type.name))
        .fold(0.0, (s, t) => s + t.montant);

    // Construction PDF
    final branding = InstitutionPdfBranding(
      legal: legal,
      documentTitle: 'Relevé de Compte Épargne',
      subtitle:
          '${_monthFmt.format(start)} — Compte ${account.numeroCompte}',
    );

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            ...branding.buildHeader(),
            pw.Divider(color: PdfColors.blueGrey200),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (ctx) => pw.Column(
          children: [
            pw.Divider(color: PdfColors.blueGrey200),
            branding.buildFooter(
              generatedAt: _dateFmt.format(DateTime.now()),
            ),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Page ${ctx.pageNumber}/${ctx.pagesCount}',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
            ),
          ],
        ),
        build: (ctx) => [
          // ── Infos client/compte ──
          _buildClientInfoSection(account),
          pw.SizedBox(height: 20),

          // ── Récapitulatif soldes ──
          _buildSummarySection(
            soldeInitial,
            soldeFinal,
            totalCredits,
            totalDebits,
          ),
          pw.SizedBox(height: 20),

          // ── Tableau des mouvements ──
          pw.Text(
            'Mouvements du mois de ${_monthFmt.format(start)}',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey800,
            ),
          ),
          pw.SizedBox(height: 8),
          monthly.isEmpty
              ? pw.Text(
                  'Aucun mouvement enregistré pour ce mois.',
                  style: const pw.TextStyle(color: PdfColors.grey600),
                )
              : _buildTransactionsTable(monthly),
        ],
      ),
    );

    return pdf.save();
  }

  /// Sauvegarde le relevé dans {appDocDir}/exports/releves/ et retourne le chemin.
  Future<String> saveMonthlyStatement(
    int accountId,
    int month,
    int year,
  ) async {
    final bytes = await generateMonthlyStatement(accountId, month, year);

    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/exports/releves');
    if (!await dir.exists()) await dir.create(recursive: true);

    final fileName =
        'releve_${accountId}_${year}_${month.toString().padLeft(2, '0')}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  /// Ouvre la visionneuse d'impression système pour le relevé.
  Future<void> printStatement(
    int accountId,
    int month,
    int year,
  ) async {
    final bytes = await generateMonthlyStatement(accountId, month, year);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  // ── Widgets PDF internes ──────────────────────────────────────────────────

  pw.Widget _buildClientInfoSection(dynamic account) {
    final clientName =
        '${account.client?.nom ?? ''} ${account.client?.prenoms ?? ''}'.trim();
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey50,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _pdfLabel('TITULAIRE DU COMPTE'),
              pw.Text(
                clientName.isEmpty ? '—' : clientName,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              _pdfLabel('NUMÉRO DE COMPTE'),
              pw.Text(
                account.numeroCompte ?? '—',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              _pdfLabel('PRODUIT'),
              pw.Text(
                account.produit?.nom ?? 'N/A',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 4),
              _pdfLabel('TAUX ANNUEL'),
              pw.Text(
                '${account.tauxInteretApplique ?? 0} %',
                style: const pw.TextStyle(fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSummarySection(
    double soldeInitial,
    double soldeFinal,
    double totalCredits,
    double totalDebits,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blueGrey200),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _summaryItem('Solde initial', soldeInitial, PdfColors.blueGrey700),
          _summaryItem('Total crédits', totalCredits, PdfColors.green700),
          _summaryItem('Total débits', totalDebits, PdfColors.orange700),
          _summaryItem('Solde final', soldeFinal, PdfColors.blue900),
        ],
      ),
    );
  }

  pw.Widget _summaryItem(String label, double value, PdfColor color) {
    return pw.Column(
      children: [
        _pdfLabel(label),
        pw.Text(
          '${_currFmt.format(value)} FCFA',
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildTransactionsTable(List<dynamic> transactions) {
    const headerStyle = pw.TextStyle(
      fontSize: 9,
      color: PdfColors.white,
    );
    const cellStyle = pw.TextStyle(fontSize: 9);

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.blueGrey100),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(2),
        4: const pw.FlexColumnWidth(2),
      },
      children: [
        // En-tête
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
          children: [
            _tableCell('DATE', headerStyle),
            _tableCell('LIBELLÉ', headerStyle),
            _tableCell('DÉBIT', headerStyle, align: pw.TextAlign.right),
            _tableCell('CRÉDIT', headerStyle, align: pw.TextAlign.right),
            _tableCell('SOLDE', headerStyle, align: pw.TextAlign.right),
          ],
        ),
        // Lignes
        ...transactions.map((t) {
          final isCredit = ['depot', 'interet'].contains(t.type.name);
          return pw.TableRow(
            children: [
              _tableCell(_dateFmt.format(t.dateOperation), cellStyle),
              _tableCell(t.type.label, cellStyle),
              _tableCell(
                isCredit ? '' : '${_currFmt.format(t.montant)} FCFA',
                cellStyle.copyWith(color: PdfColors.orange700),
                align: pw.TextAlign.right,
              ),
              _tableCell(
                isCredit ? '${_currFmt.format(t.montant)} FCFA' : '',
                cellStyle.copyWith(color: PdfColors.green700),
                align: pw.TextAlign.right,
              ),
              _tableCell(
                '${_currFmt.format(t.soldeApres)} FCFA',
                cellStyle.copyWith(fontWeight: pw.FontWeight.bold),
                align: pw.TextAlign.right,
              ),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _tableCell(
    String text,
    pw.TextStyle style, {
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(text, style: style, textAlign: align),
    );
  }

  pw.Widget _pdfLabel(String text) {
    return pw.Text(
      text,
      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
    );
  }
}
