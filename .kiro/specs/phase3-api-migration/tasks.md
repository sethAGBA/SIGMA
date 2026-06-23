# Implementation Plan: Phase 3 — Migration API complète

## Overview

Migration des modules Remboursements, Demandes de prêt, Détail prêt et Reporting vers
l'architecture hybride « Server is Truth ». Deux nouveaux services Dart sont créés
(`RepaymentApiService`, `LoanRequestApiService`), deux services existants sont étendus
(`ReportingApiService`, `LoanApiService`), six endpoints FastAPI sont ajoutés, et
11 écrans sont migrés depuis les appels `DatabaseService()` directs. Zéro régression
sur les 105 tests existants.

## Tasks

- [x] 1. Créer les modèles helper Flutter
  - [x] 1.1 Créer `lib/models/repayment_list_result.dart`
    - Classe `RepaymentListResult` avec champs `List<RepaymentSchedule> items` et `bool isIncomplete`
    - Constructeur `const` avec paramètres nommés requis
    - _Requirements: 1.13_
  - [x] 1.2 Créer `lib/models/reporting_result.dart`
    - Classe générique `ReportingResult<T>` avec champs `T data` et `bool isOfflineFallback`
    - Constructeur `const` avec paramètres nommés requis
    - Sémantique : `isOfflineFallback: false` seulement si HTTP 2xx valide
    - _Requirements: 6.10, 6.11_

