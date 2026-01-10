import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:afroforma/models/formation.dart';
import 'package:afroforma/models/student.dart';
import 'package:afroforma/models/document.dart';
import 'package:afroforma/services/database_service.dart';
import 'package:afroforma/screen/parametres/models.dart';
import 'package:afroforma/utils/pdf_style.dart';
import 'package:path_provider/path_provider.dart';

// Couleurs du design moderne
class ModernColors {
  static const PdfColor primaryGold = PdfColor(229/255, 168/255, 27/255); // #E5A81B
  static const PdfColor primaryBlue = PdfColor(14/255, 64/255, 100/255);  // #0E4064
  static const PdfColor white = PdfColor(1.0, 1.0, 1.0);                  // #FFFFFF
  static const PdfColor lightGold = PdfColor(249/255, 237/255, 205/255);  // Version claire du doré
  static const PdfColor darkBlue = PdfColor(10/255, 45/255, 70/255);      // Version plus foncée du bleu

  // Helper to get the same gold with a custom alpha (PdfColor has no copyWith)
  static PdfColor primaryGoldWithAlpha(double alpha) => PdfColor(229/255, 168/255, 27/255, alpha);
  static PdfColor primaryBlueWithAlpha(double alpha) => PdfColor(14/255, 64/255, 100/255, alpha);
}

