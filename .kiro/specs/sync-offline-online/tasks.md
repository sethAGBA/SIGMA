# Implementation Plan: Système de Synchronisation Offline/Online

## Overview

Implémentation en Dart/Flutter en 6 étapes incrémentales. Chaque étape produit du code fonctionnel et testable. Le langage est Dart, le framework Flutter, la base de données SQLite via `sqflite`. Aucune nouvelle dépendance n'est requise — tout s'appuie sur les packages déjà déclarés dans `pubspec.yaml`.

---

## Tasks

- [x] 1. Créer le modèle `SyncQueueEntry` et migrer la base SQLite vers la version 29
  - Créer `lib/models/sync_queue_entry.dart` avec les champs : `id`, `method`, `path`, `body` (Map sérialisé), `timestamp`, `priority`, `attempts`, `status`, `errorMessage`, `createdAt`
  - Implémenter `toMap()` / `fromMap()` pour la sérialisation SQLite
  - Dans `lib/core/services/database_service.dart`, incrémenter `_version` de 28 à 29
  - Ajouter le bloc `if (oldVersion < 29)` dans `_onUpgrade` pour créer la table `sync_queue` et son index `idx_sync_queue_status_priority`
  - Ajouter le `CREATE TABLE sync_queue` dans `_onCreate` pour les nouvelles installations
  - Implémenter la migration one-shot depuis SharedPreferences : lire `pending_sync_operations`, transformer chaque entrée JSON en `SyncQueueEntry` (priority=5, attempts=0, status='pending'), insérer dans `sync_queue`, puis supprimer la clé SharedPreferences
  - _Exigences : 1.1, 1.7_

  - [ ]* 1.1 Écrire les tests de la migration et du modèle
    - Tester `SyncQueueEntry.fromMap(toMap(entry)) == entry` (round-trip)
    - **Propriété 1 : Insertion en file préserve les données de l'opération**
    - **Valide : Exigences 1.2**
    - Vérifier que la table `sync_queue` existe après migration depuis v28
    - _Exigences : 1.1, 1.2_

- [x] 2. Refactoriser `SyncService` avec la table SQLite
  - Supprimer intégralement les références à `SharedPreferences` et `_pendingOpsKey` dans `lib/core/services/sync_service.dart`
  - Implémenter `_priorityFromPath(String path)` → table de mappage préfixe/priorité (remboursements=1, caisse=2, prêts=3, clients/groupes=4, épargne/autres=5)
  - Implémenter `queueOperation({method, path, body, priority})` → INSERT dans `sync_queue` via `DatabaseService`
  - Implémenter `getPendingCount()` → SELECT COUNT WHERE status IN ('pending','syncing')
  - Implémenter `getAllEntries()` → SELECT * ORDER BY priority ASC, created_at ASC
  - Implémenter `deleteEntry(int id)` → DELETE WHERE id=?
  - Implémenter `retryEntry(int id)` → UPDATE SET status='pending', attempts=0 WHERE id=?
  - _Exigences : 1.2, 1.3, 1.5, 1.6_

  - [ ]* 2.1 Écrire les tests de propriété pour le mappage de priorités
    - **Propriété 2 : Mappage path → priorité est total et déterministe**
    - **Valide : Exigences 1.3**
    - Générer 100 chemins aléatoires avec préfixes variés, vérifier que la priorité est toujours dans [1,5] et déterministe
    - _Exigences : 1.3_

  - [ ]* 2.2 Écrire les tests de propriété pour `getPendingCount()`
    - **Propriété 4 : Cohérence de getPendingCount()**
    - **Valide : Exigences 1.5**
    - Insérer N entrées avec des statuts aléatoires, vérifier que `getPendingCount()` == nombre d'entrées en 'pending'+'syncing'
    - _Exigences : 1.5_

  - [ ]* 2.3 Écrire les tests de propriété pour `deleteEntry()`
    - **Propriété 5 : Suppression définitive d'une entrée**
    - **Valide : Exigences 1.6**
    - Insérer 100 entrées aléatoires, supprimer chacune, vérifier que SELECT retourne zéro résultat
    - _Exigences : 1.6_

  - [ ]* 2.4 Écrire les tests de propriété pour `retryEntry()`
    - **Propriété 12 : Retry remet l'entrée en état initial**
    - **Valide : Exigences 4.3**
    - Créer des entrées `failed` avec attempts > 0, appeler `retryEntry()`, vérifier status='pending' et attempts=0
    - _Exigences : 4.3_

