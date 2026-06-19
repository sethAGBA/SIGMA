// lib/models/savings_account_model.dart

import 'client_model.dart';
import 'produit_financier_model.dart';

enum SavingsAccountStatus {
  actif('Actif'),
  bloque('Bloqué'),
  ferme('Fermé');

  final String label;
  const SavingsAccountStatus(this.label);
}

class SavingsAccount {
  final int? id;
  final int clientId;
  final int produitId;
  final String numeroCompte;
  final double solde;
  final double interetsAcquis;
  final SavingsAccountStatus statut;
  final DateTime dateOuverture;
  final double? tauxInteretApplique;
  final DateTime? dateEcheanceTerme;
  final double? tauxPenaliteRuptureAnt;

  // Relations optionnelles (chargées via join)
  final Client? client;
  final ProduitFinancier? produit;

  SavingsAccount({
    this.id,
    required this.clientId,
    required this.produitId,
    required this.numeroCompte,
    this.solde = 0.0,
    this.interetsAcquis = 0.0,
    required this.statut,
    required this.dateOuverture,
    this.tauxInteretApplique,
    this.dateEcheanceTerme,
    this.tauxPenaliteRuptureAnt,
    this.client,
    this.produit,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'client_id': clientId,
      'produit_id': produitId,
      'numero_compte': numeroCompte,
      'solde': solde,
      'interets_acquis': interetsAcquis,
      'statut': statut.name,
      'date_ouverture': dateOuverture.toIso8601String(),
      'taux_interet_applique': tauxInteretApplique,
      'date_echeance_terme': dateEcheanceTerme?.toIso8601String(),
      'taux_penalite_rupture_ant': tauxPenaliteRuptureAnt,
    };
  }

  factory SavingsAccount.fromMap(
    Map<String, dynamic> map, {
    Client? client,
    ProduitFinancier? produit,
  }) {
    return SavingsAccount(
      id: map['id'],
      clientId: map['client_id'],
      produitId: map['produit_id'],
      numeroCompte: map['numero_compte'],
      solde: (map['solde'] as num).toDouble(),
      interetsAcquis: (map['interets_acquis'] as num).toDouble(),
      statut: SavingsAccountStatus.values.firstWhere(
        (e) => e.name == map['statut'],
        orElse: () => SavingsAccountStatus.actif,
      ),
      dateOuverture: DateTime.parse(map['date_ouverture']),
      tauxInteretApplique: map['taux_interet_applique'] != null
          ? (map['taux_interet_applique'] as num).toDouble()
          : null,
      dateEcheanceTerme: map['date_echeance_terme'] != null
          ? DateTime.parse(map['date_echeance_terme'])
          : null,
      tauxPenaliteRuptureAnt: map['taux_penalite_rupture_ant'] != null
          ? (map['taux_penalite_rupture_ant'] as num).toDouble()
          : null,
      client: client,
      produit: produit,
    );
  }
}
