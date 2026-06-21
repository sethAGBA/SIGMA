// lib/core/services/dashboard_api_service.dart
//
// Wrapper léger sur [ReportingApiService] — aucune logique réseau dupliquée.
//
// Toute la stratégie "Server is Truth" (online → PostgreSQL, offline → SQLite)
// est gérée par [ReportingApiService.getDashboardData()].

import '../../models/dashboard_data.dart';
import 'reporting_api_service.dart';

class DashboardApiService {
  static final DashboardApiService _instance = DashboardApiService._internal();
  factory DashboardApiService() => _instance;
  DashboardApiService._internal();

  // ── KPIs du dashboard ─────────────────────────────────────────────────

  /// Retourne les données consolidées du dashboard (KPIs, portefeuille,
  /// alertes, top agents).
  ///
  /// Délègue intégralement à [ReportingApiService.getDashboardData()] :
  /// - Online  : données fraîches depuis `/reporting/dashboard`
  /// - Offline : agrégats calculés depuis SQLite via [DatabaseService]
  Future<HomeDashboardData> getKpis() {
    return ReportingApiService().getDashboardData();
  }
}
