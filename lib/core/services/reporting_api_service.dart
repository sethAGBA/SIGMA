// lib/core/services/reporting_api_service.dart
//
// Stratégie "Server is Truth" :
//
// LECTURE connecté  → PostgreSQL (données partagées tous les postes)
//                   → Retourne directement les données serveur (agrégats calculés)
// LECTURE offline   → SQLite local (agrégats calculés localement via DatabaseService)

import 'package:flutter/material.dart';

import '../../models/dashboard_data.dart';
import '../../models/par_stats_model.dart';
import 'api_service.dart';
import 'database_service.dart';
import 'sync_service.dart';

class ReportingApiService {
  static final ReportingApiService _instance = ReportingApiService._internal();
  factory ReportingApiService() => _instance;
  ReportingApiService._internal();

  // ── Dashboard data ────────────────────────────────────────────────────

  /// Retourne les données du dashboard (KPIs, portefeuille, alertes, top agents).
  ///
  /// Online  : récupère depuis `/reporting/dashboard`.
  /// Offline : calcule les agrégats depuis SQLite via [DatabaseService].
  Future<HomeDashboardData> getDashboardData() async {
    if (await SyncService().isOnline) {
      try {
        final response = await ApiService().get('/reporting/dashboard');
        final data = ApiService.decodeResponse(response);
        if (data != null && data is Map<String, dynamic>) {
          return _parseDashboardData(data);
        }
      } catch (_) {
        // Fallback silencieux vers SQLite
      }
    }
    // OFFLINE ou fallback → calcul local depuis SQLite
    return DatabaseService().getHomeDashboardData();
  }

  // ── PAR stats ─────────────────────────────────────────────────────────

  /// Retourne les statistiques Portfolio At Risk (PAR).
  ///
  /// Online  : récupère depuis `/reporting/par`.
  /// Offline : calcule depuis SQLite via [DatabaseService.getPARStats()].
  Future<PARStats> getParStats() async {
    if (await SyncService().isOnline) {
      try {
        final response = await ApiService().get('/reporting/par');
        final data = ApiService.decodeResponse(response);
        if (data != null && data is Map<String, dynamic>) {
          return _parsePARStats(data);
        }
      } catch (_) {
        // Fallback silencieux vers SQLite
      }
    }
    // OFFLINE ou fallback → calcul local depuis SQLite
    return DatabaseService().getPARStats();
  }

  // ── Parseurs de réponse serveur ───────────────────────────────────────

  /// Convertit la réponse JSON `/reporting/dashboard` en [HomeDashboardData].
  ///
  /// Les champs [DashboardKPI.icon] et [DashboardKPI.color] ne peuvent pas être
  /// sérialisés depuis JSON ; on utilise des valeurs neutres par défaut. Les
  /// écrans peuvent les surcharger si nécessaire.
  HomeDashboardData _parseDashboardData(Map<String, dynamic> json) {
    // KPIs
    final rawKpis = json['kpis'] as List<dynamic>? ?? [];
    final kpis = rawKpis.whereType<Map<String, dynamic>>().map((k) {
      return DashboardKPI(
        title: k['title'] as String? ?? '',
        value: k['value'] as String? ?? '—',
        variation: k['variation'] as String? ?? '',
        isPositive: (k['is_positive'] as bool?) ?? true,
        icon: Icons.dashboard,
        color: const Color(0xFF3B82F6),
      );
    }).toList();

    // Portfolio (évolution mensuelle)
    final rawPortfolio = json['portfolio_data'] as List<dynamic>? ?? [];
    final portfolioData = rawPortfolio
        .whereType<Map<String, dynamic>>()
        .map((p) => PortfolioDataPoint(
              month: p['month'] as String? ?? '',
              value: (p['value'] as num?)?.toDouble() ?? 0,
            ))
        .toList();

    // Alertes
    final rawAlerts = json['alerts'] as List<dynamic>? ?? [];
    final alerts = rawAlerts.whereType<Map<String, dynamic>>().map((a) {
      return AlertItem(
        title: a['title'] as String? ?? '',
        description: a['description'] as String? ?? '',
        level: _parseAlertLevel(a['level'] as String?),
        icon: Icons.notifications,
      );
    }).toList();

    // Top agents
    final rawAgents = json['top_agents'] as List<dynamic>? ?? [];
    final topAgents = rawAgents
        .whereType<Map<String, dynamic>>()
        .map((a) => AgentPerformance(
              name: a['name'] as String? ?? '',
              code: a['code'] as String? ?? '',
              performanceRate:
                  (a['performance_rate'] as num?)?.toDouble() ?? 0,
              rank: (a['rank'] as int?) ?? 0,
            ))
        .toList();

    return HomeDashboardData(
      kpis: kpis,
      portfolioData: portfolioData,
      alerts: alerts,
      topAgents: topAgents,
    );
  }

  AlertLevel _parseAlertLevel(String? raw) {
    switch (raw) {
      case 'critical':
        return AlertLevel.critical;
      case 'warning':
        return AlertLevel.warning;
      default:
        return AlertLevel.info;
    }
  }

  /// Convertit la réponse JSON `/reporting/par` en [PARStats].
  PARStats _parsePARStats(Map<String, dynamic> json) {
    Map<String, double> toDoubleMap(dynamic raw) {
      if (raw == null) return {};
      if (raw is Map) {
        return raw.map((k, v) => MapEntry(
              k.toString(),
              (v as num?)?.toDouble() ?? 0,
            ));
      }
      return {};
    }

    return PARStats(
      encoursTotal: (json['encours_total'] as num?)?.toDouble() ?? 0,
      totalPrets: (json['total_prets'] as int?) ?? 0,
      pretsEnRetard: (json['prets_en_retard'] as int?) ?? 0,
      parSains: (json['par_sains'] as num?)?.toDouble() ?? 0,
      par1: (json['par1'] as num?)?.toDouble() ?? 0,
      par30: (json['par30'] as num?)?.toDouble() ?? 0,
      par90: (json['par90'] as num?)?.toDouble() ?? 0,
      par180: (json['par180'] as num?)?.toDouble() ?? 0,
      nbSains: (json['nb_sains'] as int?) ?? 0,
      nb1: (json['nb1'] as int?) ?? 0,
      nb30: (json['nb30'] as int?) ?? 0,
      nb90: (json['nb90'] as int?) ?? 0,
      nb180: (json['nb180'] as int?) ?? 0,
      tauxRemboursement:
          (json['taux_remboursement'] as num?)?.toDouble() ?? 0,
      penalitesDues: (json['penalites_dues'] as num?)?.toDouble() ?? 0,
      provisionsConstituees:
          (json['provisions_constituees'] as num?)?.toDouble() ?? 0,
      tauxCouverture: (json['taux_couverture'] as num?)?.toDouble() ?? 0,
      parParAgence: toDoubleMap(json['par_par_agence']),
      parParAgent: toDoubleMap(json['par_par_agent']),
      parParProduit: toDoubleMap(json['par_par_produit']),
      parParSecteur: toDoubleMap(json['par_par_secteur']),
      parParTranche: toDoubleMap(json['par_par_tranche']),
      parGroupeVsIndiv: toDoubleMap(json['par_groupe_vs_indiv']),
    );
  }
}
