# Implementation Plan: Phase 0 — Infrastructure réseau

## Overview

Cette phase connecte l'application Flutter SIGMA Micro-Finance à son backend FastAPI/PostgreSQL sur le LAN local en quatre axes : migrations Alembic versionnées, neuf services API Flutter, enrichissement du `ConnectivityMonitor` avec `connectivity_plus`, et configuration de l'URL serveur dans les Paramètres (accès ADMIN uniquement).

---

## Tasks

- [x] 1. Axe A — Migrations Alembic (10 domaines métier)

  - [x] 1.1 Créer `backend/alembic/versions/001_utilisateurs.py`
    - Créer table `utilisateurs_systeme` avec colonnes : `id (String PK)`, `agent_id`, `username (unique, index)`, `password_hash`, `role`, `is_active`, `created_at`, `permissions`, `last_login`
    - `upgrade()` : `op.create_table()` + `op.create_index('ix_utilisateurs_username', unique=True)`
    - `downgrade()` : `op.drop_index()` + `op.drop_table()`
    - `revision = 'a1b2c3d4'`, `down_revision = None`
    - _Requirements: 1.1, 1.2, 1.4_

  - [x] 1.2 Créer `backend/alembic/versions/002_agences_agents.py`
    - Créer tables `agencies` et `agents` selon `backend/app/models/agency.py` et `agent.py`
    - `upgrade()` : créer `agencies` puis `agents` (FK vers `agencies.id`)
    - `downgrade()` : drop dans l'ordre inverse
    - `revision = 'b2c3d4e5'`, `down_revision = 'a1b2c3d4'`
    - _Requirements: 1.1, 1.2, 1.4_

  - [x] 1.3 Créer `backend/alembic/versions/003_produits.py`
    - Créer table `produits_financiers` selon `backend/app/models/produit_financier.py`
    - `revision = 'c3d4e5f6'`, `down_revision = 'b2c3d4e5'`
    - _Requirements: 1.1, 1.2, 1.4_

  - [x] 1.4 Créer `backend/alembic/versions/004_clients.py`
    - Créer table `clients` selon `backend/app/models/client.py`
    - `revision = 'd4e5f6a7'`, `down_revision = 'c3d4e5f6'`
    - _Requirements: 1.1, 1.2, 1.4_

  - [x] 1.5 Créer `backend/alembic/versions/005_groupes_solidaires.py`
    - Créer table `groupes_solidaires` et table de liaison `groupe_membres` selon `backend/app/models/groupe_solidaire.py`
    - FK vers `clients.id`
    - `revision = 'e5f6a7b8'`, `down_revision = 'd4e5f6a7'`
    - _Requirements: 1.1, 1.2, 1.4_

  - [x] 1.6 Créer `backend/alembic/versions/006_prets_remboursements.py`
    - Créer tables : `demandes_pret`, `prets`, `echeanciers`, `remboursements` selon `backend/app/models/pret.py` et `remboursement.py`
    - FK : `prets.client_id → clients.id`, `prets.produit_id → produits_financiers.id`, `prets.groupe_id → groupes_solidaires.id`
    - `revision = 'f6a7b8c9'`, `down_revision = 'e5f6a7b8'`
    - _Requirements: 1.1, 1.2, 1.4_

  - [x] 1.7 Créer `backend/alembic/versions/007_epargne.py`
    - Créer tables `comptes_epargne`, `transactions_epargne` selon `backend/app/models/epargne.py`
    - FK : `comptes_epargne.client_id → clients.id`, `comptes_epargne.produit_id → produits_financiers.id`
    - `revision = 'a7b8c9d0'`, `down_revision = 'f6a7b8c9'`
    - _Requirements: 1.1, 1.2, 1.4_

  - [x] 1.8 Créer `backend/alembic/versions/008_caisse.py`
    - Créer tables `operations_caisse`, `clotures_caisse` selon `backend/app/models/caisse.py`
    - Aucune FK externe
    - `revision = 'b8c9d0e1'`, `down_revision = 'a7b8c9d0'`
    - _Requirements: 1.1, 1.2_

  - [x] 1.9 Créer `backend/alembic/versions/009_comptabilite.py`
    - Créer tables `comptes_comptables`, `journaux`, `ecritures`, `lignes_ecriture` selon `backend/app/models/comptabilite.py`
    - FK internes uniquement (`lignes_ecriture.ecriture_id → ecritures.id`)
    - `revision = 'c9d0e1f2'`, `down_revision = 'b8c9d0e1'`
    - _Requirements: 1.1, 1.2_

  - [x] 1.10 Créer `backend/alembic/versions/010_configuration_audit.py`
    - Créer tables `configurations (key PK, value TEXT)` et `audit_logs` selon `backend/app/models/audit_log.py`
    - Aucune FK externe
    - `revision = 'd0e1f2a3'`, `down_revision = 'c9d0e1f2'`
    - _Requirements: 1.1, 1.2_

  - [ ]* 1.11 Écrire tests d'intégration des migrations Alembic
    - Créer `backend/tests/test_migrations.py` avec `pytest` + connexion PostgreSQL de test
    - Tester `alembic upgrade head` sur base vide → toutes les tables créées sans erreur
    - Tester `alembic downgrade -1` depuis head → rollback propre, tables des autres domaines intactes
    - Tester idempotence : deux `upgrade head` successifs sans erreur
    - _Requirements: 1.2, 1.3, 1.5, 1.6_

