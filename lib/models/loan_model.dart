// lib/models/loan_model.dart

import 'client_model.dart';
import 'produit_financier_model.dart';

enum LoanStatus {
  aJour('À jour'),
  alerte('Alerte'),
  retard('Retard'),
  contentieux('Contentieux'),
  perte('Passé en perte');

  final String label;
  const LoanStatus(this.label);
}

class Loan {
  final int? id;
  final int demandePretId;
  final int clientId;
  final int produitId;
  final String numeroPret;
  final double montantInitial;
  final double soldeRestant;
  final DateTime dateDeblocage;
  final DateTime? dateEcheanceProchaine;
  final int joursRetard;
  final LoanStatus statut;
  final String? agentGestionnaire;
  final String? agenceGestion;
  final int? moisDiffereCapital;

  // Objets joints (chargés à la demande)
  final Client? client;
  final ProduitFinancier? produit;

  Loan({
    this.id,
    required this.demandePretId,
    required this.clientId,
    required this.produitId,
    required this.numeroPret,
    required this.montantInitial,
    required this.soldeRestant,
    required this.dateDeblocage,
    this.dateEcheanceProchaine,
    this.joursRetard = 0,
    required this.statut,
    this.agentGestionnaire,
    this.agenceGestion,
    this.moisDiffereCapital = 0,
    this.client,
    this.produit,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'demande_pret_id': demandePretId,
      'client_id': clientId,
      'produit_id': produitId,
      'numero_pret': numeroPret,
      'montant_initial': montantInitial,
      'solde_restant': soldeRestant,
      'date_deblocage': dateDeblocage.toIso8601String(),
      'date_echeance_prochaine': dateEcheanceProchaine?.toIso8601String(),
      'jours_retard': joursRetard,
      'statut': statut.name,
      'agent_gestionnaire': agentGestionnaire,
      'agence_gestion': agenceGestion,
      'mois_differe_capital': moisDiffereCapital ?? 0,
    };
  }

  factory Loan.fromMap(
    Map<String, dynamic> map, {
    Client? client,
    ProduitFinancier? produit,
  }) {
    return Loan(
      id: map['id'],
      demandePretId: map['demande_pret_id'],
      clientId: map['client_id'],
      produitId: map['produit_id'],
      numeroPret: map['numero_pret'],
      montantInitial: map['montant_initial'],
      soldeRestant: map['solde_restant'],
      dateDeblocage: DateTime.parse(map['date_deblocage']),
      dateEcheanceProchaine: map['date_echeance_prochaine'] != null
          ? DateTime.parse(map['date_echeance_prochaine'])
          : null,
      joursRetard: map['jours_retard'] ?? 0,
      statut: LoanStatus.values.firstWhere(
        (e) => e.name == map['statut'],
        orElse: () => LoanStatus.aJour,
      ),
      agentGestionnaire: map['agent_gestionnaire'],
      agenceGestion: map['agence_gestion'],
      moisDiffereCapital: map['mois_differe_capital'] ?? 0,
      client: client,
      produit: produit,
    );
  }
  double calculatePenalties() {
    // Calcul simple : 1% du solde par jour de retard après 3 jours de grâce
    if (joursRetard <= 3) return 0;
    return soldeRestant * 0.01 * (joursRetard - 3);
  }
}
