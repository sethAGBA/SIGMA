// lib/core/services/custom_report_query_service.dart

import 'package:intl/intl.dart';
import 'database_service.dart';

/// Résultat d'un indicateur calculé.
class IndicatorResult {
  /// Clé technique (ex: 'outstanding_volume')
  final String key;

  /// Libellé affichable (ex: 'Volume Encours Crédit')
  final String label;

  /// Valeur principale (peut être null si aucune donnée)
  final double? value;

  /// Valeur secondaire optionnelle (ex: nombre de prêts pour disbursed_loans)
  final double? value2;

  /// Libellé de la valeur secondaire si présent
  final String? value2Label;

  /// Unité d'affichage (ex: 'FCFA', '%', 'clients')
  final String unit;

  const IndicatorResult({
    required this.key,
    required this.label,
    this.value,
    this.value2,
    this.value2Label,
    required this.unit,
  });

  /// Retourne la valeur formatée pour l'affichage.
  String get formattedValue {
    if (value == null) return '—';
    if (unit == '%') {
      return '${value!.toStringAsFixed(2)} %';
    }
    if (unit == 'FCFA') {
      return '${NumberFormat('#,##0', 'fr_FR').format(value!)} FCFA';
    }
    return NumberFormat('#,##0', 'fr_FR').format(value!);
  }

  /// Retourne la valeur secondaire formatée pour l'affichage.
  String? get formattedValue2 {
    if (value2 == null) return null;
    return NumberFormat('#,##0', 'fr_FR').format(value2!);
  }

  /// Convertit l'indicateur en ligne CSV.
  List<String> toCsvRow() {
    final row = <String>[label, formattedValue];
    if (value2 != null && value2Label != null) {
      row.add('$value2Label: ${formattedValue2!}');
    } else {
      row.add('');
    }
    return row;
  }
}

/// Indicateurs disponibles dans la whitelist du service.
enum ReportIndicator {
  outstandingVolume,
  par30,
  savingsCollected,
  activeClients,
  disbursedLoans,
  newClientsPeriod,
}

extension ReportIndicatorX on ReportIndicator {
  String get key {
    switch (this) {
      case ReportIndicator.outstandingVolume:
        return 'outstanding_volume';
      case ReportIndicator.par30:
        return 'par_30';
      case ReportIndicator.savingsCollected:
        return 'savings_collected';
      case ReportIndicator.activeClients:
        return 'active_clients';
      case ReportIndicator.disbursedLoans:
        return 'disbursed_loans';
      case ReportIndicator.newClientsPeriod:
        return 'new_clients_period';
    }
  }

  String get label {
    switch (this) {
      case ReportIndicator.outstandingVolume:
        return 'Volume Encours Crédit';
      case ReportIndicator.par30:
        return 'PAR 30 Jours (%)';
      case ReportIndicator.savingsCollected:
        return 'Épargne Collectée (Dépôts)';
      case ReportIndicator.activeClients:
        return 'Clients Actifs';
      case ReportIndicator.disbursedLoans:
        return 'Prêts Décaissés';
      case ReportIndicator.newClientsPeriod:
        return 'Nouveaux Clients (Période)';
    }
  }
}

/// Service de requêtes SQL paramétrées pour les rapports personnalisés.
///
/// Seuls les indicateurs figurant dans la whitelist [ReportIndicator] sont
/// exécutables — aucun SQL libre n'est accepté.
class CustomReportQueryService {
  final DatabaseService _db = DatabaseService();

  static const Map<String, String> indicatorLabels = {
    'outstanding_volume': 'Volume Encours Crédit',
    'par_30': 'PAR 30 Jours (%)',
    'savings_collected': 'Épargne Collectée (Dépôts)',
    'active_clients': 'Clients Actifs',
    'disbursed_loans': 'Prêts Décaissés',
    'new_clients_period': 'Nouveaux Clients (Période)',
  };

  /// Tous les indicateurs disponibles dans la whitelist.
  static List<ReportIndicator> get allIndicators => ReportIndicator.values;

  /// Exécute un indicateur unique et retourne ses résultats sous forme de
  /// [List<Map<String, dynamic>>] (colonnes + valeurs), adapté à l'affichage
  /// dans un [DataTable] ou à l'export CSV.
  ///
  /// [indicator] — indicateur à exécuter.
  /// [dateDebut] — date de début de période (optionnel).
  /// [dateFin] — date de fin de période (optionnel).
  /// [agenceId] — filtre par agence (optionnel).
  Future<List<Map<String, dynamic>>> runSingle(
    ReportIndicator indicator, {
    DateTime? dateDebut,
    DateTime? dateFin,
    String? agenceId,
  }) async {
    final result = await _compute(
      indicator.key,
      dateDebut: dateDebut,
      dateFin: dateFin,
      agenceId: agenceId,
    );
    if (result == null) return [];

    final row = <String, dynamic>{
      'Indicateur': result.label,
      'Valeur': result.formattedValue,
    };
    if (result.value2 != null && result.value2Label != null) {
      row[result.value2Label!] = result.formattedValue2 ?? '—';
    }
    return [row];
  }

