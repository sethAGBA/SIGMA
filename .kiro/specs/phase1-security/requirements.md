# Requirements Document — Phase 1 : Sécurité

## Introduction

Cette phase couvre les trois manques de sécurité critiques identifiés dans l'analyse du projet SIGMA Micro-Finance (Flutter + FastAPI + PostgreSQL) :

1. **Persistance sécurisée du token JWT** — le token est actuellement conservé en mémoire vive uniquement ; il disparaît à chaque redémarrage de l'application et ne peut pas être rafraîchi automatiquement.
2. **Contrôle d'accès RBAC dans la Sidebar** — tous les modules sont visibles quel que soit le rôle de l'utilisateur connecté ; aucun masquage dynamique n'est appliqué.
3. **Chiffrement du cache SQLite** — `KeyDerivationService` est préparé mais la clé de chiffrement n'est pas appliquée ; une contrainte technique empêche le chiffrement sur Windows Desktop.

L'objectif est de rendre l'application conforme aux exigences de sécurité d'une IMF en zone UEMOA/OHADA sans casser le mode hybride (API + fallback SQLite) ni le mode terrain offline existant.

---

## Glossaire

- **AuthService** : singleton Flutter (`lib/core/services/auth_service.dart`) qui gère la session utilisateur, le login hybride et les droits RBAC.
- **ApiService** : singleton Flutter (`lib/core/services/api_service.dart`) qui expose les méthodes HTTP `get`, `post`, `put`, `delete` vers le backend FastAPI.
- **SessionManager** : singleton Flutter gérant le timeout d'inactivité de 15 minutes avec dialog d'avertissement.
- **Sidebar** : widget Flutter (`lib/widgets/sidebar.dart`) affichant les 46 entrées de navigation organisées en 16 sections.
- **SystemRole** : enum Flutter définissant les rôles `superAdmin`, `directeurGeneral`, `directeurOperations`, `directeurFinancier`, `chefAgence`, `agentCredit`.
- **Module** : groupe fonctionnel de la Sidebar (ex. « GESTION CLIENTS », « COMPTABILITÉ »). Un module regroupe une ou plusieurs entrées de navigation.
- **JWT (JSON Web Token)** : token d'authentification signé émis par le backend FastAPI lors du login, contenant l'identité et le rôle de l'utilisateur.
- **Access Token** : JWT de courte durée (480 min, configurable dans `.env`) utilisé pour autoriser les requêtes HTTP.
- **Refresh Token** : token de longue durée (7 jours) stocké de manière sécurisée, utilisé pour obtenir un nouvel Access Token sans re-saisir les identifiants.
- **flutter_secure_storage** : bibliothèque Flutter qui stocke des valeurs chiffrées dans le Keychain (iOS/macOS) ou Keystore (Android).
- **Intercepteur HTTP** : couche transparente dans `ApiService` qui injecte automatiquement le header `Authorization: Bearer <token>` et gère les réponses 401.
- **SQLite** : base de données locale embarquée dans l'application Flutter, utilisée comme cache offline.
- **sqflite_sqlcipher** : variante chiffrée de `sqflite` utilisant SQLCipher (AES-256) pour Android et iOS.
- **sqflite_common_ffi** : implémentation FFI de `sqflite` pour Windows/Linux/macOS Desktop ; ne supporte pas SQLCipher.
- **KeyDerivationService** : service Flutter déjà présent qui dérive une clé de chiffrement depuis les identifiants de l'utilisateur.
- **SecurityAuditPage** : écran SIGMA (index 44) dédié à la sécurité et à l'audit.
- **RBAC (Role-Based Access Control)** : modèle de contrôle d'accès basé sur les rôles, définissant quels modules chaque rôle peut voir et utiliser.
- **Mode Online** : état de l'application quand le backend FastAPI est joignable sur le LAN.
- **Mode Offline** : état de l'application quand le backend FastAPI est inaccessible ; l'application fonctionne avec le cache SQLite local.

---

## Requirements

### Requirement 1 — Persistance sécurisée du token JWT (flutter_secure_storage)

