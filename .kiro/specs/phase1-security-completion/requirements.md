# Document des Exigences — Phase 1 Sécurité (Complément)

## Introduction

Ce document définit les exigences pour les deux fonctionnalités de sécurité restantes de la Phase 1 du projet SIGMA Micro-Finance (Flutter/Windows Desktop). L'authentification JWT hybride étant déjà implémentée, il reste à implémenter :

1. **Timeout de session** — déconnexion automatique après une période d'inactivité configurable, avec avertissement préalable.
2. **Chiffrement SQLite** — migration de `sqflite` vers `sqflite_sqlcipher` pour chiffrer la base de données locale à l'aide d'une clé dérivée des identifiants utilisateur.

## Glossaire

- **SessionManager** : Composant Dart responsable du timer d'inactivité, de l'avertissement et de la déconnexion automatique.
- **InactivityTimer** : Timer `dart:async` géré par le `SessionManager`, remis à zéro à chaque interaction détectée.
- **AuthService** : Singleton Flutter existant (`lib/core/services/auth_service.dart`) gérant la session utilisateur, le login et le logout.
- **MainLayout** : Widget racine de l'application après connexion (`lib/screens/main_layout.dart`), encapsulant toutes les pages.
- **DatabaseService** : Singleton Flutter existant (`lib/core/services/database_service.dart`) gérant l'accès SQLite.
- **EncryptedDatabaseService** : Version étendue du `DatabaseService` utilisant `sqflite_sqlcipher` pour l'accès chiffré.
- **KeyDerivationService** : Composant responsable de la dérivation déterministe de la clé de chiffrement.
- **SharedPreferences** : Stockage clé-valeur Flutter non sécurisé (utilisé pour `sessionTimeoutMinutes`).
- **FlutterSecureStorage** : Stockage sécurisé Flutter (chiffrement OS) utilisé pour le sel de chiffrement.
- **MigrationService** : Composant responsable de la migration d'une base de données non chiffrée vers une base chiffrée.
- **WarningDialog** : Dialog Material affiché 1 minute avant l'expiration de la session.
- **Interaction utilisateur** : Tout événement de type tap, scroll, glissement ou frappe clavier détecté par le `GestureDetector` racine.
- **Clé de chiffrement** : Chaîne dérivée de manière déterministe à partir du `username` et d'un `sel` stocké dans `FlutterSecureStorage`.
- **Sel** : Chaîne aléatoire générée une seule fois et persistée dans `FlutterSecureStorage` sous la clé `db_encryption_salt`.
- **Base non chiffrée** : Fichier `sigma_microfinance.db` créé par la version précédente utilisant `sqflite`.
- **Base chiffrée** : Fichier `sigma_microfinance_enc.db` créé et ouvert via `sqflite_sqlcipher`.

---

## Exigences

### Exigence 1 : Initialisation et configuration du timeout de session

**User Story :** En tant qu'administrateur, je veux configurer la durée d'inactivité avant déconnexion automatique, afin d'adapter la politique de sécurité aux besoins de l'institution.

#### Critères d'acceptation

1. THE `AuthService` SHALL exposer une propriété `sessionTimeoutMinutes` de type `int` indiquant la durée d'inactivité avant déconnexion automatique.
2. WHEN `AuthService.init()` est appelé, THE `AuthService` SHALL lire la valeur de `sessionTimeoutMinutes` depuis `SharedPreferences` sous la clé `session_timeout_minutes`.
3. IF la clé `session_timeout_minutes` est absente de `SharedPreferences`, THEN THE `AuthService` SHALL utiliser la valeur par défaut de 15 minutes.
4. WHEN la valeur de `sessionTimeoutMinutes` est modifiée par l'administrateur, THE `AuthService` SHALL persister la nouvelle valeur dans `SharedPreferences` sous la clé `session_timeout_minutes` et notifier les écouteurs.
5. THE `AuthService` SHALL n'accepter que des valeurs de `sessionTimeoutMinutes` comprises entre 1 et 480 minutes inclus.
6. IF une valeur hors de la plage [1, 480] est fournie, THEN THE `AuthService` SHALL rejeter la valeur et conserver la valeur précédente.

---

### Exigence 2 : Démarrage et remise à zéro du timer d'inactivité

**User Story :** En tant qu'utilisateur authentifié, je veux que mon timer d'inactivité soit actif dès ma connexion et remis à zéro à chaque interaction, afin que ma session reste ouverte tant que j'utilise activement l'application.