/// Génère les bytes du certificat PDF avec le nouveau design moderne.
Future<Uint8List> generateCertificatePdfBytes(
  Student student,
  Formation formation,
  Map<String, dynamic> certificationData,
  CompanyInfo companyInfo,
) async {
  final pdf = pw.Document();

  final fonts = await PdfStyle.loadFonts();
  final regular = fonts['regular']!;
  final bold = fonts['bold']!;
  final italic = regular;

  final companyLogo = await _loadCompanyLogo(companyInfo.logoPath);
  final validationUrl = (certificationData['validationUrl'] ?? certificationData['validation_url'] ?? '').toString();

  // Defensive local values to avoid null runtime errors
  final mentionText = (certificationData['appreciation'] ?? certificationData['mention'] ?? 'SATISFAISANT').toString().toUpperCase();

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a3.landscape,
      margin: pw.EdgeInsets.zero,
      build: (context) {
        return pw.Stack(
          children: [
            // Background avec motifs géométriques
            _buildGeometricBackground(),

            // Contenu principal
            pw.Container(
              margin: const pw.EdgeInsets.all(40),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  // Header avec logo
                  _buildModernHeader(companyLogo, companyInfo, regular, bold),

                  pw.SizedBox(height: 30),

                  // Corps principal
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        // Titre principal
                        pw.Text(
                          'CERTIFICAT DE FIN DE FORMATION',
                          style: pw.TextStyle(
                            font: bold,
                            fontSize: 42,
                            color: ModernColors.primaryBlue,
                            letterSpacing: 2.0,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),

                        pw.SizedBox(height: 8),

                        // Sous-titre
                        pw.Text(
                          'DE PARTICIPATION',
                          style: pw.TextStyle(
                            font: bold,
                            fontSize: 24,
                            color: ModernColors.primaryGold,
                            letterSpacing: 1.0,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),

                        pw.SizedBox(height: 40),

                        // Texte d'attestation
                        _buildAttestationText(companyInfo, regular, italic),

                        pw.SizedBox(height: 30),

                        // Nom de l'étudiant mis en évidence
                        _buildStudentNameHighlight(student, bold),

                        pw.SizedBox(height: 25),

                        // Informations sur l'étudiant
                        _buildModernStudentInfo(student, certificationData, regular, bold),

                        pw.SizedBox(height: 25),

                        // Texte de formation et mention
                        _buildFormationText(formation, mentionText, regular, bold),

                        pw.SizedBox(height: 20),

                        // Informations de formation
                        _buildModernFormationInfo(formation, certificationData, companyInfo, regular, bold),

                        pw.Spacer(),

                        // Section signatures
                        _buildModernSignatureSection(companyInfo, certificationData, regular, bold),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 20),

                  // Footer avec informations du certificat
                  _buildModernFooter(certificationData, regular, italic, validationUrl),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );

  return pdf.save();
}

/// Génère puis sauvegarde l'attestation d'intervention au format A4.
/// Retourne le chemin du fichier sauvegardé.
Future<String> generateAndSaveInterventionCertificate({
  required String participantFullName,
  String organisationName = 'Cabinet K-EMPIRE CORPORATION',
  DateTime? eventStart,
  DateTime? eventEnd,
  String eventTitle = "L'OHADA au service du développement économique en Afrique:\n31 Ans d'innovation juridique",
  String eventPlace = 'Kara',
  DateTime? issueDate,
  String studentId = '',
  String formationId = '',
  String? validationUrl,
}) async {
  // Generate the improved A4 PDF bytes
  final bytes = await generateInterventionCertificatePdf(
    participantFullName: participantFullName,
    organisationName: organisationName,
    eventStart: eventStart,
    eventEnd: eventEnd,
    eventTitle: eventTitle,
    eventPlace: eventPlace,
    issueDate: issueDate,
    validationUrl: validationUrl,
  );

  // Save under the student's certificates folder
  final documentsDir = await getApplicationDocumentsDirectory();
  final certsDir = Directory(p.join(documentsDir.path, 'certificates', studentId.isNotEmpty ? studentId : 'general'));
  if (!certsDir.existsSync()) certsDir.createSync(recursive: true);
  final safeName = participantFullName.replaceAll(RegExp(r"[^a-zA-Z0-9_-]"), '_');
  final fileName = 'attestation_participation_${formationId.isNotEmpty ? formationId : 'na'}_${safeName}_${DateTime.now().millisecondsSinceEpoch}.pdf';
  final filePath = p.join(certsDir.path, fileName);
  final file = File(filePath);
  await file.writeAsBytes(bytes, flush: true);

  // Insert Document record so it appears like other PDFs
  final idStr = DateTime.now().millisecondsSinceEpoch.toString();
  final certNumber = idStr; // simple certificate number; replace with your numbering scheme if needed
  final qrData = validationUrl ?? certNumber;

  final doc = Document(
    id: idStr,
    formationId: formationId,
    studentId: studentId,
    title: 'Attestation de participation - $participantFullName',
    category: 'certificat',
    fileName: fileName,
    path: filePath,
    mimeType: 'application/pdf',
    size: bytes.length,
    certificateNumber: certNumber,
    validationUrl: validationUrl ?? '',
    qrcodeData: qrData,
  );
  await DatabaseService().insertDocument(doc);

  return filePath;
}

/// Créer l'arrière-plan géométrique moderne
pw.Widget _buildGeometricBackground() {
  return pw.Stack(
    children: [
      // Fond principal blanc
      pw.Positioned.fill(
        child: pw.Container(color: ModernColors.white),
      ),

      // Motifs géométriques dans les coins (formes rotatives légères)
      _buildCornerGeometry(pw.Alignment.topLeft),
      _buildCornerGeometry(pw.Alignment.topRight),
      _buildCornerGeometry(pw.Alignment.bottomLeft),
      _buildCornerGeometry(pw.Alignment.bottomRight),

      // Diagonal subtle stripes for depth
      pw.Positioned.fill(
        child: pw.Transform.rotate(
          angle: -0.35,
          child: pw.Container(
            child: pw.Row(
              children: List.generate(20, (i) => pw.Container(
                width: 30,
                color: (i % 2 == 0) ? ModernColors.primaryGoldWithAlpha(0.02) : ModernColors.primaryBlueWithAlpha(0.02),
              )),
            ),
          ),
        ),
      ),

      // Watermark text diagonally
      pw.Positioned.fill(
        child: pw.Center(
          child: pw.Transform.rotate(
            angle: -math.pi / 8,
            child: pw.Opacity(
              opacity: 0.06,
              child: pw.Text(
                'AFROFORMA',
                style: pw.TextStyle(
                  fontSize: 120,
                  font: pw.Font.helvetica(),
                  color: ModernColors.primaryBlue,
                  letterSpacing: 4,
                ),
              ),
            ),
          ),
        ),
      ),

      // Bordures décoratives
      _buildDecorativeBorders(),
    ],
  );
}

/// Créer les motifs géométriques dans les coins
pw.Widget _buildCornerGeometry(pw.Alignment alignment) {
  // Simple positioned decorative block to replace custom painting (keeps file compatible
  // with the pdf/widgets API without referencing low-level Canvas/Path classes).
  const double size = 200;
  double left = 0;
  double top = 0;
  if (alignment == pw.Alignment.topLeft) {
    left = 0;
    top = 0;
  } else if (alignment == pw.Alignment.topRight) {
    left = PdfPageFormat.a3.landscape.width - size;
    top = 0;
  } else if (alignment == pw.Alignment.bottomLeft) {
    left = 0;
    top = PdfPageFormat.a3.landscape.height - size;
  } else {
    left = PdfPageFormat.a3.landscape.width - size;
    top = PdfPageFormat.a3.landscape.height - size;
  }

  // Create a rotated square with soft gradient and reduced opacity to act as corner decoration
  return pw.Positioned(
    left: left,
    top: top,
    child: pw.Transform.rotate(
      angle: (alignment == pw.Alignment.topLeft || alignment == pw.Alignment.bottomRight) ? -0.5 : 0.4,
      child: pw.Container(
        width: size,
        height: size,
        decoration: pw.BoxDecoration(
          gradient: pw.LinearGradient(
            colors: [ModernColors.primaryGoldWithAlpha(0.18), ModernColors.primaryBlueWithAlpha(0.12)],
            begin: pw.Alignment.topLeft,
            end: pw.Alignment.bottomRight,
          ),
          borderRadius: pw.BorderRadius.circular(16),
        ),
      ),
    ),
  );
}

/// Créer les bordures décoratives
pw.Widget _buildDecorativeBorders() {
  return pw.Stack(
    children: [
      // Bordure supérieure
      pw.Positioned(
        top: 0,
        left: 100,
        right: 100,
        child: pw.Container(
          height: 8,
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(
              colors: [ModernColors.primaryGold, ModernColors.primaryBlue, ModernColors.primaryGold],
            ),
          ),
        ),
      ),
      // Bordure inférieure
      pw.Positioned(
        bottom: 0,
        left: 100,
        right: 100,
        child: pw.Container(
          height: 8,
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(
              colors: [ModernColors.primaryGold, ModernColors.primaryBlue, ModernColors.primaryGold],
            ),
          ),
        ),
      ),
    ],
  );
}

/// Header moderne avec logo
pw.Widget _buildModernHeader(pw.MemoryImage? logo, CompanyInfo companyInfo, pw.Font regular, pw.Font bold) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 15, horizontal: 25),
    decoration: pw.BoxDecoration(
      color: ModernColors.white,
      border: pw.Border.all(color: ModernColors.primaryGold, width: 2),
      borderRadius: pw.BorderRadius.circular(12),
      boxShadow: [
        pw.BoxShadow(
          color: PdfColors.grey300,
          offset: const PdfPoint(0, 2),
          blurRadius: 4,
        ),
      ],
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        // Logo
        if (logo != null)
          pw.Container(
            width: 80,
            height: 80,
            child: pw.Image(logo, fit: pw.BoxFit.contain),
          )
        else
          pw.SizedBox(width: 80),

        // Informations de l'entreprise
        pw.Expanded(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                companyInfo.name.toUpperCase(),
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 20,
                  color: ModernColors.primaryBlue,
                  letterSpacing: 1.5,
                ),
                textAlign: pw.TextAlign.center,
              ),
              if (companyInfo.address.isNotEmpty) ...[
                pw.SizedBox(height: 5),
                pw.Text(
                  companyInfo.address,
                  style: pw.TextStyle(font: regular, fontSize: 12, color: PdfColors.grey700),
                  textAlign: pw.TextAlign.center,
                ),
              ],
              if (companyInfo.phone.isNotEmpty || companyInfo.email.isNotEmpty) ...[
                pw.SizedBox(height: 3),
                pw.Text(
                  '${companyInfo.phone}  |  ${companyInfo.email}',
                  style: pw.TextStyle(font: regular, fontSize: 10, color: PdfColors.grey600),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ],
          ),
        ),

        // Espace pour équilibrer
        pw.SizedBox(width: 80),
      ],
    ),
  );
}