**User Story :** En tant qu'utilisateur SIGMA, je veux que ma session soit restaurée automatiquement après redémarrage de l'application, afin de ne pas avoir à me reconnecter à chaque ouverture.

#### Acceptance Criteria

1. WHEN un login en mode online réussit, THE AuthService SHALL stocker l'Access Token et le Refresh Token dans `flutter_secure_storage` sous les clés `sigma_access_token` et `sigma_refresh_token`.

2. WHEN l'application démarre et qu'un Access Token valide est présent dans `flutter_secure_storage`, THE AuthService SHALL restaurer la session de l'utilisateur sans afficher l'écran de login.

3. WHEN l'application démarre et que l'Access Token est absent ou expiré mais qu'un Refresh Token valide est présent, THE AuthService SHALL tenter un rafraîchissement automatique avant de décider si l'écran de login doit être affiché.

4. IF le Refresh Token est absent, expiré ou invalide lors de la restauration de session, THEN THE AuthService SHALL supprimer toutes les entrées `flutter_secure_storage` liées à la session et rediriger l'utilisateur vers `LoginPage`.

5. WHEN l'utilisateur se déconnecte (via `AuthService.logout()`), THE AuthService SHALL supprimer les entrées `sigma_access_token` et `sigma_refresh_token` de `flutter_secure_storage`.

6. WHILE l'application fonctionne en mode offline (fallback SQLite), THE AuthService SHALL ne pas tenter de stocker de token JWT dans `flutter_secure_storage` et SHALL maintenir la session uniquement via `SharedPreferences` (comportement existant inchangé).

---

### Requirement 2 — Refresh token automatique

**User Story :** En tant qu'utilisateur SIGMA en mode online, je veux que mon Access Token soit renouvelé automatiquement avant expiration, afin de ne pas être déconnecté brutalement en cours de travail.

#### Acceptance Criteria

1. WHEN l'ApiService reçoit une réponse HTTP 401 sur un endpoint protégé, THE ApiService SHALL tenter un appel `POST /api/v1/auth/refresh` en transmettant le Refresh Token stocké dans `flutter_secure_storage`.

2. WHEN l'appel de rafraîchissement réussit (HTTP 200), THE ApiService SHALL mettre à jour l'Access Token en mémoire et dans `flutter_secure_storage`, puis relancer automatiquement la requête originale une seule fois.

3. IF l'appel de rafraîchissement échoue (réseau indisponible, token expiré, HTTP 401 ou 403), THEN THE ApiService SHALL appeler `AuthService.logout()` pour terminer la session et rediriger l'utilisateur vers `LoginPage`.

4. WHEN un rafraîchissement de token est en cours, THE ApiService SHALL mettre en file d'attente les requêtes HTTP concurrentes et les rejouer dans l'ordre après réception du nouvel Access Token.

5. THE ApiService SHALL limiter à une seule tentative de rafraîchissement par cycle pour éviter les boucles infinies.

---

### Requirement 3 — Intercepteur HTTP (header Authorization)

**User Story :** En tant que développeur SIGMA, je veux que l'header `Authorization: Bearer <token>` soit ajouté automatiquement à toutes les requêtes HTTP protégées, afin que chaque module n'ait pas à gérer ce détail manuellement.

#### Acceptance Criteria

1. THE ApiService SHALL injecter l'header `Authorization: Bearer <access_token>` dans toutes les requêtes HTTP (`get`, `post`, `put`, `delete`) quand un Access Token est disponible en mémoire.

2. WHEN aucun Access Token n'est disponible en mémoire, THE ApiService SHALL envoyer la requête sans header `Authorization` (comportement actuel inchangé pour les endpoints publics comme `/health` et `/auth/login`).

3. THE ApiService SHALL exclure de l'injection automatique les endpoints `/auth/login` et `/auth/refresh` pour éviter les requêtes circulaires.

4. WHEN l'ApiService est initialisé (`init()`), THE ApiService SHALL charger l'Access Token depuis `flutter_secure_storage` si un token y est présent, afin de rétablir l'état d'authentification après redémarrage de l'application.

---

### Requirement 4 — Masquage RBAC de la Sidebar

