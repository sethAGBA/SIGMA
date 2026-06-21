# Requirements Document

## Introduction

La Phase 0 — Infrastructure réseau établit les fondations techniques permettant à l'application Flutter SIGMA Micro-Finance de communiquer avec le backend FastAPI/PostgreSQL déployé sur le PC serveur du réseau local (LAN). Cette phase couvre quatre axes :

1. **Migrations Alembic** — écrire les fichiers de migration manquants pour chaque domaine métier afin de passer de la création automatique des tables (`create_tables()`) à une gestion versionnée du schéma PostgreSQL.
2. **Services API Flutter** — créer les neuf services API manquants (épargne, caisse, comptabilité, reporting, dashboard, produits, agences, groupes solidaires, configuration) en suivant le patron `ClientApiService` / `LoanApiService` déjà établi.
3. **Basculement automatique Online/Offline** — enrichir le `ConnectivityMonitor` existant avec la détection réseau système via `connectivity_plus` en plus du ping `/health`, et déclencher automatiquement la synchronisation des opérations en file lors du retour de la connexion.
4. **Configuration IP serveur** — exposer la configuration de l'URL du serveur dans l'écran Paramètres existant, section « Connexion serveur », accessible uniquement aux rôles `ADMIN`.

À l'issue de cette phase, tous les modules Flutter peuvent lire leurs données depuis PostgreSQL (source de vérité réseau) lorsque le serveur est disponible, et basculer automatiquement sur le cache SQLite local en cas de déconnexion.

---

## Glossaire

- **ApiService** : service Flutter singleton existant — client HTTP générique vers le backend FastAPI (`lib/core/services/api_service.dart`).
- **ConnectivityMonitor** : service Flutter singleton existant — surveille la disponibilité du serveur et notifie les widgets via `ValueNotifier<ConnectivityStatus>` (`lib/core/services/connectivity_monitor.dart`).
- **SyncService** : service Flutter singleton existant — gère la file de synchronisation différée et le flush des opérations en attente (`lib/core/services/sync_service.dart`).
- **DatabaseService** : service Flutter singleton existant — accès au cache SQLite local (`lib/core/services/database_service.dart`).
- **Module API Service** : fichier Dart nommé `{domaine}_api_service.dart` implémentant la stratégie « Server is Truth » pour un module métier.
- **Stratégie Server is Truth** : patron de lecture/écriture où PostgreSQL est la source de vérité en mode connecté, SQLite local est le cache en mode déconnecté, et toute écriture cible SQLite d'abord avant le serveur (ou la file de sync).
- **Migration Alembic** : fichier Python dans `backend/alembic/versions/` généré via Alembic, décrivant les changements de schéma PostgreSQL pour un domaine métier.
- **Domaine métier** : regroupement logique de tables PostgreSQL autour d'un périmètre fonctionnel (utilisateurs, clients, prêts/remboursements, épargne, caisse, comptabilité, produits, agences/agents, groupes solidaires, configuration/audit).
- **ConnectivityStatus** : enum Flutter existant — valeurs `online`, `offline`, `syncing`.
- **connectivity_plus** : package Flutter détectant le type de connectivité réseau du système (WiFi, mobile, Ethernet, none).
- **Endpoint `/health`** : route FastAPI existante retournant `{"status": "ok", "service": "SIGMA API"}` — utilisée pour vérifier la disponibilité du serveur.
- **Section « Connexion serveur »** : section à créer dans l'écran Paramètres Flutter, affichant et permettant la modification de l'URL du serveur.
- **Rôle ADMIN** : rôle utilisateur SIGMA disposant de l'accès complet, y compris la configuration système.
- **URL serveur** : URL de base du backend FastAPI, par défaut `http://localhost:8000/api/v1`, persistée via `SharedPreferences`.

---

## Requirements

### Requirement 1 — Migrations Alembic par domaine métier