- [x] 2. Implémenter `RepaymentApiService`
  - [x] 2.1 Créer `lib/core/services/repayment_api_service.dart` — squelette singleton
    - Patron singleton identique à `SavingsApiService` : constructeur privé `_internal`, instance statique `_instance`, factory sans paramètre
    - Dépendances injectées via getters privés (pour faciliter les tests)
    - _Requirements: 1.1, 10.1_
  - [x] 2.2 Implémenter `getPendingSchedules({bool retardOnly = false})`
    - Online → `GET /prets/collecte/jour` + `_updateLocalCacheSchedules()` fire-and-forget
    - Offline → `DatabaseService().getPendingSchedules(retardOnly: retardOnly)`
    - Cache vide offline → `RepaymentListResult(items: [], isIncomplete: true)`
    - Exception API → fallback SQLite silencieux + `debugPrint`
    - _Requirements: 1.2, 1.3, 1.11, 1.13_
  - [x] 2.3 Implémenter `getRepayments(int pretId)` et `getGlobalHistory()`
    - `getRepayments` : Online → `GET /remboursements?pret_id={pretId}` + cache ; Offline → SQLite
    - `getGlobalHistory` : Online → `GET /remboursements/history` ; Offline → `DatabaseService().getGlobalRepaymentHistory()` ; cache vide → liste vide sans exception
    - `getCollectionStats()` : délégation exclusive à `DatabaseService().getCollectionStats()` — jamais d'appel HTTP
    - _Requirements: 1.4, 1.5, 1.6, 1.12_
  - [x] 2.4 Implémenter `insertRepayment(Repayment r)`
    - SQLite d'abord : `DatabaseService().insertRepayment(r)` — exception propagée si échec
    - Online après SQLite réussi → `ApiService().post('/remboursements', r.toMap())` ; exception HTTP → `queueOperation` + retour succès
    - Offline après SQLite → `queueOperation` sans appel HTTP
    - _Requirements: 1.7, 1.8, 1.9, 1.10, 10.3_
  - [ ]* 2.5 Écrire les tests unitaires pour `RepaymentApiService`
    - Lecture online : `ApiService().get()` appelé, cache mis à jour
    - Lecture offline : `DatabaseService()` appelé, `verifyNever(mockApi.get(any))`
    - `insertRepayment` : SQLite avant HTTP (ordre d'appel vérifié)
    - `insertRepayment` : HTTP échoue après SQLite → `queueOperation()` appelé, succès retourné
    - `getCollectionStats()` : jamais HTTP quel que soit `isOnline`
    - Offline + cache vide → `RepaymentListResult(isIncomplete: true)`
    - _Requirements: 9.2_
  - [ ]* 2.6 Écrire le test de propriété P8 — Singleton
    - **Property 8: Singleton — factory retourne toujours la même instance**
    - Appeler `RepaymentApiService()` N fois (N ≥ 2) → `identical(a, b) == true`
    - Tag : `// Feature: phase3-api-migration, Property 8`
    - **Validates: Requirements 1.1, 10.1**
  - [ ]* 2.7 Écrire le test de propriété P6 — getCollectionStats() jamais HTTP
    - **Property 6: getCollectionStats() — jamais d'appel HTTP**
    - Pour tout état `isOnline`, vérifier `verifyNever(mockApi.get(any))` et `verifyNever(mockApi.post(any, any))`
    - Tag : `// Feature: phase3-api-migration, Property 6`
    - **Validates: Requirements 1.12**

- [x] 3. Implémenter `LoanRequestApiService`
  - [x] 3.1 Créer `lib/core/services/loan_request_api_service.dart` — squelette singleton
    - Patron singleton identique à `SavingsApiService`
    - _Requirements: 2.1, 10.2_
  - [x] 3.2 Implémenter `getLoanRequests({String? status})`
    - Online → `GET /demandes-pret?statut={status}` + `_updateLocalCacheLoanRequests()` fire-and-forget
    - Offline → `DatabaseService().getLoanRequests(status: status)`
    - Exception API → fallback SQLite, pas d'exception vers l'appelant
    - _Requirements: 2.2, 2.3, 2.13_
  - [x] 3.3 Implémenter `createLoanRequest(LoanRequest r)` et `updateLoanRequestStatus(...)`
    - `createLoanRequest` : SQLite d'abord → exception propagée si échec ; Online → HTTP POST ou `queueOperation` ; Offline → `queueOperation`
    - `updateLoanRequestStatus` : SQLite d'abord → exception propagée si échec ; Online → HTTP PUT ou `queueOperation` ; Offline → `queueOperation`
    - _Requirements: 2.4, 2.5, 2.6, 2.7, 2.8, 10.3_
  - [x] 3.4 Implémenter `disburseLoan(int requestId, Loan loan, List<RepaymentSchedule> schedules)`
    - Transaction atomique `db.transaction()` : insert `prets` + insert `echeancier` (N lignes) + update statut demande
    - Exception dans `db.transaction()` → propagation immédiate, 0 ligne écrite, aucun appel HTTP ni `queueOperation`
    - SQLite OK + Online → `POST /demandes-pret/{requestId}/debloquer` ; HTTP échoue → `queueOperation` + succès
    - SQLite OK + Offline → `queueOperation` + succès
    - _Requirements: 2.9, 2.10, 2.11, 2.12_
  - [ ]* 3.5 Écrire les tests unitaires pour `LoanRequestApiService`
    - Patron hybride lecture/écriture
    - `disburseLoan` : transaction SQLite réussit → Loan + N schedules insérés, HTTP appelé
    - `disburseLoan` : transaction SQLite échoue → 0 ligne, exception propagée, `verifyNever(mockApi.post(...))`, `verifyNever(mockSync.queueOperation(...))`
    - `disburseLoan` : SQLite OK + offline → `queueOperation` appelé, succès retourné
    - _Requirements: 9.3_
  - [ ]* 3.6 Écrire le test de propriété P8 — Singleton pour `LoanRequestApiService`
    - **Property 8: Singleton — factory retourne toujours la même instance**
    - Appeler `LoanRequestApiService()` N fois → `identical(a, b) == true`
    - Tag : `// Feature: phase3-api-migration, Property 8`
    - **Validates: Requirements 2.1, 10.2**
  - [ ]* 3.7 Écrire le test de propriété P3 — Atomicité disburseLoan
    - **Property 3: Atomicité disburseLoan — échec SQLite → 0 ligne créée**
    - Générer aléatoirement `Loan` + `List<RepaymentSchedule>`, forcer `db.transaction()` à lever une exception
    - Vérifier : aucune ligne dans `prets`, aucune ligne dans `echeancier`, `verifyNever(mockApi.post(...))`, `verifyNever(mockSync.queueOperation(...))`
    - Tag : `// Feature: phase3-api-migration, Property 3`
    - **Validates: Requirements 2.9, 2.12, 4.8**

- [x] 4. Checkpoint — services de base
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Étendre `ReportingApiService` et `LoanApiService`
  - [x] 5.1 Ajouter `getExecutiveStats()`, `getDelinquentLoans()`, `getDelinquentLoanDetails()` à `ReportingApiService`
    - `getExecutiveStats()` : Online → `GET /reporting/executive` → `ReportingResult(data, isOfflineFallback: false)` ; Offline → SQLite → `isOfflineFallback: true`
    - `getDelinquentLoans({String? parCategory})` : Online → `GET /reporting/delinquents?par_category=...` ; Offline → SQLite
    - `getDelinquentLoanDetails(int id)` : Online → `GET /reporting/delinquent/{id}` ; Offline → SQLite
    - `getRecoveryStats()` et `getGlobalRecoveryActionsHistory()` : toujours local, `isOfflineFallback: true`
    - Exception API → fallback SQLite + `isOfflineFallback: true` ; jamais d'exception vers l'appelant
    - _Requirements: 6.2, 6.3, 6.5, 6.7, 6.8, 6.10_
  - [x] 5.2 Ajouter `getRepaymentSchedules(int pretId)` à `LoanApiService` et adapter `getRepayments`
    - `getRepaymentSchedules` : Online → `GET /prets/{pretId}/echeancier` + cache fire-and-forget ; Offline → `DatabaseService().getRepaymentSchedules(pretId)`
    - `getRepayments` : déléguer à `RepaymentApiService().getRepayments(pretId)` — éviter la duplication
    - _Requirements: 5.2, 5.3_
  - [ ]* 5.3 Écrire les tests unitaires pour `ReportingApiService` (nouvelles méthodes)
    - `getExecutiveStats()` online → `isOfflineFallback: false`
    - `getExecutiveStats()` offline → `isOfflineFallback: true`
    - Exception API → `isOfflineFallback: true`, pas d'exception vers l'appelant
    - Méthodes local-only → `isOfflineFallback: true` inconditionnellement
    - _Requirements: 6.10, 6.11_
  - [ ]* 5.4 Écrire le test de propriété P7 — isOfflineFallback
    - **Property 7: isOfflineFallback=false seulement si données du serveur**
    - Générer aléatoirement : online/offline, réponse 2xx/4xx/5xx/exception/null
    - Vérifier : `isOfflineFallback == false` ↔ réponse HTTP 2xx + `data != null`
    - Tag : `// Feature: phase3-api-migration, Property 7`
    - **Validates: Requirements 6.10, 6.11**
  - [ ]* 5.5 Écrire le test de propriété P1 — Isolation lecture offline
    - **Property 1: Isolation lecture offline — aucun appel HTTP**
    - Pour chaque service (RepaymentApiService, LoanRequestApiService, ReportingApiService, LoanApiService), chaque méthode de lecture, avec `isOnline = false`
    - Générer aléatoirement des données cache locales, vérifier `verifyNever(mockApi.get(any))`
    - Tag : `// Feature: phase3-api-migration, Property 1`
    - **Validates: Requirements 1.3, 2.3, 6.3, 6.8, 10.3**

- [ ] 6. Tests de propriétés transversaux — sérialisation et pattern
  - [ ]* 6.1 Écrire le test de propriété P4 — Round-trip sérialisation
    - **Property 4: Round-trip sérialisation — fromMap(toMap()) ≡ objet original**
    - Générer aléatoirement `Repayment`, `RepaymentSchedule`, `LoanRequest`
    - Vérifier `fromMap(obj.toMap())` → tous les champs égaux champ par champ
    - Tag : `// Feature: phase3-api-migration, Property 4`
    - **Validates: Requirements 9.4**
  - [ ]* 6.2 Écrire le test de propriété P2 — SQLite-first écriture
    - **Property 2: SQLite-first écriture — DB appelée avant HTTP**
    - Pour `insertRepayment`, `createLoanRequest`, `updateLoanRequestStatus` avec payload valide aléatoire
    - Vérifier ordre d'appel : `DatabaseService().insertXxx()` avant `ApiService().post()` ou `put()`
    - Tag : `// Feature: phase3-api-migration, Property 2`
    - **Validates: Requirements 1.7, 2.4, 2.7, 10.3**
  - [ ]* 6.3 Écrire le test de propriété P5 — Fallback silencieux
    - **Property 5: Fallback silencieux — exception API → pas d'exception vers l'écran**
    - Pour chaque service et méthode de lecture, simuler null / 4xx / 5xx / timeout / exception réseau
    - Vérifier qu'aucune exception ne traverse la frontière service → écran
    - Tag : `// Feature: phase3-api-migration, Property 5`
    - **Validates: Requirements 1.11, 2.13, 6.10**
  - [ ]* 6.4 Écrire le test de propriété P9 — Cache fire-and-forget
    - **Property 9: Cache fire-and-forget — exception ignorée, valeur de retour inchangée**
    - Forcer `_updateLocalCacheXxx()` à lever une exception, vérifier que la valeur retournée à l'appelant est identique à celle obtenue sans l'exception
    - Tag : `// Feature: phase3-api-migration, Property 9`
    - **Validates: Requirements 1.2, 10.4**

- [x] 7. Checkpoint — services étendus et propriétés
  - Ensure all tests pass, ask the user if questions arise.


- [x] 8. Ajouter les endpoints backend FastAPI — router `demandes_pret.py`
  - [x] 8.1 Créer `backend/app/routers/demandes_pret.py` avec les 4 endpoints
    - `GET /demandes-pret` : liste avec filtre `?statut`, protégé JWT → 200
    - `POST /demandes-pret` : création avec schéma `LoanRequestCreate` → 201 `{id, numero_demande, statut}`
    - `PUT /demandes-pret/{id}/statut` : mise à jour statut avec `LoanRequestStatusUpdate` → 200
    - `POST /demandes-pret/{id}/debloquer` : opération atomique PostgreSQL (Pret + Echeancier + statut) → 201 `{loan_id, numero_pret}` ; déclenche `AutomaticAccountingService.on_deblocage_pret()`
    - JWT absent/invalide → 401 ; payload invalide + JWT valide → 422
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.9, 7.10_
  - [x] 8.2 Ajouter les schémas Pydantic dans `backend/app/schemas/pret.py`
    - `LoanRequestCreate`, `LoanRequestStatusUpdate`, `DisburseRequest`
    - _Requirements: 7.2, 7.3, 7.4_
  - [x] 8.3 Enregistrer le router `demandes_pret` dans `backend/app/main.py`
    - `app.include_router(demandes_pret.router)`
    - _Requirements: 7.1_
  - [ ]* 8.4 Écrire les tests pytest pour `demandes_pret.py`
    - `GET /demandes-pret` sans auth → 401
    - `POST /demandes-pret` payload valide → 201 avec `id`
    - `PUT /demandes-pret/{id}/statut` payload invalide → 422
    - `POST /demandes-pret/{id}/debloquer` → 201 avec `loan_id`
    - _Requirements: 7.9, 7.10_

- [x] 9. Ajouter les endpoints backend FastAPI — extensions `remboursements.py` et `reporting.py`
  - [x] 9.1 Ajouter `GET /remboursements/history` dans `backend/app/routers/remboursements.py`
    - Déclarer **avant** la route `/{id}` pour éviter l'ambiguïté FastAPI
    - Pagination : `page` (défaut 1) et `limit` (défaut 50, max 200)
    - Retourne `{items, total, page, limit}` ; protégé JWT
    - _Requirements: 7.5_
  - [x] 9.2 Ajouter `GET /reporting/executive`, `GET /reporting/delinquents`, `GET /reporting/delinquent/{id}` dans `backend/app/routers/reporting.py`
    - `GET /reporting/executive` : stats agrégées correspondant à `ExecutiveDashboardStats` ; protégé JWT
    - `GET /reporting/delinquents` : filtre `?par_category` ; protégé JWT
    - `GET /reporting/delinquent/{id}` : détail + historique recouvrement ; protégé JWT
    - JWT absent/invalide → 401 ; payload invalide → 422
    - _Requirements: 7.6, 7.7, 7.8, 7.9, 7.10_
  - [ ]* 9.3 Écrire les tests pytest pour les nouveaux endpoints reporting et historique
    - `GET /remboursements/history` : pagination correcte, auth requise
    - `GET /reporting/executive` : structure de réponse, auth requise
    - `GET /reporting/delinquents` : filtre `par_category` fonctionnel
    - `GET /reporting/delinquent/{id}` : 404 si inexistant
    - _Requirements: 7.5, 7.6, 7.7, 7.8_

- [ ] 10. Migrer les écrans du module Remboursements
  - [ ] 10.1 Migrer `DailyCollectionPage`
    - Remplacer `DatabaseService().getPendingSchedules()` → `RepaymentApiService().getPendingSchedules()`
    - Remplacer `DatabaseService().getCollectionStats()` → `RepaymentApiService().getCollectionStats()`
    - Afficher message "Aucune donnée disponible" si `RepaymentListResult.isIncomplete == true` (offline + cache vide)
    - Afficher les données du cache sans message d'erreur si offline + cache non vide
    - _Requirements: 3.1, 3.2, 3.5, 3.6, 3.7_
  - [~] 10.2 Migrer `RepaymentFormDialog`
    - Remplacer `DatabaseService().insertRepayment()` → `RepaymentApiService().insertRepayment()`
    - Conserver tous les champs et validations existants (transparence UI totale en offline)
    - _Requirements: 3.3, 3.8_
  - [~] 10.3 Migrer `RepaymentHistoryPage`
    - Remplacer `DatabaseService().getGlobalRepaymentHistory()` → `RepaymentApiService().getGlobalHistory()`
    - _Requirements: 3.4_

- [ ] 11. Migrer les écrans du module Demandes de prêt
  - [~] 11.1 Migrer `LoanRequestListPage`
    - Remplacer `DatabaseService().getLoanRequests()` → `LoanRequestApiService().getLoanRequests(status: _selectedStatus)`
    - Conserver les mêmes filtres et colonnes d'affichage
    - Afficher message subtil si offline + cache non vide (données potentiellement incomplètes)
    - Afficher message d'indisponibilité si offline + cache vide
    - _Requirements: 4.1, 4.5, 4.6, 4.7_
  - [~] 11.2 Migrer `LoanRequestFormDialog`
    - Remplacer `DatabaseService().insertLoanRequest()` → `LoanRequestApiService().createLoanRequest()`
    - _Requirements: 4.2_
  - [~] 11.3 Migrer `LoanRequestDetailDialog`
    - Remplacer `DatabaseService().updateLoanRequestStatus()` → `LoanRequestApiService().updateLoanRequestStatus()`
    - Remplacer `DatabaseService().insertLoan()` + `insertRepaymentSchedule()` → `LoanRequestApiService().disburseLoan()`
    - Afficher erreur explicite si `disburseLoan()` échoue côté SQLite, ne pas changer le statut affiché
    - _Requirements: 4.3, 4.4, 4.8_

- [ ] 12. Migrer les écrans du module Détail prêt et Reporting
  - [~] 12.1 Migrer `LoanDetailDialog`
    - Remplacer `DatabaseService().getLoanById(id)` → `LoanApiService().getLoanById(id)`
    - Remplacer `DatabaseService().getRepaymentSchedules(pretId)` → `LoanApiService().getRepaymentSchedules(pretId)`
    - Remplacer `DatabaseService().getRepayments(pretId)` → `LoanApiService().getRepayments(pretId)`
    - **Conserver** `DatabaseService()` pour `getLoanContractScan()`, `saveLoanContractScan()`, `deleteLoanContractScan()` (mode local acceptable)
    - Afficher badge/icône non-bloquant si données depuis cache SQLite
    - Afficher "Prêt introuvable" + fermer si `getLoanById` retourne `null`
    - Afficher `SnackBar` d'erreur si exception non récupérée, conserver données partielles
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7_
  - [~] 12.2 Migrer `ExecutiveDashboardPage`
    - Remplacer `DatabaseService().getExecutiveStats()` → `ReportingApiService().getExecutiveStats()`
    - Afficher bandeau "Données calculées localement" si `isOfflineFallback: true`
    - _Requirements: 6.1, 6.11_
  - [~] 12.3 Migrer `DelinquentLoansListPage` et `DelinquentLoanDetailPage`
    - `DelinquentLoansListPage` : `DatabaseService().getDelinquentLoans()` → `ReportingApiService().getDelinquentLoans(parCategory: ...)`
    - `DelinquentLoanDetailPage` : `DatabaseService()` → `ReportingApiService().getDelinquentLoanDetails(loanId)`
    - _Requirements: 6.4, 6.6_
  - [~] 12.4 Migrer `RecoveryActionsPage`
    - Remplacer les accès `DatabaseService()` → `ReportingApiService().getDelinquentLoans()`, `.getRecoveryStats()`, `.getGlobalRecoveryActionsHistory()`
    - _Requirements: 6.9_

- [ ] 13. Vérifier la non-régression et la conformité statique
  - [~] 13.1 Corriger les éventuelles erreurs `flutter analyze`
    - Résoudre toutes les erreurs et avertissements détectés par le `Dart_Analyzer`
    - _Requirements: 9.5_
  - [ ]* 13.2 Exécuter la suite de tests complète — 105 tests existants
    - Lancer `flutter test` et vérifier 105 tests passants sans régression
    - _Requirements: 9.1_

- [~] 14. Checkpoint final
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Les tâches marquées `*` sont optionnelles et peuvent être ignorées pour un MVP rapide.
- Chaque tâche référence les critères d'acceptation correspondants pour la traçabilité.
- Les checkpoints valident la progression incrémentale.
- Les tests de propriétés valident les invariants universels (P1–P9) ; les tests unitaires valident les exemples concrets.
- Les modules en mode local acceptable (Req. 8) ne sont pas migrés — aucune tâche de migration ne les concerne.
- Le router `demandes_pret.py` doit être enregistré dans `main.py` pour être actif (tâche 8.3).
- La route `/history` doit être déclarée avant `/{id}` dans `remboursements.py` (tâche 9.1).


## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2"] },
    { "id": 1, "tasks": ["2.1", "3.1"] },
    { "id": 2, "tasks": ["2.2", "2.3", "3.2", "3.3"] },
    { "id": 3, "tasks": ["2.4", "3.4"] },
    { "id": 4, "tasks": ["2.5", "2.6", "2.7", "3.5", "3.6", "3.7"] },
    { "id": 5, "tasks": ["5.1", "5.2", "8.1", "8.2"] },
    { "id": 6, "tasks": ["5.3", "5.4", "5.5", "8.3", "8.4", "9.1", "9.2"] },
    { "id": 7, "tasks": ["6.1", "6.2", "6.3", "6.4", "9.3"] },
    { "id": 8, "tasks": ["10.1", "10.2", "10.3", "11.1", "11.2", "11.3", "12.1", "12.2", "12.3", "12.4"] },
    { "id": 9, "tasks": ["13.1"] },
    { "id": 10, "tasks": ["13.2"] }
  ]
}
```
