# Implementation Plan: Phase 1 — Sécurité

## Overview

Trois axes de sécurité critiques à implémenter de manière incrémentale :

1. **Persistance JWT** — stocker/restaurer/nettoyer les tokens via `flutter_secure_storage` dans `AuthService` et `ApiService`.
2. **RBAC Sidebar** — filtrage dynamique des 46 entrées de navigation selon le rôle via `canAccessModule()`, avec garde dans `MainLayout`.
3. **Chiffrement SQLite mobile** — branchement conditionnel `sqflite_sqlcipher` (Android/iOS) vs `sqflite_common_ffi` (Desktop), enrichissement de `KeyDerivationService`, bannière et log d'audit dans `SecurityAuditPage`.

---

## Tasks

- [x] 1. Ajouter la dépendance `sqflite_sqlcipher` et l'enum `SidebarModule`
  - Ajouter `sqflite_sqlcipher: ^2.2.0` dans la section `dependencies` de `pubspec.yaml`, après `sqflite_common_ffi`
  - Créer le fichier `lib/models/sidebar_module.dart` contenant l'enum `SidebarModule` avec les 16 valeurs : `dashboard`, `clients`, `groupesSolidaires`, `prets`, `remboursements`, `epargne`, `caisse`, `comptabilite`, `reporting`, `agencesAgents`, `communications`, `documents`, `configuration`, `utilisateursDroits`, `securiteAudit`, `serveurConnexion`
  - _Requirements: 5.1, 6.1_

  - [x] 1.1 Ajouter `sqflite_sqlcipher` dans `pubspec.yaml`
    - Ajouter la ligne `sqflite_sqlcipher: ^2.2.0` dans `pubspec.yaml`
    - _Requirements: 6.1_

  - [x] 1.2 Créer `lib/models/sidebar_module.dart` avec l'enum `SidebarModule`
    - Déclarer les 16 valeurs de l'enum exactement comme spécifié dans le design
    - _Requirements: 5.1_

- [x] 2. Implémenter la persistance JWT dans `AuthService`
  - Modifier `lib/core/services/auth_service.dart` pour intégrer `flutter_secure_storage`
  - Implémenter le stockage du `sigma_access_token` et `sigma_refresh_token` au login online
  - Implémenter `_clearSecureStorage()` appelé dans `logout()`
  - Implémenter la restauration de session dans `init()` : lire le token, vérifier expiration, tenter refresh si nécessaire, sinon nettoyer et laisser l'écran de login s'afficher
  - Ajouter les méthodes RBAC `canAccessModule(SidebarModule)` et `canAccessIndex(int)` avec la matrice `_rbacMatrix` et le mapping `_moduleIndexes` tels que définis dans le design
  - Ne pas stocker de token en mode offline (Requirement 1.6 : le chemin SQLite offline reste inchangé)
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 5.1, 5.3, 5.4_

  - [x] 2.1 Stocker les tokens au login online dans `AuthService.login()`
    - Dans la branche `if (serverAvailable)` et après login réussi, appeler `FlutterSecureStorage().write` pour `sigma_access_token` et `sigma_refresh_token`
    - _Requirements: 1.1_

  - [x] 2.2 Implémenter `_clearSecureStorage()` et l'appeler dans `logout()`
    - Supprimer `sigma_access_token` et `sigma_refresh_token` du secure storage lors du logout
    - _Requirements: 1.5_

  - [x]* 2.3 Écrire le test de propriété Property 3 — Nettoyage sécurisé au logout
    - **Property 3 : Nettoyage sécurisé au logout**
    - Pour tout `accessToken` quelconque, après `logout()`, `sigma_access_token` et `sigma_refresh_token` doivent être `null` dans le storage
    - **Validates: Requirements 1.5**

  - [x] 2.4 Implémenter la restauration de session dans `AuthService.init()`
    - Lire `sigma_access_token` → valide ? → restaurer session via `SharedPreferences` userId
    - Sinon lire `sigma_refresh_token` → tenter `ApiService().tryRefresh()` → succès ? → restaurer
    - Sinon → `_clearSecureStorage()` → laisser `isLoggedIn = false`
    - _Requirements: 1.2, 1.3, 1.4_

  - [x]* 2.5 Écrire le test de propriété Property 1 — Stockage sécurisé post-login (round-trip)
    - **Property 1 : Stockage sécurisé post-login**
    - Pour tout couple `(accessToken, refreshToken)` suite à un login online réussi, la lecture dans le secure storage doit retourner exactement ces valeurs
    - **Validates: Requirements 1.1**

  - [x]* 2.6 Écrire le test de propriété Property 2 — Restauration de session au démarrage
    - **Property 2 : Restauration de session au démarrage**
    - Pour tout `accessToken` valide pré-chargé dans le secure storage, `AuthService.init()` doit produire `isLoggedIn == true`
    - **Validates: Requirements 1.2**

  - [x] 2.7 Ajouter `canAccessModule()`, `canAccessIndex()`, `_rbacMatrix` et `_moduleIndexes` dans `AuthService`
    - Implémenter la matrice RBAC complète pour les 6 rôles × 16 modules exactement comme dans le design
    - Implémenter le mapping `_moduleIndexes` associant chaque `SidebarModule` à ses index de navigation
    - _Requirements: 5.1, 5.3, 5.4_

  - [x]* 2.8 Écrire le test de propriété Property 10 — Conformité `canAccessModule()` à la matrice RBAC
    - **Property 10 : Conformité de `canAccessModule()` à la matrice RBAC**
    - Pour tout couple `(SystemRole, SidebarModule)`, `canAccessModule()` doit retourner exactement la valeur de la matrice (✓→true, ✗→false)
    - **Validates: Requirements 5.1, 5.3**

  - [x]* 2.9 Écrire le test de propriété Property 11 — Cohérence index ↔ module dans `canAccessIndex()`
    - **Property 11 : Cohérence index ↔ module dans `canAccessIndex()`**
    - Pour tout index `i` et module `m` tel que `i ∈ _moduleIndexes[m]`, `canAccessIndex(i)` doit retourner la même valeur que `canAccessModule(m)`
    - **Validates: Requirements 5.4, 4.6**

