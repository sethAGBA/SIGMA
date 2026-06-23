# Requirements Document

## Introduction

Cette phase finalise la migration de l'application Flutter SIGMA Micro-Finance vers l'architecture hybride API/SQLite. Les modules Remboursements, Demandes de prêt, Détail prêt et Reporting sont encore en accès SQLite direct ; ils doivent être branchés sur leurs services API selon le patron « Server is Truth » établi en Phase 0. Deux nouveaux services API Flutter sont à créer (`RepaymentApiService`, `LoanRequestApiService`) et quatre endpoints backend à ajouter. L'objectif est d'atteindre 100 % de migration sans régression sur les 105 tests existants.

## Glossary

- **RepaymentApiService** : service Dart singleton gérant les appels API pour les remboursements et la collecte journalière.
- **LoanRequestApiService** : service Dart singleton gérant les appels API pour les demandes de prêt et le déblocage.
- **LoanApiService** : service Dart singleton existant pour les prêts — étendu en Phase 3 pour les détails de prêt.
- **ReportingApiService** : service Dart singleton existant pour le reporting — étendu en Phase 3 pour les délinquants et le tableau de bord exécutif.
- **DatabaseService** : service Dart d'accès SQLite local — source de vérité offline et cache local.
- **ApiService** : client HTTP bas niveau (wrapper sur `http`) utilisé par tous les `XxxApiService`.
- **SyncService** : service de synchronisation différée ; expose `isOnline` et `queueOperation()`.
- **ConnectivityMonitor** : gestionnaire de connectivité réseau basé sur `connectivity_plus` + ping `/health`.
- **Server_is_Truth** : stratégie architecture — PostgreSQL serveur est la source de vérité ; SQLite local est le cache offline.
- **Patron_hybride** : lecture → API first + fallback SQLite ; écriture → SQLite first + sync serveur.
- **Deblocage** : opération d'approbation finale d'une demande de prêt qui crée simultanément le `Loan`, son `RepaymentSchedule` et notifie le serveur — opération la plus critique du module prêts.
- **Transaction_atomique** : ensemble d'opérations SQLite exécutées dans une transaction `db.transaction()` — tout réussit ou tout est annulé.
- **DailyCollectionPage** : écran de collecte journalière des remboursements (`lib/screens/remboursements/daily_collection_page.dart`).
- **RepaymentFormDialog** : dialogue de saisie d'un remboursement (`lib/screens/remboursements/repayment_form_dialog.dart`).
- **RepaymentHistoryPage** : écran d'historique global des remboursements (`lib/screens/remboursements/repayment_history_page.dart`).
- **LoanRequestListPage** : écran de liste des demandes de prêt (`lib/screens/prets/loan_request_list_page.dart`).
- **LoanRequestFormDialog** : dialogue de création d'une demande de prêt (`lib/screens/prets/loan_request_form_dialog.dart`).
- **LoanRequestDetailDialog** : dialogue de détail/décision sur une demande de prêt (`lib/screens/prets/loan_request_detail_dialog.dart`).
- **LoanDetailDialog** : dialogue de détail d'un prêt actif (`lib/screens/prets/loan_detail_dialog.dart`).
- **ExecutiveDashboardPage** : tableau de bord de direction (`lib/screens/reporting/executive_dashboard_page.dart`).
- **DelinquentLoansListPage** : liste des prêts en souffrance (`lib/screens/reporting/delinquent_loans_list_page.dart`).
- **DelinquentLoanDetailPage** : détail d'un prêt en souffrance (`lib/screens/reporting/delinquent_loan_detail_page.dart`).
- **RecoveryActionsPage** : écran de suivi des actions de recouvrement (`lib/screens/reporting/recovery_actions_page.dart`).
- **Scan_de_contrat** : fichier binaire (image/PDF) stocké en Base64 dans SQLite — reste local, jamais synchronisé.
- **Mode_local_acceptable** : module pour lequel l'accès SQLite direct est conservé intentionnellement (pas de migration requise).
- **Backend** : application FastAPI Python déployée sur le PC serveur LAN.
- **Test_Runner** : commande `flutter test` exécutée à la racine du projet Flutter.
- **Dart_Analyzer** : outil `flutter analyze` vérifiant la conformité statique du code Dart.
- **Service** : désigne indifféremment `RepaymentApiService` ou `LoanRequestApiService` selon le contexte.

