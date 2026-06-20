# Implementation Plan: Phase 5 — Mode Terrain & Synchronisation

## Overview

La Phase 5 complète l'expérience agent terrain : snapshot matinal, GPS, photos probatoires et résolution de conflits. Elle s'appuie sur le socle sync déjà livré (`sync-offline-online`). La migration SQLite passe de la version 30 à la version 31.

**Prérequis déjà livrés** (ne pas réimplémenter) :
- `SyncService`, `ConnectivityMonitor`, `SyncStatusBadge`, `SyncSupervisorScreen`
- Table `sync_queue` (v29)

**4 axes d'implémentation :**
1. **Snapshot matinal** — `FieldModeService` + bandeau mode terrain
2. **Conflits sync** — table `sync_conflicts` + dialog de résolution + HTTP 409 backend
3. **GPS** — `LocationService` + colonnes latitude/longitude
4. **Photos terrain** — visites prêt + justificatifs remboursement

## Tasks

- [x] 1. Migration SQLite v31 — Colonnes terrain et tables sync
  - Dans `lib/core/services/database_service.dart`, incrémenter `_version` de 30 à 31
  - Ajouter le bloc `if (oldVersion < 31)` dans `_onUpgrade` avec `_applyPhase5Schema(db)` :
    - `ALTER TABLE demandes_pret ADD COLUMN latitude_visite REAL`
    - `ALTER TABLE demandes_pret ADD COLUMN longitude_visite REAL`
    - `ALTER TABLE remboursements ADD COLUMN latitude REAL`
    - `ALTER TABLE remboursements ADD COLUMN longitude REAL`
    - `ALTER TABLE remboursements ADD COLUMN photo_justificatif_path TEXT`
    - `CREATE TABLE IF NOT EXISTS sync_conflicts (...)` — voir design.md
    - `CREATE TABLE IF NOT EXISTS field_snapshot_meta (...)` — voir design.md
  - Appeler `_applyPhase5Schema(db)` dans `_onCreate` pour les nouvelles installations
  - _Exigences : 5.1, 5.2, 5.3_

  - [x]* 1.1 Écrire le test de migration v30→v31
    - Vérifier présence des 5 colonnes + 2 tables après migration
    - Vérifier idempotence (double application sans erreur)
    - _Exigences : 5.4, 5.5_

- [x] 2. Mettre à jour les modèles `LoanRequest` et `Repayment`
  - Dans `lib/models/loan_request_model.dart` :
    - Ajouter `final double? latitudeVisite`, `final double? longitudeVisite`
    - Mettre à jour `toMap()`, `fromMap()`, constructeur
  - Dans `lib/models/repayment_model.dart` :
    - Ajouter `final double? latitude`, `final double? longitude`, `final String? photoJustificatifPath`
    - Mettre à jour `toMap()`, `fromMap()`, constructeur
  - Créer `lib/models/sync_conflict_model.dart` et `lib/models/field_snapshot_meta_model.dart`
  - _Exigences : 3.4, 3.5, 4.3, 2.1_