/// Texte d'attestation moderne
pw.Widget _buildAttestationText(CompanyInfo companyInfo, pw.Font regular, pw.Font italic) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 40),
    child: pw.RichText(
      textAlign: pw.TextAlign.center,
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: 'Nous, soussignés, ',
            style: pw.TextStyle(font: regular, fontSize: 16, color: PdfColors.grey800),
          ),
          pw.TextSpan(
            text: companyInfo.name.toUpperCase(),
            style: pw.TextStyle(font: italic, fontSize: 16, color: ModernColors.primaryBlue),
          ),
          pw.TextSpan(
            text: ' attestons que :',
            style: pw.TextStyle(font: regular, fontSize: 16, color: PdfColors.grey800),
          ),
        ],
      ),
    ),
  );
}

/// Nom de l'étudiant mis en évidence
pw.Widget _buildStudentNameHighlight(Student student, pw.Font bold) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 20),
    decoration: pw.BoxDecoration(
      gradient: pw.LinearGradient(
        colors: [ModernColors.lightGold, ModernColors.white, ModernColors.lightGold],
      ),
      border: pw.Border.all(color: ModernColors.primaryGold, width: 3),
      borderRadius: pw.BorderRadius.circular(15),
    ),
    child: pw.Text(
      student.name.toUpperCase(),
      style: pw.TextStyle(
        font: bold,
        fontSize: 32,
        color: ModernColors.primaryBlue,
        letterSpacing: 2.0,
      ),
      textAlign: pw.TextAlign.center,
    ),
  );
}

