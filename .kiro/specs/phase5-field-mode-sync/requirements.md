# Document des Exigences — Phase 5 : Mode Terrain & Synchronisation

## Introduction

La Phase 5 complète l'expérience **agent terrain** de SIGMA Micro-Finance : travail offline fiable en journée, synchronisation le soir, preuves géolocalisées et photos, et gestion explicite des conflits de données.

Elle s'appuie sur les fondations déjà livrées (spec `sync-offline-online`) :
- Table `sync_queue` (SQLite v29)
- `SyncService` + `ConnectivityMonitor`
- `SyncStatusBadge` + `SyncSupervisorScreen`

### Périmètre Phase 5

| Axe | Description |
|-----|-------------|
| **Mode terrain matinal** | Téléchargement d'un snapshot de référence (clients, échéances, demandes) avant la tournée |
| **Résolution de conflits** | Gestion des écritures concurrentes (last-write-wins par défaut + résolution manuelle) |
| **GPS** | Capture automatique des coordonnées sur visites et collectes |
| **Photos terrain** | Prise de photos in situ (visite prêt, justificatif remboursement) |

### État de l'existant

- `LoanRequestFormDialog` affiche « Géolocalisation activée » sans appeler de service GPS.
- `ClientFormDialog` possède des champs latitude/longitude manuels et une photo client (Phase 4), mais pas de capture GPS automatique.
- `RepaymentFormDialog` n'enregistre ni position ni photo justificative.
- `SyncService.flushPendingOperations()` traite les erreurs 4xx comme `failed` sans distinguer un conflit (409) ni proposer de résolution.
- Aucun mécanisme de « verrouillage matinal » : l'agent lit le cache SQLite existant sans snapshot daté ni bouton de préparation terrain.

## Glossaire

- **Snapshot terrain** : Copie locale datée des données de référence nécessaires à la tournée (clients du portefeuille, échéances du jour, demandes de prêt en cours).
- **FieldModeService** : Service singleton orchestrant l'activation du mode terrain, le téléchargement du snapshot et le verrouillage des rafraîchissements serveur.
- **SyncConflict** : Enregistrement représentant une opération locale rejetée par le serveur car une version plus récente existe déjà.
- **Last-Write-Wins (LWW)** : Stratégie par défaut — la version avec le `updated_at` le plus récent l'emporte.
- **LocationService** : Wrapper autour de `geolocator` pour obtenir la position GPS courante avec gestion des permissions.
- **Photo terrain** : Image capturée via `image_picker` (caméra ou galerie) et stockée localement avant sync.

---

## Exigences

### Exigence 1 : Préparation terrain matinale (snapshot + verrouillage)

**User Story :** En tant qu'agent terrain, je veux télécharger le matin les données dont j'ai besoin pour ma tournée, afin de travailler sans réseau le reste de la journée.

#### Critères d'acceptation

1. THE `FieldModeService` SHALL exposer une méthode `prepareMorningSnapshot()` téléchargeant depuis le serveur (si online) : les clients du portefeuille de l'agent connecté, les échéances du jour, et les demandes de prêt en statut `soumise` / `enAnalyse` / `approuvee`.
2. WHEN `prepareMorningSnapshot()` réussit, THE service SHALL persister un enregistrement `field_snapshot_meta` (table SQLite ou `app_prefs`) contenant : `agent_id`, `snapshot_date` (date du jour), `created_at`, `client_count`, `schedule_count`, `request_count`.
3. WHEN un snapshot valide existe pour la date du jour, THE application SHALL considérer le mode terrain comme **actif** (`FieldModeService.isFieldModeActive == true`).
4. WHILE le mode terrain est actif et le serveur est offline, THE application SHALL continuer à lire et écrire dans SQLite local sans bloquer l'utilisateur.
5. WHILE le mode terrain est actif, THE application SHALL afficher un bandeau ou badge « Mode terrain » dans l'app bar (visible uniquement pour les rôles Agent / Chef d'agence).
6. IF le serveur est indisponible lors de `prepareMorningSnapshot()`, THEN THE service SHALL afficher un message d'erreur et proposer d'utiliser le dernier snapshot disponible s'il date de moins de 24 heures.
7. THE `DashboardPage` ou un bouton dédié SHALL proposer « Préparer ma tournée » déclenchant `prepareMorningSnapshot()`.

---

### Exigence 2 : Résolution de conflits à la resynchronisation

**User Story :** En tant que chef d'agence, je veux voir et résoudre les conflits de données après la resynchronisation, afin d'éviter les pertes d'encaissements ou de mises à jour client.

#### Critères d'acceptation

1. THE migration SQLite v31 SHALL créer une table `sync_conflicts` avec : `id`, `sync_queue_id`, `entity_type`, `entity_id`, `local_payload` (TEXT JSON), `server_payload` (TEXT JSON), `local_updated_at`, `server_updated_at`, `resolution` (`pending` | `keep_local` | `keep_server`), `created_at`.
2. WHEN `SyncService.flushPendingOperations()` reçoit une réponse HTTP **409 Conflict**, THE service SHALL créer une entrée `sync_conflicts` au lieu de marquer l'opération `failed` immédiatement.
3. WHEN aucune intervention manuelle n'est requise et que `local_updated_at > server_updated_at`, THE `SyncService` SHALL appliquer automatiquement la stratégie **last-write-wins** (ré-envoi forcé ou acceptation locale selon le type d'entité).
4. THE `SyncSupervisorScreen` SHALL afficher un onglet ou section « Conflits » listant les `sync_conflicts` en statut `pending`.
5. WHEN l'utilisateur ouvre un conflit, THE application SHALL afficher un `ConflictResolutionDialog` comparant visuellement la version locale et la version serveur (champs clés : montant, date, statut).
6. WHEN l'utilisateur choisit « Garder local » ou « Garder serveur », THE `SyncService` SHALL appliquer la résolution, mettre à jour le cache SQLite, et passer `resolution` au statut choisi.
7. THE backend FastAPI SHALL retourner HTTP 409 avec un corps JSON `{ "server_payload": {...}, "server_updated_at": "..." }` pour les endpoints `PUT /clients/{id}` et `POST /remboursements` en cas de version obsolète *(extension minimale backend)*.

