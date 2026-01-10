// lib/core/services/financial_statements_service.dart

import '../services/database_service.dart';
import '../../models/financial_statements/bilan_model.dart';
import '../../models/financial_statements/compte_resultat_model.dart';
import '../../models/financial_statements/flux_tresorerie_model.dart';
import '../../models/accounting_config_model.dart';

class FinancialStatementsService {
  final DatabaseService _dbService = DatabaseService();

  /// Génère le Bilan à une date donnée (solde cumulé)
  Future<Bilan> generateBilan({DateTime? dateFin}) async {
    final date = dateFin ?? DateTime.now();
    final db = await _dbService.database;
    final config = await _dbService.getAccountingConfig();

    // Calculer les soldes de tous les comptes jusqu'à la date de fin
    final List<Map<String, dynamic>> results = await db.rawQuery(
      '''
      SELECT 
        compte_numero,
        SUM(debit) as total_debit,
        SUM(credit) as total_credit
      FROM lignes_ecriture l
      JOIN ecritures e ON l.ecriture_id = e.id
      WHERE e.date_comptable <= ?
      GROUP BY compte_numero
    ''',
      [date.toIso8601String()],
    );

    double actifImmolilise = 0;
    double actifCirculant = 0;
    double portefeuilleCredits = 0;
    double provisionsCreances = 0;
    double tresorerie = 0;
    double autresActifs = 0;

    double capitauxPropres = 0;
    double dettesFinancieres = 0;
    double epargneClientele = 0;
    double autresDettes = 0;

    // Helper to check if account matches config (using startsWith for flexibility)
    bool matches(String account, String configAccount) =>
        account.startsWith(configAccount);

    for (var row in results) {
      final numero = row['compte_numero'] as String;
      final debit = (row['total_debit'] as num).toDouble();
      final credit = (row['total_credit'] as num).toDouble();
      final solde = debit - credit;

      if (matches(numero, config.comptePrets)) {
        portefeuilleCredits += solde;
      } else if (matches(numero, config.compteBanque) ||
          matches(numero, config.compteCaisse)) {
        tresorerie += solde;
      } else if (numero.startsWith('2')) {
        actifImmolilise += solde;
      } else if (numero.startsWith('1')) {
        // CLASSE 1: RESSOURCES DURABLES
        if (matches(numero, config.compteDepots)) {
          // Depots et cautionnements reçus -> Epargne
          epargneClientele += -solde;
        } else if (numero.startsWith('10') ||
            numero.startsWith('11') ||
            numero.startsWith('12') ||
            numero.startsWith('13') ||
            numero.startsWith('14') ||
            numero.startsWith('15')) {
          // 10-15: Capitaux Propres
          capitauxPropres += -solde;
        } else {
          // 16 (hors depots), 17, 18, 19: Dettes Financières
          dettesFinancieres += -solde;
        }
      } else if (numero.startsWith('4')) {
        if (solde > 0) {
          actifCirculant += solde;
        } else {
          autresDettes += -solde;
        }
      } else if (numero.startsWith('5')) {
        // Autres comptes de classe 5 (hors banque/caisse traités plus haut)
        tresorerie += solde;
      } else {
        if (solde > 0) {
          autresActifs += solde;
        } else {
          autresDettes += -solde;
        }
      }
    }

    return Bilan(
      actif: BilanActif(
        actifImmobilise: actifImmolilise,
        actifCirculant: actifCirculant,
        portefeuilleCredits: portefeuilleCredits,
        provisionsCreances: provisionsCreances,
        tresorerie: tresorerie,
        autresActifs: autresActifs,
      ),
      passif: BilanPassif(
        capitauxPropres: capitauxPropres,
        dettesFinancieres: dettesFinancieres,
        epargneClientele: epargneClientele,
        autresDettes: autresDettes,
      ),
      dateDebut: DateTime(2000), // Historique complet
      dateFin: date,
    );
  }