/// Informations sur l'étudiant - version moderne
pw.Widget _buildModernStudentInfo(
  Student student,
  Map<String, dynamic> certificationData,
  pw.Font regular,
  pw.Font bold,
) {
  final dateVal = (student.dateNaissance.isNotEmpty)
    ? student.dateNaissance
    : (certificationData['dateNaissance']?.toString() ?? 'Non spécifiée');
  final lieuVal = (student.lieuNaissance.isNotEmpty)
    ? student.lieuNaissance
    : (certificationData['lieuNaissance']?.toString() ?? 'Non spécifié');

  return pw.Container(
    padding: const pw.EdgeInsets.all(20),
    decoration: pw.BoxDecoration(
      color: ModernColors.white,
      border: pw.Border.all(color: ModernColors.primaryGold, width: 1),
      borderRadius: pw.BorderRadius.circular(10),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
      children: [
        _buildModernInfoItem('Né(e) le', dateVal, regular, bold),
        _buildVerticalSeparator(),
        _buildModernInfoItem('À', lieuVal, regular, bold),
        _buildVerticalSeparator(),
        _buildModernInfoItem('Matricule', student.id.substring(0, 8).toUpperCase(), regular, bold),
      ],
    ),
  );
}

pw.Widget _buildModernInfoItem(String label, String value, pw.Font regular, pw.Font bold) {
  return pw.Column(
    children: [
      pw.Text(
        label,
        style: pw.TextStyle(
          font: regular,
          fontSize: 12,
          color: ModernColors.primaryGold,
        ),
      ),
      pw.SizedBox(height: 5),
      pw.Text(
        value,
        style: pw.TextStyle(
          font: bold,
          fontSize: 14,
          color: ModernColors.primaryBlue,
        ),
      ),
    ],
  );
}

pw.Widget _buildVerticalSeparator() {
  return pw.Container(
    height: 40,
    width: 1,
    color: ModernColors.primaryGold,
  );
}