- [x] 3. Implémenter le flush avec gestion des tentatives et statuts
  - Dans `SyncService`, implémenter `flushPendingOperations()` :
    - Vérifier `isOnline` en premier ; si false, retourner `SyncResult(success: false, synced: 0, failed: 0)`
    - Lire toutes les entrées WHERE status='pending' ORDER BY priority ASC, created_at ASC
    - Pour chaque entrée : UPDATE status='syncing', appeler l'API (POST/PUT/DELETE via `ApiService`)
    - Succès (2xx) : UPDATE status='success'
    - Erreur 4xx : UPDATE status='failed', attempts=3, error_message=responseBody (directement `failed`, pas de retry)
    - Erreur 5xx ou timeout : UPDATE attempts++ ; si attempts >= 3 → status='failed', error_message ; sinon → status='pending'
    - Exception Dart : même traitement que 5xx
  - Mettre à jour `main.dart` pour appeler `SyncService().flushPendingOperations()` au démarrage (comme actuellement)
  - _Exigences : 1.4, 1.2_

  - [ ]* 3.1 Écrire les tests de propriété pour l'escalade vers `failed`
    - **Propriété 3 : Escalade vers failed après 3 tentatives**
    - **Valide : Exigences 1.4**
    - Mocker `ApiService` pour retourner des erreurs 5xx, simuler 3 flush consécutifs, vérifier status='failed' et attempts=3
    - _Exigences : 1.4_

- [x] 4. Checkpoint — Tests de base
  - S'assurer que tous les tests unitaires et de propriété des étapes 1 à 3 passent
  - Vérifier que la migration v28→v29 s'effectue correctement sur une base existante avec données SharedPreferences
  - Demander à l'utilisateur si des clarifications sont nécessaires avant de continuer

- [x] 5. Implémenter `ConnectivityMonitor`
  - Créer `lib/core/services/connectivity_monitor.dart` avec un singleton
  - Déclarer `ValueNotifier<ConnectivityStatus> statusNotifier` initialisé à `offline`
  - Exposer `Stream<ConnectivityStatus> get statusStream` via `statusNotifier.stream` ou un `StreamController`
  - Implémenter `start()` : créer `Timer.periodic(Duration(seconds: 30), _onTick)`
  - Dans `_onTick()` :
    - Si `statusNotifier.value == ConnectivityStatus.syncing` → ne rien faire (pas de flush concurrent)
    - Appeler `ApiService().isServerAvailable()` dans un try/catch
    - Exception → `statusNotifier.value = ConnectivityStatus.offline`
    - false → `statusNotifier.value = ConnectivityStatus.offline`
    - true && was offline → `statusNotifier.value = ConnectivityStatus.syncing`, appeler `flushPendingOperations()`, puis `statusNotifier.value = ConnectivityStatus.online`
    - true && was already online → pas de flush, rester `online`
  - Implémenter `dispose()` : `_timer?.cancel()`
  - Démarrer `ConnectivityMonitor().start()` dans `main()` après l'initialisation
  - _Exigences : 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7_

  - [ ]* 5.1 Écrire les tests de propriété pour les transitions de statut
    - **Propriété 6 : Déclenchement du flush à la reconnexion**
    - **Valide : Exigences 2.2**
    - Générer des séquences aléatoires offline/online, vérifier que flush est appelé exactement 1 fois par transition offline→online
    - **Propriété 7 : Indisponibilité → statut offline**
    - **Valide : Exigences 2.3, 2.7**
    - Pour toute valeur false ou exception de `isServerAvailable`, vérifier que le statut est `offline`
    - _Exigences : 2.2, 2.3, 2.7_

  - [ ]* 5.2 Écrire le test de propriété pour l'absence de flush concurrent
    - **Propriété 8 : Pas de flush concurrent**
    - **Valide : Exigences 2.5**
    - Simuler N ticks du timer pendant un flush en cours, vérifier que `flushPendingOperations()` n'est appelé qu'une seule fois
    - _Exigences : 2.5_

- [x] 6. Implémenter `SyncStatusBadge`
  - Créer `lib/widgets/sync_status_badge.dart`
  - Le widget est un `StatelessWidget` ou `ValueListenableBuilder` écoutant `ConnectivityMonitor().statusNotifier` et un `FutureBuilder` sur `SyncService().getPendingCount()`
  - Table de correspondance visuelle :
    - `online` + pending=0 → icône `wifi` verte + label "En ligne"
    - `online` + pending>0 → icône `wifi` verte + label "En ligne" + badge orange (pending)
    - `offline` → icône `wifi_off` rouge + label "Hors ligne" + badge rouge (pending) si pending > 0
    - `syncing` → icône `sync` orange animée + label "Sync…"
  - Responsive : si `MediaQuery.of(context).size.width < 800`, masquer le label textuel
  - `onTap` → `Navigator.push` vers `SyncSupervisorScreen`
  - Intégrer le widget dans `_buildAppBar()` de `lib/screens/main_layout.dart` après le bouton "Alertes"
  - _Exigences : 3.1, 3.2, 3.3, 3.4, 3.6_

  - [ ]* 6.1 Écrire les tests de propriété pour le rendu du badge
    - **Propriété 9 : Rendu du badge cohérent avec l'état**
    - **Valide : Exigences 3.2, 3.3**
    - Générer 100 combinaisons aléatoires (ConnectivityStatus, pendingCount ≥ 0), vérifier couleur et présence du badge numérique
    - **Propriété 10 : Badge responsive**
    - **Valide : Exigences 3.6**
    - Générer 100 largeurs aléatoires, vérifier que le label est présent iff largeur ≥ 800
    - _Exigences : 3.2, 3.3, 3.6_