## Requirements

### Requirement 1: Service RepaymentApiService

**User Story:** En tant qu'agent de collecte, je veux que les données de remboursement soient synchronisées avec le serveur, afin que les informations soient partagées en temps réel entre tous les postes.

#### Acceptance Criteria

1. THE `RepaymentApiService` SHALL être implémenté comme singleton Dart suivant le patron `SavingsApiService` (constructeur privé `_internal`, instance statique `_instance`, factory sans paramètre).
2. WHEN `SyncService().isOnline` retourne `true`, THE `RepaymentApiService` SHALL invoquer `ApiService().get('/prets/collecte/jour')` dans `getPendingSchedules()`, retourner les données du serveur à l'appelant, puis mettre à jour le cache SQLite en fire-and-forget — IF la mise à jour du cache échoue, la valeur de retour n'est pas affectée.
3. WHEN `SyncService().isOnline` retourne `false`, THE `RepaymentApiService` SHALL retourner les données de `DatabaseService().getPendingSchedules()` sans émettre aucun appel HTTP.
4. WHEN `SyncService().isOnline` retourne `true`, THE `RepaymentApiService` SHALL invoquer `ApiService().get('/remboursements?pret_id={pretId}')` dans `getRepayments(pretId)`, retourner les données du serveur, puis mettre à jour le cache SQLite en fire-and-forget.
5. WHEN `SyncService().isOnline` retourne `true`, THE `RepaymentApiService` SHALL invoquer `ApiService().get('/remboursements/history')` dans `getGlobalHistory()` et retourner les données du serveur.
6. WHEN `SyncService().isOnline` retourne `false`, THE `RepaymentApiService` SHALL retourner les données de `DatabaseService().getGlobalRepaymentHistory()` dans `getGlobalHistory()` — IF le cache est vide, retourner une liste vide sans lever d'exception.
7. WHEN `insertRepayment(repayment)` est appelé, THE `RepaymentApiService` SHALL appeler `DatabaseService().insertRepayment(repayment)` avant tout appel à `ApiService()` — IF `DatabaseService().insertRepayment()` lève une exception, THE `RepaymentApiService` SHALL propager l'exception à l'appelant sans appeler `ApiService()`.
8. WHEN `insertRepayment(repayment)` est appelé, `DatabaseService().insertRepayment()` a réussi, ET `SyncService().isOnline` retourne `true`, THE `RepaymentApiService` SHALL invoquer `ApiService().post('/remboursements', repayment.toMap())` — IF la connexion réseau est perdue avant l'envoi HTTP, THE `RepaymentApiService` SHALL considérer l'opération réussie et appeler `SyncService().queueOperation()`.
9. IF `ApiService().post('/remboursements', ...)` lève une exception ou retourne un code HTTP non-2xx après l'insertion SQLite réussie, THEN THE `RepaymentApiService` SHALL appeler `SyncService().queueOperation(method: 'POST', path: '/remboursements', body: repayment.toMap())` et retourner succès à l'appelant (les données locales sont sauvegardées).
10. WHEN `insertRepayment(repayment)` est appelé et que `SyncService().isOnline` retourne `false`, THE `RepaymentApiService` SHALL appeler `SyncService().queueOperation(method: 'POST', path: '/remboursements', body: repayment.toMap())` sans tenter d'appel HTTP.
11. IF `ApiService().get(...)` lève une exception ou retourne `null` dans une méthode de lecture, THEN THE `RepaymentApiService` SHALL retourner les données de `DatabaseService()` sans lever d'exception vers l'appelant, et SHALL appeler `debugPrint` avec le message d'erreur pour traçabilité.
12. THE `RepaymentApiService` SHALL exposer `getCollectionStats()` qui retourne toujours les statistiques depuis `DatabaseService().getCollectionStats()` sans appel HTTP (agrégats locaux uniquement).
13. WHEN `SyncService().isOnline` retourne `false` et que le cache SQLite ne contient aucune donnée pour la méthode de lecture appelée, THE `RepaymentApiService` SHALL retourner un objet `RepaymentListResult(items: [], isIncomplete: true)` permettant à l'appelant de distinguer "données vides" de "données indisponibles".