- [x] 2. Checkpoint A — Vérifier les migrations
  - Activer le venv backend, lancer `alembic upgrade head` sur une base PostgreSQL de test
  - Vérifier que les 10 migrations s'appliquent sans erreur
  - Lancer `alembic downgrade base` pour vérifier le rollback complet
  - Corriger tout problème avant de continuer

- [x] 3. Axe B — Dépendance `connectivity_plus` dans Flutter

  - [x] 3.1 Ajouter `connectivity_plus: ^6.0.5` dans `pubspec.yaml`
    - Modifier la section `dependencies` de `pubspec.yaml`
    - Ajouter la ligne après `provider: ^6.1.2`
    - Lancer `flutter pub get` pour vérifier la résolution des dépendances
    - _Requirements: 3.1_

- [x] 4. Axe C — Enrichissement du `ConnectivityMonitor`

  - [x] 4.1 Modifier `lib/core/services/connectivity_monitor.dart` — ajouter `connectivity_plus`
    - Ajouter l'import `package:connectivity_plus/connectivity_plus.dart`
    - Ajouter le champ `StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription`
    - Dans `start()` : annuler l'ancienne subscription, créer l'abonnement `Connectivity().onConnectivityChanged.listen(_onConnectivityChanged)`
    - Implémenter `_onConnectivityChanged(List<ConnectivityResult> results)` :
      - Si `statusNotifier.value == ConnectivityStatus.syncing` → retourner immédiatement
      - Si `results` ne contient que `ConnectivityResult.none` → `statusNotifier.value = ConnectivityStatus.offline` (immédiat, sans attendre le timer)
      - Sinon → appeler `_checkAndTransition()`
    - Extraire `_checkAndTransition()` depuis `_onTick()` pour factoriser la logique commune
    - Dans `dispose()` : annuler `_connectivitySubscription`
    - _Requirements: 3.1, 3.2, 3.3, 3.5, 3.6_

  - [x] 4.2 Implémenter `_checkAndTransition()` avec séquence syncing→flush→online
    - Si `isServerAvailable()` retourne `false` → `statusNotifier.value = ConnectivityStatus.offline`
    - Si `isServerAvailable()` retourne `true` et statut courant est `offline` :
      - Passer à `syncing`
      - Appeler `await SyncService().flushPendingOperations()`
      - Passer à `online` (même si `result.failed > 0` — requirement 3.7)
    - Si `isServerAvailable()` retourne `true` et statut courant est déjà `online` → confirmer `online`
    - _Requirements: 3.4, 3.7_

  - [x]* 4.3 Écrire tests unitaires pour `ConnectivityMonitor`
    - Créer `test/core/services/connectivity_monitor_test.dart`
    - Mocker `ApiService().isServerAvailable()` et `SyncService().flushPendingOperations()`
    - **Property 8 :** événement `none` de `connectivity_plus` → `statusNotifier` passe à `offline` sans délai
    - **Property 9 :** événement non-none → `isServerAvailable()` appelé immédiatement
    - **Property 10 :** transition `offline→online` suit la séquence `syncing` → flush → `online`
    - **Property 11 :** N événements reçus pendant `syncing` → `flushPendingOperations()` appelé une seule fois
    - **Property 12 :** flush avec `failed > 0` → statut final `online`, entrées `failed` préservées dans la queue
    - _Requirements: 3.2, 3.3, 3.4, 3.5, 3.7_