- [x] 3. Créer `LocationService` — wrapper geolocator
  - Ajouter `geolocator: ^13.0.2` dans `pubspec.yaml`
  - Créer `lib/core/services/location_service.dart` :
    - `hasPermission()`, `requestPermission()`, `getCurrentPosition({timeout})`
    - Retourner `null` si permission refusée ou timeout (pas d'exception non gérée)
  - Configurer les permissions Android (`AndroidManifest.xml`) et iOS (`Info.plist`) — `ACCESS_FINE_LOCATION`, `NSLocationWhenInUseUsageDescription`
  - _Exigences : 3.1, 3.2, 3.6_

  - [ ]* 3.1 Tests unitaires LocationService
    - Mock geolocator : permission refusée → null
    - Mock geolocator : position valide → lat/lng corrects
    - _Exigences : 3.2, 3.6_

- [x] 4. Intégrer le GPS dans les formulaires terrain
  - Dans `lib/screens/prets/loan_request_form_dialog.dart` → `_buildVisiteStep()` :
    - Remplacer le libellé statique « Géolocalisation activée » par capture réelle via `LocationService`
    - Afficher lat/lng ou message d'avertissement orange si indisponible
    - Persister `latitudeVisite` / `longitudeVisite` à la soumission
  - Dans `lib/screens/remboursements/repayment_form_dialog.dart` → `_submit()` :
    - Capturer position avant `insertRepayment`
    - Persister `latitude` / `longitude` sur le `Repayment`
  - Dans `lib/widgets/dialogs/client_form_dialog.dart` → étape contact :
    - Bouton « Utiliser ma position » remplissant `_latitudeController` / `_longitudeController`
  - _Exigences : 3.3, 3.4, 3.5, 3.7_

- [x] 5. Intégrer les photos terrain
  - Dans `loan_request_form_dialog.dart` → `_buildVisiteStep()` :
    - Ajouter capture photo (caméra + galerie), max 3 fichiers, max 5 Mo
    - Copier dans `{appDocDir}/visites/{requestId}/`
    - Persister chemins dans `photos_visite` (virgule)
    - Désactiver caméra sur Windows Desktop (pattern Phase 4)
  - Dans `repayment_form_dialog.dart` :
    - Section photo justificative optionnelle avec aperçu
    - Copier dans `{appDocDir}/collectes/{repaymentId}.jpg`
    - Persister `photoJustificatifPath`
  - _Exigences : 4.1, 4.2, 4.3, 4.4, 4.5_

- [x] 6. Créer `FieldModeService` — snapshot matinal
  - Créer `lib/core/services/field_mode_service.dart` :
    - `prepareMorningSnapshot()` : si online → pull clients/échéances/demandes via `ClientApiService` / `LoanApiService`, upsert SQLite, INSERT `field_snapshot_meta`
    - Si offline → utiliser dernier snapshot < 24 h ou erreur
    - `isFieldModeActive` : snapshot du jour existe pour l'agent courant
    - `activeNotifier` + `refreshActiveState()` pour rafraîchir le bandeau UI
  - Ajouter CRUD `field_snapshot_meta` dans `DatabaseService`
  - _Exigences : 1.1, 1.2, 1.3, 1.4, 1.6_

- [x] 7. UI mode terrain — bandeau et bouton préparation
  - Créer `lib/widgets/field_mode_banner.dart` — badge « Mode terrain actif » (orange)
  - Intégrer dans `lib/screens/main_layout.dart` app bar (visible si `FieldModeService.isFieldModeActive`)
  - Ajouter bouton « Préparer ma tournée » dans `DashboardPage`
  - Afficher SnackBar de confirmation avec compteurs (clients, échéances, demandes)
  - _Exigences : 1.5, 1.7_

- [x] 8. Résolution de conflits — modèle et SyncService
  - Ajouter statut `conflict` dans le cycle de vie `sync_queue` (lié via `sync_conflicts.sync_queue_id`)
  - Dans `SyncService.flushPendingOperations()` :
    - HTTP 409 → INSERT `sync_conflicts`, ne pas marquer `failed`
    - LWW auto : si `local_updated_at > server_updated_at` → ré-envoi forcé sans UI
  - Ajouter CRUD `sync_conflicts` dans `DatabaseService`
  - Méthodes `resolveConflict(id, keepLocal|keepServer)` dans `SyncService`
  - _Exigences : 2.1, 2.2, 2.3_

- [x] 9. Créer `ConflictResolutionDialog` et enrichir `SyncSupervisorScreen`
  - Créer `lib/widgets/dialogs/conflict_resolution_dialog.dart` :
    - Comparaison côte à côte local vs serveur
    - Boutons « Garder local » / « Garder serveur »
  - Dans `lib/screens/sync/sync_supervisor_screen.dart` :
    - Ajouter section « Conflits (N) »
    - Lister `sync_conflicts` en `resolution='pending'`
    - Ouvrir `ConflictResolutionDialog` au tap
  - _Exigences : 2.4, 2.5, 2.6_

- [x] 10. Extension backend — HTTP 409 sur conflits
  - Dans `backend/app/routers/clients.py` → `PUT /clients/{id}` :
    - Comparer `date_modification` / `updated_at` body vs BDD ; si obsolète → `HTTPException(409, detail={server_payload, server_updated_at})`
  - Dans `backend/app/routers/remboursements.py` → `POST /remboursements` :
    - Détecter doublon `numero_recu` → 409
  - Ajouter `numero_recu: Optional[str]` dans `RemboursementCreate` (schema Pydantic)
  - _Exigences : 2.7_

- [x] 11. Checkpoint — Tests et analyse
  - Lancer `flutter test` (migration v31 + LocationService si tests ajoutés)
  - Lancer `flutter analyze` — 0 erreur bloquante
  - Tester manuellement : préparation tournée → saisie offline → flush → conflit simulé
  - _Exigences : 5.5_

- [x] 12. Mettre à jour `analyse_projet.md`
  - Cocher les éléments Phase 5 accomplis
  - Noter les éléments reportés (upload photos serveur → Phase 7)

## Task Dependency Graph

```json
{
  "waves": [
    { "wave": 1, "tasks": ["1", "2"] },
    { "wave": 2, "tasks": ["3", "6"] },
    { "wave": 3, "tasks": ["4", "5", "7"] },
    { "wave": 4, "tasks": ["8", "10"] },
    { "wave": 5, "tasks": ["9"] },
    { "wave": 6, "tasks": ["11", "12"] }
  ]
}
```

## Notes

- Les tâches marquées `*` sont optionnelles (tests)
- La tâche 1 (migration) est le prérequis de toutes les autres
- Les tâches 4 et 5 (GPS + photos) sont indépendantes et peuvent s'exécuter en parallèle après la tâche 3
- La tâche 10 (backend 409) peut être développée en parallèle de la tâche 8 côté Flutter
- `image_picker` est déjà dans `pubspec.yaml` (Phase 4) — seul `geolocator` est à ajouter
- Le spec `sync-offline-online` reste la référence pour le socle sync ; ne pas dupliquer son implémentation
- Windows Desktop : caméra désactivée, GPS via IP/WiFi si disponible sinon null

## État initial Phase 5 (déjà livré avant ce plan)

| Élément | Statut | Référence |
|---------|--------|-----------|
| File sync différée `sync_queue` | ✅ Livré | spec `sync-offline-online` |
| `ConnectivityMonitor` + flush auto | ✅ Livré | spec `sync-offline-online` |
| `SyncSupervisorScreen` | ✅ Livré | spec `sync-offline-online` |
| Photo client `ClientFormDialog` | ✅ Livré | Phase 4 tâche 21 |
| Snapshot matinal / mode terrain | ✅ Livré | Tâches 6–7 |
| Résolution conflits | ✅ Livré | Tâches 8–10 |
| GPS réel | ✅ Livré | Tâches 3–4 |
| Photos visite / justificatif | ✅ Livré | Tâche 5 |