- [x] 3. Checkpoint — Vérifier la persistance JWT et le RBAC service
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Mettre à jour `ApiService` avec le chargement de token et l'intercepteur 401
  - Modifier `lib/core/services/api_service.dart`
  - Dans `init()` : charger `sigma_access_token` depuis `FlutterSecureStorage` et l'affecter à `_accessToken`
  - Remplacer le getter `_authHeaders` par `_headersFor(String path)` excluant `/auth/login` et `/auth/refresh` de l'injection du header `Authorization`
  - Mettre à jour les méthodes `get`, `post`, `put`, `delete` pour utiliser `_headersFor(path)`
  - Ajouter `bool tryRefresh(String refreshToken)` qui appelle `POST /auth/refresh`, met à jour `_accessToken` + secure storage, retourne `false` en cas d'échec
  - Ajouter `_isRefreshing`, `_refreshQueue` (liste de `Completer<bool>`) et `_handleUnauthorized()` avec file d'attente
  - Modifier `get`, `post`, `put`, `delete` pour détecter HTTP 401 et appeler `_handleUnauthorized()` puis rejouer la requête une fois
  - Exposer `String? get currentAccessToken => _accessToken`
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 3.1, 3.2, 3.3, 3.4_

  - [x] 4.1 Charger le token depuis `flutter_secure_storage` dans `ApiService.init()`
    - Ajouter `_accessToken = await storage.read(key: 'sigma_access_token')` à la fin de `init()`
    - _Requirements: 3.4_

  - [x]* 4.2 Écrire le test de propriété Property 5 — Chargement du token au démarrage d'`ApiService` (round-trip)
    - **Property 5 : Chargement du token au démarrage d'`ApiService`**
    - Pour tout `accessToken` préalablement stocké, après `ApiService.init()`, les requêtes doivent injecter ce token dans `Authorization`
    - **Validates: Requirements 3.4**

  - [x] 4.3 Implémenter `_headersFor(path)` et mettre à jour les méthodes HTTP
    - Exclure `/auth/login` et `/auth/refresh` de l'injection du header
    - Mettre à jour `get`, `post`, `put`, `delete` pour utiliser `_headersFor(path)`
    - _Requirements: 3.1, 3.2, 3.3_

  - [x]* 4.4 Écrire le test de propriété Property 4 — Injection du header Authorization
    - **Property 4 : Injection du header Authorization**
    - Pour tout `accessToken` non nul et tout endpoint hors `/auth/login`/`/auth/refresh`, le header `Authorization: Bearer` doit être présent. Pour token nul ou endpoint exclu, le header doit être absent.
    - **Validates: Requirements 3.1, 3.2, 3.3**

  - [x] 4.5 Implémenter `tryRefresh()`, `_handleUnauthorized()` et la file d'attente dans `ApiService`
    - Implémenter `_isRefreshing`, `_refreshQueue`, `_drainQueue()` et `_handleUnauthorized()` comme décrit dans le design
    - Modifier `get`, `post`, `put`, `delete` pour rappeler la requête après refresh réussi (une seule tentative)
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

  - [x]* 4.6 Écrire le test de propriété Property 6 — Unicité du refresh par cycle
    - **Property 6 : Unicité du refresh par cycle**
    - Pour tout `N ≥ 1` requêtes concurrentes recevant 401, `POST /auth/refresh` doit être appelé exactement une fois et toutes les requêtes en attente doivent être rejouées
    - **Validates: Requirements 2.4, 2.5**

  - [x]* 4.7 Écrire le test de propriété Property 7 — Rejeu des requêtes après refresh réussi
    - **Property 7 : Rejeu des requêtes après refresh réussi**
    - Pour tout nouvel `accessToken` obtenu via refresh, toutes les requêtes en file doivent être renvoyées avec ce nouveau token
    - **Validates: Requirements 2.2, 2.4**

