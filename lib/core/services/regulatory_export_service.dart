import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/plan_comptable_type.dart';
import '../../models/trial_balance_model.dart';
import 'database_service.dart';

/// Exports réglementaires (balance SYSCOHADA/RCSSFD, futurs exports BCEAO).
class RegulatoryExportService {
  final DatabaseService _db = DatabaseService();
  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _fileDateFormat = DateFormat('yyyyMMdd_HHmmss');

  /// Exporte la balance générale au format CSV (séparateur `;`, UTF-8 BOM)
  /// compatible Excel français et auditeurs externes.
  Future<String> exportTrialBalanceCsv({
    required TrialBalance balance,
    DateTime? dateDebut,
    DateTime? dateFin,
    PlanComptableType? planType,
  }) async {
    final legal = await _db.getLegalInformation();
    final plan = planType ?? await _db.getPlanComptableType();
    final periodLabel = _buildPeriodLabel(dateDebut, dateFin);

    final buffer = StringBuffer();
    buffer.writeln(
      'SIGMA Micro-Finance — Balance Générale (${plan.label})',
    );
    buffer.writeln('Institution;${legal.raisonSociale}');
    buffer.writeln('N° agrément;${legal.numeroAgrement}');
    buffer.writeln('IFU;${legal.numeroFiscal}');
    buffer.writeln('Période;$periodLabel');
    buffer.writeln('Date export;${_dateFormat.format(DateTime.now())}');
    buffer.writeln();
    buffer.writeln(
      'N° Compte;Libellé;Total Débit;Total Crédit;Solde Débiteur;Solde Créditeur',
    );

    for (final entry in balance.entries) {
      buffer.writeln(
        '${entry.compteNumero};'
        '${_escapeCsv(entry.compteLibelle)};'
        '${_formatAmount(entry.totalDebit)};'
        '${_formatAmount(entry.totalCredit)};'
        '${_formatAmount(entry.soldeDebiteur)};'
        '${_formatAmount(entry.soldeCrediteur)}',
      );
    }

    buffer.writeln();
    buffer.writeln(
      'TOTAUX;;'
      '${_formatAmount(balance.totalDebits)};'
      '${_formatAmount(balance.totalCredits)};'
      '${_formatAmount(balance.totalSoldesDebiteurs)};'
      '${_formatAmount(balance.totalSoldesCrediteurs)}',
    );

    final dir = await getApplicationDocumentsDirectory();
    final exportsDir = Directory('${dir.path}/exports');
    if (!await exportsDir.exists()) {
      await exportsDir.create(recursive: true);
    }

    final fileName =
        'balance_${plan.key}_${_fileDateFormat.format(DateTime.now())}.csv';
    final file = File('${exportsDir.path}/$fileName');
    final bytes = utf8.encode('\uFEFF${buffer.toString()}');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  String _buildPeriodLabel(DateTime? debut, DateTime? fin) {
    if (debut == null && fin == null) return 'Toutes périodes';
    if (debut != null && fin != null) {
      return '${_dateFormat.format(debut)} — ${_dateFormat.format(fin)}';
    }
    if (debut != null) return 'À partir du ${_dateFormat.format(debut)}';
    return 'Jusqu\'au ${_dateFormat.format(fin!)}';
  }

  String _formatAmount(double value) =>
      value.toStringAsFixed(0).replaceAll('.', ',');

  String _escapeCsv(String value) =>
      value.contains(';') ? '"${value.replaceAll('"', '""')}"' : value;
}