/// Texte de formation et mention
pw.Widget _buildFormationText(Formation formation, String mentionText, pw.Font regular, pw.Font bold) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 40),
    child: pw.RichText(
      textAlign: pw.TextAlign.center,
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: 'a participé effectivement à la formation en ',
            style: pw.TextStyle(font: regular, fontSize: 18, color: PdfColors.grey800),
          ),
          pw.TextSpan(
            text: formation.title.toUpperCase(),
            style: pw.TextStyle(font: bold, fontSize: 20, color: ModernColors.primaryBlue),
          ),
          pw.TextSpan(
            text: ', et a obtenu la mention ',
            style: pw.TextStyle(font: regular, fontSize: 18, color: PdfColors.grey800),
          ),
          pw.TextSpan(
            text: mentionText,
            style: pw.TextStyle(font: bold, fontSize: 20, color: ModernColors.primaryGold),
          ),
          pw.TextSpan(
            text: '.',
            style: pw.TextStyle(font: regular, fontSize: 18, color: PdfColors.grey800),
          ),
        ],
      ),
    ),
  );
}

/// Informations de formation - version moderne
pw.Widget _buildModernFormationInfo(
  Formation formation,
  Map<String, dynamic> certificationData,
  CompanyInfo companyInfo,
  pw.Font regular,
  pw.Font bold,
) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(25),
    decoration: pw.BoxDecoration(
      gradient: pw.LinearGradient(
        colors: [ModernColors.lightGold.shade(30), ModernColors.white],
        begin: pw.Alignment.topLeft,
        end: pw.Alignment.bottomRight,
      ),
      border: pw.Border.all(color: ModernColors.primaryGold, width: 2),
      borderRadius: pw.BorderRadius.circular(12),
    ),
    child: pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
          children: [
            _buildFormationDetailModern('Niveau', 
                certificationData['niveau'] ?? 'Certification', bold, regular),
            _buildFormationDetailModern('Durée', 
                '${formation.duration.isNotEmpty ? formation.duration : 'N/A'} heures', bold, regular),
            _buildFormationDetailModern('Session', 
                companyInfo.academic_year, bold, regular),
          ],
        ),
        if (certificationData['specialite'] != null && 
            certificationData['specialite'].toString().isNotEmpty) ...[
          pw.SizedBox(height: 15),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: pw.BoxDecoration(
              color: ModernColors.primaryGoldWithAlpha(0.2),
              borderRadius: pw.BorderRadius.circular(20),
            ),
            child: pw.Text(
              'Spécialité: ${certificationData['specialite']}',
              style: pw.TextStyle(
                font: regular,
                fontSize: 14,
                color: ModernColors.primaryBlue,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ],
      ],
    ),
  );
}

pw.Widget _buildFormationDetailModern(String label, String value, pw.Font boldFont, pw.Font regular) {
  return pw.Column(
    children: [
      pw.Text(
        label,
        style: pw.TextStyle(
          font: boldFont,
          fontSize: 13,
          color: ModernColors.primaryGold,
        ),
      ),
      pw.SizedBox(height: 8),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 15, vertical: 5),
        decoration: pw.BoxDecoration(
          color: ModernColors.white,
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: ModernColors.primaryBlue, width: 1),
        ),
        child: pw.Text(
          value,
          style: pw.TextStyle(
            font: regular,
            fontSize: 12,
            color: ModernColors.primaryBlue,
          ),
        ),
      ),
    ],
  );
}

