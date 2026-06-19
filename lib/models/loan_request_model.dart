// lib/models/loan_request_model.dart

import 'client_model.dart';
import 'produit_financier_model.dart';

enum LoanRequestStatus {
  brouillon,
  soumise,
  enAnalyse,
  enComite,
  approuvee,
  rejetee,
  debloquee;

  String get label {
    switch (this) {
      case brouillon:
        return 'Brouillon';
      case soumise:
        return 'Soumise';
      case enAnalyse:
        return 'En analyse';
      case enComite:
        return 'En comité';
      case approuvee:
        return 'Approuvée';
      case rejetee:
        return 'Rejetée';
      case debloquee:
        return 'Débloquée';
    }
  }
}

class LoanRequest {
  final int? id;
  final int clientId;
  final int produitId;
  final double montantDemande;
  final int dureeMois;
  final RepaymentFrequency frequenceRemboursement;
  final String objetPret;

  // Simulation results
  final double mensualite;
  final double totalARembourser;
  final double coutTotalCredit;
  final double teg; // Taux Effectif Global
  final int moisDiffereCapital;

  // Analyse financière
  final double revenusMensuels;
  final double chargesMensuelles;
  final double capaciteRemboursement;
  final double tauxEffort;
  final double autresDettes;
  final double resteAVivre;

  // Garanties
  final String? typeGarantie;
  final String? descriptionGarantie;
  final double? valeurGarantie;
  final String? cautionPersonnelle;

  // Visite & Score
  final String? rapportVisite;
  final String? observationsVisite;
  final String? photosVisite; // Chemins séparés par virgules
  final int scoreCalcule;
  final String? recommandationSysteme;

  // Circuit de Décision
  final String? avisAgent;
  final String? avisChefAgence;
  final String? avisComite;

  // Documents Joints
  final String?
  documentsDossier; // Chemins séparés par virgules (CNI, Contrat, etc.)

  LoanRequestStatus statut;
  final DateTime dateCreation;
  DateTime? dateModification;
  String? motifRejet;

  // Relations (peuvent être nulles si non chargées)
  final Client? client;
  final ProduitFinancier? produit;

  LoanRequest({
    this.id,
    required this.clientId,
    required this.produitId,
    required this.montantDemande,
    required this.dureeMois,
    required this.frequenceRemboursement,
    required this.objetPret,
    required this.mensualite,
    required this.totalARembourser,
    required this.coutTotalCredit,
    required this.teg,
    this.moisDiffereCapital = 0,
    this.revenusMensuels = 0,
    this.chargesMensuelles = 0,
    this.capaciteRemboursement = 0,
    this.tauxEffort = 0,
    this.autresDettes = 0,
    this.resteAVivre = 0,
    this.typeGarantie,
    this.descriptionGarantie,
    this.valeurGarantie,
    this.cautionPersonnelle,
    this.rapportVisite,
    this.observationsVisite,
    this.photosVisite,
    this.scoreCalcule = 0,
    this.recommandationSysteme,
    this.avisAgent,
    this.avisChefAgence,
    this.avisComite,
    this.documentsDossier,
    this.statut = LoanRequestStatus.brouillon,
    required this.dateCreation,
    this.dateModification,
    this.motifRejet,
    this.client,
    this.produit,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'client_id': clientId,
      'produit_id': produitId,
      'montant_demande': montantDemande,
      'duree_mois': dureeMois,
      'frequence_remboursement': frequenceRemboursement.name,
      'objet_pret': objetPret,
      'mensualite': mensualite,
      'total_a_rembourser': totalARembourser,
      'cout_total_credit': coutTotalCredit,
      'teg': teg,
      'mois_differe_capital': moisDiffereCapital,
      'revenus_mensuels': revenusMensuels,
      'charges_mensuelles': chargesMensuelles,
      'capacite_remboursement': capaciteRemboursement,
      'taux_effort': tauxEffort,
      'autres_dettes': autresDettes,
      'reste_a_vivre': resteAVivre,
      'type_garantie': typeGarantie,
      'description_garantie': descriptionGarantie,
      'valeur_garantie': valeurGarantie,
      'caution_personnelle': cautionPersonnelle,
      'rapport_visite': rapportVisite,
      'observations_visite': observationsVisite,
      'photos_visite': photosVisite,
      'score_calcule': scoreCalcule,
      'recommandation_systeme': recommandationSysteme,
      'avis_agent': avisAgent,
      'avis_chef_agence': avisChefAgence,
      'avis_comite': avisComite,
      'documents_dossier': documentsDossier,
      'statut': statut.name,
      'date_creation': dateCreation.toIso8601String(),
      'date_modification': dateModification?.toIso8601String(),
      'motif_rejet': motifRejet,
    };
  }

  factory LoanRequest.fromMap(
    Map<String, dynamic> map, {
    Client? client,
    ProduitFinancier? produit,
  }) {
    return LoanRequest(
      id: map['id'],
      clientId: map['client_id'],
      produitId: map['produit_id'],
      montantDemande: map['montant_demande'],
      dureeMois: map['duree_mois'],
      frequenceRemboursement: RepaymentFrequency.values.byName(
        map['frequence_remboursement'],
      ),
      objetPret: map['objet_pret'],
      mensualite: map['mensualite'],
      totalARembourser: map['total_a_rembourser'],
      coutTotalCredit: map['cout_total_credit'],
      teg: map['teg'],
      moisDiffereCapital: map['mois_differe_capital'] ?? 0,
      revenusMensuels: map['revenus_mensuels'] ?? 0,
      chargesMensuelles: map['charges_mensuelles'] ?? 0,
      capaciteRemboursement: map['capacite_remboursement'] ?? 0,
      tauxEffort: map['taux_effort'] ?? 0,
      autresDettes: map['autres_dettes'] ?? 0,
      resteAVivre: map['reste_a_vivre'] ?? 0,
      typeGarantie: map['type_garantie'],
      descriptionGarantie: map['description_garantie'],
      valeurGarantie: map['valeur_garantie'],
      cautionPersonnelle: map['caution_personnelle'],
      rapportVisite: map['rapport_visite'],
      observationsVisite: map['observations_visite'],
      photosVisite: map['photos_visite'],
      scoreCalcule: map['score_calcule'] ?? 0,
      recommandationSysteme: map['recommandation_systeme'],
      avisAgent: map['avis_agent'],
      avisChefAgence: map['avis_chef_agence'],
      avisComite: map['avis_comite'],
      documentsDossier: map['documents_dossier'],
      statut: LoanRequestStatus.values.byName(map['statut']),
      dateCreation: DateTime.parse(map['date_creation']),
      dateModification: map['date_modification'] != null
          ? DateTime.parse(map['date_modification'])
          : null,
      motifRejet: map['motif_rejet'],
      client: client,
      produit: produit,
    );
  }
}