#### Critères d'acceptation

1. WHEN `AuthService.login()` réussit, THE `SessionManager` SHALL démarrer l'`InactivityTimer` avec la durée `sessionTimeoutMinutes`.
2. WHEN une interaction utilisateur (tap, scroll, glissement, frappe clavier) est détectée par le `GestureDetector` racine de `MainLayout`, THE `SessionManager` SHALL remettre l'`InactivityTimer` à zéro.
3. WHILE l'utilisateur est connecté, THE `SessionManager` SHALL maintenir un seul `InactivityTimer` actif à tout moment.
4. WHEN `AuthService.logout()` est appelé (déconnexion manuelle), THE `SessionManager` SHALL annuler l'`InactivityTimer` actif.
5. WHEN `AuthService.init()` démarre avec une session persistée valide, THE `SessionManager` SHALL démarrer l'`InactivityTimer` automatiquement.

---

### Exigence 3 : Avertissement avant expiration de session

**User Story :** En tant qu'utilisateur, je veux être averti 1 minute avant l'expiration de ma session, afin de pouvoir prolonger ma session en interagissant avec l'application.

#### Critères d'acceptation

1. WHEN le temps restant avant expiration atteint exactement 60 secondes, THE `SessionManager` SHALL afficher le `WarningDialog` en superposition de l'écran courant.
2. THE `WarningDialog` SHALL afficher le message « Votre session expire dans 1 minute. Touchez l'écran pour rester connecté. »
3. THE `WarningDialog` SHALL proposer un bouton « Rester connecté » permettant à l'utilisateur de prolonger sa session.
4. WHEN l'utilisateur appuie sur le bouton « Rester connecté », THE `SessionManager` SHALL fermer le `WarningDialog` et remettre l'`InactivityTimer` à zéro.
5. WHEN le `WarningDialog` est affiché et que l'utilisateur effectue une interaction (tap, scroll, frappe), THE `SessionManager` SHALL fermer le `WarningDialog` et remettre l'`InactivityTimer` à zéro.
6. IF le `WarningDialog` est déjà affiché, THEN THE `SessionManager` SHALL ne pas en afficher un second.

---

### Exigence 4 : Déconnexion automatique par inactivité

**User Story :** En tant qu'administrateur, je veux que l'application déconnecte automatiquement l'utilisateur après la période d'inactivité configurée, afin de protéger les données financières en cas d'abandon de poste.

#### Critères d'acceptation

1. WHEN l'`InactivityTimer` expire, THE `SessionManager` SHALL appeler `AuthService.logout()`.
2. WHEN `AuthService.logout()` est déclenché par le `SessionManager`, THE `SessionManager` SHALL naviguer vers `LoginPage` en remplaçant toute la pile de navigation.
3. WHEN la déconnexion automatique est effectuée, THE `SessionManager` SHALL fermer le `WarningDialog` s'il est affiché.
4. WHEN la déconnexion automatique est effectuée, THE `SessionManager` SHALL annuler l'`InactivityTimer`.
5. WHEN l'application est en arrière-plan (minimisée), THE `SessionManager` SHALL continuer à décrémenter l'`InactivityTimer`.

---

### Exigence 5 : Dérivation et stockage de la clé de chiffrement

**User Story :** En tant qu'administrateur de sécurité, je veux que la clé de chiffrement de la base de données soit dérivée de manière déterministe et sécurisée, afin que les données soient protégées même en cas d'accès physique au fichier de base de données.

#### Critères d'acceptation

1. WHEN `KeyDerivationService.getOrCreateKey(username)` est appelé pour la première fois, THE `KeyDerivationService` SHALL générer un sel aléatoire de 32 octets et le persister dans `FlutterSecureStorage` sous la clé `db_encryption_salt`.
2. WHEN `KeyDerivationService.getOrCreateKey(username)` est appelé, THE `KeyDerivationService` SHALL dériver la clé en appliquant PBKDF2-HMAC-SHA256 avec le `username`, le `sel`, 10 000 itérations et une longueur de sortie de 32 octets.
3. WHEN `KeyDerivationService.getOrCreateKey(username)` est appelé pour un même `username` avec le même `sel`, THE `KeyDerivationService` SHALL retourner une clé identique (propriété de déterminisme).
4. THE `KeyDerivationService` SHALL encoder la clé dérivée en hexadécimal avant de la transmettre à `sqflite_sqlcipher`.
5. THE `KeyDerivationService` SHALL ne jamais persister la clé dérivée elle-même dans `SharedPreferences` ou dans un fichier.
6. IF `FlutterSecureStorage` est inaccessible, THEN THE `KeyDerivationService` SHALL propager une exception `EncryptionKeyException` avec un message descriptif.

