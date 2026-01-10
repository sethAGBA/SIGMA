// lib/models/produit_financier_model.dart

enum ProductType {
  credit,
  epargne;

  String get label => this == credit ? 'Crédit' : 'Épargne';
}

enum InterestCalculationMode {
  decliningBalance, // Dégressif
  flat, // Constant sur le capital initial
  simple; // Simple

  String get label {
    switch (this) {
      case decliningBalance:
        return 'Dégressif';
      case flat:
        return 'Constant (Flat)';
      case simple:
        return 'Simple';
    }
  }
}

enum RepaymentFrequency {
  weekly,
  monthly,
  quarterly,
  atMaturity; // In fine

  String get label {
    switch (this) {
      case weekly:
        return 'Hebdomadaire';
      case monthly:
        return 'Mensuelle';
      case quarterly:
        return 'Trimestrielle';
      case atMaturity:
        return 'À l\'échéance (In fine)';
    }
  }
}

enum CreditCategory {
  individuel,
  groupe,
  agr, // Activité Génératrice de Revenus
  equipement,
  social,
  agricole;

  String get label {
    switch (this) {
      case individuel:
        return 'Crédit individuel';
      case groupe:
        return 'Crédit groupe solidaire';
      case agr:
        return 'Crédit AGR';
      case equipement:
        return 'Crédit équipement';
      case social:
        return 'Crédit urgence/social';
      case agricole:
        return 'Crédit agricole';
    }
  }
}

enum SavingsCategory {
  libre,
  obligatoire,
  programmee,
  bloquee,
  projet;

  String get label {
    switch (this) {
      case libre:
        return 'Épargne libre';
      case obligatoire:
        return 'Épargne obligatoire (prêt)';
      case programmee:
        return 'Épargne programmée';
      case bloquee:
        return 'Épargne bloquée (DAT)';
      case projet:
        return 'Épargne projet/éducation';
    }
  }
}

class ProduitFinancier {
  final int? id;
  final String nom;
  final String code;
  final String description;
  final ProductType type;

  // Paramètres communs
  final double tauxInteret; // Pourcentage annuel
  final String? conditionsEligibilite;
  final String? documentsRequis;
  final String? fraisCommissions;
  final String? assurancesObligatoires;

  // Paramètres Crédit
  final CreditCategory? creditCategory;
  final double? montantMin;
  final double? montantMax;
  final int? dureeMinMois;
  final int? dureeMaxMois;
  final InterestCalculationMode? modeCalculInteret;
  final RepaymentFrequency? frequenceRemboursement;

  // Champs spécifiques du S.I.
  final bool differePossible;
  final String? secteursEligibles;
  final String? materielFinancable;
  final String? accompagnementTechnique;
  final String? garantieSurEquipement;
  final bool procedureAcceleree;
  final bool cautionSolidaireRequise;

  // Paramètres Épargne
  final SavingsCategory? savingsCategory;
  final double? soldeMinimum;
  final double? versementMinimum;

  ProduitFinancier({
    this.id,
    required this.nom,
    required this.code,
    required this.description,
    required this.type,
    required this.tauxInteret,
    this.conditionsEligibilite,
    this.documentsRequis,
    this.fraisCommissions,
    this.assurancesObligatoires,
    this.creditCategory,
    this.montantMin,
    this.montantMax,
    this.dureeMinMois,
    this.dureeMaxMois,
    this.modeCalculInteret,
    this.frequenceRemboursement,
    this.differePossible = false,
    this.secteursEligibles,
    this.materielFinancable,
    this.accompagnementTechnique,
    this.garantieSurEquipement,
    this.procedureAcceleree = false,
    this.cautionSolidaireRequise = false,
    this.savingsCategory,
    this.soldeMinimum,
    this.versementMinimum,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nom': nom,
      'code': code,
      'description': description,
      'type': type.name,
      'taux_interet': tauxInteret,
      'conditions_eligibilite': conditionsEligibilite,
      'documents_requis': documentsRequis,
      'frais_commissions': fraisCommissions,
      'assurances_obligatoires': assurancesObligatoires,
      'credit_category': creditCategory?.name,
      'montant_min': montantMin,
      'montant_max': montantMax,
      'duree_min_mois': dureeMinMois,
      'duree_max_mois': dureeMaxMois,
      'mode_calcul_interet': modeCalculInteret?.name,
      'frequence_remboursement': frequenceRemboursement?.name,
      'differe_possible': differePossible ? 1 : 0,
      'secteurs_eligibles': secteursEligibles,
      'materiel_financable': materielFinancable,
      'accompagnement_technique': accompagnementTechnique,
      'garantie_sur_equipement': garantieSurEquipement,
      'procedure_acceleree': procedureAcceleree ? 1 : 0,
      'caution_solidaire_requise': cautionSolidaireRequise ? 1 : 0,
      'savings_category': savingsCategory?.name,
      'solde_minimum': soldeMinimum,
      'versement_minimum': versementMinimum,
    };
  }

  factory ProduitFinancier.fromMap(Map<String, dynamic> map) {
    return ProduitFinancier(
      id: map['id'],
      nom: map['nom'],
      code: map['code'],
      description: map['description'] ?? '',
      type: ProductType.values.byName(map['type']),
      tauxInteret: map['taux_interet'],
      conditionsEligibilite: map['conditions_eligibilite'],
      documentsRequis: map['documents_requis'],
      fraisCommissions: map['frais_commissions'],
      assurancesObligatoires: map['assurances_obligatoires'],
      creditCategory: map['credit_category'] != null
          ? CreditCategory.values.byName(map['credit_category'])
          : null,
      montantMin: map['montant_min'],
      montantMax: map['montant_max'],
      dureeMinMois: map['duree_min_mois'],
      dureeMaxMois: map['duree_max_mois'],
      modeCalculInteret: map['mode_calcul_interet'] != null
          ? InterestCalculationMode.values.byName(map['mode_calcul_interet'])
          : null,
      frequenceRemboursement: map['frequence_remboursement'] != null
          ? RepaymentFrequency.values.byName(map['frequence_remboursement'])
          : null,
      differePossible: (map['differe_possible'] ?? 0) == 1,
      secteursEligibles: map['secteurs_eligibles'],
      materielFinancable: map['materiel_financable'],
      accompagnementTechnique: map['accompagnement_technique'],
      garantieSurEquipement: map['garantie_sur_equipement'],
      procedureAcceleree: (map['procedure_acceleree'] ?? 0) == 1,
      cautionSolidaireRequise: (map['caution_solidaire_requise'] ?? 0) == 1,
      savingsCategory: map['savings_category'] != null
          ? SavingsCategory.values.byName(map['savings_category'])
          : null,
      soldeMinimum: map['solde_minimum'],
      versementMinimum: map['versement_minimum'],
    );
  }
}
