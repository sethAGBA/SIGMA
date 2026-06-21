// lib/core/services/loan_contract_template_service.dart
//
// Génère un contrat de prêt PDF multi-pages au format officiel.
// Exigences : 7.1 (variables métier), 7.2 (template configurable institution).

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/client_model.dart';
import '../../models/loan_model.dart';
import '../../models/loan_request_model.dart';
import '../../models/produit_financier_model.dart';
import '../../models/repayment_schedule_model.dart';
import 'database_service.dart';
import 'institution_pdf_branding.dart';

/// Service de génération de contrat de prêt PDF avancé.
///
/// Usage :
/// ```dart
/// final path = await LoanContractTemplateService().generateLoanContract(loanId);
/// ```
class LoanContractTemplateService {
  // ---------------------------------------------------------------------------
  // Formatters
  // ---------------------------------------------------------------------------

  final _currencyFmt = NumberFormat('#,##0', 'fr_FR');
  final _dateFmt = DateFormat('dd/MM/yyyy');
  final _dateTimeFmt = DateFormat('dd/MM/yyyy HH:mm');

  String _fmtAmount(double v) => '${_currencyFmt.format(v)} FCFA';
  String _fmtDate(DateTime d) => _dateFmt.format(d);


  // ---------------------------------------------------------------------------
  // Entry point
  // ---------------------------------------------------------------------------

  /// Génère le contrat PDF pour le prêt [loanId] et retourne le chemin du
  /// fichier créé dans `{appDocDir}/exports/contrats/`.
  ///
  /// Lance une [Exception] si le prêt ou le client est introuvable.
  Future<String> generateLoanContract(int loanId) async {
    final db = DatabaseService();

    // 1. Charger le prêt avec client + produit
    final loan = await db.getLoanById(loanId);
    if (loan == null) throw Exception('Prêt #$loanId introuvable.');
    if (loan.client == null) throw Exception('Client introuvable pour le prêt #$loanId.');

    // 2. Charger la demande de prêt associée (TEG, garanties, fréquence…)
    final loanRequest = await _fetchLoanRequest(db, loan);

    // 3. Charger l'échéancier
    final schedule = await db.getRepaymentSchedules(loanId);

    // 4. Charger le branding institution
    final legal = await db.getLegalInformation();
    final branding = InstitutionPdfBranding(
      legal: legal,
      documentTitle: 'CONTRAT DE PRÊT',
      subtitle: 'N° ${loan.numeroPret}  —  Date : ${_fmtDate(DateTime.now())}',
    );

    // 5. Construire le PDF
    final pdfDoc = await _buildPdf(loan, loanRequest, schedule, branding);

    // 6. Sauvegarder sur disque
    final path = await _savePdf(pdfDoc, loan);
    return path;
  }


  // ---------------------------------------------------------------------------
  // Data loading helpers
  // ---------------------------------------------------------------------------

  /// Tente de retrouver la demande de prêt liée via `demande_pret_id`.
  /// Retourne null si absente (prêts migrés anciens sans demande liée).
  Future<LoanRequest?> _fetchLoanRequest(DatabaseService db, Loan loan) async {
    if (loan.demandePretId <= 0) return null;
    try {
      final raw = await db.database;
      final maps = await raw.query(
        'demandes_pret',
        where: 'id = ?',
        whereArgs: [loan.demandePretId],
      );
      if (maps.isEmpty) return null;
      final map = maps.first;
      // Charger client + produit pour le modèle
      final clientMaps = await raw.query(
        'clients',
        where: 'id = ?',
        whereArgs: [map['client_id']],
      );
      final produitMaps = await raw.query(
        'produits_financiers',
        where: 'id = ?',
        whereArgs: [map['produit_id']],
      );
      return LoanRequest.fromMap(
        map,
        client: clientMaps.isNotEmpty ? Client.fromMap(clientMaps.first) : null,
        produit: produitMaps.isNotEmpty
            ? ProduitFinancier.fromMap(produitMaps.first)
            : null,
      );
    } catch (e) {
      debugPrint('[LoanContractTemplateService] Demande non chargée : $e');
    }
    return null;
  }