  /// Génère le Compte de Résultat pour une période donnée
  Future<CompteResultat> generateCompteResultat({
    required DateTime dateDebut,
    required DateTime dateFin,
  }) async {
    final db = await _dbService.database;
    final config = await _dbService.getAccountingConfig();

    final List<Map<String, dynamic>> results = await db.rawQuery(
      '''
      SELECT 
        compte_numero,
        SUM(debit) as total_debit,
        SUM(credit) as total_credit
      FROM lignes_ecriture l
      JOIN ecritures e ON l.ecriture_id = e.id
      WHERE e.date_comptable >= ? AND e.date_comptable <= ?
      GROUP BY compte_numero
    ''',
      [dateDebut.toIso8601String(), dateFin.toIso8601String()],
    );

    double interetsPrets = 0; // Revenus financiers
    double commissions = 0; // Vente Services
    double penalites = 0; // Penalités
    double autresProduits = 0;

    double interetsEpargne = 0;
    double chargesPersonnel = 0;
    double chargesFonctionnement = 0;
    double dotationsProvisions = 0;
    double autresCharges = 0;

    bool matches(String account, String configAccount) =>
        account.startsWith(configAccount);

    for (var row in results) {
      final numero = row['compte_numero'] as String;
      final debit = (row['total_debit'] as num).toDouble();
      final credit = (row['total_credit'] as num).toDouble();

      if (numero.startsWith('7')) {
        // PRODUITS (Crédit - Débit)
        final solde = credit - debit;
        if (matches(numero, config.compteProduitsFinanciers) ||
            matches(numero, config.compteInterets)) {
          interetsPrets += solde; // Revenus financiers (Intérêts)
        } else if (matches(numero, config.compteVenteServices)) {
          commissions += solde; // Ventes/Services (Commissions)
        } else if (matches(numero, config.comptePenalites)) {
          penalites += solde;
        } else {
          autresProduits += solde;
        }
      } else if (numero.startsWith('6')) {
        // CHARGES (Débit - Crédit)
        final solde = debit - credit;
        if (matches(numero, config.compteChargeInteretEpargne) ||
            numero.startsWith('67')) {
          // Frais Financiers (Interets Epargne / Emprunts)
          interetsEpargne += solde;
        } else if (numero.startsWith('66')) {
          // Charges de Personnel
          chargesPersonnel += solde;
        } else if (matches(numero, config.compteDotationProvisions) ||
            matches(numero, config.compteDepreciationPrets) ||
            numero.startsWith('68') ||
            numero.startsWith('69')) {
          // Dotations aux amortissements et provisions
          dotationsProvisions += solde;
        } else {
          // 60, 61, 62, 63, 64, 65: Autres charges fonctionnement
          chargesFonctionnement += solde;
        }
      }
    }

    return CompteResultat(
      produits: Produits(
        interetsPrets: interetsPrets,
        commissions: commissions,
        penalites: penalites,
        autresProduits: autresProduits,
      ),
      charges: Charges(
        interetsEpargne: interetsEpargne,
        chargesPersonnel: chargesPersonnel,
        chargesFonctionnement: chargesFonctionnement,
        dotationsProvisions: dotationsProvisions,
        autresCharges: autresCharges,
      ),
      dateDebut: dateDebut,
      dateFin: dateFin,
    );
  }

  /// Génère le Tableau de Flux de Trésorerie
  Future<TableauFlux> generateTableauFlux({
    required DateTime dateDebut,
    required DateTime dateFin,
  }) async {
    final db = await _dbService.database;
    final config = await _dbService.getAccountingConfig();

    String caissePrefix = config.compteCaisse;
    String banquePrefix = config.compteBanque;

    // Trésorerie début (Banque + Caisse)
    final resDebut = await db.rawQuery(
      '''
      SELECT SUM(debit - credit) as solde
      FROM lignes_ecriture l
      JOIN ecritures e ON l.ecriture_id = e.id
      WHERE e.date_comptable < ? AND (compte_numero LIKE '$caissePrefix%' OR compte_numero LIKE '$banquePrefix%')
    ''',
      [dateDebut.toIso8601String()],
    );
    final double tresorerieDebut =
        (resDebut.first['solde'] as num?)?.toDouble() ?? 0.0;

    // Trésorerie fin (Banque + Caisse)
    final resFin = await db.rawQuery(
      '''
      SELECT SUM(debit - credit) as solde
      FROM lignes_ecriture l
      JOIN ecritures e ON l.ecriture_id = e.id
      WHERE e.date_comptable <= ? AND (compte_numero LIKE '$caissePrefix%' OR compte_numero LIKE '$banquePrefix%')
    ''',
      [dateFin.toIso8601String()],
    );
    final double tresorerieFin =
        (resFin.first['solde'] as num?)?.toDouble() ?? 0.0;

    // Flux de la période
    final List<Map<String, dynamic>> movements = await db.rawQuery(
      '''
      SELECT 
        e.libelle,
        l.debit,
        l.credit,
        l.compte_numero
      FROM lignes_ecriture l
      JOIN ecritures e ON l.ecriture_id = e.id
      WHERE e.date_comptable >= ? AND e.date_comptable <= ?
      AND e.id IN (SELECT ecriture_id FROM lignes_ecriture WHERE compte_numero LIKE '$caissePrefix%' OR compte_numero LIKE '$banquePrefix%')
      AND (l.compte_numero NOT LIKE '$caissePrefix%' AND l.compte_numero NOT LIKE '$banquePrefix%')
    ''',
      [dateDebut.toIso8601String(), dateFin.toIso8601String()],
    );

    double encaissementsClients = 0;
    double decaissementsPrets = 0;
    double depotsEpargne = 0;
    double retraitsEpargne = 0;
    double autresFluxOperationnels = 0;

    for (var mov in movements) {
      final debit = (mov['debit'] as num).toDouble();
      final credit = (mov['credit'] as num).toDouble();
      final compte = mov['compte_numero'] as String;

      if (compte.startsWith(config.comptePrets)) {
        // Flux lié aux prêts
        decaissementsPrets += debit; // Prêt décaissé
        encaissementsClients += credit; // Remboursement
      } else if (compte.startsWith(config.compteDepots)) {
        // Flux lié à l'épargne (Dépôts)
        depotsEpargne += credit; // Dépôt
        retraitsEpargne += debit; // Retrait
      } else {
        autresFluxOperationnels += (credit - debit);
      }
    }

    return TableauFlux(
      fluxOperationnels: FluxOperationnels(
        encaissementsClients: encaissementsClients,
        decaissementsPrets: decaissementsPrets,
        depotsEpargne: depotsEpargne,
        retraitsEpargne: retraitsEpargne,
        autresFluxOperationnels: autresFluxOperationnels,
      ),
      fluxInvestissement: FluxInvestissement(
        acquisitionsImmobilisations: 0,
        cessionsActifs: 0,
        autresFluxInvestissement: 0,
      ),
      tresorerieDebut: tresorerieDebut,
      tresorerieFin: tresorerieFin,
      dateDebut: dateDebut,
      dateFin: dateFin,
    );
  }
}
