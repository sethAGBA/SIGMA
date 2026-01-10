// lib/models/financial_statements/bilan_model.dart

/// Représente l'Actif du Bilan
class BilanActif {
  final double actifImmobilise;
  final double actifCirculant;
  final double portefeuilleCredits; // Compte 27
  final double provisionsCreances;
  final double tresorerie; // Compte 57
  final double autresActifs;

  BilanActif({
    required this.actifImmobilise,
    required this.actifCirculant,
    required this.portefeuilleCredits,
    required this.provisionsCreances,
    required this.tresorerie,
    required this.autresActifs,
  });

  double get totalActif =>
      actifImmobilise +
      actifCirculant +
      portefeuilleCredits +
      provisionsCreances +
      tresorerie +
      autresActifs;
}

/// Représente le Passif du Bilan
class BilanPassif {
  final double capitauxPropres;
  final double dettesFinancieres;
  final double epargneClientele; // Compte 26
  final double autresDettes;

  BilanPassif({
    required this.capitauxPropres,
    required this.dettesFinancieres,
    required this.epargneClientele,
    required this.autresDettes,
  });

  double get totalPassif =>
      capitauxPropres + dettesFinancieres + epargneClientele + autresDettes;
}

/// Représente le Bilan complet
class Bilan {
  final BilanActif actif;
  final BilanPassif passif;
  final DateTime dateDebut;
  final DateTime dateFin;

  Bilan({
    required this.actif,
    required this.passif,
    required this.dateDebut,
    required this.dateFin,
  });

  bool get isBalanced => (actif.totalActif - passif.totalPassif).abs() < 0.01;

  double get difference => actif.totalActif - passif.totalPassif;
}