**User Story :** En tant qu'administrateur système, je veux des migrations Alembic versionnées pour chaque domaine métier, afin de pouvoir initialiser et faire évoluer le schéma PostgreSQL de manière reproductible entre les environnements de développement, de test et de production.

#### Acceptance Criteria

1. THE Migration System SHALL produire un fichier de migration Alembic distinct dans `backend/alembic/versions/` pour chacun des dix domaines métier suivants : utilisateurs, clients, prêts/remboursements, épargne, caisse, comptabilité, produits, agences/agents, groupes solidaires, configuration/audit.

2. WHEN la commande `alembic upgrade head` est exécutée sur une base PostgreSQL vide, THE Migration System SHALL créer la totalité des tables définies dans `backend/app/models/` sans erreur.

3. WHEN la commande `alembic downgrade -1` est exécutée, THE Migration System SHALL annuler la migration du domaine correspondant sans corrompre les tables des autres domaines.

4. THE Migration System SHALL couvrir les relations de clés étrangères entre domaines en respectant un ordre de migration qui garantit que les tables référencées sont créées avant les tables référençantes.

5. WHEN une migration est appliquée sur une base contenant déjà des données, THE Migration System SHALL préserver les données existantes dans les tables non modifiées par cette migration.

6. IF `alembic upgrade head` échoue en raison d'une erreur de schéma, THEN THE Migration System SHALL effectuer un rollback automatique de la migration en cours et retourner un message d'erreur précisant la migration et la table en cause.

---

### Requirement 2 — Services API Flutter pour les neuf modules manquants

**User Story :** En tant que développeur Flutter, je veux un service API dédié pour chacun des neuf modules sans couverture réseau (épargne, caisse, comptabilité, reporting, dashboard, produits, agences, groupes solidaires, configuration), afin que ces modules lisent leurs données depuis PostgreSQL quand le serveur est disponible et depuis SQLite local en mode déconnecté.

#### Acceptance Criteria

1. THE Flutter Application SHALL fournir les neuf fichiers suivants, chacun dans `lib/core/services/` : `savings_api_service.dart`, `cash_api_service.dart`, `accounting_api_service.dart`, `reporting_api_service.dart`, `dashboard_api_service.dart`, `products_api_service.dart`, `agency_api_service.dart`, `group_api_service.dart`, `configuration_api_service.dart`.

2. THE Flutter Application SHALL implémenter chaque Module API Service comme un singleton Dart suivant le patron `ClientApiService` : constructeur privé `_internal()`, instance statique, factory renvoyant l'instance unique.

3. WHEN le serveur est disponible (résultat `SyncService().isOnline` est `true`), THE Module API Service SHALL envoyer les requêtes de lecture via `ApiService().get(path)` et mettre à jour le cache SQLite local via `DatabaseService()` avant de retourner les données.

4. WHEN le serveur est indisponible (résultat `SyncService().isOnline` est `false`), THE Module API Service SHALL retourner les données depuis `DatabaseService()` sans émettre de requête HTTP.

5. WHEN une opération d'écriture est initiée, THE Module API Service SHALL d'abord persister la donnée dans SQLite via `DatabaseService()`, puis tenter l'envoi vers le serveur via `ApiService()`, et en cas d'échec enqueue l'opération via `SyncService().queueOperation()`.

6. IF `ApiService().get(path)` retourne `null` ou un code HTTP hors de la plage 200-299, THEN THE Module API Service SHALL utiliser les données du cache SQLite local sans propager d'exception vers l'appelant.

7. THE Flutter Application SHALL intégrer chaque Module API Service dans les écrans correspondants en remplacement des appels directs à `DatabaseService()` pour les opérations de lecture principale.

---

### Requirement 3 — Basculement automatique Online/Offline

**User Story :** En tant qu'utilisateur SIGMA, je veux que l'application bascule automatiquement entre le mode connecté et le mode déconnecté, afin que la synchronisation des opérations en attente démarre dès le retour du réseau sans action manuelle de ma part.

#### Acceptance Criteria