  Future<String> _savePdf(pw.Document pdfDoc, Loan loan) async {
    final appDir = await getApplicationDocumentsDirectory();
    final contratsDir = Directory('${appDir.path}/exports/contrats');
    if (!contratsDir.existsSync()) contratsDir.createSync(recursive: true);

    final clientSlug = loan.client!.nom.replaceAll(RegExp(r'\s+'), '_');
    final dateStamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final fileName = 'Contrat_${loan.numeroPret}_${clientSlug}_$dateStamp.pdf';
    final file = File('${contratsDir.path}/$fileName');
    await file.writeAsBytes(await pdfDoc.save());
    return file.path;
  }


  // ---------------------------------------------------------------------------
  // PDF assembly
  // ---------------------------------------------------------------------------

  Future<pw.Document> _buildPdf(
    Loan loan,
    LoanRequest? req,
    List<RepaymentSchedule> schedule,
    InstitutionPdfBranding branding,
  ) async {
    final pdf = pw.Document();
    final generatedAt = _dateTimeFmt.format(DateTime.now());

    // --- Page 1 : Identité des parties ---
    pdf.addPage(_buildPage1(loan, req, branding, generatedAt));

    // --- Page 2 : Conditions financières + Garanties ---
    pdf.addPage(_buildPage2(loan, req, branding, generatedAt));

    // --- Page 3+ : Tableau d'amortissement ---
    pdf.addPage(_buildAmortizationPage(loan, schedule, branding, generatedAt));

    return pdf;
  }


  // ---------------------------------------------------------------------------
  // Page 1 — Identité des parties
  // ---------------------------------------------------------------------------