---

### Requirement 2: Service LoanRequestApiService

**User Story:** En tant qu'agent de crédit, je veux que les demandes de prêt et le déblocage soient synchronisés avec le serveur, afin que le comité de crédit puisse consulter et approuver les dossiers depuis n'importe quel poste.

#### Acceptance Criteria

1. THE `LoanRequestApiService` SHALL être implémenté comme singleton Dart suivant le patron `SavingsApiService` (constructeur privé `_internal`, instance statique `_instance`, factory sans paramètre).
2. WHEN `SyncService().isOnline` retourne `true`, THE `LoanRequestApiService` SHALL invoquer `ApiService().get('/demandes-pret?statut={status}')` dans `getLoanRequests(status)`, retourner les données du serveur, puis mettre à jour le cache SQLite en fire-and-forget.
3. WHEN `SyncService().isOnline` retourne `false`, THE `LoanRequestApiService` SHALL retourner les données de `DatabaseService().getLoanRequests(status: status)` sans émettre aucun appel HTTP.
4. WHEN `createLoanRequest(request)` est appelé, THE `LoanRequestApiService` SHALL appeler `DatabaseService().insertLoanRequest(request)` avant tout appel HTTP — IF `DatabaseService().insertLoanRequest()` lève une exception, THE `LoanRequestApiService` SHALL propager l'exception à l'appelant sans appeler `ApiService()`.
5. WHEN `createLoanRequest(request)` est appelé, `DatabaseService().insertLoanRequest()` a réussi, ET `SyncService().isOnline` retourne `true`, THE `LoanRequestApiService` SHALL invoquer `ApiService().post('/demandes-pret', request.toMap())` — IF l'appel HTTP lève une exception ou retourne un code non-2xx, THE `LoanRequestApiService` SHALL appeler `SyncService().queueOperation(method: 'POST', path: '/demandes-pret', body: request.toMap())`.
6. WHEN `createLoanRequest(request)` est appelé et que `SyncService().isOnline` retourne `false`, THE `LoanRequestApiService` SHALL appeler `SyncService().queueOperation(method: 'POST', path: '/demandes-pret', body: request.toMap())` sans tenter d'appel HTTP.
7. WHEN `updateLoanRequestStatus(id, status, motif)` est appelé, THE `LoanRequestApiService` SHALL appeler `DatabaseService().updateLoanRequestStatus(id, status, motif: motif)` avant tout appel HTTP — IF `DatabaseService()` lève une exception, THE `LoanRequestApiService` SHALL propager l'exception sans appeler `ApiService()`.
8. WHEN `updateLoanRequestStatus(id, status, motif)` est appelé, la mise à jour SQLite a réussi, ET `SyncService().isOnline` retourne `true`, THE `LoanRequestApiService` SHALL invoquer `ApiService().put('/demandes-pret/{id}/statut', {statut: status.name, motif_rejet: motif})` — IF l'appel HTTP lève une exception ou retourne un code non-2xx, THE `LoanRequestApiService` SHALL appeler `SyncService().queueOperation()`.
9. WHEN `disburseLoan(requestId, loan, schedules)` est appelé, THE `LoanRequestApiService` SHALL exécuter l'insertion du `Loan` et de tous ses `RepaymentSchedule` dans une seule `Transaction_atomique` SQLite via `db.transaction()` — IF le mécanisme de transaction ne peut pas être établi (exception sur `db.transaction()`), THEN THE `LoanRequestApiService` SHALL propager l'exception immédiatement sans aucune écriture partielle.
10. WHEN la `Transaction_atomique` du `Deblocage` réussit ET `SyncService().isOnline` retourne `true`, THE `LoanRequestApiService` SHALL invoquer `ApiService().post('/demandes-pret/{requestId}/debloquer', {loan_id: loanId, ...})` — IF l'appel HTTP lève une exception ou retourne un code non-2xx, THE `LoanRequestApiService` SHALL appeler `SyncService().queueOperation(method: 'POST', path: '/demandes-pret/{requestId}/debloquer', body: ...)` et retourner succès à l'appelant.
11. WHEN la `Transaction_atomique` du `Deblocage` réussit ET `SyncService().isOnline` retourne `false`, THE `LoanRequestApiService` SHALL appeler `SyncService().queueOperation()` et retourner succès à l'appelant.
12. IF la `Transaction_atomique` du `Deblocage` échoue (exception dans `db.transaction()`), THEN THE `LoanRequestApiService` SHALL laisser SQLite annuler la transaction complète et retourner une erreur à l'appelant sans appeler le serveur.
13. IF `ApiService().get(...)` retourne `null` ou lève une exception dans une méthode de lecture, THEN THE `LoanRequestApiService` SHALL retourner les données de `DatabaseService().getLoanRequests()` ou `DatabaseService().getLoanById()` selon le contexte, sans lever d'exception vers l'appelant.

