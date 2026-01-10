import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Styling utilities for PDF generators (top-level helper).
class PdfStyle {
  static final PdfColor primaryColor = PdfColor.fromHex('#06B6D4');
  static final PdfColor secondaryColor = PdfColor.fromHex('#6B7280');
  static final PdfColor lightBgColor = PdfColor.fromHex('#F3F4F6');

  /// Load common fonts (Times/TimesBold). Returns a map with 'regular' and 'bold'.
  static Future<Map<String, pw.Font>> loadFonts() async {
    final regular = await pw.Font.times();
    final bold = await pw.Font.timesBold();
    return {'regular': regular, 'bold': bold};
  }

  /// Build a standard header widget using optional logo image and contact info.
  static pw.Widget header({
    pw.MemoryImage? logo,
    required String name,
    required String address,
    required String contact,
    required pw.Font regular,
    required pw.Font bold,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: lightBgColor,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Logo on the left
          if (logo != null)
            pw.Container(width: 96, alignment: pw.Alignment.centerLeft, child: pw.Image(logo, height: 80, width: 80, fit: pw.BoxFit.contain)),
          if (logo == null) pw.SizedBox(width: 8),

          // Spacer between logo and info
          pw.SizedBox(width: 12),

          // Company info on the right
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(name, style: pw.TextStyle(font: bold, fontSize: 16, color: primaryColor, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text(address, style: pw.TextStyle(font: regular, fontSize: 9, color: secondaryColor)),
                pw.SizedBox(height: 2),
                pw.Text(contact, style: pw.TextStyle(font: regular, fontSize: 9, color: secondaryColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build a compact footer from company identifiers.
  static pw.Widget footer({
    required String rccm,
    required String nif,
    required String website,
    required pw.Font regular,
  }) {
  final parts = <String>[];
  if (rccm.isNotEmpty) parts.add('RCCM: $rccm');
  if (nif.isNotEmpty) parts.add('NIF: $nif');
  if (website.isNotEmpty) parts.add(website);
  // Format like: (RCCM: 123456 NIF: 123456 cabinetacte.com)
  final footerText = parts.isNotEmpty ? '(${parts.join(' ')})' : '';
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Divider(color: lightBgColor, thickness: 1),
        pw.SizedBox(height: 6),
    pw.Text(footerText, style: pw.TextStyle(font: regular, fontSize: 9), textAlign: pw.TextAlign.center),
      ],
    );
  }
}