- [x] 5. Axe D — Neuf services API Flutter

  - [x] 5.1 Créer `lib/core/services/savings_api_service.dart`
    - Singleton `SavingsApiService` suivant le patron `ClientApiService`
    - Méthodes : `getComptes()`, `getCompteById(int id)`, `ouvrirCompte(SavingsAccount compte)`, `effectuerTransaction(SavingsTransaction tx)`, `getTransactions(int compteId)`
    - Endpoints : `/epargne/comptes`, `/epargne/comptes/{id}`, `/epargne/transactions`
    - Lecture online : `ApiService().get()` + `_updateLocalCache()` fire-and-forget + retour données serveur
    - Lecture offline : `DatabaseService().getCompteEpargne()` / `getSavingsTransactions()`
    - Écriture : SQLite d'abord, puis serveur ou `SyncService().queueOperation()`
    - Fallback silencieux sur SQLite si `decodeResponse()` retourne `null` (req. 2.6)
    - Utilise les modèles existants `SavingsAccount` (`savings_account_model.dart`) et `SavingsTransaction` (`savings_transaction_model.dart`)
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

  - [x] 5.2 Créer `lib/core/services/cash_api_service.dart`
    - Singleton `CashApiService`
    - Méthodes : `getOperations()`, `getSolde()`, `createOperation(CashOperation op)`, `getClotures()`, `clotureCaisse(CashClosingModel cloture)`
    - Endpoints : `/caisse/operations`, `/caisse/solde`, `/caisse/clotures`
    - Utilise les modèles existants `CashOperation` (`cash_operation_model.dart`) et `CashClosingModel` (`cash_closing_model.dart`)
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

  - [x] 5.3 Créer `lib/core/services/accounting_api_service.dart`
    - Singleton `AccountingApiService`
    - Méthodes : `getComptes()`, `getJournaux()`, `getEcritures({DateTime? from, DateTime? to})`, `createEcriture(EcritureComptable ecriture)`, `getBalance()`
    - Endpoints : `/comptabilite/comptes`, `/comptabilite/journaux`, `/comptabilite/ecritures`, `/comptabilite/balance`
    - Utilise les modèles existants `AccountingAccountModel`, `EcritureComptable`, `JournalModel`
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

  - [x] 5.4 Créer `lib/core/services/reporting_api_service.dart`
    - Singleton `ReportingApiService`
    - Méthodes : `getDashboardData()`, `getParStats()`
    - Endpoints : `/reporting/dashboard`, `/reporting/par`
    - Lecture online → serveur ; lecture offline → `DatabaseService()`
    - Utilise les modèles existants `DashboardData`, `ParStatsModel`
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.6_

  - [x] 5.5 Créer `lib/core/services/dashboard_api_service.dart`
    - Singleton `DashboardApiService`
    - Méthode : `getKpis()` — délègue à `ReportingApiService().getDashboardData()`
    - Wrapper léger, pas de duplication de logique réseau
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.6_

  - [x] 5.6 Créer `lib/core/services/products_api_service.dart`
    - Singleton `ProductsApiService`
    - Méthodes : `getProducts()`, `getProductById(int id)`, `createProduct(ProduitFinancier p)`, `updateProduct(ProduitFinancier p)`, `deleteProduct(int id)`
    - Endpoints : `/produits`, `/produits/{id}`
    - Utilise le modèle existant `ProduitFinancier` (`produit_financier_model.dart`)
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

  - [x] 5.7 Créer `lib/core/services/agency_api_service.dart`
    - Singleton `AgencyApiService`
    - Méthodes : `getAgencies()`, `getAgencyById(int id)`, `createAgency(AgencyModel a)`, `getAgents({int? agencyId})`
    - Endpoints : `/agencies`, `/agencies/{id}`, `/agents`
    - Utilise les modèles existants `AgencyModel` et `AgentModel`
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

  - [x] 5.8 Créer `lib/core/services/group_api_service.dart`
    - Singleton `GroupApiService`
    - Méthodes : `getGroupes()`, `getGroupeById(int id)`, `createGroupe(GroupeSolidaire g)`, `updateGroupe(GroupeSolidaire g)`
    - Endpoints : `/groupes`, `/groupes/{id}`
    - Utilise le modèle existant `GroupeSolidaire` (`groupe_solidaire_model.dart`)
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

  - [x] 5.9 Créer `lib/core/services/configuration_api_service.dart`
    - Singleton `ConfigurationApiService`
    - Méthodes : `getConfiguration()` → `Map<String, String>`, `updateConfiguration(String key, String value)`
    - Endpoints : `/configuration`, `/configuration/{key}`
    - Lecture online : retourner map clé/valeur du serveur + mise à jour cache
    - Écriture : SQLite d'abord, puis serveur ou queue
    - Utilise le modèle existant `ConfigurationModel`
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

  - [ ]* 5.10 Écrire tests unitaires pour les neuf services API
    - Créer `test/core/services/api_services_test.dart`
    - Mocker `ApiService`, `SyncService`, `DatabaseService` via `mockito`
    - **Property 3 :** singleton — factory retourne toujours la même instance pour chacun des 9 services
    - **Property 4 :** lecture online → `ApiService().get()` appelé, cache SQLite mis à jour
    - **Property 5 :** lecture offline → aucun appel `ApiService().get()`, retour depuis `DatabaseService()`
    - **Property 6 :** écriture → `DatabaseService().insertXxx()` appelé avant tout appel HTTP
    - **Property 7 :** réponse null ou non-2xx → aucune exception levée, retour depuis cache SQLite
    - _Requirements: 2.2, 2.3, 2.4, 2.5, 2.6_