---

### Requirement 3: Migration du module Remboursements

**User Story:** En tant qu'agent de collecte, je veux que les écrans de remboursement utilisent le service API, afin d'avoir des données synchronisées avec le serveur tout en conservant le fonctionnement offline.

#### Acceptance Criteria

1. THE `DailyCollectionPage` SHALL utiliser `RepaymentApiService().getPendingSchedules()` au lieu de `DatabaseService().getPendingSchedules()` directement.
2. THE `DailyCollectionPage` SHALL utiliser `RepaymentApiService().getCollectionStats()` au lieu de `DatabaseService().getCollectionStats()` directement.
3. THE `RepaymentFormDialog` SHALL utiliser `RepaymentApiService().insertRepayment()` au lieu de `DatabaseService().insertRepayment()` directement.
4. THE `RepaymentHistoryPage` SHALL utiliser `RepaymentApiService().getGlobalHistory()` au lieu de `DatabaseService().getGlobalRepaymentHistory()` directement.
5. WHEN les écrans du module Remboursements appellent `RepaymentApiService`, THE `DailyCollectionPage` SHALL afficher le même contenu qu'avant la migration sans aucun message d'erreur lié à la connectivité, qu'elle soit disponible ou non (transparence UI totale).
6. WHEN le serveur est indisponible et que le cache SQLite contient des données, THE `DailyCollectionPage` SHALL afficher les données du cache SQLite sans message d'erreur lié à la connectivité.
7. WHEN le serveur est indisponible et que le cache SQLite est vide, THE `DailyCollectionPage` SHALL afficher un message indiquant qu'aucune donnée n'est disponible.
8. THE `RepaymentFormDialog` SHALL permettre la saisie et la validation d'un remboursement en mode offline avec les mêmes champs et validations qu'en mode online.

---

### Requirement 4: Migration du module Demandes de prêt

**User Story:** En tant qu'agent de crédit, je veux que les écrans de demandes de prêt utilisent le service API, afin que les dossiers soient accessibles et modifiables depuis tous les postes connectés.

#### Acceptance Criteria

1. THE `LoanRequestListPage` SHALL utiliser `LoanRequestApiService().getLoanRequests(status: _selectedStatus)` au lieu de `DatabaseService().getLoanRequests()` directement.
2. THE `LoanRequestFormDialog` SHALL utiliser `LoanRequestApiService().createLoanRequest()` au lieu de `DatabaseService().insertLoanRequest()` directement.
3. THE `LoanRequestDetailDialog` SHALL utiliser `LoanRequestApiService().updateLoanRequestStatus()` au lieu de `DatabaseService().updateLoanRequestStatus()` directement.
4. WHEN le bouton de déblocage est activé dans `LoanRequestDetailDialog`, THE `LoanRequestDetailDialog` SHALL appeler `LoanRequestApiService().disburseLoan()` au lieu d'appeler directement `DatabaseService().insertLoan()` et `DatabaseService().insertRepaymentSchedule()`.
5. WHEN les écrans du module Demandes de prêt appellent `LoanRequestApiService`, THE `LoanRequestListPage` SHALL afficher le même contenu et les mêmes filtres qu'avant la migration.
6. WHEN le serveur est indisponible et que le cache SQLite contient des données, THE `LoanRequestListPage` SHALL afficher les données du cache avec un message subtil indiquant que les données peuvent être incomplètes en raison de l'indisponibilité du serveur.
7. WHEN le serveur est indisponible et que le cache SQLite est vide, THE `LoanRequestListPage` SHALL afficher un message indiquant que les données sont indisponibles en raison de l'indisponibilité du serveur.
8. IF le `Deblocage` échoue côté SQLite, THEN THE `LoanRequestDetailDialog` SHALL afficher un message d'erreur explicite et ne pas changer le statut de la demande.