---

### Exigence 3 : Géolocalisation des visites et collectes

**User Story :** En tant qu'agent terrain, je veux que ma position GPS soit enregistrée automatiquement lors des visites client et des encaissements, afin de prouver ma présence sur le terrain.

#### Critères d'acceptation

1. THE `pubspec.yaml` SHALL déclarer la dépendance `geolocator: ^13.0.2` (ou version compatible Flutter 3.9+).
2. THE `LocationService` SHALL exposer `Future<Position?> getCurrentPosition()` avec timeout 10 s, gestion des permissions refusées (retour `null` sans crash).
3. WHEN l'étape « Visite terrain » de `LoanRequestFormDialog` est affichée, THE form SHALL capturer automatiquement la position GPS et afficher latitude/longitude réelles (remplacer le libellé statique « Géolocalisation activée »).
4. WHEN l'agent soumet une demande de prêt, THE `LoanRequest` SHALL persister `latitude_visite` et `longitude_visite` (nouvelles colonnes `demandes_pret` via migration v31).
5. WHEN l'agent enregistre un remboursement via `RepaymentFormDialog`, THE `Repayment` SHALL persister `latitude` et `longitude` de la collecte (nouvelles colonnes `remboursements`).
6. IF la position GPS est indisponible, THE formulaire SHALL afficher un avertissement orange mais SHALL permettre la soumission (champs nullable).
7. WHEN l'agent crée ou modifie un client dans `ClientFormDialog`, THE form SHALL proposer un bouton « Utiliser ma position » remplissant les champs latitude/longitude.

---

### Exigence 4 : Photos terrain (visites et justificatifs)

**User Story :** En tant qu'agent terrain, je veux prendre des photos sur place lors des visites et des encaissements, afin de constituer un dossier probatoire même sans réseau.

#### Critères d'acceptation

1. WHEN l'étape « Visite terrain » de `LoanRequestFormDialog` est affichée, THE form SHALL proposer un bouton « Prendre une photo » et « Choisir depuis la galerie » (réutiliser `image_picker` déjà présent).
2. THE form SHALL permettre jusqu'à **3 photos** de visite ; les chemins SHALL être stockés dans `photos_visite` (séparateur virgule) et les fichiers copiés dans `{appDocDir}/visites/{requestId}/`.
3. WHEN l'agent enregistre un remboursement, THE `RepaymentFormDialog` SHALL proposer une photo justificative optionnelle (reçu signé, liasse de billets) stockée dans `{appDocDir}/collectes/{repaymentId}/` et référencée par `photo_justificatif_path` (colonne `remboursements`, migration v31).
4. THE validation SHALL limiter chaque photo à **5 Mo** et aux formats `jpg`, `jpeg`, `png`.
5. IF l'appareil est Windows Desktop, THE bouton caméra SHALL être désactivé avec tooltip explicatif (galerie/fichier reste disponible) — même comportement que Phase 4.
6. WHEN les photos sont synchronisées au serveur, THE `SyncService` SHALL inclure le chemin local dans le body ; l'upload binaire vers le serveur est **hors périmètre** Phase 5 (chemins locaux uniquement, upload fichier = Phase 7).

---

### Exigence 5 : Migration SQLite v31 et non-régression sync

**User Story :** En tant que développeur, je veux une migration incrémentale v30→v31, afin d'ajouter les colonnes terrain sans casser les bases existantes.

#### Critères d'acceptation

1. THE `DatabaseService` SHALL incrémenter `_version` de 30 à 31.
2. THE migration v31 SHALL ajouter idempotemment :
   - `demandes_pret.latitude_visite REAL`, `demandes_pret.longitude_visite REAL`
   - `remboursements.latitude REAL`, `remboursements.longitude REAL`, `remboursements.photo_justificatif_path TEXT`
   - Table `sync_conflicts` (schéma Exigence 2)
   - Table `field_snapshot_meta` (`id`, `agent_id`, `snapshot_date`, `created_at`, `client_count`, `schedule_count`, `request_count`)
3. THE migration SHALL être idempotente via `_addColumnIfNotExists` (même pattern que Phase 4).
4. THE tests de migration v30→v31 SHALL vérifier la présence des colonnes/tables et l'idempotence.
5. THE `flutter test` et `flutter analyze` SHALL passer sans erreur bloquante à la fin de la Phase 5.

---

## Hors périmètre Phase 5

- Upload binaire des photos vers le serveur (API multipart) — reporté Phase 7
- OCR scan CNI — reporté Phase 6+
- Résolution de conflits sur toutes les entités (seulement `clients` et `remboursements` en MVP)
- Mode terrain pour le rôle Caissier (PC fixe) — agents terrain uniquement
