// lib/core/services/pdf_export_service.dart

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/loan_request_model.dart';
import '../../models/par_stats_model.dart';
import '../../models/reporting/monthly_report_model.dart';
import '../../models/repayment_schedule_model.dart';
import '../../core/utils/loan_calculator.dart';
import 'database_service.dart';
import 'institution_pdf_branding.dart';

class PdfExportService {
  final currencyFormat = NumberFormat.currency(
    symbol: 'FCFA',
    decimalDigits: 0,
    locale: 'fr_FR',
  );
  final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  Future<pw.Document> buildLoanContractPdf(LoanRequest request) async {
    final client = request.client;
    final produit = request.produit;
    final clientName = client?.nomComplet ?? 'Client #${request.clientId}';
    final produitName = produit?.nom ?? 'Produit #${request.produitId}';
    final tauxNominal = produit?.tauxInteret ?? 0;
    final dateStr = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final legal = await DatabaseService().getLegalInformation();
    final branding = InstitutionPdfBranding(
      legal: legal,
      documentTitle: 'CONTRAT DE PRÊT',
      subtitle: 'Date : $dateStr',
    );

    // Fetch real schedule if loan exists, otherwise calculate from parameters
    List<RepaymentSchedule> dbSchedule = [];
    if (request.id != null) {
      final loan = await DatabaseService().getLoanByRequestId(request.id!);
      if (loan != null) {
        dbSchedule = await DatabaseService().getRepaymentSchedules(loan.id!);
      }
    }

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            ...branding.buildHeader(),
            pw.Text(
              'Entre ${legal.raisonSociale.isNotEmpty ? legal.raisonSociale : "l\'Institution"}, '
              'ci-après dénommée « l\'Institution », '
              'et $clientName, ci-après dénommé(e) « l\'Emprunteur », '
              'il est convenu ce qui suit :',
              style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.4),
            ),
            pw.SizedBox(height: 20),
            _buildContractSection('Article 1 — Objet du prêt', [
              'Produit : $produitName',
              'Objet : ${request.objetPret}',
              'Montant accordé : ${currencyFormat.format(request.montantDemande)}',
              'Durée : ${request.dureeMois} mois',
              'Fréquence de remboursement : ${request.frequenceRemboursement.label}',
            ]),
            pw.SizedBox(height: 16),
            _buildContractSection('Article 2 — Conditions financières', [
              'Taux d\'intérêt nominal : ${tauxNominal.toStringAsFixed(2)} %/an',
              'TEG (Taux Effectif Global) : ${request.teg.toStringAsFixed(2)} %/an',
              'Mensualité estimée : ${currencyFormat.format(request.mensualite)}',
              'Total à rembourser : ${currencyFormat.format(request.totalARembourser)}',
              if (request.moisDiffereCapital > 0)
                'Différé de capital : ${request.moisDiffereCapital} mois',
            ]),
            pw.SizedBox(height: 16),
            _buildContractSection('Article 3 — Engagements de l\'Emprunteur', [
              'Rembourser les échéances aux dates convenues.',
              'Informer l\'Institution de tout changement significatif de situation.',
              'Respecter les garanties et conditions du produit sélectionné.',
            ]),
            pw.SizedBox(height: 16),
            // Article 4 — Garanties
            _buildGuaranteesSection(request),
            pw.SizedBox(height: 20),
            // Table d'amortissement
            _buildAmortizationTable(request, dbSchedule),
            pw.SizedBox(height: 40),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'L\'Emprunteur',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 40),
                    pw.Text(clientName),
                    pw.Text('Date : ____/____/________'),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      legal.raisonSociale.isNotEmpty
                          ? legal.raisonSociale
                          : 'SIGMA Micro-Finance',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 40),
                    pw.Text('Cachet et signature'),
                    pw.Text('Date : $dateStr'),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );
    return pdf;
  }

  Future<void> exportLoanContract(LoanRequest request) async {
    final client = request.client;
    final pdf = await buildLoanContractPdf(request);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name:
          'Contrat_Pret_${client?.nom ?? request.clientId}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  pw.Widget _buildGuaranteesSection(LoanRequest request) {
    final List<String> lines = [];

    if (request.typeGarantie != null && request.typeGarantie!.isNotEmpty) {
      lines.add('Type de garantie : ${request.typeGarantie}');
    }
    if (request.descriptionGarantie != null &&
        request.descriptionGarantie!.isNotEmpty) {
      lines.add('Désignation : ${request.descriptionGarantie}');
    }
    if (request.valeurGarantie != null && request.valeurGarantie! > 0) {
      lines.add(
          'Valeur d\'expertise : ${currencyFormat.format(request.valeurGarantie!)}');
    }
    if (request.cautionPersonnelle != null &&
        request.cautionPersonnelle!.isNotEmpty) {
      lines.add('Caution personnelle : ${request.cautionPersonnelle}');
    }
    if (lines.isEmpty) {
      lines.add('Aucune garantie enregistrée pour ce dossier.');
    }

    return _buildContractSection('Article 4 — Garanties', lines);
  }

  pw.Widget _buildAmortizationTable(
    LoanRequest request,
    List<RepaymentSchedule> dbSchedule,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Annexe — Table d\'amortissement',
          style:
              pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          columnWidths: {
            0: const pw.FixedColumnWidth(28),
            1: const pw.FixedColumnWidth(60),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(2),
            4: const pw.FlexColumnWidth(2),
            5: const pw.FlexColumnWidth(2),
          },
          children: [
            // Header row
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey100),
              children: [
                _buildAmortCell('N°', isHeader: true),
                _buildAmortCell('Date prévue', isHeader: true),
                _buildAmortCell('Capital', isHeader: true,
                    align: pw.TextAlign.right),
                _buildAmortCell('Intérêts', isHeader: true,
                    align: pw.TextAlign.right),
                _buildAmortCell('Total dû', isHeader: true,
                    align: pw.TextAlign.right),
                _buildAmortCell('Cap. restant', isHeader: true,
                    align: pw.TextAlign.right),
              ],
            ),
            // Data rows from DB schedule if available, else compute
            if (dbSchedule.isNotEmpty)
              ...dbSchedule.map(
                (s) => pw.TableRow(
                  children: [
                    _buildAmortCell('${s.numeroEcheance}'),
                    _buildAmortCell(
                        DateFormat('dd/MM/yyyy').format(s.datePrevue)),
                    _buildAmortCell(
                        _formatPdfAmount(s.capitalDu),
                        align: pw.TextAlign.right),
                    _buildAmortCell(
                        _formatPdfAmount(s.interetsDus),
                        align: pw.TextAlign.right),
                    _buildAmortCell(
                        _formatPdfAmount(s.totalDu),
                        align: pw.TextAlign.right),
                    _buildAmortCell(
                        _formatPdfAmount(s.capitalRestant),
                        align: pw.TextAlign.right),
                  ],
                ),
              )
            else
              ..._buildCalculatedRows(request),
          ],
        ),
      ],
    );
  }

  List<pw.TableRow> _buildCalculatedRows(LoanRequest request) {
    final rows = LoanCalculator.calculerEcheancierAvecDiffere(
      montant: request.montantDemande,
      duree: request.dureeMois,
      tauxAnnuel: request.produit?.tauxInteret ?? 0,
      moisDiffere: request.moisDiffereCapital,
    );

    double capitalRestant = request.montantDemande;
    final startDate = DateTime.now();
    final tableRows = <pw.TableRow>[];

    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      final capital = row['capital_du'] ?? 0;
      capitalRestant = (capitalRestant - capital).clamp(0, double.infinity);
      final echeanceDate =
          DateTime(startDate.year, startDate.month + i + 1, startDate.day);
      tableRows.add(
        pw.TableRow(
          children: [
            _buildAmortCell('${i + 1}'),
            _buildAmortCell(DateFormat('dd/MM/yyyy').format(echeanceDate)),
            _buildAmortCell(_formatPdfAmount(capital),
                align: pw.TextAlign.right),
            _buildAmortCell(
                _formatPdfAmount(row['interets_dus'] ?? 0),
                align: pw.TextAlign.right),
            _buildAmortCell(
                _formatPdfAmount(row['total_du'] ?? 0),
                align: pw.TextAlign.right),
            _buildAmortCell(_formatPdfAmount(capitalRestant),
                align: pw.TextAlign.right),
          ],
        ),
      );
    }
    return tableRows;
  }

  pw.Widget _buildAmortCell(
    String text, {
    bool isHeader = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight:
              isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  String _formatPdfAmount(double amount) {
    return NumberFormat('#,##0', 'fr_FR').format(amount);
  }

  pw.Widget _buildContractSection(String title, List<String> lines) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        ...lines.map(
          (line) => pw.Padding(
            padding: const pw.EdgeInsets.only(left: 12, bottom: 4),
            child: pw.Text('• $line', style: const pw.TextStyle(fontSize: 10)),
          ),
        ),
      ],
    );
  }

  Future<void> exportPARDashboard(PARStats stats) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildHeader(stats),
            pw.SizedBox(height: 24),
            _buildInfoBanner(),
            pw.SizedBox(height: 32),
            _buildKeyMetrics(stats),
            pw.SizedBox(height: 32),
            _buildClassificationTable(stats),
            pw.SizedBox(height: 48),
            _buildFooter(),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Rapport_PAR_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  Future<void> exportMonthlyActivityReport(MonthlyReportStats stats) async {
    final pdf = pw.Document();
    final monthLabel = DateFormat('MMMM yyyy', 'fr_FR').format(stats.month);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildMonthlyHeader(monthLabel),
            pw.SizedBox(height: 24),
            _buildMonthlySection('I. SYNTHÈSE EXÉCUTIVE', [
              'Encours total: ${currencyFormat.format(stats.encoursTotal)} (+${stats.encoursVariation}%)',
              'PAR 30: ${stats.par30Rate.toStringAsFixed(1)}% (objectif < 3%)',
              'Taux remboursement: ${stats.repaymentRate.toStringAsFixed(1)}%',
              'Nouveaux clients: ${stats.newClientsCount}',
              'Résultat net: ${currencyFormat.format(stats.netIncome)}',
            ]),
            pw.SizedBox(height: 20),
            _buildMonthlySection('II. ACTIVITÉ CRÉDIT', [
              'Demandes reçues: ${stats.loanRequestsReceived}',
              'Prêts approuvés: ${stats.loansApproved} (${stats.approvalRate.toStringAsFixed(0)}%)',
              'Montant décaissé: ${currencyFormat.format(stats.disbursedAmount)}',
              'Montant remboursé: ${currencyFormat.format(stats.repaidAmount)}',
              'Encours fin mois: ${currencyFormat.format(stats.encoursTotal)}',
            ]),
            pw.SizedBox(height: 20),
            _buildMonthlySection('III. QUALITÉ DU PORTEFEUILLE', [
              'PAR 1-30j: ${stats.par1_30Rate.toStringAsFixed(1)}% (stable)',
              'PAR 31-90j: ${stats.par31_90Rate.toStringAsFixed(1)}% (-0,3%)',
              'PAR > 90j: ${stats.par90PlusRate.toStringAsFixed(1)}% (-0,1%)',
              'Créances passées en perte: ${currencyFormat.format(stats.writeOffAmount)}',
            ]),
            pw.SizedBox(height: 20),
            _buildMonthlySection('IV. ÉPARGNE', [
              'Solde épargne: ${currencyFormat.format(stats.totalSavings)} (+${stats.savingsGrowth}M)',
              'Nouveaux comptes: ${stats.newAccountsCount}',
              'Ratio épargne/crédit: ${stats.savingsCreditRatio.toStringAsFixed(1)}%',
            ]),
            pw.SizedBox(height: 20),
            _buildMonthlySection('V. PERFORMANCE FINANCIÈRE', [
              'Produits financiers: ${currencyFormat.format(stats.financialProductsIncome)}',
              'Charges d\'exploitation: ${currencyFormat.format(stats.operatingExpenses)}',
              'Résultat net: ${currencyFormat.format(stats.netIncome)}',
              'ROA: ${stats.roa.toStringAsFixed(1)}% | ROE: ${stats.roe.toStringAsFixed(1)}%',
            ]),
            pw.SizedBox(height: 48),
            _buildFooter(),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Rapport_Mensuel_${DateFormat('yyyyMM').format(stats.month)}.pdf',
    );
  }

  pw.Widget _buildMonthlyHeader(String monthLabel) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'RAPPORT MENSUEL D\'ACTIVITÉ - $monthLabel',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Divider(thickness: 2, color: PdfColors.blue900),
      ],
    );
  }

  pw.Widget _buildMonthlySection(String title, List<String> bulletPoints) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 8),
        ...bulletPoints.map(
          (text) => pw.Padding(
            padding: const pw.EdgeInsets.only(left: 12, bottom: 4),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('• ', style: const pw.TextStyle(fontSize: 10)),
                pw.Expanded(
                  child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildHeader(PARStats stats) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'SIGMA MICRO-FINANCE',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
            pw.Text('Système d\'Information et de Gestion'),
            pw.SizedBox(height: 8),
            pw.Text(
              'RAPPORT DE QUALITE DU PORTEFEUILLE (PAR)',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey700,
              ),
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'Date du rapport: ${dateFormat.format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.Text(
              'Statut: Officiel',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.green),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildInfoBanner() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.blueGrey100),
      ),
      child: pw.Text(
        'Ce rapport présente l\'état de dégradation du portefeuille de crédits classé par ancienneté de retard. Le PAR (Portfolio At Risk) est calculé sur le capital restant dû conformément aux normes prudentielles.',
        style: const pw.TextStyle(fontSize: 9, lineSpacing: 1.5),
      ),
    );
  }

  pw.Widget _buildKeyMetrics(PARStats stats) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'INDICATEURS CLÉS',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          children: [
            _buildMetricBox(
              'Encours Brut Total',
              currencyFormat.format(stats.encoursTotal),
              PdfColors.blue900,
            ),
            _buildMetricBox(
              'Pénalités Dues',
              currencyFormat.format(stats.penalitesDues),
              PdfColors.orange900,
            ),
            _buildMetricBox(
              'PAR 30 Jours',
              '${stats.tauxPAR30.toStringAsFixed(2)}%',
              PdfColors.deepOrange900,
            ),
            _buildMetricBox(
              'Taux de Couverture',
              '${stats.tauxCouverture.toStringAsFixed(1)}%',
              PdfColors.green900,
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildMetricBox(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.symmetric(horizontal: 4),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          children: [
            pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildClassificationTable(PARStats stats) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'CLASSIFICATION DES CRÉDITS PAR ANCIENNETÉ DE RETARD',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(1),
          },
          children: [
            _buildTableHeader(),
            _buildTableRow(
              'Crédits Sains (0 jour)',
              stats.nbSains,
              stats.parSains,
              (stats.parSains / stats.encoursTotal * 100),
            ),
            _buildTableRow(
              'Sous Surveillance (1-30j)',
              stats.nb1,
              stats.par1,
              stats.tauxPAR1,
            ),
            _buildTableRow(
              'En Retard (31-90j)',
              stats.nb30,
              stats.par30,
              stats.tauxPAR30,
            ),
            _buildTableRow(
              'Douteux (91-180j)',
              stats.nb90,
              stats.par90,
              stats.tauxPAR90,
            ),
            _buildTableRow(
              'Compromis (> 180j)',
              stats.nb180,
              stats.par180,
              stats.tauxPAR180,
            ),
            _buildTableFooter(stats),
          ],
        ),

        pw.SizedBox(height: 30),
        _buildSegmentedAnalysisPDF(stats, currencyFormat),
      ],
    );
  }

  pw.TableRow _buildTableHeader() {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
      children: [
        _buildTableCell('Catégorie de Risque', isHeader: true),
        _buildTableCell('Nb Prêts', isHeader: true),
        _buildTableCell('Capital Restant Dû', isHeader: true),
        _buildTableCell('% Port.', isHeader: true),
      ],
    );
  }

  pw.TableRow _buildTableRow(
    String label,
    int count,
    double amount,
    double percentage,
  ) {
    return pw.TableRow(
      children: [
        _buildTableCell(label),
        _buildTableCell(count.toString(), align: pw.TextAlign.center),
        _buildTableCell(
          currencyFormat.format(amount),
          align: pw.TextAlign.right,
        ),
        _buildTableCell(
          '${percentage.toStringAsFixed(2)}%',
          align: pw.TextAlign.right,
        ),
      ],
    );
  }

  pw.TableRow _buildTableFooter(PARStats stats) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
      children: [
        _buildTableCell('TOTAL PORTEFEUILLE ACTIF', isHeader: true),
        _buildTableCell(
          stats.totalPrets.toString(),
          isHeader: true,
          align: pw.TextAlign.center,
        ),
        _buildTableCell(
          currencyFormat.format(stats.encoursTotal),
          isHeader: true,
          align: pw.TextAlign.right,
        ),
        _buildTableCell('100.00%', isHeader: true, align: pw.TextAlign.right),
      ],
    );
  }

  pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _buildFooter() {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'SIGMA Finance - Rapport de gestion interne',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
            pw.Text(
              'Document généré par le système - Page 1/1',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildSegmentedAnalysisPDF(PARStats stats, NumberFormat format) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Analyse PAR par segment (>30j):',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
        ),
        pw.SizedBox(height: 15),
        pw.Wrap(
          spacing: 20,
          runSpacing: 15,
          children: [
            _buildSegmentPDFTable('Par Agence', stats.parParAgence, format),
            _buildSegmentPDFTable('Par Produit', stats.parParProduit, format),
            _buildSegmentPDFTable('Par Secteur', stats.parParSecteur, format),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildSegmentPDFTable(
    String title,
    Map<String, double> data,
    NumberFormat format,
  ) {
    if (data.isEmpty) return pw.SizedBox();

    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return pw.Container(
      width: 160,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          ),
          pw.SizedBox(height: 10),
          ...sorted
              .take(4)
              .map(
                (e) => pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      e.key.length > 20
                          ? e.key.substring(0, 17) + '...'
                          : e.key,
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.Text(
                      format.format(e.value),
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