---

### Requirement 5: Migration du module Détail prêt

**User Story:** En tant qu'agent de crédit, je veux que le détail d'un prêt affiche les données du serveur, afin que les informations soient à jour depuis tous les postes.

#### Acceptance Criteria

1. THE `LoanDetailDialog` SHALL utiliser `LoanApiService().getLoanById(id)` au lieu de `DatabaseService().getLoanById(id)` directement.
2. THE `LoanDetailDialog` SHALL utiliser `LoanApiService().getRepaymentSchedules(pretId)` au lieu de `DatabaseService().getRepaymentSchedules(pretId)` directement.
3. THE `LoanDetailDialog` SHALL utiliser `LoanApiService().getRepayments(pretId)` au lieu de `DatabaseService().getRepayments(pretId)` directement.
4. THE `LoanDetailDialog` SHALL continuer d'utiliser `DatabaseService()` directement pour `getLoanContractScan()`, `saveLoanContractScan()` et `deleteLoanContractScan()` (`Scan_de_contrat` — `Mode_local_acceptable`).
5. IF `LoanApiService()` retourne les données depuis le cache SQLite (serveur indisponible), THEN THE `LoanDetailDialog` SHALL afficher un indicateur visuel non-bloquant (icône ou badge) signalant que les données peuvent ne pas être à jour — cet indicateur ne doit pas empêcher l'accès aux données.
6. IF `LoanApiService().getLoanById(id)` retourne `null` (entrée introuvable en ligne et hors cache), THEN THE `LoanDetailDialog` SHALL afficher un message d'erreur "Prêt introuvable" et fermer le dialogue.
7. IF `LoanApiService()` lève une exception non récupérée, THEN THE `LoanDetailDialog` SHALL afficher un `SnackBar` d'erreur et continuer d'afficher les données partielles disponibles.

---

### Requirement 6: Migration du module Reporting

**User Story:** En tant que directeur, je veux que les tableaux de bord et les rapports de délinquance utilisent le serveur, afin d'avoir une vue consolidée de toutes les agences.

#### Acceptance Criteria

1. THE `ExecutiveDashboardPage` SHALL utiliser `ReportingApiService().getExecutiveStats()` au lieu de `DatabaseService().getExecutiveStats()` directement.
2. WHEN `SyncService().isOnline` retourne `true`, THE `ReportingApiService` SHALL invoquer `ApiService().get('/reporting/executive')` dans `getExecutiveStats()` et retourner les données du serveur.
3. WHEN `SyncService().isOnline` retourne `false`, THE `ReportingApiService` SHALL retourner les données de `DatabaseService().getExecutiveStats()` dans `getExecutiveStats()`.
4. THE `DelinquentLoansListPage` SHALL utiliser `ReportingApiService().getDelinquentLoans(parCategory: ...)` au lieu de `DatabaseService().getDelinquentLoans()` directement.
5. WHEN `SyncService().isOnline` retourne `true`, THE `ReportingApiService` SHALL invoquer `ApiService().get('/reporting/delinquents?par_category={category}')` dans `getDelinquentLoans()` et retourner les données du serveur.
6. THE `DelinquentLoanDetailPage` SHALL utiliser `ReportingApiService().getDelinquentLoanDetails(loanId)` au lieu de `DatabaseService()` directement.
7. WHEN `SyncService().isOnline` retourne `true`, THE `ReportingApiService` SHALL invoquer `ApiService().get('/reporting/delinquent/{id}')` dans `getDelinquentLoanDetails(id)`.
8. WHEN `SyncService().isOnline` retourne `false`, THE `ReportingApiService` SHALL retourner les données de `DatabaseService().getDelinquentLoanDetails(id)` dans `getDelinquentLoanDetails(id)`.
9. THE `RecoveryActionsPage` SHALL utiliser `ReportingApiService()` pour `getDelinquentLoans()`, `getRecoveryStats()` et `getGlobalRecoveryActionsHistory()` au lieu de `DatabaseService()` directement.
10. IF `ApiService().get(...)` retourne `null` ou lève une exception dans n'importe quelle méthode de `ReportingApiService`, THEN THE `ReportingApiService` SHALL retourner les données de `DatabaseService()` sans lever d'exception vers l'appelant — IF les données SQLite locales sont vides ou absentes, THE `ReportingApiService` SHALL retourner un objet vide/liste vide accompagné d'un flag `isOfflineFallback: true` permettant à l'écran d'afficher un indicateur visuel.
11. IF `ReportingApiService()` retourne les données depuis le cache SQLite (flag `isOfflineFallback: true`), THEN THE `ExecutiveDashboardPage` SHALL afficher les données locales et un indicateur visuel non-bloquant signalant que les chiffres sont calculés localement.

