// lib/models/reporting_result.dart

/// Résultat générique d'une lecture de données de reporting.
///
/// [isOfflineFallback] est `false` **uniquement** si les données proviennent
/// d'une réponse HTTP 2xx valide du serveur. Dans tous les autres cas
/// (serveur indisponible, exception réseau, réponse null, méthodes
/// local-only comme `getRecoveryStats`), [isOfflineFallback] est `true`.
class ReportingResult<T> {
  final T data;

  /// `false` uniquement si les données viennent du serveur (HTTP 2xx valide).
  /// `true` dans tous les autres cas (offline, exception, null, local-only).
  final bool isOfflineFallback;

  const ReportingResult({
    required this.data,
    required this.isOfflineFallback,
  });
}
