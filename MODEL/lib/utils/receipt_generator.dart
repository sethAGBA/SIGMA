// dart:typed_data not needed because Flutter's services and pdf packages provide Uint8List
import 'package:afroforma/models/formation.dart';
import 'package:afroforma/models/student.dart';
import 'package:afroforma/screen/parametres/models.dart'; // Import CompanyInfo
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'pdf_style.dart';
import 'template_canvas_pdf.dart';
import 'package:printing/printing.dart';

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/document.dart';
import '../services/database_service.dart'; // Import DatabaseService

/// Generate the PDF bytes for a receipt (does not save to disk).
Future<Uint8List> generateReceiptPdfBytes(
  Student student,
  Formation? formation,
  Map<String, dynamic> newPayment,
  List<Map<String, dynamic>> paymentHistory,
  double balance,
  CompanyInfo companyInfo, { // Add CompanyInfo parameter
  String? inscriptionId,
  bool useCanvasTemplate = false,
  String? templateId,
}) async {
  // If requested, try to render with a canvas template stored in DB.
  if (useCanvasTemplate) {
    try {
      final templates = await DatabaseService().getDocumentTemplates();
      // prefer explicit id, else try to find a canvas_receipt or similar
      DocumentTemplate? chosen;
      if (templateId != null && templateId.isNotEmpty) {
        chosen = templates.firstWhere((t) => t.id == templateId, orElse: () => DocumentTemplate.fromMap({
          'id': '', 'name': '', 'type': '', 'content': '[]', 'lastModified': DateTime.now().millisecondsSinceEpoch
        }));
        if (chosen.id == '') chosen = null;
      }
      if (chosen == null) {
        chosen = templates.firstWhere((t) => t.type == 'canvas' && (t.id.contains('receipt') || t.name.toLowerCase().contains('reçu') || t.name.toLowerCase().contains('receipt')), orElse: () => templates.firstWhere((t) => t.type == 'canvas', orElse: () => DocumentTemplate.fromMap({
          'id': '', 'name': '', 'type': '', 'content': '[]', 'lastModified': DateTime.now().millisecondsSinceEpoch
        })));
        if (chosen.id == '') chosen = null;
      }

      if (chosen != null) {
        // Build data map for template rendering
        final data = <String, dynamic>{
          'receipt_number': newPayment['id']?.toString() ?? '',
          'receipt_date': DateFormat.yMMMd('fr_FR').format(DateTime.now()),
          'payer_name': student.name,
          'student_id': student.id,
          'formation_name': formation?.title ?? '',
          'amount': newPayment['amount']?.toString() ?? '',
          'academic_year': companyInfo.academic_year,
          // include company fields for template convenience
          'company_name': companyInfo.name,
          'company_logo': companyInfo.logoPath,
          'company_address': companyInfo.address,
          'company_phone': companyInfo.phone,
          'company_email': companyInfo.email,
        };

        // also include a simple payments list if template needs iteration
        data['payments'] = paymentHistory.map((p) => {
          'date': DateFormat.yMMMd('fr_FR').format(DateTime.fromMillisecondsSinceEpoch((p['createdAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch)),
          'amount': _amountToString(p['amount']),
          'method': (p['method'] ?? '').toString(),
          'note': (p['note'] ?? '').toString(),
        }).toList();

        try {
          final bytes = await generatePdfFromCanvasTemplate(chosen, data);
          if (bytes.isNotEmpty) return bytes;
        } catch (_) {
          // fall through to standard generator
        }
      }
    } catch (_) {
      // ignore errors and fallback to standard generator
    }
  }
  final pdf = pw.Document();

  final regularFont = await rootBundle.load("assets/fonts/Nunito-Regular.ttf");
  final boldFontData = await rootBundle.load("assets/fonts/Nunito-Bold.ttf");
  final regularPwFont = pw.Font.ttf(regularFont);
  final boldFont = pw.Font.ttf(boldFontData);

  final pw.MemoryImage? companyLogo = await _loadCompanyLogo(companyInfo.logoPath);
  // Use centralized PdfStyle helpers
  // load common fonts from PdfStyle if needed elsewhere
  await PdfStyle.loadFonts();

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (pw.Context context) {
        // watermark (logo or company name) behind content
        final pw.Widget watermark = (companyLogo != null)
            ? pw.Positioned.fill(
                child: pw.Center(
                  child: pw.Opacity(
                    opacity: 0.06,
                    child: pw.Image(companyLogo, width: 400),
                  ),
                ),
              )
            : pw.Positioned.fill(
                child: pw.Center(
                  child: pw.Opacity(
                    opacity: 0.05,
                    child: pw.Transform.rotate(
                      angle: -0.4,
                      child: pw.Text(companyInfo.name, style: pw.TextStyle(font: boldFont, fontSize: 80, color: PdfColors.grey300)),
                    ),
                  ),
                ),
              );

        return pw.Stack(children: [
          if (companyLogo != null || (companyInfo.name.isNotEmpty)) watermark,
          pw.Positioned.fill(
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(8.0),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  PdfStyle.header(
                    logo: companyLogo,
                    name: companyInfo.name,
                    address: companyInfo.address,
                    contact: '${companyInfo.phone}  |  ${companyInfo.email}',
                    regular: regularPwFont,
                    bold: boldFont,
                  ),
                  pw.SizedBox(height: 6),
                  pw.Header(
                    level: 0,
                    child: pw.Text('Reçu de Paiement', style: pw.TextStyle(font: boldFont, fontSize: 24)),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Étudiant: ${student.name}', style: pw.TextStyle(font: boldFont)),
                          pw.Text('Formation: ${formation?.title ?? 'N/A'}', style: pw.TextStyle(font: regularPwFont)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Date: ${DateFormat.yMMMd('fr_FR').format(DateTime.now())}', style: pw.TextStyle(font: regularPwFont)),
                          pw.Text('Reçu #: ${newPayment['id'].toString().substring(0, 8)}', style: pw.TextStyle(font: regularPwFont)),
                        ],
                      ),
                    ],
                  ),
                  pw.Divider(height: 18),

                  // Paiement effectué (dernier paiement)
                  pw.Text('Paiement Effectué', style: pw.TextStyle(font: boldFont, fontSize: 18)),
                  pw.SizedBox(height: 10),
                  pw.TableHelper.fromTextArray(
                    data: [
                      ['Montant', 'Méthode', 'Note', 'Date', 'Type'],
                      [
                        '${_amountToString(newPayment['amount'])} XOF',
                        (newPayment['method'] ?? '').toString(),
                        (newPayment['note'] ?? '').toString(),
                        DateFormat.yMMMd('fr_FR').format(DateTime.fromMillisecondsSinceEpoch((newPayment['createdAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch)),
                        ((newPayment['isCredit'] as int?) == 1) ? 'Avance' : '',
                      ],
                    ],
                    headerStyle: pw.TextStyle(font: boldFont),
                    cellAlignment: pw.Alignment.centerLeft,
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  ),

                  pw.SizedBox(height: 12),

                  // Historique des paiements
                  pw.Divider(height: 18),
                  pw.Text('Historique des Paiements', style: pw.TextStyle(font: boldFont, fontSize: 18)),
                  pw.SizedBox(height: 8),
                  pw.TableHelper.fromTextArray(
                    data: [
                      ['Date', 'Montant', 'Méthode', 'Note', 'Type'],
                      ...paymentHistory.map((p) => [
                            DateFormat.yMMMd('fr_FR').format(DateTime.fromMillisecondsSinceEpoch((p['createdAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch)),
                            '${_amountToString(p['amount'])} XOF',
                            (p['method'] ?? '').toString(),
                            (p['note'] ?? '').toString(),
                            ((p['isCredit'] as int?) == 1) ? 'Avance' : '',
                          ])
                    ],
                    headerStyle: pw.TextStyle(font: boldFont),
                    cellAlignment: pw.Alignment.centerLeft,
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  ),

                  pw.SizedBox(height: 12),

                  // Résumé financier (solde) : placé après l'historique
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(6)),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Résumé Financier', style: pw.TextStyle(font: boldFont, fontSize: 12)),
                            pw.SizedBox(height: 6),
                            pw.Text('Total payé: ${paymentHistory.fold<double>(0, (prev, e) => prev + ((e['amount'] as num?)?.toDouble() ?? 0)).toStringAsFixed(2)} XOF', style: pw.TextStyle(font: regularPwFont)),
                            pw.SizedBox(height: 4),
                            if (balance <= 0)
                              pw.Text('Statut: PAYÉ', style: pw.TextStyle(font: boldFont, fontSize: 14, color: PdfColors.green700))
                            else
                              pw.Text('Solde restant: ${balance.toStringAsFixed(2)} XOF', style: pw.TextStyle(font: boldFont, fontSize: 14, color: PdfColors.red700)),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text('Session: ${companyInfo.academic_year}', style: pw.TextStyle(font: regularPwFont)),
                            pw.SizedBox(height: 4),
                            pw.Text('Année académique: ${companyInfo.academic_year}', style: pw.TextStyle(font: regularPwFont)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 18),
                  pw.Text('Signature et Cachet de l\'établissement', style: pw.TextStyle(font: regularPwFont), textAlign: pw.TextAlign.right),
                  pw.SizedBox(height: 40),

                  pw.Spacer(),
                  PdfStyle.footer(
                    rccm: companyInfo.rccm,
                    nif: companyInfo.nif,
                    website: companyInfo.website,
                    regular: regularPwFont,
                  ),
                ],
              ),
            ),
          ),
        ]);
      },
    ),
  );

  return pdf.save();
}

Future<void> generateAndPrintReceipt(
  Student student,
  Formation? formation,
  Map<String, dynamic> newPayment,
  List<Map<String, dynamic>> paymentHistory,
  double balance,
) async {
  final companyInfo = await DatabaseService().getCompanyInfo();
  final bytes = await generateReceiptPdfBytes(student, formation, newPayment, paymentHistory, balance, companyInfo!, inscriptionId: newPayment['inscriptionId']?.toString());
  await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => bytes);
}

/// Generate the receipt PDF and save it to disk, register as a Document in the database.
/// Returns the saved file path.
Future<String> generateAndSaveReceipt(
  Student student,
  Formation? formation,
  Map<String, dynamic> newPayment,
  List<Map<String, dynamic>> paymentHistory,
  double balance, {
  String? inscriptionId,
}) async {
  final companyInfo = await DatabaseService().getCompanyInfo();
  final bytes = await generateReceiptPdfBytes(student, formation, newPayment, paymentHistory, balance, companyInfo!, inscriptionId: inscriptionId);

  // save to application documents/receipts/<studentId>/
  final documentsDir = await getApplicationDocumentsDirectory();
  final receiptsDir = Directory(p.join(documentsDir.path, 'receipts', student.id));
  if (!receiptsDir.existsSync()) receiptsDir.createSync(recursive: true);
  final fileName = 'receipt_${inscriptionId ?? 'unknown'}_${DateTime.now().millisecondsSinceEpoch}.pdf';
  final filePath = p.join(receiptsDir.path, fileName);
  final file = File(filePath);
  await file.writeAsBytes(bytes, flush: true);

  // register as document in DB
  final doc = Document(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    formationId: formation?.id ?? '',
    studentId: student.id,
    title: 'Reçu paiement ${formation?.title ?? ''}',
    category: 'reçu',
    fileName: fileName,
    path: filePath,
    mimeType: 'application/pdf',
    size: bytes.length,
  certificateNumber: '',
  validationUrl: '',
  qrcodeData: '',
  );
  await DatabaseService().insertDocument(doc);

  return filePath;
}

String _amountToString(dynamic v) {
  if (v == null) return '0.00';
  if (v is num) return v.toDouble().toStringAsFixed(2);
  final parsed = double.tryParse(v.toString());
  return (parsed ?? 0.0).toStringAsFixed(2);
}

Future<pw.MemoryImage?> _loadCompanyLogo(String? logoPath) async {
  if (logoPath == null || logoPath.isEmpty) return null;
  final file = File(logoPath);
  if (!file.existsSync()) return null;
  final bytes = await file.readAsBytes();
  return pw.MemoryImage(bytes);
}