- [x] 5. Checkpoint — Vérifier l'intercepteur HTTP et le refresh token
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Refactoriser `Sidebar` avec structure déclarative et filtrage RBAC
  - Modifier `lib/widgets/sidebar.dart`
  - Déclarer les classes internes `_SidebarSection` et `_SidebarEntry` (ou des structures équivalentes) dans le fichier
  - Construire la liste `_allSections` de façon déclarative : une `_SidebarSection` par groupe de navigation, chacune portant son `SidebarModule` et sa liste d'`_SidebarEntry` (index, icon, label)
  - Dans `build()`, filtrer `_allSections` avec `AuthService().canAccessModule(section.module)` → `visibleSections`
  - Itérer sur `visibleSections` pour rendre `_buildSectionTitle()` + les `_buildNavItem()` correspondants
  - Les entrées et titres de section non autorisés ne doivent pas apparaître dans le widget tree (ni `Opacity`, ni `Visibility`, ni `IgnorePointer`)
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 5.2_

  - [x] 6.1 Créer la structure déclarative `_SidebarSection` / `_SidebarEntry` et la liste `_allSections`
    - Mapper les 46 entrées existantes en 16 sections avec leurs `SidebarModule` associés
    - _Requirements: 4.1, 5.2_

  - [x] 6.2 Implémenter le filtrage RBAC dans `Sidebar.build()` via `canAccessModule()`
    - Filtrer les sections et afficher uniquement les entrées autorisées
    - Supprimer les appels hardcodés à `_buildNavItem` et `_buildSectionTitle` de la `ListView`
    - _Requirements: 4.1, 4.4, 4.5_

  - [ ]* 6.3 Écrire le test de propriété Property 8 — Visibilité RBAC de la Sidebar
    - **Property 8 : Visibilité RBAC de la Sidebar**
    - Pour tout rôle `r` et module `m`, les entrées correspondant à `m` doivent être présentes dans le widget tree si et seulement si `canAccessModule(m) == true`. Les entrées non autorisées ne doivent pas apparaître (ni grisées, ni masquées)
    - **Validates: Requirements 4.1, 4.4, 5.2**

  - [ ]* 6.4 Écrire le test de propriété Property 9 — Masquage des titres de sections vides
    - **Property 9 : Masquage des titres de sections vides**
    - Pour tout rôle `r`, si toutes les entrées d'une section sont non autorisées, le titre de section doit être absent du widget tree
    - **Validates: Requirements 4.5**

- [x] 7. Ajouter la garde RBAC dans `MainLayout.onDestinationSelected()`
  - Modifier `lib/screens/main_layout.dart`
  - Dans le callback `onDestinationSelected`, avant toute logique existante, appeler `AuthService().canAccessIndex(index)`
  - Si `false` : `setState(() => _selectedIndex = 0)` + afficher un `SnackBar` rouge avec le message `'Accès refusé. Vous n\'avez pas les droits pour ce module.'`
  - Si `true` : exécuter le comportement existant inchangé (dialog index 3, incrémentation `_dashboardRefreshKey`, navigation)
  - _Requirements: 4.6_

  - [x] 7.1 Implémenter la garde RBAC dans `onDestinationSelected` de `_MainLayoutState`
    - Insérer la vérification `canAccessIndex` en tête du callback
    - _Requirements: 4.6_

  - [ ]* 7.2 Écrire les tests unitaires pour la garde RBAC de `MainLayout`
    - Test : navigation vers index non autorisé → `_selectedIndex` reste 0 + SnackBar affiché
    - Test : navigation vers index autorisé → `_selectedIndex` mis à jour correctement
    - _Requirements: 4.6_

