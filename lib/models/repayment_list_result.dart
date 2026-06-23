// lib/models/repayment_list_result.dart

import 'repayment_schedule_model.dart';

/// Résultat d'une lecture de liste d'échéances.
///
/// [isIncomplete] est `true` quand les données sont potentiellement
/// incomplètes, c'est-à-dire quand le serveur est indisponible et que
/// le cache SQLite local ne contenait aucune donnée.
class RepaymentListResult {
  final List<RepaymentSchedule> items;

  /// `true` si les données sont incomplètes (offline + cache vide).
  final bool isIncomplete;

  const RepaymentListResult({
    required this.items,
    required this.isIncomplete,
  });
}
