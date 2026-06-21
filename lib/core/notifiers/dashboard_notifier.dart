// lib/core/notifiers/dashboard_notifier.dart
//
// State management du dashboard via Provider (ChangeNotifier).
// Cache les données en mémoire pour éviter les recalculs à chaque navigation.
// Phase 3 — Exigences 9.1, 9.2, 9.3, 9.4, 9.5, 9.6

import 'package:flutter/material.dart';
import '../services/dashboard_api_service.dart';
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
    return DashboardApiService().getKpis();
  }
}