**User Story :** En tant qu'administrateur SIGMA, je veux que chaque utilisateur ne voie dans la Sidebar que les modules auxquels son rôle donne accès, afin d'éviter tout accès non autorisé à une page sensible.

#### Acceptance Criteria

1. THE Sidebar SHALL évaluer le rôle de l'utilisateur connecté via `AuthService().currentRole` et afficher uniquement les entrées de navigation autorisées selon la matrice RBAC définie en Requirement 5.

2. WHEN le rôle de l'utilisateur est `superAdmin`, THE Sidebar SHALL afficher toutes les 46 entrées de navigation sans restriction.

3. WHEN le rôle de l'utilisateur est `agentCredit`, THE Sidebar SHALL masquer les entrées des modules Caisse (index 14–17), Comptabilité (index 22–27), Agences & Agents (index 31–33), Communications (index 34–36), Configuration (index 40–42), Utilisateurs & droits (index 43), Sécurité & audit (index 44) et Serveur & Connexion (index 45).

4. WHEN un module est masqué pour le rôle connecté, THE Sidebar SHALL supprimer visuellement l'entrée de navigation (ne pas l'afficher en grisé) afin de ne pas révéler l'existence de fonctionnalités inaccessibles.

5. WHEN le titre de section (ex. « COMPTABILITÉ ») n'a plus aucune entrée visible pour le rôle connecté, THE Sidebar SHALL masquer également ce titre de section.

6. IF un utilisateur tente de naviguer directement vers une page non autorisée (index connu) sans passer par la Sidebar, THEN THE MainLayout SHALL rediriger l'utilisateur vers le Dashboard (index 0) et afficher un message d'accès refusé.

7. WHEN l'utilisateur se reconnecte avec un rôle différent, THE Sidebar SHALL reconstruire la liste des entrées visibles selon le nouveau rôle immédiatement après la connexion.

---

### Requirement 5 — Matrice RBAC des modules

**User Story :** En tant qu'administrateur SIGMA, je veux une définition précise et unique des droits d'accès par module et par rôle, afin que la configuration RBAC soit cohérente entre la Sidebar, les pages et les futures vérifications serveur.

#### Acceptance Criteria

1. THE AuthService SHALL exposer une méthode `canAccessModule(SidebarModule module)` qui retourne `true` si le rôle courant a accès au module, `false` sinon, selon la matrice ci-dessous.

2. THE Sidebar SHALL utiliser exclusivement `AuthService.canAccessModule()` pour décider si une entrée est visible, sans dupliquer la logique de rôle dans le widget.

3. THE AuthService SHALL appliquer la matrice RBAC suivante (✓ = accès autorisé, ✗ = accès refusé) :

   | Module (enum SidebarModule) | superAdmin | directeurGeneral | directeurOperations | directeurFinancier | chefAgence | agentCredit |
   |---|---|---|---|---|---|---|
   | dashboard | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
   | clients | ✓ | ✓ | ✓ | ✗ | ✓ | ✓ |
   | groupesSolidaires | ✓ | ✓ | ✓ | ✗ | ✓ | ✓ |
   | prets | ✓ | ✓ | ✓ | ✗ | ✓ | ✓ |
   | remboursements | ✓ | ✓ | ✓ | ✗ | ✓ | ✓ |
   | epargne | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
   | caisse | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ |
   | comptabilite | ✓ | ✓ | ✗ | ✓ | ✗ | ✗ |
   | reporting | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ |
   | agencesAgents | ✓ | ✓ | ✓ | ✗ | ✓ | ✗ |
   | communications | ✓ | ✓ | ✓ | ✗ | ✓ | ✗ |
   | documents | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
   | configuration | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ |
   | utilisateursDroits | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ |
   | securiteAudit | ✓ | ✓ | ✗ | ✓ | ✗ | ✗ |
   | serveurConnexion | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ |

4. THE AuthService SHALL associer chaque valeur de `SidebarModule` aux index de navigation de `MainLayout` correspondants, afin que `canAccessModule()` puisse être utilisé aussi bien par la Sidebar que par `MainLayout` pour la vérification directe par index.

---