/// Section des signatures - version moderne
pw.Widget _buildModernSignatureSection(
  CompanyInfo companyInfo,
  Map<String, dynamic> certificationData,
  pw.Font regular,
  pw.Font bold,
) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      _buildModernSignatureBox('Le Directeur', 
          certificationData['signatureDirecteur'] ?? companyInfo.name, regular, bold),
      
      // Cachet officiel moderne au centre
      pw.Container(
        width: 140,
        height: 140,
        decoration: pw.BoxDecoration(
          shape: pw.BoxShape.circle,
          border: pw.Border.all(color: ModernColors.primaryGold, width: 4),
          gradient: pw.LinearGradient(
            colors: [ModernColors.lightGold, ModernColors.white],
          ),
        ),
        child: pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                'CACHET',
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 16,
                  color: ModernColors.primaryBlue,
                ),
              ),
              pw.Text(
                'OFFICIEL',
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 16,
                  color: ModernColors.primaryBlue,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: ModernColors.primaryGold,
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Text(
                  DateFormat('dd/MM/yyyy').format(DateTime.now()),
                  style: pw.TextStyle(
                    font: regular,
                    fontSize: 10,
                    color: ModernColors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      
      _buildModernSignatureBox('Le Responsable Pédagogique', 
          certificationData['signatureResponsable'] ?? 'Direction Pédagogique', regular, bold),
    ],
  );
}

