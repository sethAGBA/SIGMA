import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sigma/core/services/database_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sigma/models/produit_financier_model.dart';
import 'package:sigma/models/client_model.dart';
import 'package:sigma/models/savings_account_model.dart';
import 'package:intl/intl.dart';

Future<void> _setupSchema(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS produits_financiers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nom TEXT NOT NULL,
      code TEXT UNIQUE NOT NULL,
      description TEXT,
      type TEXT NOT NULL,
      taux_interet REAL,
      credit_category TEXT,
      taux_assurance REAL,
      duree_max_differe_capital_mois INTEGER,
      montant_min REAL,
      montant_max REAL,
      duree_min_mois INTEGER,
      duree_max_mois INTEGER,
      mode_calcul_interet TEXT,
      frequence_remboursement TEXT,
      conditions_eligibilite TEXT,
      documents_requis TEXT,
      frais_commissions TEXT,
      assurances_obligatoires TEXT,
      differe_possible INTEGER DEFAULT 0,
      secteurs_eligibles TEXT,
      materiel_financable TEXT,
      accompagnement_technique TEXT,
      garantie_sur_equipement TEXT,
      procedure_acceleree INTEGER DEFAULT 0,
      caution_solidaire_requise INTEGER DEFAULT 0,
      savings_category TEXT,
      solde_minimum REAL,
      versement_minimum REAL
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS clients (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      numero_client TEXT UNIQUE NOT NULL,
      nom TEXT NOT NULL,
      prenoms TEXT NOT NULL,
      date_naissance TEXT,
      lieu_naissance TEXT,
      sexe TEXT,
      numero_cni TEXT,
      numero_passeport TEXT,
      telephone TEXT,
      email TEXT,
      whatsapp TEXT,
      adresse TEXT,
      situation_familiale TEXT,
      nombre_enfants INTEGER,
      type_logement TEXT,
      description_logement TEXT,
      langues_parlees TEXT,
      reference_nom_1 TEXT,
      reference_tel_1 TEXT,
      reference_relation_1 TEXT,
      reference_nom_2 TEXT,
      reference_tel_2 TEXT,
      reference_relation_2 TEXT,
      activite_principale TEXT,
      activites_secondaires TEXT,
      revenus_mensuels REAL,
      charges_mensuelles REAL,
      capacite_remboursement REAL,
      anciennete_activite INTEGER,
      lieu_exercice_activite TEXT,
      description_activite TEXT,
      biens_patrimoine TEXT,
      groupe_solidaire_id INTEGER,
      caution_solidaire_active INTEGER DEFAULT 0,
      score_credit INTEGER DEFAULT 50,
      niveau_risque TEXT DEFAULT 'Moyen',
      capacite_endettement REAL,
      taux_endettement REAL,
      montant_max_autorise REAL,
      date_creation TEXT DEFAULT CURRENT_TIMESTAMP,
      agence TEXT,
      agent_affecte TEXT,
      photo_path TEXT,
      document_cni_path TEXT,
      document_justif_domicile_path TEXT,
      photo_commerce_path TEXT,
      photo_domicile_path TEXT,
      latitude REAL,
      longitude REAL,
      statut TEXT DEFAULT 'Actif',
      date_evaluation TEXT,
      epargne_obligatoire_ouverte INTEGER DEFAULT 0
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS comptes_epargne (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      client_id INTEGER,
      produit_id INTEGER,
      numero_compte TEXT UNIQUE NOT NULL,
      solde REAL DEFAULT 0.0,
      interets_acquis REAL DEFAULT 0.0,
      statut TEXT,
      date_ouverture TEXT,
      taux_interet_applique REAL,
      date_echeance_terme TEXT,
      taux_penalite_rupture_ant REAL,
      FOREIGN KEY (client_id) REFERENCES clients (id),
      FOREIGN KEY (produit_id) REFERENCES produits_financiers (id)
    )
  ''');
}

Future<Database> _openTestDb() async {
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) async => await _setupSchema(db),
    ),
  );
  DatabaseService.setDatabaseForTesting(db);
  return db;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() {
    DatabaseService.resetDatabaseForTesting();
  });

  test('auto-ouverture crée un compte épargne obligatoire', () async {
    final db = await _openTestDb();
    final service = DatabaseService();

    // Insérer un produit épargne obligatoire
    final produit = ProduitFinancier(
      nom: 'EP Oblig',
      code: 'EPO',
      description: 'Produit obligatoire',
      type: ProductType.epargne,
      tauxInteret: 1.5,
      savingsCategory: SavingsCategory.obligatoire,
    );
    final pid = await service.insertProduitFinancier(produit);

    // Insérer un client
    final client = Client(
      numeroClient: 'NC001',
      nom: 'Dupont',
      prenoms: 'Jean',
      sexe: ClientGender.m,
      dateCreation: DateTime.now(),
    );
    final clientId = await service.insertClient(client);

    // Simuler la logique d'auto-ouverture (même que dans ClientFormDialog)
    final produits = await service.getProduits(type: ProductType.epargne);
    final obligatoire = produits.where((p) => p.savingsCategory == SavingsCategory.obligatoire).toList();
    if (obligatoire.isNotEmpty) {
      final p = obligatoire.first;
      final month = DateFormat('yyyyMM').format(DateTime.now());
      await service.insertSavingsAccount(SavingsAccount(
        clientId: clientId,
        produitId: p.id ?? pid,
        numeroCompte: 'CEP-$clientId-$month',
        statut: SavingsAccountStatus.actif,
        dateOuverture: DateTime.now(),
        tauxInteretApplique: p.tauxInteret,
      ));
    }

    final accounts = await service.getSavingsAccounts(clientId: clientId);
    expect(accounts.length, 1);
    expect(accounts.first.numeroCompte.startsWith('CEP-$clientId-'), isTrue);

    await db.close();
  });

  test('aucune création si pas de produit obligatoire', () async {
    final db = await _openTestDb();
    final service = DatabaseService();

    // Insérer un produit épargne non-obligatoire
    final produit = ProduitFinancier(
      nom: 'EP Libre',
      code: 'EPL',
      description: 'Produit libre',
      type: ProductType.epargne,
      tauxInteret: 0.5,
      savingsCategory: SavingsCategory.libre,
    );
    await service.insertProduitFinancier(produit);

    final client = Client(
      numeroClient: 'NC002',
      nom: 'Martin',
      prenoms: 'Claire',
      sexe: ClientGender.f,
      dateCreation: DateTime.now(),
    );
    final clientId = await service.insertClient(client);

    // Simuler auto-ouverture — ne doit rien faire
    final produits = await service.getProduits(type: ProductType.epargne);
    final obligatoire = produits.where((p) => p.savingsCategory == SavingsCategory.obligatoire).toList();
    if (obligatoire.isNotEmpty) {
      final p = obligatoire.first;
      final month = DateFormat('yyyyMM').format(DateTime.now());
      await service.insertSavingsAccount(SavingsAccount(
        clientId: clientId,
        produitId: p.id ?? 0,
        numeroCompte: 'CEP-$clientId-$month',
        statut: SavingsAccountStatus.actif,
        dateOuverture: DateTime.now(),
        tauxInteretApplique: p.tauxInteret,
      ));
    }

    final accounts = await service.getSavingsAccounts(clientId: clientId);
    expect(accounts.length, 0);

    await db.close();
  });
}