### Requirement 6 — Chiffrement SQLite sur mobile (Android/iOS)

**User Story :** En tant qu'administrateur SIGMA, je veux que le cache SQLite local soit chiffré sur les appareils mobiles (Android et iOS), afin de protéger les données financières en cas de perte ou de vol d'un appareil de terrain.

#### Acceptance Criteria

1. WHERE la plateforme cible est Android ou iOS, THE DatabaseService SHALL ouvrir la base de données SQLite via `sqflite_sqlcipher` en utilisant une clé de chiffrement AES-256 dérivée par `KeyDerivationService`.

2. WHERE la plateforme cible est Windows, Linux ou macOS Desktop, THE DatabaseService SHALL ouvrir la base de données via `sqflite_common_ffi` sans chiffrement (contrainte technique : SQLCipher non supporté par `sqflite_common_ffi`).

3. WHEN l'application démarre pour la première fois sur mobile et qu'aucune base de données n'existe, THE DatabaseService SHALL créer la base chiffrée avec la clé dérivée sans aucune intervention manuelle de l'utilisateur.

4. WHEN l'utilisateur se connecte sur mobile, THE KeyDerivationService SHALL dériver la clé de chiffrement depuis un secret stocké dans `flutter_secure_storage`, distinct des tokens JWT.

5. IF la dérivation de clé échoue sur mobile (secret absent, `flutter_secure_storage` inaccessible), THEN THE DatabaseService SHALL afficher une erreur critique non ignorable et empêcher l'ouverture de la base de données non chiffrée.

---

### Requirement 7 — Avertissement de sécurité sur Desktop

**User Story :** En tant qu'administrateur SIGMA, je veux être informé que le cache SQLite n'est pas chiffré sur les postes Windows/Desktop, afin de prendre des mesures compensatoires (chiffrement disque, accès physique restreint).

#### Acceptance Criteria

1. WHERE la plateforme est Windows, Linux ou macOS Desktop, THE SecurityAuditPage SHALL afficher une bannière d'avertissement permanente indiquant que le cache SQLite local n'est pas chiffré en raison d'une contrainte technique, et recommandant le chiffrement du disque système (BitLocker, FileVault, LUKS).

2. THE SecurityAuditPage SHALL afficher dans la bannière la mention « Contrainte technique : sqflite_common_ffi (Desktop) ne supporte pas SQLCipher. Chiffrement actif sur Android/iOS uniquement. » suivi de la recommandation de chiffrement disque.

3. WHEN un utilisateur avec le rôle `superAdmin` ou `directeurFinancier` se connecte sur Desktop, THE SecurityAuditPage SHALL enregistrer un événement d'audit dans la table `audit_log` avec la mention `SQLITE_UNENCRYPTED_DESKTOP` à chaque démarrage de session.

---

### Requirement 8 — Cohérence de session entre mode online et mode offline

**User Story :** En tant qu'utilisateur SIGMA, je veux que ma session reste valide et cohérente lorsque l'application bascule entre le mode online (API) et le mode offline (SQLite), afin de travailler sans interruption lors d'une coupure réseau temporaire.

#### Acceptance Criteria

1. WHILE l'application est en mode online et que la session est active, THE AuthService SHALL surveiller la disponibilité du serveur toutes les 60 secondes via `ApiService.isServerAvailable()`.

2. WHEN le serveur devient inaccessible pendant une session online active, THE AuthService SHALL basculer en mode offline et conserver la session utilisateur active sans afficher d'écran de login, en notifiant l'utilisateur via le `SyncStatusBadge` existant.

3. WHEN la connexion au serveur est rétablie après un mode offline temporaire, THE AuthService SHALL tenter de revalider le token JWT via `POST /api/v1/auth/refresh` avant de repasser en mode online.

4. IF la revalidation du token échoue à la reconnexion, THEN THE AuthService SHALL maintenir la session en mode offline et ne pas déconnecter l'utilisateur de force, afin de ne pas interrompre une saisie en cours.

5. THE SessionManager SHALL continuer à appliquer le timeout d'inactivité de 15 minutes (configurable) indépendamment du mode online ou offline.
