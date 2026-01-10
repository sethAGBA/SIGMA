// lib/models/financial_statements/compte_resultat_model.dart

/// Représente les Produits d'exploitation
class Produits {
  final double interetsPrets; // Compte 70
  final double commissions;
  final double penalites; // Compte 75
  final double autresProduits;

  Produits({
    required this.interetsPrets,
    required this.commissions,
    required this.penalites,
    required this.autresProduits,
  });

  double get totalProduits =>
      interetsPrets + commissions + penalites + autresProduits;
}

/// Représente les Charges d'exploitation
class Charges {
  final double interetsEpargne;
  final double chargesPersonnel;
  final double chargesFonctionnement;
  final double dotationsProvisions;
  final double autresCharges;

  Charges({
    required this.interetsEpargne,
    required this.chargesPersonnel,
    required this.chargesFonctionnement,
    required this.dotationsProvisions,
    required this.autresCharges,
  });

  double get totalCharges =>
      interetsEpargne +
      chargesPersonnel +
      chargesFonctionnement +
      dotationsProvisions +
      autresCharges;
}

/// Représente le Compte de Résultat complet
class CompteResultat {
  final Produits produits;
  final Charges charges;
  final DateTime dateDebut;
  final DateTime dateFin;

  CompteResultat({
    required this.produits,
    required this.charges,
    required this.dateDebut,
    required this.dateFin,
  });

  double get resultatNet => produits.totalProduits - charges.totalCharges;

  bool get isProfitable => resultatNet > 0;

  double get margeNette => produits.totalProduits > 0
      ? (resultatNet / produits.totalProduits) * 100
      : 0;
}