pw.Widget _buildModernSignatureBox(String title, String name, pw.Font regular, pw.Font bold) {
  return pw.Container(
    width: 180,
    child: pw.Column(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          decoration: pw.BoxDecoration(
            color: ModernColors.primaryBlue,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Text(
            title,
            style: pw.TextStyle(
              font: regular,
              fontSize: 11,
              color: ModernColors.white,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.SizedBox(height: 50), // Espace pour signature manuscrite
        pw.Container(
          height: 2,
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(
              colors: [ModernColors.primaryGold, ModernColors.primaryBlue],
            ),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          name,
          style: pw.TextStyle(
            font: bold,
            fontSize: 11,
            color: ModernColors.primaryBlue,
          ),
          textAlign: pw.TextAlign.center,
        ),
      ],
    ),
  );
}

/// Footer moderne avec informations du certificat
pw.Widget _buildModernFooter(
  Map<String, dynamic> certificationData,
  pw.Font regular,
  pw.Font italic,
  String? validationUrl,
) {
  final certificateNumber = certificationData['numeroCertificat'] ??
      'CERT-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

  return pw.Container(
    padding: const pw.EdgeInsets.all(20),
    decoration: pw.BoxDecoration(
      gradient: pw.LinearGradient(
        colors: [ModernColors.primaryBlue, ModernColors.primaryGold],
      ),
      borderRadius: pw.BorderRadius.circular(10),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        // Numéro de certificat
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Certificat N°:',
              style: pw.TextStyle(
                font: italic,
                fontSize: 12,
                color: ModernColors.white,
              ),
            ),
            pw.Text(
              certificateNumber.toString(),
              style: pw.TextStyle(
                font: regular,
                fontSize: 14,
                color: ModernColors.white,
              ),
            ),
          ],
        ),

        // QR Code (optionnel)
        if (validationUrl != null && validationUrl.isNotEmpty)
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: ModernColors.white,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.BarcodeWidget(
              data: validationUrl,
              barcode: pw.Barcode.qrCode(),
              width: 80,
              height: 80,
            ),
          )
        else
          pw.SizedBox(width: 80, height: 80),

        // Date de délivrance
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'Fait à Lomé, le:',
              style: pw.TextStyle(
                font: italic,
                fontSize: 12,
                color: ModernColors.white,
              ),
            ),
            pw.Text(
              DateFormat('dd MMMM yyyy', 'fr_FR').format(DateTime.now()),
              style: pw.TextStyle(
                font: regular,
                fontSize: 14,
                color: ModernColors.white,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Fonction principale pour générer et sauvegarder le certificat
Future<String> generateAndSaveCertificate(
  Student student,
  Formation formation,
  Map<String, dynamic> certificationData,
) async {
  final companyInfo = await DatabaseService().getCompanyInfo();
  final bytes = await generateCertificatePdfBytes(
      student, formation, certificationData, companyInfo!);

  // Sauvegarder dans le dossier des certificats
  final documentsDir = await getApplicationDocumentsDirectory();
  final certificatesDir = Directory(p.join(documentsDir.path, 'certificates', student.id));
  if (!certificatesDir.existsSync()) certificatesDir.createSync(recursive: true);
  
  final fileName = 'certificate_${formation.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';
  final filePath = p.join(certificatesDir.path, fileName);
  final file = File(filePath);
  await file.writeAsBytes(bytes, flush: true);

  // Enregistrer comme document dans la base de données
  final idStr2 = DateTime.now().millisecondsSinceEpoch.toString();
  final validationUrl = (certificationData['validationUrl'] ?? certificationData['validation_url'] ?? '').toString();
  final certNumber2 = (certificationData['certificate_number'] ?? certificationData['certificateNumber'] ?? idStr2).toString();
  final qrData2 = validationUrl.isNotEmpty ? validationUrl : certNumber2;

  final doc = Document(
    id: idStr2,
    formationId: formation.id,
    studentId: student.id,
    title: 'Certificat - ${formation.title}',
    category: 'certificat',
    fileName: fileName,
    path: filePath,
    mimeType: 'application/pdf',
    size: bytes.length,
    certificateNumber: certNumber2,
    validationUrl: validationUrl,
    qrcodeData: qrData2,
  );
  await DatabaseService().insertDocument(doc);

  return filePath;
}

/// Fonction pour imprimer le certificat
Future<void> generateAndPrintCertificate(
  Student student,
  Formation formation,
  Map<String, dynamic> certificationData,
) async {
  final companyInfo = await DatabaseService().getCompanyInfo();
  final bytes = await generateCertificatePdfBytes(
      student, formation, certificationData, companyInfo!);
  await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => bytes);
}

/// Génère un certificat d'intervention / attestation de participation au format A4
/// selon la mise en page demandée.
Future<Uint8List> generateInterventionCertificatePdf({
  required String participantFullName,
  String organisationName = 'Cabinet K-EMPIRE CORPORATION',
  DateTime? eventStart,
  DateTime? eventEnd,
  String eventTitle = "L'OHADA au service du développement économique en Afrique:\n31 Ans d'innovation juridique",
  String eventPlace = 'Kara',
  DateTime? issueDate,
  String? validationUrl,
}) async {
  final pdf = pw.Document();

  // Try to load a nicer local font (JosefinSans) for a more elegant look
  pw.Font regular;
  pw.Font bold;
  try {
    final fontData = await rootBundle.load('assets/fonts/JosefinSans-Regular.ttf');
    final fontBoldData = await rootBundle.load('assets/fonts/JosefinSans-Bold.ttf');
    regular = pw.Font.ttf(fontData);
    bold = pw.Font.ttf(fontBoldData);
  } catch (_) {
    // fallback
    regular = pw.Font.helvetica();
    bold = pw.Font.helveticaBold();
  }

  final DateTime start = eventStart ?? DateTime(2024, 10, 30);
  final DateTime end = eventEnd ?? DateTime(2024, 10, 31);
  final DateTime issued = issueDate ?? DateTime(2024, 11, 7);

  final dateFormat = DateFormat('dd MMMM yyyy', 'fr_FR');

  // Load company info and logo synchronously before building pages
  final companyInfo = await DatabaseService().getCompanyInfo();
  final pw.MemoryImage? companyLogoImage = await _loadCompanyLogo(companyInfo?.logoPath);

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.all(48),
      build: (context) {
        return pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: ModernColors.primaryBlue, width: 2),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          padding: const pw.EdgeInsets.all(24),
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              // En-tête avec logo à gauche et titres au centre
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (companyLogoImage != null)
                    pw.Container(width: 80, height: 80, child: pw.Image(companyLogoImage, fit: pw.BoxFit.contain))
                  else
                    pw.SizedBox(width: 80, height: 80),
                  pw.Expanded(
                    child: pw.Column(
                      children: [
                        pw.Text(
                          'CERTIFICAT D’INTERVENTION',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            font: bold,
                            fontSize: 34,
                            color: ModernColors.primaryBlue,
                            letterSpacing: 1.5,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          'ATTESTATION DE PARTICIPATION',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            font: bold,
                            fontSize: 20,
                            color: ModernColors.primaryGold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 80, height: 80),
                ],
              ),

              // Corps
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.SizedBox(height: 12),
                  pw.Text(
                    'Nous, soussignés, $organisationName attestons que :',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: regular, fontSize: 12, color: PdfColors.grey800),
                  ),

                  pw.SizedBox(height: 18),

                  pw.Text(
                    participantFullName,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: bold, fontSize: 26, color: ModernColors.darkBlue),
                  ),

                  pw.SizedBox(height: 12),

                  pw.Text(
                    'a participé effectivement au Webinaire commémoratif des 31 ans de l’OHADA,\nsur le thème :',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: regular, fontSize: 12, color: PdfColors.grey800),
                  ),

                  pw.SizedBox(height: 10),

                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: pw.BoxDecoration(
                      color: ModernColors.primaryGoldWithAlpha(0.06),
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: ModernColors.primaryGoldWithAlpha(0.24), width: 1),
                      boxShadow: [
                        pw.BoxShadow(color: ModernColors.primaryBlueWithAlpha(0.02), blurRadius: 6)
                      ],
                    ),
                    child: pw.Text(
                      '"$eventTitle"',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(font: italicFontOr(regular), fontSize: 13, color: ModernColors.primaryBlue),
                    ),
                  ),

                  pw.SizedBox(height: 12),

                  pw.Text(
                    'qui s’est tenu du ${dateFormat.format(start)} au ${dateFormat.format(end)}.',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: regular, fontSize: 12, color: PdfColors.grey800),
                  ),
                ],
              ),

              // Clause finale (juste au-dessus du pied de page)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 8, bottom: 8),
                child: pw.Text(
                  'En foi de quoi, la présente attestation lui est délivrée\npour servir et valoir ce que de droit.',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: regular, fontSize: 11, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700),
                ),
              ),

              // Pied de page + signature
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Left footer + QR
                  pw.Row(
                    mainAxisSize: pw.MainAxisSize.max,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            pw.Text(
                              'Fait à $eventPlace, le ${dateFormat.format(issued)}',
                              style: pw.TextStyle(font: regular, fontSize: 11, color: PdfColors.grey800),
                            ),
                          ],
                        ),
                      ),

                      // QR code for validation (if validationUrl provided)
                      if (validationUrl != null && validationUrl.isNotEmpty)
                        pw.Container(
                          width: 80,
                          height: 80,
                          padding: const pw.EdgeInsets.all(6),
                          decoration: pw.BoxDecoration(
                            color: ModernColors.white,
                            borderRadius: pw.BorderRadius.circular(6),
                            border: pw.Border.all(color: ModernColors.primaryBlueWithAlpha(0.2)),
                          ),
                          child: pw.BarcodeWidget(
                            data: validationUrl,
                            barcode: pw.Barcode.qrCode(),
                          ),
                        )
                      else
                        pw.SizedBox(width: 80, height: 80),

                      // Signature block right with line
                      pw.SizedBox(width: 12),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Text(
                            'Le Directeur',
                            style: pw.TextStyle(font: regular, fontSize: 12, color: ModernColors.primaryBlue),
                          ),
                          pw.SizedBox(height: 18),
                          pw.Container(width: 180, height: 1, color: ModernColors.primaryBlue),
                          pw.SizedBox(height: 6),
                          pw.Text(
                            'Kouami Emmanuel KOUDADJE',
                            style: pw.TextStyle(font: bold, fontSize: 12, color: ModernColors.primaryBlue),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );

  return pdf.save();
}

// Small helper: return an italic font if available, otherwise use the provided fallback
pw.Font italicFontOr(pw.Font fallback) {
  try {
    return pw.Font.helveticaOblique();
  } catch (_) {
    return fallback;
  }
}

// Fonctions utilitaires
Future<pw.MemoryImage?> _loadCompanyLogo(String? logoPath) async {
  if (logoPath == null || logoPath.isEmpty) return null;
  final file = File(logoPath);
  if (!file.existsSync()) return null;
  final bytes = await file.readAsBytes();
  return pw.MemoryImage(bytes);
}