  pw.Page _buildPage1(
    Loan loan,
    LoanRequest? req,
    InstitutionPdfBranding branding,
    String generatedAt,
  ) {
    final client = loan.client!;
    final institutionName = branding.legal.raisonSociale.isNotEmpty
        ? branding.legal.raisonSociale
        : 'L\'Institution';

    return pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 40),
      footer: (ctx) => branding.buildFooter(generatedAt: generatedAt),
      build: (ctx) => [
        ...branding.buildHeader(),
        _divider(),
        pw.SizedBox(height: 16),
        _sectionTitle('ENTRE LES SOUSSIGNÉS'),
        pw.SizedBox(height: 12),

        // Bloc institution
        _infoBlock('L\'Institution (prêteur)', [
          _row('Dénomination', institutionName),
          if (branding.legal.numeroAgrement.isNotEmpty)
            _row('N° Agrément', branding.legal.numeroAgrement),
          if (branding.legal.numeroFiscal.isNotEmpty)
            _row('IFU', branding.legal.numeroFiscal),
          if (branding.legal.adresseSiege.isNotEmpty)
            _row('Adresse', branding.legal.adresseSiege),
          if (branding.legal.contactsOfficiels.isNotEmpty)
            _row('Contact', branding.legal.contactsOfficiels),
        ]),
        pw.SizedBox(height: 16),

        _centerText('— ET —'),
        pw.SizedBox(height: 16),

        // Bloc client
        _infoBlock('L\'Emprunteur', [
          _row('Nom', client.nom),
          _row('Prénom(s)', client.prenoms),
          if (client.numeroCNI != null && client.numeroCNI!.isNotEmpty)
            _row('N° CNI / Pièce d\'identité', client.numeroCNI!),
          if (client.numeroPasseport != null && client.numeroPasseport!.isNotEmpty)
            _row('N° Passeport', client.numeroPasseport!),
          if (client.adresse != null && client.adresse!.isNotEmpty)
            _row('Adresse', client.adresse!),
          if (client.telephone != null && client.telephone!.isNotEmpty)
            _row('Téléphone', client.telephone!),
          if (client.activitePrincipale != null && client.activitePrincipale!.isNotEmpty)
            _row('Activité principale', client.activitePrincipale!),
          _row('N° Client', client.numeroClient),
        ]),
        pw.SizedBox(height: 24),

        _paragraph(
          'Il a été convenu et arrêté ce qui suit, en application des conditions générales '
          'du produit de crédit et conformément aux dispositions réglementaires en vigueur '
          'au sein de l\'espace UEMOA.',
        ),
        pw.SizedBox(height: 32),

        // Signatures préliminaires (lu et approuvé)
        _signatureBlock(
          clientName: client.nomComplet,
          institutionName: institutionName,
          dateStr: _fmtDate(DateTime.now()),
        ),
      ],
    );
  }


  // ---------------------------------------------------------------------------
  // Page 2 — Conditions financières + Garanties
  // ---------------------------------------------------------------------------

  pw.Page _buildPage2(
    Loan loan,
    LoanRequest? req,
    InstitutionPdfBranding branding,
    String generatedAt,
  ) {
    final produit = loan.produit;
    final tauxNominal = produit?.tauxInteret ?? 0.0;
    final teg = req?.teg ?? 0.0;
    final dureeMois = req?.dureeMois ?? 0;
    final frequence = req?.frequenceRemboursement.label ?? '-';
    final objetPret = req?.objetPret ?? '-';
    final mensualite = req?.mensualite ?? 0.0;
    final totalARembourser = req?.totalARembourser ?? 0.0;
    final moisDiffere = req?.moisDiffereCapital ?? loan.moisDiffereCapital ?? 0;

    return pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 40),
      footer: (ctx) => branding.buildFooter(generatedAt: generatedAt),
      build: (ctx) => [
        ...branding.buildHeader(),
        _divider(),
        pw.SizedBox(height: 12),

        // Article 1 — Objet
        _articleTitle('Article 1 — Objet et montant du prêt'),
        pw.SizedBox(height: 8),
        _infoBlock(null, [
          _row('Produit de crédit', produit?.nom ?? '-'),
          _row('Objet du financement', objetPret),
          _row('Montant accordé', _fmtAmount(loan.montantInitial)),
          _row('Durée', dureeMois > 0 ? '$dureeMois mois' : '-'),
          _row('Fréquence de remboursement', frequence),
          if (moisDiffere > 0)
            _row('Différé de capital', '$moisDiffere mois'),
          _row('Date de déblocage', _fmtDate(loan.dateDeblocage)),
          if (loan.dateEcheanceProchaine != null)
            _row('Date dernière échéance', _fmtDate(loan.dateEcheanceProchaine!)),
        ]),
        pw.SizedBox(height: 16),

        // Article 2 — Conditions financières
        _articleTitle('Article 2 — Conditions financières'),
        pw.SizedBox(height: 8),
        _infoBlock(null, [
          _row('Taux d\'intérêt nominal (annuel)', '${tauxNominal.toStringAsFixed(2)} %'),
          _row('TEG — Taux Effectif Global', teg > 0 ? '${teg.toStringAsFixed(2)} %' : 'Non calculé'),
          if (mensualite > 0)
            _row('Échéance périodique estimée', _fmtAmount(mensualite)),
          if (totalARembourser > 0)
            _row('Total à rembourser', _fmtAmount(totalARembourser)),
          if (produit?.tauxAssurance != null && produit!.tauxAssurance! > 0)
            _row('Taux d\'assurance', '${produit.tauxAssurance!.toStringAsFixed(2)} % / an'),
          if (produit?.fraisCommissions != null && produit!.fraisCommissions!.isNotEmpty)
            _row('Frais / Commissions', produit.fraisCommissions!),
        ]),
        pw.SizedBox(height: 16),

        // Article 3 — Engagements emprunteur
        _articleTitle('Article 3 — Engagements de l\'Emprunteur'),
        pw.SizedBox(height: 8),
        ..._bulletList([
          'Rembourser les échéances aux dates convenues.',
          'Informer l\'Institution de tout changement significatif de situation financière.',
          'Ne pas contracter de nouveaux emprunts susceptibles de compromettre le remboursement.',
          'Maintenir les garanties données en bon état pendant toute la durée du prêt.',
          'Autoriser l\'Institution à effectuer toute vérification jugée utile.',
        ]),
        pw.SizedBox(height: 16),

        // Article 4 — Garanties (Exigence 7.1)
        _articleTitle('Article 4 — Garanties'),
        pw.SizedBox(height: 8),
        _buildGuaranteesBlock(req, loan),
        pw.SizedBox(height: 16),

        // Article 5 — Pénalités
        _articleTitle('Article 5 — Pénalités de retard'),
        pw.SizedBox(height: 8),
        ..._bulletList([
          'En cas de retard de paiement au-delà de 3 jours ouvrables, une pénalité de 1 % '
          'du capital restant dû par jour de retard sera appliquée.',
          'L\'Institution se réserve le droit d\'exiger le remboursement anticipé intégral '
          'en cas de retard supérieur à 90 jours.',
        ]),
      ],
    );
  }


  // ---------------------------------------------------------------------------
  // Page 3+ — Tableau d'amortissement (Exigence 7.1)
  // ---------------------------------------------------------------------------

  pw.Page _buildAmortizationPage(
    Loan loan,
    List<RepaymentSchedule> schedule,
    InstitutionPdfBranding branding,
    String generatedAt,
  ) {
    return pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      footer: (ctx) => branding.buildFooter(generatedAt: generatedAt),
      build: (ctx) => [
        ...branding.buildHeader(),
        _divider(),
        pw.SizedBox(height: 8),
        _sectionTitle('ANNEXE — TABLEAU D\'AMORTISSEMENT'),
        pw.Text(
          'Prêt ${loan.numeroPret} — ${loan.client!.nomComplet} — '
          'Montant initial : ${_fmtAmount(loan.montantInitial)}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 12),
        _buildAmortizationTable(schedule),
        if (schedule.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          _buildAmortizationTotals(schedule),
        ],
      ],
    );
  }

  pw.Widget _buildAmortizationTable(List<RepaymentSchedule> schedule) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(26),   // N°
        1: const pw.FixedColumnWidth(58),   // Date prévue
        2: const pw.FlexColumnWidth(2),     // Capital
        3: const pw.FlexColumnWidth(2),     // Intérêts
        4: const pw.FlexColumnWidth(1.5),   // Frais
        5: const pw.FlexColumnWidth(2),     // Total dû
        6: const pw.FlexColumnWidth(2),     // Cap. restant
        7: const pw.FixedColumnWidth(46),   // Statut
      },
      children: [
        // En-tête
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
          children: [
            _amortCell('N°', isHeader: true),
            _amortCell('Date prévue', isHeader: true),
            _amortCell('Capital', isHeader: true, align: pw.TextAlign.right),
            _amortCell('Intérêts', isHeader: true, align: pw.TextAlign.right),
            _amortCell('Frais', isHeader: true, align: pw.TextAlign.right),
            _amortCell('Total dû', isHeader: true, align: pw.TextAlign.right),
            _amortCell('Cap. restant', isHeader: true, align: pw.TextAlign.right),
            _amortCell('Statut', isHeader: true),
          ],
        ),
        // Lignes données
        for (final row in schedule)
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: row.statut == RepaymentStatus.paye
                  ? PdfColors.green50
                  : row.statut == RepaymentStatus.impaye
                      ? PdfColors.red50
                      : null,
            ),
            children: [
              _amortCell('${row.numeroEcheance}'),
              _amortCell(_dateFmt.format(row.datePrevue)),
              _amortCell(_currencyFmt.format(row.capitalDu), align: pw.TextAlign.right),
              _amortCell(_currencyFmt.format(row.interetsDus), align: pw.TextAlign.right),
              _amortCell(_currencyFmt.format(row.fraisDus), align: pw.TextAlign.right),
              _amortCell(_currencyFmt.format(row.totalDu), align: pw.TextAlign.right),
              _amortCell(_currencyFmt.format(row.capitalRestant), align: pw.TextAlign.right),
              _amortCell(_statusLabel(row.statut)),
            ],
          ),
      ],
    );
  }

  pw.Widget _buildAmortizationTotals(List<RepaymentSchedule> schedule) {
    final totalCapital = schedule.fold(0.0, (s, r) => s + r.capitalDu);
    final totalInterets = schedule.fold(0.0, (s, r) => s + r.interetsDus);
    final totalFrais = schedule.fold(0.0, (s, r) => s + r.fraisDus);
    final totalDu = schedule.fold(0.0, (s, r) => s + r.totalDu);

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              'TOTAUX',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
          ),
          _totalCell(_currencyFmt.format(totalCapital)),
          _totalCell(_currencyFmt.format(totalInterets)),
          _totalCell(_currencyFmt.format(totalFrais)),
          _totalCell(_currencyFmt.format(totalDu)),
          pw.Expanded(flex: 4, child: pw.SizedBox()),
        ],
      ),
    );
  }


  // ---------------------------------------------------------------------------
  // Garanties block
  // ---------------------------------------------------------------------------

  pw.Widget _buildGuaranteesBlock(LoanRequest? req, Loan loan) {
    if (req == null) {
      return _paragraph('Garanties non disponibles (ancienne demande non liée).');
    }

    final items = <Map<String, String>>[];

    if (req.typeGarantie != null && req.typeGarantie!.isNotEmpty) {
      items.add({'label': 'Type de garantie', 'value': req.typeGarantie!});
    }
    if (req.descriptionGarantie != null && req.descriptionGarantie!.isNotEmpty) {
      items.add({'label': 'Désignation', 'value': req.descriptionGarantie!});
    }
    if (req.valeurGarantie != null && req.valeurGarantie! > 0) {
      items.add({'label': 'Valeur d\'expertise', 'value': _fmtAmount(req.valeurGarantie!)});
    }
    if (req.cautionPersonnelle != null && req.cautionPersonnelle!.isNotEmpty) {
      items.add({'label': 'Caution personnelle', 'value': req.cautionPersonnelle!});
    }
    if (loan.produit?.cautionSolidaireRequise == true) {
      items.add({'label': 'Caution solidaire', 'value': 'Requise'});
    }
    if (loan.produit?.garantieSurEquipement != null &&
        loan.produit!.garantieSurEquipement!.isNotEmpty) {
      items.add({'label': 'Garantie équipement', 'value': loan.produit!.garantieSurEquipement!});
    }

    if (items.isEmpty) {
      return _paragraph('Aucune garantie enregistrée pour ce dossier.');
    }

    return _infoBlock(null, items.map((m) => _row(m['label']!, m['value']!)).toList());
  }

  // ---------------------------------------------------------------------------
  // Small widget helpers
  // ---------------------------------------------------------------------------

  pw.Widget _divider() => pw.Divider(thickness: 1, color: PdfColors.blueGrey200);

  pw.Widget _sectionTitle(String text) => pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blueGrey800,
        ),
      );

  pw.Widget _articleTitle(String text) => pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blue900,
        ),
      );

  pw.Widget _paragraph(String text) => pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.4),
      );

  pw.Widget _centerText(String text) => pw.Center(
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey600,
          ),
        ),
      );

  pw.Widget _row(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 170,
              child: pw.Text(
                label,
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
            ),
            pw.Text(': ', style: const pw.TextStyle(fontSize: 9)),
            pw.Expanded(
              child: pw.Text(
                value,
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );

  pw.Widget _infoBlock(String? title, List<pw.Widget> rows) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey700,
              ),
            ),
            pw.SizedBox(height: 6),
          ],
          ...rows,
        ],
      ),
    );
  }

  List<pw.Widget> _bulletList(List<String> items) => items
      .map(
        (s) => pw.Padding(
          padding: const pw.EdgeInsets.only(left: 12, bottom: 4),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('• ', style: const pw.TextStyle(fontSize: 10)),
              pw.Expanded(
                child: pw.Text(s, style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.3)),
              ),
            ],
          ),
        ),
      )
      .toList();


  pw.Widget _signatureBlock({
    required String clientName,
    required String institutionName,
    required String dateStr,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'L\'Emprunteur (Lu et approuvé)',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            ),
            pw.SizedBox(height: 40),
            pw.Text(clientName, style: const pw.TextStyle(fontSize: 9)),
            pw.Text('Date : ____/____/________', style: const pw.TextStyle(fontSize: 9)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              institutionName,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            ),
            pw.SizedBox(height: 40),
            pw.Text('Cachet et signature', style: const pw.TextStyle(fontSize: 9)),
            pw.Text('Date : $dateStr', style: const pw.TextStyle(fontSize: 9)),
          ],
        ),
      ],
    );
  }

  pw.Widget _amortCell(
    String text, {
    bool isHeader = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        child: pw.Text(
          text,
          textAlign: align,
          style: pw.TextStyle(
            fontSize: 7,
            fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );

  pw.Widget _totalCell(String text) => pw.Expanded(
        flex: 2,
        child: pw.Text(
          text,
          textAlign: pw.TextAlign.right,
          style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
        ),
      );

  String _statusLabel(RepaymentStatus status) {
    switch (status) {
      case RepaymentStatus.paye:
        return 'Payé';
      case RepaymentStatus.impaye:
        return 'Impayé';
      case RepaymentStatus.partiel:
        return 'Partiel';
      case RepaymentStatus.enAttente:
        return 'Attente';
    }
  }
}
