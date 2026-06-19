# Document de Exigences — Système de Synchronisation Offline/Online

## Introduction

L'application SIGMA Micro-Finance opère en mode **offline-first** : les clients Flutter (PC caissier, tablettes agents terrain) fonctionnent en autonomie sur un réseau LAN local, avec un backend Python FastAPI + PostgreSQL sur un PC serveur local. Quand le serveur est indisponible (coupure réseau, démarrage tardif), les opérations d'écriture doivent être conservées localement, puis transmises automatiquement dès que la connexion est rétablie.

Ce document définit les exigences pour refondre et enrichir le système de synchronisation existant autour de quatre modules :

1. **Table `sync_queue` en SQLite** — remplacement de la queue `SharedPreferences` par une table persistante avec métadonnées complètes.
2. **Détection automatique de reconnexion** — surveillance de la disponibilité du serveur en arrière-plan, déclenchement automatique du flush.
3. **Indicateur de statut dans la sidebar/app bar** — badge visuel permanent (online / offline / opérations en attente).
4. **Écran de supervision des opérations en attente** — liste consultable avec retry manuel, suppression et visualisation des erreurs.

La stratégie de résolution de conflits adoptée est **"Server is Truth"** (last-write-wins basée sur le timestamp).

---

## Glossaire

- **SyncService** : Service Dart singleton gérant la file de synchronisation et l'orchestration des flux offline/online.
- **ConnectivityMonitor** : Composant de surveillance périodique de la disponibilité du serveur (polling toutes les 30 secondes via `isServerAvailable()`).
- **SyncQueue** : Table SQLite `sync_queue` stockant les opérations en attente de synchronisation.
- **SyncOperation** : Enregistrement unique dans `SyncQueue`, représentant une requête HTTP (POST, PUT, DELETE) à rejouer.
- **SyncStatus** : Énumération des états possibles d'une `SyncOperation` : `pending`, `in_progress`, `synced`, `failed`.
- **SyncStatusIndicator** : Widget Flutter affiché en permanence dans la sidebar et l'app bar, indiquant l'état de connectivité et le nombre d'opérations en attente.
- **SyncSupervisionScreen** : Écran dédié à la visualisation, au retry manuel et à la suppression des `SyncOperation`.
- **ApiService** : Service Dart singleton gérant les appels HTTP vers le backend FastAPI, incluant `isServerAvailable()`.
- **DatabaseService** : Service Dart singleton gérant la base SQLite locale (version 28, migrations via `_onUpgrade`).
- **Priorité** : Ordre de traitement des opérations lors du flush : `remboursements` (1 = plus haute) > `clients` (2) > `epargne` (3) > `autres` (4).
- **Flush** : Action d'envoyer toutes les `SyncOperation` en statut `pending` au serveur dans l'ordre de priorité.

---

## Exigences

### Exigence 1 : Table `sync_queue` SQLite

**User Story :** En tant que développeur, je veux que les opérations en attente soient stockées dans une vraie table SQLite, afin que les métadonnées (timestamp, tentatives, priorité, statut) soient persistantes entre les redémarrages de l'application.

#### Critères d'acceptation

1. THE `DatabaseService` SHALL créer une table `sync_queue` dans la base SQLite lors de la migration vers la version 29, avec les colonnes : `id` (TEXT PRIMARY KEY), `method` (TEXT NOT NULL), `path` (TEXT NOT NULL), `body` (TEXT), `status` (TEXT NOT NULL DEFAULT `pending`), `priority` (INTEGER NOT NULL DEFAULT 4), `created_at` (TEXT NOT NULL), `updated_at` (TEXT NOT NULL), `attempt_count` (INTEGER NOT NULL DEFAULT 0), `last_error` (TEXT).
2. WHEN une `SyncOperation` est ajoutée à la `SyncQueue`, THE `SyncService` SHALL générer un identifiant UUID unique et enregistrer `created_at` et `updated_at` avec le timestamp ISO 8601 de l'instant courant.
3. WHEN une opération concerne le chemin `/remboursements`, THE `SyncService` SHALL affecter la priorité 1.
4. WHEN une opération concerne le chemin `/clients`, THE `SyncService` SHALL affecter la priorité 2.
5. WHEN une opération concerne le chemin `/epargne` ou `/comptes_epargne`, THE `SyncService` SHALL affecter la priorité 3.
6. WHEN une opération ne correspond à aucun critère de priorité spécifique, THE `SyncService` SHALL affecter la priorité 4.
7. THE `SyncService` SHALL exposer une méthode `getPendingCount()` retournant le nombre de `SyncOperation` ayant le statut `pending` ou `in_progress`.
8. THE `SyncService` SHALL exposer une méthode `getAllPendingOperations()` retournant la liste ordonnée des `SyncOperation` par priorité croissante, puis par `created_at` croissant.
9. IF une `SyncOperation` doit être migrée depuis `SharedPreferences`, THEN THE `SyncService` SHALL importer les entrées existantes dans la table `sync_queue` lors de la première ouverture après migration, puis supprimer la clé `pending_sync_operations` de `SharedPreferences`.

---

### Exigence 2 : Détection automatique de reconnexion

**User Story :** En tant qu'agent de terrain, je veux que l'application détecte automatiquement le retour de la connexion au serveur, afin que mes opérations en attente soient transmises sans action manuelle de ma part.