- [x] 6. Checkpoint B — Vérifier les services Flutter
  - Lancer `flutter analyze` — zéro erreur, zéro warning
  - Lancer `flutter test test/core/services/` (si tests écrits)
  - Corriger tout problème avant de continuer

- [x] 7. Axe E — Section « Connexion serveur » dans l'écran Paramètres

  - [x] 7.1 Enrichir `lib/screens/configuration/server_config_page.dart` — validation URL et indicateur statut
    - Ajouter import de `ConnectivityMonitor` et `ConnectivityStatus`
    - Ajouter la regex de validation : `^https?://[a-zA-Z0-9\-\.]+:\d{1,5}(/.*)?$`
    - Modifier `_save()` pour valider le format avant d'appeler `ApiService().setServerUrl(url)` — afficher `_validationError` si non conforme
    - Après `setServerUrl()` réussi, appeler `ConnectivityMonitor().start()` pour déclencher une vérification immédiate (req. 4.4)
    - Ajouter `ValueListenableBuilder<ConnectivityStatus>` wrappant un indicateur visuel coloré :
      - `online` → cercle vert + libellé « Connecté »
      - `syncing` → cercle orange + libellé « Synchronisation... »
      - `offline` → cercle rouge + libellé « Hors ligne »
    - Le bouton « Tester la connexion » appelle `ApiService().isServerAvailable()` avec l'URL saisie (sans persister) et affiche le résultat
    - _Requirements: 4.2, 4.3, 4.4, 4.5, 4.6, 4.7_

  - [x] 7.2 Conditionner l'accès à `ServerConfigPage` selon le rôle ADMIN dans `main_layout.dart`
    - Dans `MainLayout`, l'entrée de menu menant à `ServerConfigPage` (index 45) doit être visible uniquement si `AuthService().isAdmin`
    - La page `ServerConfigPage` elle-même doit vérifier `AuthService().isAdmin` en tête de `build()` et retourner un widget vide (`SizedBox.shrink()`) si le rôle n'est pas ADMIN — pas de message d'erreur affiché
    - Modifier la sidebar ou le menu de navigation pour cacher l'entrée pour les non-ADMIN
    - _Requirements: 4.1, 4.8_

  - [ ]* 7.3 Écrire tests unitaires pour `ServerConfigPage` et `ConnectivityMonitor` — section UI
    - Créer `test/screens/configuration/server_config_page_test.dart`
    - **Property 13 :** widget présent dans l'arbre si rôle ADMIN, absent si autre rôle
    - **Property 14 :** URL invalide soumise → message d'erreur affiché, `setServerUrl()` non appelé
    - **Property 15 :** URL valide soumise → `setServerUrl()` appelé avec la bonne valeur, puis `ConnectivityMonitor().start()` déclenché
    - **Property 16 :** `statusNotifier` change de valeur → indicateur coloré mis à jour synchroniquement
    - _Requirements: 4.1, 4.3, 4.4, 4.5, 4.6, 4.8_