- [x] 8. Checkpoint — Vérifier le filtrage RBAC Sidebar et la garde MainLayout
  - Ensure all tests pass, ask the user if questions arise.

- [x] 9. Enrichir `KeyDerivationService` avec génération et stockage de `sigma_db_key`
  - Modifier `lib/core/services/key_derivation_service.dart`
  - Ajouter la méthode publique `Future<String> getDatabaseKey()` qui :
    - Lit `sigma_db_key` depuis `FlutterSecureStorage`
    - Si absent, génère un secret aléatoire sécurisé (utiliser `dart:math` `Random.secure()` + encodage hex 32 octets), le stocke sous `sigma_db_key`, puis le retourne
    - Dérive la clé finale depuis le secret via la méthode `_deriveKey()` existante (input = le secret seul, sans username)
    - Si `flutter_secure_storage` est inaccessible, lève une `EncryptionKeyException` (classe déjà présente dans le fichier)
  - _Requirements: 6.4, 6.5_

  - [x] 9.1 Implémenter `getDatabaseKey()` dans `KeyDerivationService`
    - Génération, stockage et dérivation de `sigma_db_key` indépendamment des tokens JWT
    - _Requirements: 6.4_

  - [ ]* 9.2 Écrire le test de propriété Property 12 — Dérivation de clé déterministe
    - **Property 12 : Dérivation de clé déterministe (idempotence)**
    - Pour tout secret `s` stocké dans le secure storage, deux appels successifs à `getDatabaseKey()` doivent retourner une clé identique
    - **Validates: Requirements 6.4**

- [x] 10. Brancher `DatabaseService` sur `sqflite_sqlcipher` (mobile) vs `sqflite_common_ffi` (desktop)
  - Modifier `lib/core/services/database_service.dart`
  - Ajouter l'import conditionnel : `import 'dart:io' show Platform` (déjà présent probablement — vérifier)
  - Extraire le contenu de `_initDatabase()` dans deux méthodes dédiées :
    - `_openMobileDatabase(String path)` : appelle `KeyDerivationService().getDatabaseKey()`, puis `openDatabase(path, password: key, ...)` via `sqflite_sqlcipher`. En cas d'exception de `KeyDerivationService`, re-lever sans ouvrir la base non chiffrée.
    - `_openDesktopDatabase(String path)` : positionne `databaseFactory = databaseFactoryFfi` puis appelle `openDatabase(path, ...)` sans mot de passe
  - Dans `_initDatabase()` : dispatcher via `if (Platform.isAndroid || Platform.isIOS)` → `_openMobileDatabase` / else → `_openDesktopDatabase`
  - Ajouter les imports nécessaires : `sqflite_sqlcipher` (conditionnel, uniquement mobile) et `sqflite_common_ffi`
  - _Requirements: 6.1, 6.2, 6.3, 6.5_

  - [x] 10.1 Ajouter les imports et implémenter `_openDesktopDatabase()` (comportement existant extrait)
    - Déplacer la logique `databaseFactoryFfi` existante dans `_openDesktopDatabase()`
    - _Requirements: 6.2_

  - [x] 10.2 Implémenter `_openMobileDatabase()` avec `sqflite_sqlcipher` et `KeyDerivationService`
    - Appeler `getDatabaseKey()`, ouvrir via `sqflite_sqlcipher`, propager l'exception si la clé est indisponible
    - _Requirements: 6.1, 6.3, 6.5_

  - [x] 10.3 Implémenter le dispatcher plateforme dans `_initDatabase()`
    - Conditionner sur `Platform.isAndroid || Platform.isIOS`
    - _Requirements: 6.1, 6.2_

  - [ ]* 10.4 Écrire les tests unitaires de branchement plateforme dans `DatabaseService`
    - Test : plateforme mobile → `_openMobileDatabase` sélectionné (mock `Platform`)
    - Test : plateforme desktop → `_openDesktopDatabase` sélectionné
    - Test : `KeyDerivationService` lance une exception → `DatabaseService` ne tente pas d'ouvrir la base non chiffrée
    - _Requirements: 6.1, 6.2, 6.5_

