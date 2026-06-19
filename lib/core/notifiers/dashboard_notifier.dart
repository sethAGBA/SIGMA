// lib/core/notifiers/dashboard_notifier.dart
//
// State management du dashboard via Provider (ChangeNotifier).
// Cache les données en mémoire pour éviter les recalculs à chaque navigation.
// Phase 3 — Exigences 9.1, 9.2, 9.3, 9.4, 9.5, 9.6

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../../models/dashboard_data.dart';

class DashboardNotifier extends ChangeNotifier {
  // ── État interne ──────────────────────────────────────────────────────────

  HomeDashboardData? _cachedData;
  bool _isLoading = false;
  String? _error;

  // ── Getters publics ───────────────────────────────────────────────────────

  /// Données du dashboard actuellement en cache (null si pas encore chargé).
  HomeDashboardData? get cachedData => _cachedData;

  /// True pendant le chargement initial ou un refresh.
  bool get isLoading => _isLoading;

  /// Message d'erreur du dernier chargement échoué, null sinon.
  String? get error => _error;

  // ── Méthodes publiques ────────────────────────────────────────────────────

  /// Charge les données du dashboard.
  ///
  /// Si le cache est déjà rempli, ne fait rien (évite les appels redondants
  /// lors des navigations répétées — Exigence 9.2).
  /// Sinon, charge depuis l'API (si serveur disponible) ou SQLite (offline).
  Future<void> load() async {
    // Cache chaud → affichage immédiat, pas d'appel réseau (Exigence 9.2)
    if (_cachedData != null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _fetchData();
      _cachedData = data; // Exigence 9.1
    } catch (e) {
      // Conserver les données en cache existantes, exposer l'erreur
      // de manière non bloquante (Exigence 9.6)
      _error = e.toString();
      debugPrint('[DashboardNotifier] Erreur de chargement : $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Force le rechargement des données en vidant d'abord le cache.
  ///
  /// Appelé par le RefreshIndicator (Exigence 9.3).
  Future<void> refresh() async {
    _cachedData = null;
    await load();
  }

  /// Vide le cache sans recharger.
  ///
  /// Doit être appelé lors du logout pour éviter d'afficher les données
  /// d'un autre utilisateur (Exigence 9.4).
  void clearCache() {
    _cachedData = null;
    _error = null;
    notifyListeners();
  }

  // ── Logique de chargement (reproduit _loadData de DashboardPage) ──────────

  Future<HomeDashboardData> _fetchData() async {
    final serverAvailable = await ApiService().isServerAvailable();

    if (serverAvailable) {
      // CONNECTÉ → données du serveur enrichies avec les données locales
      final apiData = await _loadFromApi();
      if (apiData != null) {
        final localData = await DatabaseService().getHomeDashboardData();
        return HomeDashboardData(
          kpis: apiData.kpis,
          portfolioData: localData.portfolioData,
          alerts: {...apiData.alerts, ...localData.alerts}.toList(),
          topAgents: localData.topAgents,
        );
      } else {
        // API disponible mais réponse vide → fallback local
        return await DatabaseService().getHomeDashboardData();
      }
    } else {
      // OFFLINE → cache local uniquement
      return await DatabaseService().getHomeDashboardData();
    }
  }

  Future<HomeDashboardData?> _loadFromApi() async {
    final response = await ApiService().get('/reporting/dashboard');
    final data = ApiService.decodeResponse(response);
    if (data == null) return null;

    final kpis = <DashboardKPI>[
      DashboardKPI(
        title: 'Clients Actifs',
        value: '${data['clients_actifs'] ?? 0}',
        variation: '+0',
        isPositive: true,
        icon: const IconData(0xe7fd, fontFamily: 'MaterialIcons'), // people_rounded
        color: const Color(0xFF3B82F6),
      ),
      DashboardKPI(
        title: 'Encours Total',
        value: _formatAmount((data['encours_total'] as num?)?.toDouble() ?? 0),
        variation: '+0%',
        isPositive: true,
        icon: const IconData(0xe84f, fontFamily: 'MaterialIcons'), // account_balance_wallet_rounded
        color: const Color(0xFF10B981),
      ),
      DashboardKPI(
        title: 'PAR > 30j',
        value: '${data['taux_remboursement'] ?? 0}%',
        variation: 'Normal',
        isPositive: true,
        icon: const IconData(0xe8e4, fontFamily: 'MaterialIcons'), // trending_down_rounded
        color: const Color(0xFFF59E0B),
      ),
      DashboardKPI(
        title: 'Prêts Actifs',
        value: '${data['prets_actifs'] ?? 0}',
        variation: '0',
        isPositive: true,
        icon: const IconData(0xef63, fontFamily: 'MaterialIcons'), // payments_rounded
        color: const Color(0xFF8B5CF6),
      ),
    ];

    final alerts = <AlertItem>[];
    final pretsEnRetard = (data['prets_en_retard'] as num?)?.toInt() ?? 0;
    if (pretsEnRetard > 0) {
      alerts.add(AlertItem(
        title: '$pretsEnRetard prêts en retard',
        description: 'Actions de recouvrement requises',
        level: AlertLevel.warning,
        icon: const IconData(0xe002, fontFamily: 'MaterialIcons'), // warning_rounded
      ));
    }

    return HomeDashboardData(
      kpis: kpis,
      portfolioData: [],
      alerts: alerts,
      topAgents: [],
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}k';
    return amount.toStringAsFixed(0);
  }
}