- [x] 8. Axe F — Séquence d'initialisation dans `main.dart`

  - [x] 8.1 Mettre à jour `lib/main.dart` — garantir l'ordre d'initialisation
    - Vérifier que `ApiService().init()` est appelé avant `ConnectivityMonitor().start()`
    - Vérifier que `ConnectivityMonitor().start()` est appelé après `ApiService().init()` et avant `runApp()`
    - L'ordre actuel dans `main.dart` est déjà proche ; s'assurer que `await authService.init()` (qui appelle `ApiService().init()`) précède bien `ConnectivityMonitor().start()`
    - Documenter la séquence dans un commentaire bloc dans `main()`
    - _Requirements: 3.1_

- [ ] 9. Checkpoint final — Validation complète
  - Lancer `flutter analyze` depuis la racine du projet — zéro erreur
  - Lancer `flutter test --reporter=expanded` — tous les tests passent
  - Sur le backend, activer le venv et lancer `alembic upgrade head` sur `sigma_db` — vérifier les 10 migrations
  - Lancer `pytest backend/tests/test_migrations.py -v` (si tests écrits) — tous verts
  - Tester manuellement dans l'app : connexion WiFi → statut vert, coupure réseau → statut rouge immédiat, reconnexion → statut orange puis vert
  - Vérifier que la section « Connexion serveur » est visible avec rôle ADMIN et invisible avec un autre rôle

---

## Notes

- Les tâches marquées `*` sont optionnelles et peuvent être sautées pour un MVP rapide
- Les 9 modèles Dart requis existent déjà dans `lib/models/` — pas de création de modèle nécessaire
- `connectivity_plus: ^6.0.5` doit être ajouté **avant** de modifier `ConnectivityMonitor` (tâche 3.1 est un prérequis de 4.1)
- `ServerConfigPage` existe déjà — les modifications sont incrémentales, pas une réécriture
- Les migrations doivent être testées sur une base PostgreSQL vide pour valider la chaîne complète
- `AuthService().isAdmin` utilise le getter existant qui vérifie `SystemRole.superAdmin`
- Chaque service API suit strictement le patron `ClientApiService` (constructeur privé, instance statique, factory)
- Les propriétés de correction P1–P16 sont couvertes par les tâches de test 1.11, 4.3, 5.10 et 7.3

---

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "3.1"] },
    { "id": 1, "tasks": ["1.2", "1.3", "1.4"] },
    { "id": 2, "tasks": ["1.5", "1.6"] },
    { "id": 3, "tasks": ["1.7", "1.8", "1.9", "1.10"] },
    { "id": 4, "tasks": ["1.11", "4.1"] },
    { "id": 5, "tasks": ["4.2"] },
    { "id": 6, "tasks": ["4.3", "5.1", "5.2", "5.3", "5.4", "5.6", "5.7", "5.8", "5.9", "8.1"] },
    { "id": 7, "tasks": ["5.5"] },
    { "id": 8, "tasks": ["5.10", "7.1"] },
    { "id": 9, "tasks": ["7.2"] },
    { "id": 10, "tasks": ["7.3"] }
  ]
}
```