#### Critères d'acceptation

1. WHEN l'application est active (au premier plan), THE `ConnectivityMonitor` SHALL interroger `ApiService().isServerAvailable()` toutes les 30 secondes.
2. WHEN le résultat de `isServerAvailable()` passe de `false` à `true`, THE `ConnectivityMonitor` SHALL déclencher immédiatement un flush des opérations en attente via `SyncService.flushPendingOperations()`.
3. WHILE le serveur est indisponible, THE `ConnectivityMonitor` SHALL continuer le polling toutes les 30 secondes sans interrompre l'utilisation de l'application.
4. WHILE un flush est en cours, THE `SyncService` SHALL passer le statut des `SyncOperation` traitées à `in_progress` et ne pas relancer un flush concurrent.
5. WHEN `flushPendingOperations()` est invoqué et qu'un flush est déjà en cours, THE `SyncService` SHALL ignorer la nouvelle invocation.
6. WHEN une `SyncOperation` est transmise avec succès au serveur, THE `SyncService` SHALL passer son statut à `synced` et enregistrer `updated_at`.
7. WHEN une `SyncOperation` échoue lors du flush et que `attempt_count` est inférieur à 3, THE `SyncService` SHALL incrémenter `attempt_count`, enregistrer `last_error`, passer le statut à `pending` et remettre l'opération en file pour la prochaine tentative.
8. WHEN une `SyncOperation` échoue et que `attempt_count` est égal ou supérieur à 3, THE `SyncService` SHALL passer son statut à `failed`, enregistrer `last_error` et `updated_at`, et ne plus tenter de la renvoyer automatiquement.
9. THE `ConnectivityMonitor` SHALL s'initialiser au démarrage de l'application et se stopper proprement lors de la fermeture.

---

### Exigence 3 : Indicateur de statut dans la sidebar/app bar

**User Story :** En tant qu'utilisateur, je veux voir en permanence l'état de connexion au serveur et le nombre d'opérations en attente, afin de savoir à tout moment si mes données sont synchronisées.

#### Critères d'acceptation

1. THE `SyncStatusIndicator` SHALL afficher un badge vert avec l'icône de connexion WHEN le serveur est disponible et qu'aucune `SyncOperation` n'est en statut `pending`.
2. WHEN le serveur est indisponible, THE `SyncStatusIndicator` SHALL afficher un badge rouge avec l'icône de déconnexion.
3. WHEN le serveur est disponible et que `getPendingCount()` retourne une valeur supérieure à 0, THE `SyncStatusIndicator` SHALL afficher un badge orange avec le compteur d'opérations en attente.
4. WHILE un flush est en cours, THE `SyncStatusIndicator` SHALL afficher une animation de chargement (spinner) indiquant la synchronisation active.
5. THE `SyncStatusIndicator` SHALL être visible en permanence dans la barre latérale (sidebar) de l'application, sans nécessiter une action de navigation.
6. THE `SyncStatusIndicator` SHALL se mettre à jour au maximum toutes les 5 secondes pour refléter les changements d'état.
7. WHEN l'utilisateur clique sur le `SyncStatusIndicator`, THE Application SHALL naviguer vers la `SyncSupervisionScreen`.

---

### Exigence 4 : Écran de supervision des opérations en attente

**User Story :** En tant qu'administrateur ou caissier, je veux consulter la liste des opérations en attente, pouvoir les relancer manuellement ou les supprimer, afin de maintenir la cohérence des données en cas de problème persistant.

#### Critères d'acceptation

1. THE `SyncSupervisionScreen` SHALL afficher la liste de toutes les `SyncOperation` dont le statut est `pending`, `in_progress` ou `failed`, ordonnées par priorité puis par `created_at`.
2. WHEN la liste est vide, THE `SyncSupervisionScreen` SHALL afficher un message informatif indiquant qu'aucune opération n'est en attente.
3. THE `SyncSupervisionScreen` SHALL afficher pour chaque `SyncOperation` : la méthode HTTP, le chemin (`path`), le statut, la priorité, le nombre de tentatives, la date de création et le dernier message d'erreur si présent.
4. WHEN l'utilisateur sélectionne une `SyncOperation` en statut `failed` et clique sur "Réessayer", THE `SyncService` SHALL remettre le statut de l'opération à `pending` et réinitialiser `attempt_count` à 0, puis déclencher un flush.
5. WHEN l'utilisateur sélectionne une `SyncOperation` et clique sur "Supprimer", THE Application SHALL afficher une confirmation, et si confirmée, THE `SyncService` SHALL supprimer définitivement l'opération de la `SyncQueue`.
6. THE `SyncSupervisionScreen` SHALL proposer un bouton "Tout synchroniser" qui déclenche `flushPendingOperations()` si le serveur est disponible.
7. IF le serveur est indisponible et que l'utilisateur clique sur "Tout synchroniser", THEN THE `SyncSupervisionScreen` SHALL afficher un message d'erreur indiquant que le serveur est inaccessible.
8. THE `SyncSupervisionScreen` SHALL se rafraîchir automatiquement après chaque opération de retry ou de suppression.
9. WHEN l'utilisateur clique sur le détail d'une `SyncOperation`, THE `SyncSupervisionScreen` SHALL afficher le corps JSON de la requête (`body`) dans une vue expandable.
