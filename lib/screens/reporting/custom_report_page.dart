// lib/screens/reporting/custom_report_page.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/services/custom_report_query_service.dart';
import '../../core/services/database_service.dart';
import '../../core/services/institution_pdf_branding.dart';
import '../../core/theme/app_colors.dart';

/// Page de génération de rapports dynamiques avec indicateurs SQL prédéfinis.
///
/// Exigences 4.1 et 4.2 :
/// - Exécute des requêtes SQL paramétrées depuis [CustomReportQueryService]
/// - Résultats affichés dans un [DataTable]
/// - Export CSV dans `{appDocDir}/exports/rapports/`
class CustomReportPage extends StatefulWidget {
  const CustomReportPage({super.key});

  @override
  State<CustomReportPage> createState() => _CustomReportPageState();
}

class _CustomReportPageState extends State<CustomReportPage> {
  final _service = CustomReportQueryService();
  final _dateFmt = DateFormat('dd/MM/yyyy');
  final _fileDateFmt = DateFormat('yyyyMMdd_HHmmss');

  /// Indicateur sélectionné dans le dropdown.
  ReportIndicator _selectedIndicator = ReportIndicator.outstandingVolume;

  DateTime? _dateDebut;
  DateTime? _dateFin;

  bool _loading = false;
  String? _errorMessage;

  /// Résultats de la dernière exécution.
  List<Map<String, dynamic>> _results = [];

