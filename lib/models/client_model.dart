// lib/models/client_model.dart

enum ClientStatus {
  active,
  inactive,
  blacklisted;

  String get label {
    switch (this) {
      case ClientStatus.active:
        return 'Actif';
      case ClientStatus.inactive:
        return 'Inactif';
      case ClientStatus.blacklisted:
        return 'Blacklisté';
    }
  }
}

enum ClientRisk {
  low,
  medium,
  high;

  String get label {
    switch (this) {
      case ClientRisk.low:
        return 'Faible';
      case ClientRisk.medium:
        return 'Moyen';
      case ClientRisk.high:
        return 'Élevé';
    }
  }
}

enum ClientGender {
  m,
  f;

  String get label => this == m ? 'Masculin' : 'Féminin';
}

enum SituationFamiliale {
  celibataire,
  marie,
  divorce,
  veuf;

  String get label {
    switch (this) {
      case SituationFamiliale.celibataire:
        return 'Célibataire';
      case SituationFamiliale.marie:
        return 'Marié(e)';
      case SituationFamiliale.divorce:
        return 'Divorcé(e)';
      case SituationFamiliale.veuf:
        return 'Veuf/Veuve';
    }
  }
}

enum TypeLogement {
  proprietaire,
  locataire;

  String get label => this == proprietaire ? 'Propriétaire' : 'Locataire';
}

class Client {
  final int? id;
  final String numeroClient;
  final String nom;
  final String prenoms;
  final DateTime? dateNaissance;
  final String? lieuNaissance;
  final ClientGender sexe;

  String get nomComplet => '$nom $prenoms';

  // Pièces d'identité
  final String? numeroCNI;
  final String? numeroPasseport;

  // Contacts
  final String? telephone;
  final String? email;
  final String? whatsapp;
  final String? adresse;

  // Situation familiale
  final SituationFamiliale? situationFamiliale;
  final int? nombreEnfants;
  final TypeLogement? typeLogement;
  final String? descriptionLogement;
  final String? languesParlees; // Stocké comme string séparé par virgules

  // Personnes références
  final String? referenceNom1;
  final String? referenceTel1;
  final String? referenceRelation1;
  final String? referenceNom2;
  final String? referenceTel2;
  final String? referenceRelation2;

  // Activité économique
  final String? activitePrincipale;
  final String? activitesSecondaires;
  final double? revenusMensuels;
  final double? chargesMensuelles;
  final double? capaciteRemboursement; // Calculé
  final int? ancienneteActivite; // En mois
  final String? lieuExerciceActivite;
  final String? descriptionActivite;
  final String? biensPatrimoine;

  // Groupe solidaire
  final int? groupeSolidaireId;
  final bool cautionSolidaireActive;

  // Scoring & Évaluation
  final int scoreCredit;
  final ClientRisk niveauRisque;
  final double? capaciteEndettement;
  final double? tauxEndettement;
  final double? montantMaxAutorise;
  final DateTime? dateEvaluation;

  // Statut et dates
  final ClientStatus statut;
  final DateTime dateCreation;

  // Documents & Photos
  final String? photoPath;
  final String? documentCNIPath;
  final String? documentJustifDomicilePath;
  final String? photoCommercePath;
  final String? photoDomicilePath;

  // Géolocalisation
  final double? latitude;
  final double? longitude;

  // Agence & Gestion
  final String? agence;
  final String? agentAffecte;

  // Épargne
  final bool epargneObligatoireOuverte;

