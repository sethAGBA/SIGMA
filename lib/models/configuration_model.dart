class LegalInformation {
  final String raisonSociale;
  final String formeJuridique;
  final String numeroAgrement;
  final String registreCommerce;
  final String numeroFiscal; // IFU
  final String adresseSiege;
  final String contactsOfficiels;
  final String logoPath;

  LegalInformation({
    this.raisonSociale = '',
    this.formeJuridique = '',
    this.numeroAgrement = '',
    this.registreCommerce = '',
    this.numeroFiscal = '',
    this.adresseSiege = '',
    this.contactsOfficiels = '',
    this.logoPath = '',
  });

  Map<String, String> toMap() {
    return {
      'legal_raison_sociale': raisonSociale,
      'legal_forme_juridique': formeJuridique,
      'legal_numero_agrement': numeroAgrement,
      'legal_registre_commerce': registreCommerce,
      'legal_numero_fiscal': numeroFiscal,
      'legal_adresse_siege': adresseSiege,
      'legal_contacts_officiels': contactsOfficiels,
      'legal_logo_path': logoPath,
    };
  }

  factory LegalInformation.fromMap(Map<String, dynamic> map) {
    return LegalInformation(
      raisonSociale: map['legal_raison_sociale'] ?? '',
      formeJuridique: map['legal_forme_juridique'] ?? '',
      numeroAgrement: map['legal_numero_agrement'] ?? '',
      registreCommerce: map['legal_registre_commerce'] ?? '',
      numeroFiscal: map['legal_numero_fiscal'] ?? '',
      adresseSiege: map['legal_adresse_siege'] ?? '',
      contactsOfficiels: map['legal_contacts_officiels'] ?? '',
      logoPath: map['legal_logo_path'] ?? '',
    );
  }
}

class FinancialParameters {
  final String exerciceFiscal;
  final String deviseReference;
  final double tauxChange;
  final double plafondCaisse;
  final double seuilApprobation;
  final double fraisDossierStandard;

  FinancialParameters({
    this.exerciceFiscal = '',
    this.deviseReference = 'FCFA',
    this.tauxChange = 1.0,
    this.plafondCaisse = 0.0,
    this.seuilApprobation = 0.0,
    this.fraisDossierStandard = 0.0,
  });

  Map<String, String> toMap() {
    return {
      'fin_exercice_fiscal': exerciceFiscal,
      'fin_devise_reference': deviseReference,
      'fin_taux_change': tauxChange.toString(),
      'fin_plafond_caisse': plafondCaisse.toString(),
      'fin_seuil_approbation': seuilApprobation.toString(),
      'fin_frais_dossier_standard': fraisDossierStandard.toString(),
    };
  }

  factory FinancialParameters.fromMap(Map<String, dynamic> map) {
    return FinancialParameters(
      exerciceFiscal: map['fin_exercice_fiscal'] ?? '',
      deviseReference: map['fin_devise_reference'] ?? 'FCFA',
      tauxChange: double.tryParse(map['fin_taux_change'] ?? '1.0') ?? 1.0,
      plafondCaisse: double.tryParse(map['fin_plafond_caisse'] ?? '0.0') ?? 0.0,
      seuilApprobation:
          double.tryParse(map['fin_seuil_approbation'] ?? '0.0') ?? 0.0,
      fraisDossierStandard:
          double.tryParse(map['fin_frais_dossier_standard'] ?? '0.0') ?? 0.0,
    );
  }
}

class CreditParameters {
  final double tauxInteretDefaut;
  final String modeCalculInteret; // Linéaire, Dégressif, Amortissement constant
  final List<String> frequencesRemboursement;
  final double tauxPenaliteRetard;
  final int delaiGraceMax;
  final double epargneObligatoire; // %
  final double ratioEndettementMax; // %

  CreditParameters({
    this.tauxInteretDefaut = 0.0,
    this.modeCalculInteret = 'Dégressif',
    this.frequencesRemboursement = const ['Mensuel'],
    this.tauxPenaliteRetard = 0.0,
    this.delaiGraceMax = 0,
    this.epargneObligatoire = 0.0,
    this.ratioEndettementMax = 0.0,
  });

  Map<String, String> toMap() {
    return {
      'cred_taux_interet_defaut': tauxInteretDefaut.toString(),
      'cred_mode_calcul_interet': modeCalculInteret,
      'cred_frequences_remboursement': frequencesRemboursement.join(','),
      'cred_taux_penalite_retard': tauxPenaliteRetard.toString(),
      'cred_delai_grace_max': delaiGraceMax.toString(),
      'cred_epargne_obligatoire': epargneObligatoire.toString(),
      'cred_ratio_endettement_max': ratioEndettementMax.toString(),
    };
  }

  factory CreditParameters.fromMap(Map<String, dynamic> map) {
    return CreditParameters(
      tauxInteretDefaut:
          double.tryParse(map['cred_taux_interet_defaut'] ?? '0.0') ?? 0.0,
      modeCalculInteret: map['cred_mode_calcul_interet'] ?? 'Dégressif',
      frequencesRemboursement:
          (map['cred_frequences_remboursement'] as String?)?.split(',') ??
          ['Mensuel'],
      tauxPenaliteRetard:
          double.tryParse(map['cred_taux_penalite_retard'] ?? '0.0') ?? 0.0,
      delaiGraceMax: int.tryParse(map['cred_delai_grace_max'] ?? '0') ?? 0,
      epargneObligatoire:
          double.tryParse(map['cred_epargne_obligatoire'] ?? '0.0') ?? 0.0,
      ratioEndettementMax:
          double.tryParse(map['cred_ratio_endettement_max'] ?? '0.0') ?? 0.0,
    );
  }
}