1. THE ConnectivityMonitor SHALL détecter les changements de connectivité réseau système en s'abonnant aux événements du package `connectivity_plus` en complément du ping périodique vers `/health`.

2. WHEN `connectivity_plus` signale un type de connectivité `none`, THE ConnectivityMonitor SHALL passer immédiatement `statusNotifier` à `ConnectivityStatus.offline` sans attendre le prochain tick du timer.

3. WHEN `connectivity_plus` signale un type de connectivité différent de `none` (WiFi, Ethernet, mobile), THE ConnectivityMonitor SHALL déclencher une vérification immédiate de disponibilité du serveur via `ApiService().isServerAvailable()`.

4. WHEN `ApiService().isServerAvailable()` retourne `true` après une période de statut `offline`, THE ConnectivityMonitor SHALL passer `statusNotifier` à `ConnectivityStatus.syncing`, appeler `SyncService().flushPendingOperations()`, puis passer à `ConnectivityStatus.online` une fois le flush terminé.

5. WHILE `statusNotifier` est `ConnectivityStatus.syncing`, THE ConnectivityMonitor SHALL ignorer les nouveaux événements de connectivité afin d'éviter les appels concurrents à `flushPendingOperations()`.

6. THE ConnectivityMonitor SHALL maintenir le ping périodique vers `/health` toutes les 30 secondes comme mécanisme de vérification complémentaire, indépendamment des événements `connectivity_plus`.

7. IF `SyncService().flushPendingOperations()` retourne un `SyncResult` avec `failed > 0`, THEN THE ConnectivityMonitor SHALL passer `statusNotifier` à `ConnectivityStatus.online` et conserver les entrées en statut `failed` dans la file pour une résolution manuelle ultérieure.

---

### Requirement 4 — Configuration IP serveur dans les Paramètres

**User Story :** En tant qu'administrateur SIGMA, je veux configurer l'adresse IP et le port du serveur backend depuis l'écran Paramètres de l'application, afin de pointer l'application vers le bon serveur lors du premier déploiement ou lors d'un changement d'adresse réseau.

#### Acceptance Criteria

1. THE Settings Screen SHALL afficher une section intitulée « Connexion serveur » visible uniquement lorsque l'utilisateur connecté possède le rôle `ADMIN`.

2. THE Settings Screen SHALL afficher dans la section « Connexion serveur » un champ de saisie pré-rempli avec la valeur actuelle de l'URL serveur lue depuis `ApiService().baseUrl`.

3. WHEN un administrateur soumet une nouvelle URL dans le champ de saisie, THE Settings Screen SHALL appeler `ApiService().setServerUrl(url)` pour persister la valeur via `SharedPreferences`.

4. WHEN `ApiService().setServerUrl(url)` est appelé avec succès, THE ConnectivityMonitor SHALL déclencher une vérification immédiate de disponibilité du serveur via `ApiService().isServerAvailable()` et mettre à jour `statusNotifier` en conséquence.

5. THE Settings Screen SHALL afficher un indicateur visuel dans la section « Connexion serveur » reflétant le statut de connexion courant : vert pour `ConnectivityStatus.online`, orange pour `ConnectivityStatus.syncing`, rouge pour `ConnectivityStatus.offline`.

6. IF l'URL saisie ne correspond pas au format `http(s)://[host]:[port]`, THEN THE Settings Screen SHALL afficher un message d'erreur de validation en ligne et ne pas appeler `ApiService().setServerUrl()`.

7. WHEN l'administrateur active le bouton « Tester la connexion » dans la section « Connexion serveur », THE Settings Screen SHALL appeler `ApiService().isServerAvailable()` avec l'URL saisie et afficher le résultat (succès ou échec) dans la section sans modifier l'URL persistée.

8. IF un utilisateur dont le rôle n'est pas `ADMIN` tente d'accéder à la section « Connexion serveur », THEN THE Settings Screen SHALL masquer entièrement la section et ne pas afficher de message d'erreur.
