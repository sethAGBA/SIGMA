// lib/core/services/reporting_api_service.dart
//
// Stratégie "Server is Truth" :
//
// LECTURE connecté  → PostgreSQL (données partagées tous les postes)
//                   → Retourne directement les données serveur (agrégats calculés)
// LECTURE offline   → SQLite local (agrégats calculés localement via DatabaseService)

import 'package:flutter/material.dart';

import '../../models/dashboard_data.dart';
import '../../models/client_model.dart';
import '../../models/delinquent_loan_details_model.dart';
import '../../models/executive_stats_model.dart';
import '../../models/loan_model.dart';
import '../../models/par_stats_model.dart';
import '../../models/recovery_action_model.dart';
import '../../models/repayment_schedule_model.dart';
import '../../models/reporting_result.dart';
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

  // ── Executive stats ───────────────────────────────────────────────────

  /// Retourne les statistiques exécutives (direction).
  ///
  /// Online  : récupère depuis `/reporting/executive`.
  /// Offline : calcule les agrégats depuis SQLite via [DatabaseService].
  /// Exception API → fallback SQLite + `isOfflineFallback: true`.
  /// Jamais d'exception vers l'appelant.
  Future<ReportingResult<ExecutiveDashboardStats>> getExecutiveStats() async {
    if (await SyncService().isOnline) {
      try {
        final response = await ApiService().get('/reporting/executive');
        final data = ApiService.decodeResponse(response);
        if (data != null && data is Map<String, dynamic>) {
          final parsed = _parseExecutiveStats(data);
          return ReportingResult(data: parsed, isOfflineFallback: false);
        }
      } catch (_) {
        // Fallback silencieux vers SQLite
      }
    }
    final local = await DatabaseService().getExecutiveStats();
    return ReportingResult(data: local, isOfflineFallback: true);
  }

  // ── Delinquent loans ──────────────────────────────────────────────────

  /// Retourne la liste des prêts en souffrance.
  ///
  /// Online  : récupère depuis `/reporting/delinquents?par_category=...`.
  /// Offline : calcule depuis SQLite via [DatabaseService.getDelinquentLoans()].
  /// Exception API → fallback SQLite + `isOfflineFallback: true`.
  /// Jamais d'exception vers l'appelant.
  Future<ReportingResult<List<Map<String, dynamic>>>> getDelinquentLoans({
    String? parCategory,
  }) async {
    if (await SyncService().isOnline) {
      try {
        final path = parCategory != null
            ? '/reporting/delinquents?par_category=${Uri.encodeQueryComponent(parCategory)}'
            : '/reporting/delinquents';
        final response = await ApiService().get(path);
        final data = ApiService.decodeResponse(response);
        if (data != null) {
          final list = data is List
              ? data.whereType<Map<String, dynamic>>().toList()
              : (data['items'] as List? ?? [])
                  .whereType<Map<String, dynamic>>()
                  .toList();
          return ReportingResult(data: list, isOfflineFallback: false);
        }
      } catch (_) {
        // Fallback silencieux vers SQLite
      }
    }
    final local = await DatabaseService().getDelinquentLoans(parCategory: parCategory);
    return ReportingResult(data: local, isOfflineFallback: true);
  }

  // ── Delinquent loan details ───────────────────────────────────────────

  /// Retourne les détails d'un prêt en souffrance.
  ///
  /// Online  : récupère depuis `/reporting/delinquent/{id}`.
  /// Offline : calcule depuis SQLite via [DatabaseService.getDelinquentLoanDetails(id)].
  /// Exception API → fallback SQLite + `isOfflineFallback: true`.
  /// Jamais d'exception vers l'appelant.
  Future<ReportingResult<DelinquentLoanDetails?>> getDelinquentLoanDetails(int id) async {
    if (await SyncService().isOnline) {
      try {
        final response = await ApiService().get('/reporting/delinquent/$id');
        final data = ApiService.decodeResponse(response);
        if (data != null && data is Map<String, dynamic>) {
          final parsed = _parseDelinquentLoanDetails(data);
          return ReportingResult(data: parsed, isOfflineFallback: false);
        }
      } catch (_) {
        // Fallback silencieux vers SQLite
      }
    }
    final local = await DatabaseService().getDelinquentLoanDetails(id);
    return ReportingResult(data: local, isOfflineFallback: true);
  }

  // ── Recovery stats (toujours local) ──────────────────────────────────

  /// Retourne les statistiques de recouvrement depuis SQLite.
  ///
  /// Toujours local — jamais d'appel HTTP, quel que soit l'état de la connexion.
  Future<ReportingResult<RecoveryStats>> getRecoveryStats() async {
    final data = await DatabaseService().getRecoveryStats();
    return ReportingResult(data: data, isOfflineFallback: true);
  }

  // ── Global recovery actions history (toujours local) ─────────────────

  /// Retourne l'historique global des actions de recouvrement depuis SQLite.
  ///
  /// Toujours local — jamais d'appel HTTP, quel que soit l'état de la connexion.
  Future<ReportingResult<List<RecoveryAction>>> getGlobalRecoveryActionsHistory() async {
    final data = await DatabaseService().getGlobalRecoveryActionsHistory();
    return ReportingResult(data: data, isOfflineFallback: true);
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
      encours: (json['encours_total'] as num?)?.toDouble() ?? 0.0, // Phase 2 — BottomStatsBar
      collecteJour: (json['collecte_jour'] as num?)?.toDouble() ?? 0.0, // Phase 2 — BottomStatsBar
      par30: (json['par30_rate'] as num?)?.toDouble() ?? 0.0, // Phase 2 — BottomStatsBar
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

  // ── Parseurs pour les nouvelles méthodes ─────────────────────────────

  /// Convertit la réponse JSON `/reporting/executive` en [ExecutiveDashboardStats].
  ///
  /// En cas de champs manquants, des valeurs neutres par défaut sont utilisées
  /// pour éviter toute exception de parsing.
  ExecutiveDashboardStats _parseExecutiveStats(Map<String, dynamic> json) {
    Map<String, double> toDoubleMap(dynamic raw) {
      if (raw == null) return {};
      if (raw is Map) {
        return raw.map((k, v) => MapEntry(k.toString(), (v as num?)?.toDouble() ?? 0));
      }
      return {};
    }

    List<EvolutionPoint> toEvolutionList(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) {
        return raw.whereType<Map<String, dynamic>>().map((e) {
          return EvolutionPoint(
            e['label'] as String? ?? '',
            (e['value'] as num?)?.toDouble() ?? 0,
          );
        }).toList();
      }
      return [];
    }

    final actJson = json['activity'] as Map<String, dynamic>? ?? {};
    final activity = ActivityStats(
      activeClientsCount: (actJson['active_clients_count'] as int?) ?? 0,
      newClientsMonth: (actJson['new_clients_month'] as int?) ?? 0,
      lapsedClients: (actJson['lapsed_clients'] as int?) ?? 0,
      penetrationRate: (actJson['penetration_rate'] as num?)?.toDouble() ?? 0,
      retentionRate: (actJson['retention_rate'] as num?)?.toDouble() ?? 0,
    );

    final portJson = json['portfolio'] as Map<String, dynamic>? ?? {};
    final portfolio = PortfolioStats(
      totalOutstanding: (portJson['total_outstanding'] as num?)?.toDouble() ?? 0,
      activeLoansCount: (portJson['active_loans_count'] as int?) ?? 0,
      averageLoanAmount: (portJson['average_loan_amount'] as num?)?.toDouble() ?? 0,
      monthlyGrowth: (portJson['monthly_growth'] as num?)?.toDouble() ?? 0,
      disbursementsMonth: (portJson['disbursements_month'] as num?)?.toDouble() ?? 0,
      repaymentsMonth: (portJson['repayments_month'] as num?)?.toDouble() ?? 0,
      outstandingByProduct: toDoubleMap(portJson['outstanding_by_product']),
    );

    final qualJson = json['quality'] as Map<String, dynamic>? ?? {};
    final quality = QualityStats(
      par30Rate: (qualJson['par30_rate'] as num?)?.toDouble() ?? 0,
      repaymentRate: (qualJson['repayment_rate'] as num?)?.toDouble() ?? 0,
      writeOffRate: (qualJson['write_off_rate'] as num?)?.toDouble() ?? 0,
      provisionsOutstandingRatio: (qualJson['provisions_outstanding_ratio'] as num?)?.toDouble() ?? 0,
      par12MonthEvolution: toEvolutionList(qualJson['par12_month_evolution']),
      repaymentRateEvolution: toEvolutionList(qualJson['repayment_rate_evolution']),
      doubtfulDebts: (qualJson['doubtful_debts'] as num?)?.toDouble() ?? 0,
    );

    final savJson = json['savings'] as Map<String, dynamic>? ?? {};
    final savings = SavingsStats(
      totalSavings: (savJson['total_savings'] as num?)?.toDouble() ?? 0,
      accountsCount: (savJson['accounts_count'] as int?) ?? 0,
      averageSavings: (savJson['average_savings'] as num?)?.toDouble() ?? 0,
      savingsGrowth: (savJson['savings_growth'] as num?)?.toDouble() ?? 0,
      savingsCreditRatio: (savJson['savings_credit_ratio'] as num?)?.toDouble() ?? 0,
      savingsByType: toDoubleMap(savJson['savings_by_type']),
    );

    final rawAgents = json['top_agents'] as List<dynamic>? ?? [];
    final topAgents = rawAgents.whereType<Map<String, dynamic>>().map((a) {
      return AgentPerformanceMetric(
        name: a['name'] as String? ?? '',
        volume: (a['volume'] as num?)?.toDouble() ?? 0,
        parRate: (a['par_rate'] as num?)?.toDouble() ?? 0,
        collectionRate: (a['collection_rate'] as num?)?.toDouble() ?? 0,
      );
    }).toList();

    final rawGeo = json['geographic_distribution'] as List<dynamic>? ?? [];
    final geographicDistribution = rawGeo.whereType<Map<String, dynamic>>().map((g) {
      return GeographicPoint(
        region: g['region'] as String? ?? '',
        volume: (g['volume'] as num?)?.toDouble() ?? 0,
        clientCount: (g['client_count'] as int?) ?? 0,
      );
    }).toList();

    final rawProducts = json['popular_products'] as List<dynamic>? ?? [];
    final popularProducts = rawProducts.whereType<Map<String, dynamic>>().map((p) {
      return ProductDemand(
        name: p['name'] as String? ?? '',
        requestCount: (p['request_count'] as int?) ?? 0,
        totalRequestedAmount: (p['total_requested_amount'] as num?)?.toDouble() ?? 0,
      );
    }).toList();

    final finJson = json['financial'] as Map<String, dynamic>? ?? {};
    final financial = FinancialPerformance(
      netInterestIncome: (finJson['net_interest_income'] as num?)?.toDouble() ?? 0,
      feeIncome: (finJson['fee_income'] as num?)?.toDouble() ?? 0,
      operatingExpenses: (finJson['operating_expenses'] as num?)?.toDouble() ?? 0,
      netIncome: (finJson['net_income'] as num?)?.toDouble() ?? 0,
      roe: (finJson['roe'] as num?)?.toDouble() ?? 0,
      roa: (finJson['roa'] as num?)?.toDouble() ?? 0,
    );

    final lastUpdateRaw = json['last_update'] as String?;
    final lastUpdate = lastUpdateRaw != null
        ? DateTime.tryParse(lastUpdateRaw) ?? DateTime.now()
        : DateTime.now();

    return ExecutiveDashboardStats(
      activity: activity,
      portfolio: portfolio,
      quality: quality,
      savings: savings,
      topAgents: topAgents,
      geographicDistribution: geographicDistribution,
      popularProducts: popularProducts,
      outstanding12MonthEvolution: toEvolutionList(json['outstanding_12_month_evolution']),
      financial: financial,
      lastUpdate: lastUpdate,
    );
  }

  /// Convertit la réponse JSON `/reporting/delinquent/{id}` en [DelinquentLoanDetails].
  ///
  /// Retourne `null` si les données sont insuffisantes pour reconstruire l'objet.
  DelinquentLoanDetails? _parseDelinquentLoanDetails(Map<String, dynamic> json) {
    try {
      final loanJson = json['loan'] as Map<String, dynamic>?;
      final clientJson = json['client'] as Map<String, dynamic>?;
      if (loanJson == null || clientJson == null) return null;

      final loan = Loan.fromMap(loanJson);
      final client = Client.fromMap(clientJson);

      final rawSchedules = json['unpaid_schedules'] as List<dynamic>? ?? [];
      final unpaidSchedules = rawSchedules
          .whereType<Map<String, dynamic>>()
          .map((s) => RepaymentSchedule.fromMap(s))
          .toList();

      final rawActions = json['recovery_actions'] as List<dynamic>? ?? [];
      final recoveryActions = rawActions
          .whereType<Map<String, dynamic>>()
          .map((a) => RecoveryAction.fromMap(a))
          .toList();

      return DelinquentLoanDetails(
        loan: loan,
        client: client,
        unpaidSchedules: unpaidSchedules,
        penalitesAccumulees: (json['penalites_accumulees'] as num?)?.toDouble() ?? 0,
        provisionConstituee: (json['provision_constituee'] as num?)?.toDouble() ?? 0,
        joursRetard: (json['jours_retard'] as int?) ?? 0,
        recoveryActions: recoveryActions,
      );
    } catch (_) {
      return null;
    }
  }
}