- [x] 7. Implémenter `SyncSupervisorScreen`
  - Créer `lib/screens/sync/sync_supervisor_screen.dart`
  - Widget `StatefulWidget` avec état local `List<SyncQueueEntry> _entries` chargé via `SyncService().getAllEntries()`
  - S'abonner à `ConnectivityMonitor().statusNotifier` pour rafraîchir la liste lors des changements
  - Afficher pour chaque entrée dans un `ListView` :
    - Méthode HTTP (chip coloré : POST=bleu, PUT=orange, DELETE=rouge)
    - Chemin API (`path`)
    - Horodatage de création (`createdAt`) formaté en `dd/MM/yyyy HH:mm`
    - Priorité (étoiles ou numéro)
    - Nombre de tentatives (`attempts`)
    - Statut (chip coloré : pending=gris, syncing=orange, success=vert, failed=rouge)
    - Si `status == 'failed'` et `errorMessage != null` : afficher `errorMessage` en rouge
    - Bouton "Réessayer" (uniquement si `status == 'failed'`) → appel `SyncService().retryEntry(id)` + refresh
    - Bouton "Supprimer" → `showDialog` de confirmation → `SyncService().deleteEntry(id)` + refresh
  - Bouton flottant ou dans l'AppBar : "Tout synchroniser" → vérifier `isOnline`, si oui appeler `flushPendingOperations()`, si non afficher `SnackBar('Serveur indisponible — synchronisation impossible')`
  - État vide : afficher une `Column` centrée avec icône `cloud_done` et texte "Aucune opération en attente"
  - _Exigences : 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 4.9_

  - [ ]* 7.1 Écrire les tests de propriété pour le tri de la liste
    - **Propriété 11 : Tri de la liste de supervision**
    - **Valide : Exigences 4.1**
    - Générer 100 listes aléatoires de SyncQueueEntry avec priorités et timestamps variés, vérifier que `getAllEntries()` les retourne triées
    - _Exigences : 4.1_

  - [ ]* 7.2 Écrire les tests de propriété pour l'affichage des métadonnées
    - **Propriété 13 : Affichage complet des métadonnées en supervision**
    - **Valide : Exigences 4.2, 4.5**
    - Pour 100 SyncQueueEntry générées aléatoirement, vérifier que le widget rendu contient method, path, createdAt, priority, attempts, status, et errorMessage si failed
    - _Exigences : 4.2, 4.5_

  - [ ]* 7.3 Écrire les tests unitaires pour les actions de la supervision
    - Tester confirmation de suppression (dialog) → annuler vs confirmer
    - Tester le SnackBar d'erreur quand serveur indisponible lors du flush manuel
    - Tester l'état vide quand `getAllEntries()` retourne une liste vide
    - _Exigences : 4.4, 4.7, 4.9_

- [x] 8. Checkpoint final — Intégration et vérification complète
  - S'assurer que tous les tests passent (`flutter test`)
  - Vérifier que `main.dart` démarre correctement `ConnectivityMonitor().start()` et appelle `SyncService().flushPendingOperations()` au démarrage
  - Vérifier la navigation complète : AppBar → SyncStatusBadge → SyncSupervisorScreen
  - Vérifier que la migration v28→v29 ne casse pas les données existantes
  - Demander à l'utilisateur si des ajustements sont nécessaires avant la livraison

## Notes

- Les tâches marquées `*` sont optionnelles et peuvent être ignorées pour un MVP rapide
- Chaque tâche de propriété référence explicitement une propriété du document de conception
- La migration depuis SharedPreferences est idempotente : si la clé n'existe pas, elle est simplement ignorée
- Le `ConnectivityMonitor` doit être démarré une seule fois dans `main()` via `ConnectivityMonitor().start()`
- Les erreurs 4xx sont traitées comme `failed` immédiatement (pas de retry) car elles indiquent une requête incorrecte ou un conflit irrécupérable

## Task Dependency Graph

```json
{
  "waves": [
    { "wave": 1, "tasks": ["1"] },
    { "wave": 2, "tasks": ["2"] },
    { "wave": 3, "tasks": ["3"] },
    { "wave": 4, "tasks": ["4"] },
    { "wave": 5, "tasks": ["5"] },
    { "wave": 6, "tasks": ["6", "7"] },
    { "wave": 7, "tasks": ["8"] }
  ]
}
```

Les étapes 6 et 7 peuvent être développées en parallèle une fois l'étape 5 terminée.