---

### Exigence 6 : Ouverture de la base de données chiffrée

**User Story :** En tant que développeur, je veux que `DatabaseService` ouvre une base de données chiffrée transparentement, afin que toutes les opérations existantes fonctionnent sans modification.

#### Critères d'acceptation

1. WHEN `DatabaseService` initialise la base de données, THE `DatabaseService` SHALL utiliser `sqflite_sqlcipher` comme fabrique de base de données à la place de `sqflite` standard.
2. WHEN `DatabaseService` ouvre la base de données, THE `DatabaseService` SHALL fournir la clé de chiffrement dérivée par `KeyDerivationService` via le paramètre `password` de `sqflite_sqlcipher`.
3. WHILE la base de données chiffrée est ouverte, THE `DatabaseService` SHALL garantir que toutes les opérations CRUD existantes (clients, prêts, remboursements, épargne, etc.) fonctionnent de manière identique à la version non chiffrée.
4. IF la clé de chiffrement fournie est incorrecte, THEN THE `DatabaseService` SHALL propager une exception `DatabaseOpenException` et logger l'erreur.
5. THE `DatabaseService` SHALL nommer le fichier de base de données chiffrée `sigma_microfinance_enc.db`.

---

### Exigence 7 : Migration de la base de données existante

**User Story :** En tant qu'utilisateur existant, je veux que mes données actuelles soient automatiquement migrées vers la base chiffrée lors de la mise à jour, afin de ne pas perdre l'historique des opérations.

#### Critères d'acceptation

1. WHEN `DatabaseService` s'initialise et détecte la présence du fichier `sigma_microfinance.db` non chiffré, THE `MigrationService` SHALL démarrer automatiquement le processus de migration.
2. WHEN le processus de migration démarre, THE `MigrationService` SHALL copier toutes les tables et données de la base non chiffrée vers une nouvelle base chiffrée `sigma_microfinance_enc.db`.
3. WHEN la migration est terminée avec succès, THE `MigrationService` SHALL marquer la migration comme complète dans `SharedPreferences` sous la clé `db_migration_v1_done` avec la valeur `true`.
4. WHEN la migration est terminée avec succès, THE `MigrationService` SHALL supprimer le fichier `sigma_microfinance.db` non chiffré.
5. IF la migration échoue, THEN THE `MigrationService` SHALL conserver le fichier `sigma_microfinance.db` non chiffré intact et propager une `DatabaseMigrationException`.
6. WHEN `DatabaseService` s'initialise et que la clé `db_migration_v1_done` est `true`, THE `DatabaseService` SHALL ouvrir directement `sigma_microfinance_enc.db` sans tenter de migration.
7. WHEN `DatabaseService` s'initialise et que ni `sigma_microfinance.db` ni `sigma_microfinance_enc.db` n'existent, THE `DatabaseService` SHALL créer directement `sigma_microfinance_enc.db` chiffré.

---

### Exigence 8 : Intégration avec `pubspec.yaml` et configuration de la plateforme

**User Story :** En tant que développeur, je veux que les dépendances nécessaires soient déclarées dans `pubspec.yaml`, afin que le projet compile correctement sur toutes les plateformes cibles.

#### Critères d'acceptation

1. THE `pubspec.yaml` SHALL déclarer la dépendance `sqflite_sqlcipher` avec une version compatible avec le SDK Dart `^3.9.2`.
2. THE `pubspec.yaml` SHALL déclarer la dépendance `flutter_secure_storage` avec une version compatible avec le SDK Dart `^3.9.2`.
3. THE `pubspec.yaml` SHALL conserver la dépendance `sqflite_common_ffi` pour la compatibilité Windows Desktop.
4. WHEN l'application est compilée sur Windows, THE `DatabaseService` SHALL utiliser `sqflite_sqlcipher_ffi` comme fabrique de base de données à la place de `sqflite_common_ffi`.
5. THE `pubspec.yaml` SHALL supprimer la dépendance `sqflite` standard après migration complète vers `sqflite_sqlcipher`.