- [x] 11. Ajouter la bannière Desktop et le log d'audit dans `SecurityAuditPage`
  - Modifier `lib/screens/configuration/security_audit_page.dart`
  - Ajouter la méthode `Widget _buildDesktopWarningBanner()` :
    - Retourne `SizedBox.shrink()` si `!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS`
    - Sinon retourne un `Container` amber avec l'icône `Icons.warning_amber_rounded` et le texte exact : « Contrainte technique : sqflite_common_ffi (Desktop) ne supporte pas SQLCipher. Chiffrement actif sur Android/iOS uniquement. » + recommandation BitLocker/FileVault/LUKS
  - Injecter `_buildDesktopWarningBanner()` en tête du `body` du Scaffold (avant la `TabBarView`)
  - Ajouter la méthode `Future<void> _logDesktopSessionIfNeeded()` dans `_SecurityAuditPageState` :
    - Retourne si non desktop
    - Retourne si rôle != `superAdmin` et != `directeurFinancier`
    - Sinon insère un `AuditLog` avec `action: 'SQLITE_UNENCRYPTED_DESKTOP'`, `severity: AuditSeverity.medium`
  - Appeler `_logDesktopSessionIfNeeded()` dans `initState()` après `_loadLogs()`
  - _Requirements: 7.1, 7.2, 7.3_

  - [x] 11.1 Implémenter `_buildDesktopWarningBanner()` et l'injecter dans le `build()`
    - Bannière conditionnelle avec le texte réglementaire exact
    - _Requirements: 7.1, 7.2_

  - [x] 11.2 Implémenter `_logDesktopSessionIfNeeded()` et l'appeler dans `initState()`
    - Log d'audit `SQLITE_UNENCRYPTED_DESKTOP` pour `superAdmin` et `directeurFinancier` sur Desktop
    - _Requirements: 7.3_

  - [ ]* 11.3 Écrire les tests unitaires de `SecurityAuditPage`
    - Test : Desktop → bannière visible dans le widget tree
    - Test : `superAdmin` + Desktop → `insertAuditLog` appelé avec `SQLITE_UNENCRYPTED_DESKTOP`
    - Test : rôle `agentCredit` + Desktop → `insertAuditLog` non appelé
    - _Requirements: 7.1, 7.2, 7.3_

- [x] 12. Checkpoint final — `flutter analyze` + `flutter test`
  - Lancer `flutter analyze` et corriger tous les avertissements et erreurs
  - Lancer `flutter test` et s'assurer que tous les tests passent
  - ~~Vérifier que la compilation release Android (`flutter build apk --release`) ne lève pas d'erreur liée à `sqflite_sqlcipher`~~ — **non applicable** (développement Desktop PC uniquement)
  - Ensure all tests pass, ask the user if questions arise.
  - **Validé** : `flutter analyze lib/` 0 erreur, `flutter test` 81 tests OK (juin 2026)

---

## Notes

- Les tâches marquées `*` sont optionnelles et peuvent être sautées pour un MVP plus rapide.
- Chaque tâche référence les exigences spécifiques du `requirements.md` pour la traçabilité.
- Le mode offline (fallback SQLite) ne doit jamais être modifié : les tokens JWT ne sont ni stockés ni lus en mode offline (Requirement 1.6).
- `sigma_db_key` doit survivre au logout — ne jamais l'inclure dans `_clearSecureStorage()` (décision architecturale : clé de chiffrement persistante, tokens JWT éphémères).
- Le branchement `sqflite_sqlcipher` vs `sqflite_common_ffi` est conditionnel à l'exécution via `Platform.isAndroid || Platform.isIOS` — pas de compilation conditionnelle nécessaire.
- Les tests de propriétés utilisent `dart_check` ou `fast_check` avec minimum 100 itérations par propriété.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2"] },
    { "id": 1, "tasks": ["2.1", "2.7"] },
    { "id": 2, "tasks": ["2.2", "2.4"] },
    { "id": 3, "tasks": ["2.3", "2.5", "2.6", "2.8", "2.9", "4.1"] },
    { "id": 4, "tasks": ["4.3", "4.5"] },
    { "id": 5, "tasks": ["4.2", "4.4", "4.6", "4.7"] },
    { "id": 6, "tasks": ["6.1", "9.1", "10.1"] },
    { "id": 7, "tasks": ["6.2", "7.1", "10.2"] },
    { "id": 8, "tasks": ["6.3", "6.4", "7.2", "9.2", "10.3"] },
    { "id": 9, "tasks": ["10.4", "11.1"] },
    { "id": 10, "tasks": ["11.2", "11.3"] }
  ]
}
```
