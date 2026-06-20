import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/configuration_model.dart';

/// En-tête et pied de page PDF dynamiques depuis la configuration institution.
class InstitutionPdfBranding {
  final LegalInformation legal;
  final String? documentTitle;
  final String? subtitle;

  InstitutionPdfBranding({
    required this.legal,
    this.documentTitle,
    this.subtitle,
  });

  List<pw.Widget> buildHeader() {
    final institutionName = legal.raisonSociale.isNotEmpty
        ? legal.raisonSociale
        : 'SIGMA Micro-Finance';

    return [
      pw.Text(
        institutionName,
        style: pw.TextStyle(
          fontSize: 18,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blue900,
        ),
      ),
      if (documentTitle != null) ...[
        pw.SizedBox(height: 4),
        pw.Text(
          documentTitle!,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blueGrey700,
          ),
        ),
      ],
      if (subtitle != null) ...[
        pw.SizedBox(height: 4),
        pw.Text(subtitle!, style: const pw.TextStyle(fontSize: 10)),
      ],
      if (legal.numeroAgrement.isNotEmpty ||
          legal.adresseSiege.isNotEmpty) ...[
        pw.SizedBox(height: 6),
        pw.Text(
          [
            if (legal.numeroAgrement.isNotEmpty)
              'Agrément : ${legal.numeroAgrement}',
            if (legal.adresseSiege.isNotEmpty) legal.adresseSiege,
          ].join(' — '),
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
      ],
      pw.SizedBox(height: 16),
    ];
  }

  pw.Widget buildFooter({String? generatedAt}) {
    final lines = <String>[
      if (legal.contactsOfficiels.isNotEmpty) legal.contactsOfficiels,
      if (generatedAt != null) 'Document généré le $generatedAt',
    ];
    if (lines.isEmpty) return pw.SizedBox();

    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 24),
      child: pw.Text(
        lines.join('\n'),
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        textAlign: pw.TextAlign.center,
      ),
    );
  }
}
