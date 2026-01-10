// lib/models/dashboard_data.dart

import 'package:flutter/material.dart';

/// Modèle pour les indicateurs clés de performance (KPI)
class DashboardKPI {
  final String title;
  final String value;
  final String variation;
  final bool isPositive;
  final IconData icon;
  final Color color;

  DashboardKPI({
    required this.title,
    required this.value,
    required this.variation,
    required this.isPositive,
    required this.icon,
    required this.color,
  });
}

/// Point de données pour le graphique d'évolution du portefeuille
class PortfolioDataPoint {
  final String month;
  final double value;

  PortfolioDataPoint({required this.month, required this.value});
}

/// Modèle pour les alertes critiques
class AlertItem {
  final String title;
  final String description;
  final AlertLevel level;
  final IconData icon;

  AlertItem({
    required this.title,
    required this.description,
    required this.level,
    required this.icon,
  });

  Color get color {
    switch (level) {
      case AlertLevel.critical:
        return const Color(0xFFEF4444);
      case AlertLevel.warning:
        return const Color(0xFFF59E0B);
      case AlertLevel.info:
        return const Color(0xFF3B82F6);
    }
  }
}

enum AlertLevel { critical, warning, info }

/// Modèle pour la performance des agents
class AgentPerformance {
  final String name;
  final String code;
  final double performanceRate;
  final int rank;

  AgentPerformance({
    required this.name,
    required this.code,
    required this.performanceRate,
    required this.rank,
  });
}

/// Classe utilitaire pour générer des données simulées
class DashboardDataGenerator {
  /// Génère les KPI du dashboard
  static List<DashboardKPI> generateKPIs() {
    return [
      DashboardKPI(
        title: 'Clients Actifs',
        value: '1,247',
        variation: '+12',
        isPositive: true,
        icon: Icons.people_rounded,
        color: const Color(0xFF3B82F6),
      ),
      DashboardKPI(
        title: 'Encours Total',
        value: '125.4M',
        variation: '+4.2%',
        isPositive: true,
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xFF10B981),
      ),
      DashboardKPI(
        title: 'PAR > 30j',
        value: '2.3%',
        variation: '-0.1%',
        isPositive: true,
        icon: Icons.trending_down_rounded,
        color: const Color(0xFFF59E0B),
      ),
      DashboardKPI(
        title: 'Collecte Jour',
        value: '2.34M',
        variation: '78%',
        isPositive: true,
        icon: Icons.payments_rounded,
        color: const Color(0xFF8B5CF6),
      ),
    ];
  }

  /// Génère les données du graphique d'évolution (12 mois)
  static List<PortfolioDataPoint> generatePortfolioData() {
    return [
      PortfolioDataPoint(month: 'Jan', value: 95.2),
      PortfolioDataPoint(month: 'Fév', value: 98.5),
      PortfolioDataPoint(month: 'Mar', value: 102.3),
      PortfolioDataPoint(month: 'Avr', value: 108.7),
      PortfolioDataPoint(month: 'Mai', value: 112.4),
      PortfolioDataPoint(month: 'Jui', value: 115.8),
      PortfolioDataPoint(month: 'Jul', value: 118.2),
      PortfolioDataPoint(month: 'Aoû', value: 120.5),
      PortfolioDataPoint(month: 'Sep', value: 122.1),
      PortfolioDataPoint(month: 'Oct', value: 123.8),
      PortfolioDataPoint(month: 'Nov', value: 124.6),
      PortfolioDataPoint(month: 'Déc', value: 125.4),
    ];
  }

  /// Génère les alertes critiques du jour
  static List<AlertItem> generateAlerts() {
    return [
      AlertItem(
        title: '3 prêts > 90j retard',
        description: 'Action de recouvrement urgente requise',
        level: AlertLevel.critical,
        icon: Icons.error_outline_rounded,
      ),
      AlertItem(
        title: 'Caisse Nord non clôturée',
        description: 'Clôture en attente depuis hier',
        level: AlertLevel.warning,
        icon: Icons.warning_amber_rounded,
      ),
      AlertItem(
        title: '5 échéances impayées',
        description: 'Relances à effectuer aujourd\'hui',
        level: AlertLevel.warning,
        icon: Icons.schedule_rounded,
      ),
      AlertItem(
        title: 'Budget dépassé Ouest',
        description: 'Charges de fonctionnement +15%',
        level: AlertLevel.info,
        icon: Icons.info_outline_rounded,
      ),
    ];
  }

  /// Génère le top 5 des agents performants
  static List<AgentPerformance> generateTopAgents() {
    return []; // Will be loaded from DB
  }
}

class HomeDashboardData {
  final List<DashboardKPI> kpis;
  final List<PortfolioDataPoint> portfolioData;
  final List<AlertItem> alerts;
  final List<AgentPerformance> topAgents;

  HomeDashboardData({
    required this.kpis,
    required this.portfolioData,
    required this.alerts,
    required this.topAgents,
  });
}