  /// Exécute tous les indicateurs demandés avec les filtres optionnels.
  ///
  /// [indicators] — liste de clés issues de [indicatorLabels].
  /// [dateDebut] — date de début de période (optionnel).
  /// [dateFin] — date de fin de période (optionnel).
  /// [agenceId] — filtre par agence (optionnel).
  Future<List<IndicatorResult>> run({
    required List<String> indicators,
    DateTime? dateDebut,
    DateTime? dateFin,
    String? agenceId,
  }) async {
    final results = <IndicatorResult>[];
    for (final key in indicators) {
      final result = await _compute(
        key,
        dateDebut: dateDebut,
        dateFin: dateFin,
        agenceId: agenceId,
      );
      if (result != null) results.add(result);
    }
    return results;
  }

  Future<IndicatorResult?> _compute(
    String key, {
    DateTime? dateDebut,
    DateTime? dateFin,
    String? agenceId,
  }) async {
    switch (key) {
      case 'outstanding_volume':
        return _outstandingVolume(agenceId: agenceId);
      case 'par_30':
        return _par30(agenceId: agenceId);
      case 'savings_collected':
        return _savingsCollected(
          dateDebut: dateDebut,
          dateFin: dateFin,
          agenceId: agenceId,
        );
      case 'active_clients':
        return _activeClients(agenceId: agenceId);
      case 'disbursed_loans':
        return _disbursedLoans(
          dateDebut: dateDebut,
          dateFin: dateFin,
          agenceId: agenceId,
        );
      case 'new_clients_period':
        return _newClientsPeriod(
          dateDebut: dateDebut,
          dateFin: dateFin,
        );
      default:
        return null; // Clé inconnue : ignorée (whitelist stricte)
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Indicateur 1 — outstanding_volume
  // SELECT COALESCE(SUM(capital_restant), 0) FROM prets WHERE statut='Actif'
  // ──────────────────────────────────────────────────────────────────────────
  Future<IndicatorResult> _outstandingVolume({String? agenceId}) async {
    final db = await _db.database;

    final where = <String>["statut = 'Actif'"];
    final args = <dynamic>[];

    if (agenceId != null && agenceId.isNotEmpty) {
      where.add('agence_gestion = ?');
      args.add(agenceId);
    }

    final res = await db.rawQuery(
      '''SELECT COALESCE(SUM(solde_restant), 0) AS total
         FROM prets
         WHERE ${where.join(' AND ')}''',
      args.isEmpty ? null : args,
    );

    final total = (res.first['total'] as num?)?.toDouble() ?? 0.0;
    return IndicatorResult(
      key: 'outstanding_volume',
      label: indicatorLabels['outstanding_volume']!,
      value: total,
      unit: 'FCFA',
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Indicateur 2 — par_30
  // Calcul : capital à risque (retard > 30j) / encours total × 100
  // Basé sur la table `prets` (jours_retard est maintenu par refreshLoanDelinquencyStats)
  // ──────────────────────────────────────────────────────────────────────────
  Future<IndicatorResult> _par30({String? agenceId}) async {
    final db = await _db.database;

    final agenceFilter =
        (agenceId != null && agenceId.isNotEmpty) ? 'AND agence_gestion = ?' : '';
    final args = <dynamic>[];
    if (agenceId != null && agenceId.isNotEmpty) args.add(agenceId);

    // Capital à risque (prêts avec retard > 30 jours)
    final atRiskRes = await db.rawQuery(
      '''SELECT COALESCE(SUM(solde_restant), 0) AS at_risk
         FROM prets
         WHERE statut = 'Actif'
           AND jours_retard > 30
           $agenceFilter''',
      args.isEmpty ? null : args,
    );

    // Encours total actif
    final totalRes = await db.rawQuery(
      '''SELECT COALESCE(SUM(solde_restant), 0) AS total
         FROM prets
         WHERE statut = 'Actif'
           $agenceFilter''',
      args.isEmpty ? null : args,
    );

    final atRisk = (atRiskRes.first['at_risk'] as num?)?.toDouble() ?? 0.0;
    final total = (totalRes.first['total'] as num?)?.toDouble() ?? 0.0;
    final par = total > 0 ? (atRisk / total) * 100 : 0.0;

    return IndicatorResult(
      key: 'par_30',
      label: indicatorLabels['par_30']!,
      value: par,
      unit: '%',
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Indicateur 3 — savings_collected
  // SELECT COALESCE(SUM(montant), 0) FROM transactions_epargne WHERE type_operation='DEPOT'
  // ──────────────────────────────────────────────────────────────────────────
  Future<IndicatorResult> _savingsCollected({
    DateTime? dateDebut,
    DateTime? dateFin,
    String? agenceId,
  }) async {
    final db = await _db.database;

    final where = <String>["te.type_operation = 'depot'"];
    final args = <dynamic>[];

    if (dateDebut != null) {
      where.add('te.date_operation >= ?');
      args.add(dateDebut.toIso8601String().substring(0, 10));
    }
    if (dateFin != null) {
      where.add('te.date_operation <= ?');
      args.add(dateFin.toIso8601String().substring(0, 10));
    }

    // Filtre agence : non supporté en v1 (transactions_epargne n'a pas de agence_id direct).
    // Ignoré silencieusement.

    final res = await db.rawQuery(
      'SELECT COALESCE(SUM(te.montant), 0) AS total FROM transactions_epargne te WHERE ${where.join(' AND ')}',
      args.isEmpty ? null : args,
    );

    final total = (res.first['total'] as num?)?.toDouble() ?? 0.0;
    return IndicatorResult(
      key: 'savings_collected',
      label: indicatorLabels['savings_collected']!,
      value: total,
      unit: 'FCFA',
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Indicateur 4 — active_clients
  // SELECT COUNT(*) FROM clients WHERE statut='Actif'
  // ──────────────────────────────────────────────────────────────────────────
  Future<IndicatorResult> _activeClients({String? agenceId}) async {
    final db = await _db.database;

    // La table clients n'a pas de colonne agence_id directe.
    // Filtre agence ignoré pour cet indicateur (v1).
    final res = await db.rawQuery(
      "SELECT COUNT(*) AS total FROM clients WHERE statut = 'Actif'",
    );

    final total = (res.first['total'] as num?)?.toDouble() ?? 0.0;
    return IndicatorResult(
      key: 'active_clients',
      label: indicatorLabels['active_clients']!,
      value: total,
      unit: 'clients',
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Indicateur 5 — disbursed_loans
  // SELECT COUNT(*), COALESCE(SUM(montant), 0) FROM prets WHERE statut IN ('Actif','Soldé')
  // ──────────────────────────────────────────────────────────────────────────
  Future<IndicatorResult> _disbursedLoans({
    DateTime? dateDebut,
    DateTime? dateFin,
    String? agenceId,
  }) async {
    final db = await _db.database;

    final where = <String>["statut IN ('Actif', 'Soldé')"];
    final args = <dynamic>[];

    if (dateDebut != null) {
      where.add('date_deblocage >= ?');
      args.add(dateDebut.toIso8601String().substring(0, 10));
    }
    if (dateFin != null) {
      where.add('date_deblocage <= ?');
      args.add(dateFin.toIso8601String().substring(0, 10));
    }
    if (agenceId != null && agenceId.isNotEmpty) {
      where.add('agence_gestion = ?');
      args.add(agenceId);
    }

    final res = await db.rawQuery(
      'SELECT COUNT(*) AS nb, COALESCE(SUM(montant), 0) AS total FROM prets WHERE ${where.join(' AND ')}',
      args.isEmpty ? null : args,
    );

    final nb = (res.first['nb'] as num?)?.toDouble() ?? 0.0;
    final total = (res.first['total'] as num?)?.toDouble() ?? 0.0;

    return IndicatorResult(
      key: 'disbursed_loans',
      label: indicatorLabels['disbursed_loans']!,
      value: total,
      value2: nb,
      value2Label: 'Nombre de prêts',
      unit: 'FCFA',
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Indicateur 6 — new_clients_period
  // SELECT COUNT(*) FROM clients WHERE date_creation BETWEEN dateDebut AND dateFin
  // ──────────────────────────────────────────────────────────────────────────
  Future<IndicatorResult> _newClientsPeriod({
    DateTime? dateDebut,
    DateTime? dateFin,
  }) async {
    final db = await _db.database;

    final where = <String>[];
    final args = <dynamic>[];

    if (dateDebut != null) {
      where.add('date_creation >= ?');
      args.add(dateDebut.toIso8601String().substring(0, 10));
    }
    if (dateFin != null) {
      where.add('date_creation <= ?');
      args.add(dateFin.toIso8601String().substring(0, 10));
    }

    final whereClause =
        where.isNotEmpty ? 'WHERE ${where.join(' AND ')}' : '';

    final res = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM clients $whereClause',
      args.isEmpty ? null : args,
    );

    final total = (res.first['total'] as num?)?.toDouble() ?? 0.0;
    return IndicatorResult(
      key: 'new_clients_period',
      label: indicatorLabels['new_clients_period']!,
      value: total,
      unit: 'clients',
    );
  }
}