---

### Requirement 7: Endpoints backend à ajouter

**User Story:** En tant que développeur backend, je veux que les nouveaux endpoints API soient disponibles, afin que les services Flutter puissent accéder aux données manquantes depuis le serveur.

#### Acceptance Criteria

1. THE `Backend` SHALL exposer `GET /demandes-pret` retournant la liste des demandes de prêt avec filtre optionnel `?statut={statut}`, protégé par JWT.
2. THE `Backend` SHALL exposer `POST /demandes-pret` acceptant un payload JSON correspondant au schéma `LoanRequest` et créant l'enregistrement en base PostgreSQL — en cas de succès, retourner HTTP 201 avec `{ id, numero_demande, statut }`.
3. THE `Backend` SHALL exposer `PUT /demandes-pret/{id}/statut` acceptant `{ statut, motif_rejet? }` et mettant à jour le statut de la demande.
4. THE `Backend` SHALL exposer `POST /demandes-pret/{id}/debloquer` déclenchant la création atomique du prêt et de son échéancier en base PostgreSQL — en cas de succès, retourner HTTP 201 avec `{ loan_id, numero_pret }`.
5. THE `Backend` SHALL exposer `GET /remboursements/history` retournant l'historique global des remboursements avec pagination — `page` (défaut 1) et `limit` (défaut 50, max 200).
6. THE `Backend` SHALL exposer `GET /reporting/executive` retournant les statistiques exécutives agrégées correspondant au modèle `ExecutiveDashboardStats` calculées depuis PostgreSQL.
7. THE `Backend` SHALL exposer `GET /reporting/delinquents` retournant la liste des prêts en souffrance avec filtre optionnel `?par_category={category}`.
8. THE `Backend` SHALL exposer `GET /reporting/delinquent/{id}` retournant le détail complet d'un prêt en souffrance, incluant l'historique de recouvrement.
9. WHEN un endpoint `Backend` reçoit une requête avec un token JWT invalide, expiré ou absent, THE `Backend` SHALL retourner HTTP 401 indépendamment de la validité du payload.
10. WHEN un endpoint `Backend` reçoit un payload invalide ET un token JWT valide, THE `Backend` SHALL retourner HTTP 422 avec un corps JSON listant les champs en erreur et un message descriptif par champ.

---

### Requirement 8: Modules en mode local acceptable

**User Story:** En tant que développeur, je veux que les modules identifiés comme locaux restent en accès SQLite direct, afin de ne pas introduire de complexité inutile pour des données qui n'ont pas besoin d'être synchronisées.

#### Acceptance Criteria

1. THE `DataExportPage` SHALL continuer d'accéder directement à `DatabaseService()` pour les exports de données brutes SQLite (`Mode_local_acceptable`).
2. THE `MessageTemplatesPage` SHALL continuer d'accéder directement à `DatabaseService()` pour `getMessageTemplates()`, `insertMessageTemplate()` et `deleteMessageTemplate()` (`Mode_local_acceptable`).
3. THE `NotificationHistoryPage` SHALL continuer d'accéder directement à `DatabaseService()` pour `getNotificationLogs()` (`Mode_local_acceptable`).
4. THE `CustomReportPage` SHALL continuer d'accéder directement à `DatabaseService()` pour `getLegalInformation()` (`Mode_local_acceptable`).
5. THE `LoanDetailDialog` SHALL continuer d'accéder directement à `DatabaseService()` pour les opérations `Scan_de_contrat` (`Mode_local_acceptable` — fichiers binaires trop volumineux pour la synchronisation réseau).
6. THE `SmsSendingPage` SHALL continuer d'accéder directement à `DatabaseService()` pour `insertNotificationLog()` (`Mode_local_acceptable`).

