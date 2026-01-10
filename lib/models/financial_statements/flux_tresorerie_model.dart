// lib/models/financial_statements/flux_tresorerie_model.dart

/// Représente les Flux opérationnels
class FluxOperationnels {
  final double encaissementsClients;
  final double decaissementsPrets;
  final double depotsEpargne;
  final double retraitsEpargne;
  final double autresFluxOperationnels;

  FluxOperationnels({
    required this.encaissementsClients,
    required this.decaissementsPrets,
    required this.depotsEpargne,
    required this.retraitsEpargne,
    required this.autresFluxOperationnels,
  });

  double get totalFluxOperationnels =>
      encaissementsClients +
      depotsEpargne -
      decaissementsPrets -
      retraitsEpargne +
      autresFluxOperationnels;
}

/// Représente les Flux d'investissement
class FluxInvestissement {
  final double acquisitionsImmobilisations;
  final double cessionsActifs;
  final double autresFluxInvestissement;

  FluxInvestissement({
    required this.acquisitionsImmobilisations,
    required this.cessionsActifs,
    required this.autresFluxInvestissement,
  });

  double get totalFluxInvestissement =>
      cessionsActifs - acquisitionsImmobilisations + autresFluxInvestissement;
}

/// Représente le Tableau de Flux de Trésorerie complet
class TableauFlux {
  final FluxOperationnels fluxOperationnels;
  final FluxInvestissement fluxInvestissement;
  final double tresorerieDebut;
  final double tresorerieFin;
  final DateTime dateDebut;
  final DateTime dateFin;

  TableauFlux({
    required this.fluxOperationnels,
    required this.fluxInvestissement,
    required this.tresorerieDebut,
    required this.tresorerieFin,
    required this.dateDebut,
    required this.dateFin,
  });

  double get variationTresorerie =>
      fluxOperationnels.totalFluxOperationnels +
      fluxInvestissement.totalFluxInvestissement;

  double get tresorerieCalculee => tresorerieDebut + variationTresorerie;

  bool get isCoherent => (tresorerieCalculee - tresorerieFin).abs() < 0.01;
}