  /// Colonnes extraites des résultats.
  List<String> get _columns {
    if (_results.isEmpty) return [];
    return _results.first.keys.toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 680),
        child: Column(
          children: [
            _buildHeader(context),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFilters(context, isDark),
                    const SizedBox(height: 24),
                    _buildGenerateButton(context),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      _buildError(),
                    ],
                    if (_results.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildResultsSection(context),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── En-tête ──────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Rapport Personnalisé',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            tooltip: 'Fermer',
          ),
        ],
      ),
    );
  }

  // ─── Filtres ──────────────────────────────────────────────────────────────

  Widget _buildFilters(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Paramètres du rapport',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 16),

        // Dropdown indicateur
        DropdownButtonFormField<ReportIndicator>(
          initialValue: _selectedIndicator,
          decoration: const InputDecoration(
            labelText: 'Indicateur',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.bar_chart_rounded),
          ),
          items: ReportIndicator.values.map((ind) {
            return DropdownMenuItem(
              value: ind,
              child: Text(ind.label),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedIndicator = value;
                _results = [];
                _errorMessage = null;
              });
            }
          },
        ),

        const SizedBox(height: 16),

        // Filtres dates en ligne
        Row(
          children: [
            Expanded(
              child: _DatePickerField(
                label: 'Date début (optionnel)',
                value: _dateDebut,
                onChanged: (d) => setState(() {
                  _dateDebut = d;
                  _results = [];
                }),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _DatePickerField(
                label: 'Date fin (optionnel)',
                value: _dateFin,
                onChanged: (d) => setState(() {
                  _dateFin = d;
                  _results = [];
                }),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Bouton Générer ───────────────────────────────────────────────────────

  Widget _buildGenerateButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _loading ? null : _generateReport,
        icon: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.play_arrow_rounded),
        label: Text(_loading ? 'Calcul en cours…' : 'Générer'),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // ─── Message d'erreur ─────────────────────────────────────────────────────

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Section résultats ────────────────────────────────────────────────────

  Widget _buildResultsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Résultats',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _exportCsv,
                  icon: const Icon(Icons.table_chart_outlined, size: 18),
                  label: const Text('Exporter CSV'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _exportPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text('Exporter PDF'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildDataTable(),
      ],
    );
  }

  Widget _buildDataTable() {
    if (_columns.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        border: TableBorder.all(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(8),
        ),
        headingRowColor: WidgetStateProperty.resolveWith(
          (_) => AppColors.primary.withValues(alpha: 0.08),
        ),
        columns: _columns
            .map(
              (col) => DataColumn(
                label: Text(
                  col,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            )
            .toList(),
        rows: _results.map((row) {
          return DataRow(
            cells: _columns
                .map((col) => DataCell(Text('${row[col] ?? '—'}')))
                .toList(),
          );
        }).toList(),
      ),
    );
  }

  // ─── Actions ──────────────────────────────────────────────────────────────

  Future<void> _generateReport() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
      _results = [];
    });

    try {
      final rows = await _service.runSingle(
        _selectedIndicator,
        dateDebut: _dateDebut,
        dateFin: _dateFin,
      );
      setState(() => _results = rows);
    } catch (e) {
      setState(() => _errorMessage = 'Erreur lors du calcul : $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _exportCsv() async {
    if (_results.isEmpty || _columns.isEmpty) return;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final exportsDir = Directory('${dir.path}/exports/rapports');
      if (!await exportsDir.exists()) {
        await exportsDir.create(recursive: true);
      }

      final buffer = StringBuffer();

      // En-tête CSV
      buffer.writeln('Rapport SIGMA — ${_selectedIndicator.label}');
      if (_dateDebut != null || _dateFin != null) {
        final debut = _dateDebut != null ? _dateFmt.format(_dateDebut!) : 'début';
        final fin = _dateFin != null ? _dateFmt.format(_dateFin!) : 'fin';
        buffer.writeln('Période;$debut — $fin');
      }
      buffer.writeln('Date export;${_dateFmt.format(DateTime.now())}');
      buffer.writeln();

      // Colonnes
      buffer.writeln(_columns.map(_escapeCsv).join(';'));

      // Lignes
      for (final row in _results) {
        buffer.writeln(_columns.map((col) => _escapeCsv('${row[col] ?? ''}')).join(';'));
      }

      final fileName =
          'rapport_${_selectedIndicator.key}_${_fileDateFmt.format(DateTime.now())}.csv';
      final file = File('${exportsDir.path}/$fileName');
      await file.writeAsBytes(utf8.encode('\uFEFF${buffer.toString()}'));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV exporté : ${file.path}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur export CSV : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _escapeCsv(String value) {
    if (value.contains(';') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  Future<void> _exportPdf() async {
    if (_results.isEmpty || _columns.isEmpty) return;

    try {
      // Branding institution
      final legal = await DatabaseService().getLegalInformation();
      final periodDebut = _dateDebut != null ? _dateFmt.format(_dateDebut!) : null;
      final periodFin = _dateFin != null ? _dateFmt.format(_dateFin!) : null;
      final subtitle = (periodDebut != null || periodFin != null)
          ? 'Période : ${periodDebut ?? 'début'} — ${periodFin ?? 'fin'}'
          : null;

      final branding = InstitutionPdfBranding(
        legal: legal,
        documentTitle: _selectedIndicator.label,
        subtitle: subtitle,
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
          build: (_) => [
            _buildPdfTable(),
          ],
        ),
      );

      final bytes = await pdf.save();

      // Sauvegarde dans {appDocDir}/exports/rapports/
      final dir = await getApplicationDocumentsDirectory();
      final exportsDir = Directory('${dir.path}/exports/rapports');
      if (!await exportsDir.exists()) {
        await exportsDir.create(recursive: true);
      }

      final fileName =
          'rapport_${_selectedIndicator.key}_${_fileDateFmt.format(DateTime.now())}.pdf';
      final file = File('${exportsDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF exporté : ${file.path}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur export PDF : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  pw.Widget _buildPdfTable() {
    const headerStyle = pw.TextStyle(
      fontSize: 9,
      color: PdfColors.white,
    );
    const cellStyle = pw.TextStyle(fontSize: 9);

    final headerRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
      children: _columns
          .map(
            (col) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: pw.Text(col, style: headerStyle),
            ),
          )
          .toList(),
    );

    final dataRows = _results.map((row) {
      return pw.TableRow(
        children: _columns.map((col) {
          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: pw.Text('${row[col] ?? '—'}', style: cellStyle),
          );
        }).toList(),
      );
    }).toList();

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.blueGrey100),
      children: [headerRow, ...dataRows],
    );
  }
}

// ─── Widget date picker réutilisable ──────────────────────────────────────────

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2015),
          lastDate: DateTime(2100),
        );
        if (picked != null) onChanged(picked);
      },
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: value != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  tooltip: 'Effacer',
                  onPressed: () => onChanged(null),
                )
              : const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(
          value != null ? fmt.format(value!) : 'Non défini',
          style: TextStyle(
            color: value != null
                ? Theme.of(context).textTheme.bodyMedium?.color
                : Colors.grey,
          ),
        ),
      ),
    );
  }
}