---

### Requirement 9: Non-régression et intégrité des tests

**User Story:** En tant que développeur, je veux que la migration ne casse aucun test existant, afin de garantir la stabilité de l'application pendant la migration.

#### Acceptance Criteria

1. WHEN la suite de tests est exécutée après la migration, THE `Test_Runner` SHALL rapporter 105 tests passants sans régression.
2. THE `RepaymentApiService` SHALL être couvert par des tests unitaires vérifiant : (a) lecture online → `ApiService().get()` appelé, cache mis à jour ; (b) lecture offline → `DatabaseService()` appelé, aucun appel HTTP ; (c) écriture → `DatabaseService()` appelé avant `ApiService()` ; (d) erreur HTTP après SQLite réussi → `SyncService().queueOperation()` appelé, succès retourné.
3. THE `LoanRequestApiService` SHALL être couvert par des tests unitaires vérifiant : (a) le `Patron_hybride` sur lecture/écriture ; (b) atomicité du `Deblocage` — échec SQLite → aucune écriture partielle + exception propagée ; (c) succès SQLite + erreur HTTP → `queueOperation()` appelé, succès retourné.
4. FOR ALL méthodes de lecture de `RepaymentApiService` et `LoanRequestApiService`, parsing a valid server response then serializing it back SHALL produce an object where all fields are equal field-by-field to the original response (propriété de round-trip).
5. WHEN `flutter analyze` est exécuté après la migration, THE `Dart_Analyzer` SHALL retourner zéro erreur et zéro avertissement.

---

### Requirement 10: Cohérence du patron hybride

**User Story:** En tant qu'architecte logiciel, je veux que tous les nouveaux services respectent le patron « Server is Truth » établi en Phase 0, afin de garantir la cohérence architecturale de l'application.

#### Acceptance Criteria

1. THE `RepaymentApiService` SHALL suivre exactement le même patron de singleton que `SavingsApiService` (constructeur privé `_internal`, instance statique, factory sans paramètre).
2. THE `LoanRequestApiService` SHALL suivre exactement le même patron de singleton que `SavingsApiService` (constructeur privé `_internal`, instance statique, factory sans paramètre).
3. WHILE `DatabaseService().insertXxx()` est en attente de résolution dans `RepaymentApiService` ou `LoanRequestApiService`, THE `Service` SHALL ne jamais appeler `ApiService().post()` ou `ApiService().put()` — l'appel HTTP ne sera émis qu'après le retour (succès) de `DatabaseService()`.
4. FOR ALL méthodes de lecture de `RepaymentApiService` et `LoanRequestApiService`, WHEN `SyncService().isOnline` retourne `true` ET que la réponse serveur est valide, THE `Service` SHALL mettre à jour le cache SQLite local via `DatabaseService()` en fire-and-forget — IF la mise à jour du cache lève une exception, THE `Service` SHALL ignorer l'exception silencieusement sans affecter la valeur de retour.
5. THE `RepaymentApiService` SHALL encapsuler tous les accès à `DatabaseService` et `ApiService` — les écrans ne doivent jamais appeler ces services directement pour les opérations couvertes.
6. THE `LoanRequestApiService` SHALL encapsuler tous les accès à `DatabaseService` et `ApiService` — les écrans ne doivent jamais appeler ces services directement pour les opérations couvertes.
7. WHERE plusieurs postes Flutter saisissent des données concurrentes pour le même enregistrement, THE `SyncService` SHALL résoudre le conflit en appliquant la stratégie last-write-wins basée sur le champ `updatedAt` — l'enregistrement avec le `updatedAt` le plus récent écrase silencieusement les versions antérieures sans notification à l'utilisateur.
