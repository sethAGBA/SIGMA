import 'dart:io';
import 'dart:typed_data';
import 'package:afroforma/models/formation.dart';
import 'package:afroforma/models/student.dart';
import 'package:afroforma/screen/parametres/models.dart'; // CompanyInfo
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/document.dart';
import '../services/database_service.dart';
import 'package:afroforma/utils/pdf_style.dart';

/// Generate a diploma PDF with the required fields.
Future<Uint8List> generateDiplomaPdfBytes({
  required Student student,
  required Formation formation,
  required DateTime birthDate,
  required String placeOfBirth,
  required String studentMatricule,
  required String level,
  required String mention,
  required String academicYear,
  required String diplomaNumber,
  required CompanyInfo companyInfo,
}) async {
  final pdf = pw.Document();

  // Load fonts
  final regularFontData = await rootBundle.load('assets/fonts/Nunito-Regular.ttf');
  final boldFontData = await rootBundle.load('assets/fonts/Nunito-Bold.ttf');
  final italicFontData = await rootBundle.load('assets/fonts/Nunito-Italic.ttf');
  final regular = pw.Font.ttf(regularFontData);
  final bold = pw.Font.ttf(boldFontData);
  final italic = pw.Font.ttf(italicFontData);

  final pw.MemoryImage? companyLogo = await _loadCompanyLogo(companyInfo.logoPath);

  // watermark widget
  final pw.Widget watermark = (companyLogo != null)
      ? pw.Positioned.fill(
          child: pw.Center(child: pw.Opacity(opacity: 0.06, child: pw.Image(companyLogo, width: 700))),
        )
      : pw.Positioned.fill(
          child: pw.Center(
            child: pw.Opacity(
              opacity: 0.05,
              child: pw.Transform.rotate(
                angle: -0.18,
                child: pw.Text(companyInfo.name, style: pw.TextStyle(font: bold, fontSize: 90, color: PdfColors.grey300)),
              ),
            ),
          ),
        );

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a3.landscape,
      build: (pw.Context context) {
        return pw.Stack(children: [
          if (companyLogo != null || companyInfo.name.isNotEmpty) watermark,
          pw.Positioned.fill(
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(40),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  // Header
                  PdfStyle.header(
                    logo: companyLogo,
                    name: companyInfo.name,
                    address: companyInfo.address,
                    contact: '${companyInfo.phone}  |  ${companyInfo.email}',
                    regular: regular,
                    bold: bold,
                  ),

                  pw.SizedBox(height: 20),

                  // Diploma title and number
                  pw.Center(
                    child: pw.Column(
                      children: [
                        pw.Text('DIPLÔME', style: pw.TextStyle(font: bold, fontSize: 56, color: PdfColors.blue900)),
                        pw.SizedBox(height: 6),
                        pw.Text('N° $diplomaNumber', style: pw.TextStyle(font: regular, fontSize: 12, color: PdfColors.grey600)),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 24),

                  // Framed content
                  pw.Container(
                    padding: const pw.EdgeInsets.all(28),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300, width: 2),
                      borderRadius: pw.BorderRadius.circular(6),
                      color: PdfColors.white,
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.RichText(
                          textAlign: pw.TextAlign.left,
                          text: pw.TextSpan(
                            children: [
                              pw.TextSpan(text: 'Par la présente, '),
                              pw.TextSpan(text: companyInfo.name, style: pw.TextStyle(font: bold)),
                              pw.TextSpan(text: ' certifie que :'),
                            ],
                            style: pw.TextStyle(font: regular, fontSize: 16),
                          ),
                        ),

                        pw.SizedBox(height: 18),

                        // Student identity block
                        pw.Container(
                          padding: const pw.EdgeInsets.all(12),
                          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey200)),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              _fieldRow('Nom & Prénoms', student.name, bold, regular),
                              _fieldRow('Date et lieu de naissance', '${DateFormat.yMMMMd('fr_FR').format(birthDate)} — $placeOfBirth', bold, regular),
                              _fieldRow('Numéro matricule', studentMatricule, bold, regular),
                              _fieldRow('Intitulé de la formation', formation.title, bold, regular),
                              _fieldRow('Niveau', level, bold, regular),
                              _fieldRow('Mention / Grade obtenu', mention, bold, regular),
                              _fieldRow('Année académique', academicYear, bold, regular),
                            ],
                          ),
                        ),

                        pw.SizedBox(height: 18),

                        // Official statement
                        pw.Text(
                          'En foi de quoi, le présent diplôme est délivré à l’étudiant(e) mentionné(e) ci-dessus pour servir et valoir ce que de droit.',
                          style: pw.TextStyle(font: regular, fontSize: 14),
                        ),

                        pw.SizedBox(height: 26),

                        // Signatures area
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Container(width: 220, height: 1, color: PdfColors.grey700),
                                pw.SizedBox(height: 6),
                                pw.Text('Signature du Directeur', style: pw.TextStyle(font: italic, fontSize: 12)),
                              ],
                            ),
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.center,
                              children: [
                                pw.Container(width: 220, height: 1, color: PdfColors.grey700),
                                pw.SizedBox(height: 6),
                                pw.Text('Signature du Responsable pédagogique', style: pw.TextStyle(font: italic, fontSize: 12)),
                              ],
                            ),
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.end,
                              children: [
                                pw.Container(width: 220, height: 1, color: PdfColors.grey700),
                                pw.SizedBox(height: 6),
                                pw.Text('Cachet de l\'école', style: pw.TextStyle(font: italic, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  pw.Spacer(),
                  // Footer with identifiers
                  PdfStyle.footer(rccm: companyInfo.rccm, nif: companyInfo.nif, website: companyInfo.website, regular: regular),
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

Future<String> generateAndSaveDiploma({
  required Student student,
  required Formation formation,
  required DateTime birthDate,
  required String placeOfBirth,
  required String studentMatricule,
  required String level,
  required String mention,
  required String academicYear,
  required String diplomaNumber,
}) async {
  final companyInfo = await DatabaseService().getCompanyInfo();
  final bytes = await generateDiplomaPdfBytes(
    student: student,
    formation: formation,
    birthDate: birthDate,
    placeOfBirth: placeOfBirth,
    studentMatricule: studentMatricule,
    level: level,
    mention: mention,
    academicYear: academicYear,
    diplomaNumber: diplomaNumber,
    companyInfo: companyInfo!,
  );

  final documentsDir = await getApplicationDocumentsDirectory();
  final diplomasDir = Directory(p.join(documentsDir.path, 'diplomas', student.id));
  if (!diplomasDir.existsSync()) diplomasDir.createSync(recursive: true);

  final fileName = 'diploma_${diplomaNumber}_${student.name.replaceAll(' ', '_')}.pdf';
  final filePath = p.join(diplomasDir.path, fileName);
  final file = File(filePath);
  await file.writeAsBytes(bytes, flush: true);

  final doc = Document(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    formationId: formation.id,
    studentId: student.id,
    title: 'Diplôme ${formation.title}',
    category: 'diplome',
    fileName: fileName,
    path: filePath,
    mimeType: 'application/pdf',
    size: bytes.length,
  certificateNumber: diplomaNumber,
  validationUrl: '',
  qrcodeData: diplomaNumber,
  );
  await DatabaseService().insertDocument(doc);

  return filePath;
}

pw.Widget _fieldRow(String label, String value, pw.Font bold, pw.Font regular) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 6),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(flex: 3, child: pw.Text('$label', style: pw.TextStyle(font: bold, fontSize: 12))),
        pw.SizedBox(width: 12),
        pw.Expanded(flex: 7, child: pw.Text(value, style: pw.TextStyle(font: regular, fontSize: 12))),
      ],
    ),
  );
}

Future<pw.MemoryImage?> _loadCompanyLogo(String? logoPath) async {
  if (logoPath == null || logoPath.isEmpty) return null;
  final file = File(logoPath);
  if (!file.existsSync()) return null;
  final bytes = await file.readAsBytes();
  return pw.MemoryImage(bytes);
}