  Client({
    this.id,
    required this.numeroClient,
    required this.nom,
    required this.prenoms,
    this.dateNaissance,
    this.lieuNaissance,
    required this.sexe,
    this.numeroCNI,
    this.numeroPasseport,
    this.telephone,
    this.email,
    this.whatsapp,
    this.adresse,
    this.situationFamiliale,
    this.nombreEnfants,
    this.typeLogement,
    this.descriptionLogement,
    this.languesParlees,
    this.referenceNom1,
    this.referenceTel1,
    this.referenceRelation1,
    this.referenceNom2,
    this.referenceTel2,
    this.referenceRelation2,
    this.activitePrincipale,
    this.activitesSecondaires,
    this.revenusMensuels,
    this.chargesMensuelles,
    this.capaciteRemboursement,
    this.ancienneteActivite,
    this.lieuExerciceActivite,
    this.descriptionActivite,
    this.biensPatrimoine,
    this.groupeSolidaireId,
    this.cautionSolidaireActive = false,
    this.scoreCredit = 50,
    this.niveauRisque = ClientRisk.medium,
    this.capaciteEndettement,
    this.tauxEndettement,
    this.montantMaxAutorise,
    this.dateEvaluation,
    this.statut = ClientStatus.active,
    required this.dateCreation,
    this.photoPath,
    this.documentCNIPath,
    this.documentJustifDomicilePath,
    this.photoCommercePath,
    this.photoDomicilePath,
    this.latitude,
    this.longitude,
    this.agence,
    this.agentAffecte,
    this.epargneObligatoireOuverte = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'numero_client': numeroClient,
      'nom': nom,
      'prenoms': prenoms,
      'date_naissance': dateNaissance?.toIso8601String().split('T')[0],
      'lieu_naissance': lieuNaissance,
      'sexe': sexe.name.toUpperCase(),
      'numero_cni': numeroCNI,
      'numero_passeport': numeroPasseport,
      'telephone': telephone,
      'email': email,
      'whatsapp': whatsapp,
      'adresse': adresse,
      'situation_familiale': situationFamiliale?.name,
      'nombre_enfants': nombreEnfants,
      'type_logement': typeLogement?.name,
      'description_logement': descriptionLogement,
      'langues_parlees': languesParlees,
      'reference_nom_1': referenceNom1,
      'reference_tel_1': referenceTel1,
      'reference_relation_1': referenceRelation1,
      'reference_nom_2': referenceNom2,
      'reference_tel_2': referenceTel2,
      'reference_relation_2': referenceRelation2,
      'activite_principale': activitePrincipale,
      'activites_secondaires': activitesSecondaires,
      'revenus_mensuels': revenusMensuels,
      'charges_mensuelles': chargesMensuelles,
      'capacite_remboursement': capaciteRemboursement,
      'anciennete_activite': ancienneteActivite,
      'lieu_exercice_activite': lieuExerciceActivite,
      'description_activite': descriptionActivite,
      'biens_patrimoine': biensPatrimoine,
      'groupe_solidaire_id': groupeSolidaireId,
      'caution_solidaire_active': cautionSolidaireActive ? 1 : 0,
      'score_credit': scoreCredit,
      'niveau_risque': _riskToLabel(niveauRisque),
      'capacite_endettement': capaciteEndettement,
      'taux_endettement': tauxEndettement,
      'montant_max_autorise': montantMaxAutorise,
      'date_evaluation': dateEvaluation?.toIso8601String(),
      'statut': _statusToLabel(statut),
      'date_creation': dateCreation.toIso8601String(),
      'photo_path': photoPath,
      'document_cni_path': documentCNIPath,
      'document_justif_domicile_path': documentJustifDomicilePath,
      'photo_commerce_path': photoCommercePath,
      'photo_domicile_path': photoDomicilePath,
      'latitude': latitude,
      'longitude': longitude,
      'agence': agence,
      'agent_affecte': agentAffecte,
      'epargne_obligatoire_ouverte': epargneObligatoireOuverte ? 1 : 0,
    };
  }

  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'],
      numeroClient: (map['numero_client'] ?? '').toString(),
      nom: (map['nom'] ?? '').toString(),
      prenoms: (map['prenoms'] ?? '').toString(),
      dateNaissance: map['date_naissance'] != null
          ? DateTime.parse(map['date_naissance'])
          : null,
      lieuNaissance: map['lieu_naissance'],
      sexe: map['sexe'] == 'F' ? ClientGender.f : ClientGender.m,
      numeroCNI: map['numero_cni'],
      numeroPasseport: map['numero_passeport'],
      telephone: map['telephone'],
      email: map['email'],
      whatsapp: map['whatsapp'],
      adresse: map['adresse'],
      situationFamiliale: map['situation_familiale'] != null
          ? SituationFamiliale.values.firstWhere(
              (e) => e.name == map['situation_familiale'],
              orElse: () => SituationFamiliale.celibataire,
            )
          : null,
      nombreEnfants: map['nombre_enfants'],
      typeLogement: map['type_logement'] != null
          ? TypeLogement.values.firstWhere(
              (e) => e.name == map['type_logement'],
              orElse: () => TypeLogement.locataire,
            )
          : null,
      descriptionLogement: map['description_logement'],
      languesParlees: map['langues_parlees'],
      referenceNom1: map['reference_nom_1'],
      referenceTel1: map['reference_tel_1'],
      referenceRelation1: map['reference_relation_1'],
      referenceNom2: map['reference_nom_2'],
      referenceTel2: map['reference_tel_2'],
      referenceRelation2: map['reference_relation_2'],
      activitePrincipale: map['activite_principale'],
      activitesSecondaires: map['activites_secondaires'],
      revenusMensuels: map['revenus_mensuels']?.toDouble(),
      chargesMensuelles: map['charges_mensuelles']?.toDouble(),
      capaciteRemboursement: map['capacite_remboursement']?.toDouble(),
      ancienneteActivite: map['anciennete_activite'],
      lieuExerciceActivite: map['lieu_exercice_activite'],
      descriptionActivite: map['description_activite'],
      biensPatrimoine: map['biens_patrimoine'],
      groupeSolidaireId: map['groupe_solidaire_id'],
      cautionSolidaireActive: map['caution_solidaire_active'] == 1,
      scoreCredit: map['score_credit'] ?? 50,
      niveauRisque: _labelToRisk(map['niveau_risque']),
      capaciteEndettement: map['capacite_endettement']?.toDouble(),
      tauxEndettement: map['taux_endettement']?.toDouble(),
      montantMaxAutorise: map['montant_max_autorise']?.toDouble(),
      dateEvaluation: map['date_evaluation'] != null
          ? DateTime.parse(map['date_evaluation'])
          : null,
      statut: _labelToStatus(map['statut']),
      dateCreation: DateTime.tryParse(map['date_creation']?.toString() ?? '') ?? DateTime.now(),
      photoPath: map['photo_path'],
      documentCNIPath: map['document_cni_path'],
      documentJustifDomicilePath: map['document_justif_domicile_path'],
      photoCommercePath: map['photo_commerce_path'],
      photoDomicilePath: map['photo_domicile_path'],
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      agence: map['agence'],
      agentAffecte: map['agent_affecte'],
      epargneObligatoireOuverte: map['epargne_obligatoire_ouverte'] == 1,
    );
  }

  static String _riskToLabel(ClientRisk risk) {
    switch (risk) {
      case ClientRisk.low:
        return 'Faible';
      case ClientRisk.medium:
        return 'Moyen';
      case ClientRisk.high:
        return 'Élevé';
    }
  }

  static ClientRisk _labelToRisk(String? label) {
    switch (label) {
      case 'Faible':
        return ClientRisk.low;
      case 'Élevé':
        return ClientRisk.high;
      default:
        return ClientRisk.medium;
    }
  }

  static String _statusToLabel(ClientStatus status) {
    switch (status) {
      case ClientStatus.active:
        return 'Actif';
      case ClientStatus.inactive:
        return 'Inactif';
      case ClientStatus.blacklisted:
        return 'Blacklisté';
    }
  }

  static ClientStatus _labelToStatus(String? label) {
    switch (label) {
      case 'Inactif':
        return ClientStatus.inactive;
      case 'Blacklisté':
        return ClientStatus.blacklisted;
      default:
        return ClientStatus.active;
    }
  }
}
