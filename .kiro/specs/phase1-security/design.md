# Design Document — Phase 1 : Sécurité

## Vue d'ensemble

Ce document décrit l'architecture et les modifications nécessaires pour implémenter les trois axes de sécurité de la Phase 1 :

1. **Persistance sécurisée JWT** — stockage dans `flutter_secure_storage`, restauration de session au démarrage, refresh automatique.
2. **RBAC Sidebar** — filtrage dynamique des entrées de navigation via `AuthService.canAccessModule()`, protection par index dans `MainLayout`.
3. **Chiffrement SQLite mobile** — branchement conditionnel `sqflite_sqlcipher` (Android/iOS) vs `sqflite_common_ffi` (Desktop), bannière d'avertissement Desktop.

L'application est un client Flutter hybride (API FastAPI + fallback SQLite offline-first) ciblant Android, iOS, macOS, Windows et Linux.

---

## Architecture générale

```
┌──────────────────────────────────────────────────────────────────────┐
│  Flutter App                                                         │
│                                                                      │
│  ┌─────────────┐    canAccessModule()    ┌──────────────────────┐   │
│  │   Sidebar   │◄────────────────────────│    AuthService        │   │
│  └─────────────┘                         │  (singleton)          │   │
│         │                                │  - _accessToken       │   │
│  ┌─────────────┐   index access check    │  - _refreshToken      │   │
│  │ MainLayout  │◄────────────────────────│  - _currentUser       │   │
│  └─────────────┘                         │  - canAccessModule()  │   │
│                                          └──────────┬────────────┘   │
│  ┌─────────────────────┐                            │                │
│  │     ApiService       │  JWT inject + 401 retry   │                │
│  │  (singleton)         │◄──────────────────────────┘                │
│  │  - intercepteur HTTP │                                            │
│  │  - refresh queue     │                                            │
│  └──────────┬──────────┘                                            │
│             │                                                        │
│  ┌──────────▼──────────┐     ┌──────────────────────────────────┐   │
│  │  DatabaseService     │     │  flutter_secure_storage          │   │
│  │  - Platform branch   │     │  - sigma_access_token            │   │
│  │  - sqlcipher (mob)   │     │  - sigma_refresh_token           │   │
│  │  - sqflite_ffi (dsk) │     │  - sigma_db_key (mobile only)    │   │
│  └─────────────────────┘     └──────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Composants modifiés

### 1. `pubspec.yaml`

Ajout de `sqflite_sqlcipher` en dépendance conditionnelle mobile. `flutter_secure_storage` est déjà présent (version `^9.2.2`).

```yaml
dependencies:
  flutter_secure_storage: ^9.2.2   # déjà présent
  sqflite_sqlcipher: ^2.2.0        # NOUVEAU — Android/iOS uniquement
  sqflite_common_ffi: ^2.3.7+1    # déjà présent — Desktop
  sqflite: ^2.4.2                  # déjà présent — fallback
```

> **Note :** `sqflite_sqlcipher` ne doit pas être importé sur Desktop. Le branchement se fait à l'exécution via `Platform.isAndroid || Platform.isIOS` dans `DatabaseService`.

---

### 2. `AuthService` — `lib/core/services/auth_service.dart`

#### Nouvelles responsabilités

- Stocker / lire / supprimer `sigma_access_token` et `sigma_refresh_token` dans `flutter_secure_storage`.
- Exposer `canAccessModule(SidebarModule module) → bool` basé sur la matrice RBAC.
- Surveiller la disponibilité du serveur toutes les 60 s en mode online.
- Orchestrer le basculement online ↔ offline sans déconnecter l'utilisateur.

#### Enum `SidebarModule` (nouveau — à créer dans `user_model.dart` ou fichier dédié)

```dart
enum SidebarModule {
  dashboard,
  clients,
  groupesSolidaires,
  prets,
  remboursements,
  epargne,
  caisse,
  comptabilite,
  reporting,
  agencesAgents,
  communications,
  documents,
  configuration,
  utilisateursDroits,
  securiteAudit,
  serveurConnexion,
}
```

#### Mapping module → index de navigation

```dart
static const Map<SidebarModule, List<int>> _moduleIndexes = {
  SidebarModule.dashboard:          [0],
  SidebarModule.clients:            [1, 2, 3],
  SidebarModule.groupesSolidaires:  [2],
  SidebarModule.prets:              [4, 5, 6, 7],
  SidebarModule.remboursements:     [8, 9, 10],
  SidebarModule.epargne:            [11, 12, 13],
  SidebarModule.caisse:             [14, 15, 16, 17],
  SidebarModule.comptabilite:       [22, 23, 24, 25, 26, 27],
  SidebarModule.reporting:          [18, 19, 20, 21, 28, 29, 30],
  SidebarModule.agencesAgents:      [31, 32, 33],
  SidebarModule.communications:     [34, 35, 36],
  SidebarModule.documents:          [37, 38, 39],
  SidebarModule.configuration:      [40, 41, 42],
  SidebarModule.utilisateursDroits: [43],
  SidebarModule.securiteAudit:      [44],
  SidebarModule.serveurConnexion:   [45],
};
```

#### Matrice RBAC (implémentée dans `canAccessModule()`)

```dart
static const Map<SystemRole, Set<SidebarModule>> _rbacMatrix = {
  SystemRole.superAdmin: { /* tous les modules */ },
  SystemRole.directeurGeneral: {
    SidebarModule.dashboard, SidebarModule.clients,
    SidebarModule.groupesSolidaires, SidebarModule.prets,
    SidebarModule.remboursements, SidebarModule.epargne,
    SidebarModule.caisse, SidebarModule.comptabilite,
    SidebarModule.reporting, SidebarModule.agencesAgents,
    SidebarModule.communications, SidebarModule.documents,
    SidebarModule.configuration, SidebarModule.securiteAudit,
  },
  SystemRole.directeurOperations: {
    SidebarModule.dashboard, SidebarModule.clients,
    SidebarModule.groupesSolidaires, SidebarModule.prets,
    SidebarModule.remboursements, SidebarModule.epargne,
    SidebarModule.caisse, SidebarModule.reporting,
    SidebarModule.agencesAgents, SidebarModule.communications,
    SidebarModule.documents,
  },
  SystemRole.directeurFinancier: {
    SidebarModule.dashboard, SidebarModule.epargne,
    SidebarModule.caisse, SidebarModule.comptabilite,
    SidebarModule.reporting, SidebarModule.documents,
    SidebarModule.securiteAudit,
  },
  SystemRole.chefAgence: {
    SidebarModule.dashboard, SidebarModule.clients,
    SidebarModule.groupesSolidaires, SidebarModule.prets,
    SidebarModule.remboursements, SidebarModule.epargne,
    SidebarModule.caisse, SidebarModule.reporting,
    SidebarModule.agencesAgents, SidebarModule.communications,
    SidebarModule.documents,
  },
  SystemRole.agentCredit: {
    SidebarModule.dashboard, SidebarModule.clients,
    SidebarModule.groupesSolidaires, SidebarModule.prets,
    SidebarModule.remboursements, SidebarModule.epargne,
    SidebarModule.documents,
  },
};

bool canAccessModule(SidebarModule module) {
  final role = _currentUser?.role;
  if (role == null) return false;
  if (role == SystemRole.superAdmin) return true;
  return _rbacMatrix[role]?.contains(module) ?? false;
}

bool canAccessIndex(int index) {
  for (final entry in _moduleIndexes.entries) {
    if (entry.value.contains(index)) {
      return canAccessModule(entry.key);
    }
  }
  return false; // index inconnu → refusé
}
```

#### Pseudo-code `init()` avec restauration de session

```dart
Future<void> init() async {
  await ApiService().init(); // charge URL + token depuis secure storage

  final storage = const FlutterSecureStorage();
  final accessToken = await storage.read(key: 'sigma_access_token');
  final refreshToken = await storage.read(key: 'sigma_refresh_token');

  if (accessToken != null && !_isTokenExpired(accessToken)) {
    // Restaurer session depuis SharedPreferences (userId) ou JWT claims
    await _restoreSessionFromToken(accessToken);
  } else if (refreshToken != null) {
    // Tenter refresh automatique
    final refreshed = await ApiService().tryRefresh(refreshToken);
    if (refreshed) {
      await _restoreSessionFromToken(ApiService().currentAccessToken!);
    } else {
      await _clearSecureStorage();
    }
  } else {
    await _clearSecureStorage();
  }

  _isInitialized = true;
  notifyListeners();
}
```

#### Pseudo-code `login()` — stockage sécurisé post-login

```dart
// Ajout dans la branche online après login réussi :
final storage = const FlutterSecureStorage();
await storage.write(key: 'sigma_access_token', value: result['access_token']);
if (result['refresh_token'] != null) {
  await storage.write(key: 'sigma_refresh_token', value: result['refresh_token']);
}
```

#### Pseudo-code `logout()` — nettoyage sécurisé

```dart
Future<void> _clearSecureStorage() async {
  final storage = const FlutterSecureStorage();
  await storage.delete(key: 'sigma_access_token');
  await storage.delete(key: 'sigma_refresh_token');
}
```

#### Surveillance de disponibilité serveur (mode online)

```dart
Timer? _serverMonitor;

void _startServerMonitor() {
  _serverMonitor?.cancel();
  _serverMonitor = Timer.periodic(const Duration(seconds: 60), (_) async {
    if (!_isOnlineMode) return;
    final available = await ApiService().isServerAvailable();
    if (!available) {
      _isOnlineMode = false;
      notifyListeners(); // SyncStatusBadge se met à jour
    }
  });
}
```

---

### 3. `ApiService` — `lib/core/services/api_service.dart`

#### Nouvelles responsabilités

- Charger l'`accessToken` depuis `flutter_secure_storage` lors de `init()`.
- Injecter `Authorization: Bearer` sur tous les endpoints sauf `/auth/login` et `/auth/refresh`.
- Gérer les réponses 401 : refresh automatique, file d'attente des requêtes concurrentes, limite une tentative par cycle.

#### Gestion du refresh et de la file d'attente

```dart
bool _isRefreshing = false;
final List<Completer<bool>> _refreshQueue = [];

// Appelé depuis _makeRequest() quand statusCode == 401
Future<bool> _handleUnauthorized() async {
  if (_isRefreshing) {
    // Mettre en attente
    final completer = Completer<bool>();
    _refreshQueue.add(completer);
    return completer.future;
  }

  _isRefreshing = true;
  final storage = const FlutterSecureStorage();
  final refreshToken = await storage.read(key: 'sigma_refresh_token');

  if (refreshToken == null) {
    _drainQueue(success: false);
    await AuthService().logout();
    return false;
  }

  final response = await http.post(
    Uri.parse('$_baseUrl/auth/refresh'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'refresh_token': refreshToken}),
  ).timeout(_timeout);

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    _accessToken = data['access_token'];
    await storage.write(key: 'sigma_access_token', value: _accessToken!);
    _isRefreshing = false;
    _drainQueue(success: true);
    return true;
  } else {
    _isRefreshing = false;
    _drainQueue(success: false);
    await AuthService().logout();
    return false;
  }
}

void _drainQueue({required bool success}) {
  for (final c in _refreshQueue) {
    c.complete(success);
  }
  _refreshQueue.clear();
}
```

#### Injection du header — règle d'exclusion

```dart
static const _noAuthPaths = {'/auth/login', '/auth/refresh'};

Map<String, String> _headersFor(String path) {
  final inject = _accessToken != null && !_noAuthPaths.contains(path);
  return {
    'Content-Type': 'application/json',
    if (inject) 'Authorization': 'Bearer $_accessToken',
  };
}
```

#### Chargement du token depuis secure storage au démarrage

```dart
Future<void> init() async {
  // Charger l'URL serveur (existant)
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString(_prefKeyUrl);
  if (saved != null && saved.isNotEmpty) _baseUrl = saved;

  // NOUVEAU : charger le token JWT depuis secure storage
  const storage = FlutterSecureStorage();
  _accessToken = await storage.read(key: 'sigma_access_token');
}
```

---

### 4. `Sidebar` — `lib/widgets/sidebar.dart`

#### Principe de filtrage RBAC

Le `Sidebar` ne duplique aucune logique de rôle. Il délègue entièrement à `AuthService().canAccessModule()`.

**Structure refactorisée :** au lieu de hardcoder les entrées dans `ListView`, on déclare une structure de données déclarative filtrée à la construction :

```dart
// Déclaration déclarative d'une section
class _SidebarSection {
  final String title;
  final SidebarModule module;
  final List<_SidebarEntry> entries;
  const _SidebarSection({required this.title, required this.module, required this.entries});
}

class _SidebarEntry {
  final int index;
  final IconData icon;
  final String label;
  const _SidebarEntry(this.index, this.icon, this.label);
}
```

**Filtrage dans `build()` :**

```dart
final auth = AuthService();
final visibleSections = _allSections.where((section) {
  return auth.canAccessModule(section.module);
}).toList();

// Dashboard toujours visible (module.dashboard autorisé pour tous)
// Rendu : pour chaque section visible → _buildSectionTitle() + entrées
```

**Suppression visuelle (pas de grisé) :** une entrée non autorisée n'est pas rendue du tout dans le `ListView`. Aucun `Opacity` ou `IgnorePointer` — l'item est simplement absent du widget tree.

---

### 5. `MainLayout` — `lib/screens/main_layout.dart`

#### Vérification d'accès par index (Requirement 4.6)

La méthode `onDestinationSelected` est enrichie d'une garde :

```dart
onDestinationSelected: (index) {
  // Garde RBAC
  if (!AuthService().canAccessIndex(index)) {
    setState(() => _selectedIndex = 0); // Rediriger vers Dashboard
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Accès refusé. Vous n\'avez pas les droits pour ce module.'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
    return;
  }
  // Comportement existant inchangé…
  if (index == 3) {
    showDialog(/* Nouveau Client dialog */);
  } else {
    setState(() {
      if (index == 0 && _selectedIndex != 0) _dashboardRefreshKey++;
      _selectedIndex = index;
    });
  }
},
```

Cette garde est un filet de sécurité secondaire. La Sidebar filtre déjà les entrées ; la garde bloque les navigations programmatiques directes (deep link, test, etc.).

---

### 6. `DatabaseService` — `lib/core/services/database_service.dart`

#### Branchement conditionnel de chiffrement

```dart
import 'dart:io' show Platform;

Future<Database> _initDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  final path = join(dir.path, 'sigma_microfinance.db');

  if (Platform.isAndroid || Platform.isIOS) {
    return _openMobileDatabase(path);
  } else {
    return _openDesktopDatabase(path);
  }
}

/// Mobile : SQLCipher via sqflite_sqlcipher
Future<Database> _openMobileDatabase(String path) async {
  final key = await KeyDerivationService().getDatabaseKey();
  // key est dérivé depuis flutter_secure_storage (secret 'sigma_db_key')
  return await openDatabase(          // import from sqflite_sqlcipher
    path,
    password: key,
    version: _version,
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
  );
}

/// Desktop : sqflite_common_ffi sans chiffrement
Future<Database> _openDesktopDatabase(String path) async {
  databaseFactory = databaseFactoryFfi; // sqflite_common_ffi
  return await openDatabase(
    path,
    version: _version,
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
  );
}
```

> **Contrainte technique documentée :** `sqflite_common_ffi` (Windows/Linux/macOS) ne supporte pas SQLCipher. Le chiffrement est donc actif uniquement sur Android et iOS. Cette contrainte est affichée à l'utilisateur via la `SecurityAuditPage`.

#### `KeyDerivationService` — branchement mobile

```dart
// lib/core/services/key_derivation_service.dart (existant, à enrichir)

Future<String> getDatabaseKey() async {
  const storage = FlutterSecureStorage();
  String? secret = await storage.read(key: 'sigma_db_key');
  if (secret == null) {
    // Premier démarrage : générer et stocker un secret aléatoire
    secret = _generateSecureRandom();
    await storage.write(key: 'sigma_db_key', value: secret);
  }
  return _deriveKey(secret); // PBKDF2 ou Argon2
}
```

**Gestion d'erreur critique :**
```dart
// Dans DatabaseService._openMobileDatabase()
String key;
try {
  key = await KeyDerivationService().getDatabaseKey();
} catch (e) {
  // Ne pas ouvrir la base sans chiffrement
  throw SecurityException(
    'Impossible de dériver la clé de chiffrement. '
    'Vérifiez que flutter_secure_storage est accessible.',
  );
}
```

---

### 7. `SecurityAuditPage` — `lib/screens/configuration/security_audit_page.dart`

#### Bannière Desktop (Requirement 7.1 / 7.2)

Injectée en tête du widget `build()`, conditionnellement à la plateforme :

```dart
Widget _buildDesktopWarningBanner() {
  if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
    return const SizedBox.shrink();
  }
  return Container(
    width: double.infinity,
    color: Colors.amber.shade100,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    child: Row(
      children: [
        const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Base de données locale non chiffrée',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 4),
              Text(
                'Contrainte technique : sqflite_common_ffi (Desktop) ne supporte pas '
                'SQLCipher. Chiffrement actif sur Android/iOS uniquement. '
                'Recommandation : activez le chiffrement disque système '
                '(BitLocker sous Windows, FileVault sous macOS, LUKS sous Linux).',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
```

#### Log d'audit au démarrage de session Desktop (Requirement 7.3)

Dans `initState()` de `_SecurityAuditPageState` :

```dart
Future<void> _logDesktopSessionIfNeeded() async {
  if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;
  final role = AuthService().currentRole;
  if (role != SystemRole.superAdmin && role != SystemRole.directeurFinancier) return;

  await DatabaseService().insertAuditLog(AuditLog(
    id: const Uuid().v4(),
    userId: AuthService().currentUserId,
    username: AuthService().currentUsername,
    action: 'SQLITE_UNENCRYPTED_DESKTOP',
    details: 'Session démarrée sur Desktop — base SQLite non chiffrée.',
    timestamp: DateTime.now(),
    severity: AuditSeverity.medium,
  ));
}
```

---

## Modèles de données

### Clés `flutter_secure_storage`

| Clé                   | Valeur                           | Cycle de vie                              |
|-----------------------|----------------------------------|-------------------------------------------|
| `sigma_access_token`  | JWT access token (string)        | Créé au login online, supprimé au logout  |
| `sigma_refresh_token` | JWT refresh token (string)       | Créé au login online, supprimé au logout  |
| `sigma_db_key`        | Secret brut pour dérivation clé  | Créé au 1er démarrage mobile, persistant  |

### Extension du modèle `AuditLog`

La table `audit_logs` existante est utilisée sans modification de schéma. Nouveau code d'action défini par convention : `SQLITE_UNENCRYPTED_DESKTOP`.

---

## Flux de séquence

### Flux 1 : Démarrage de l'application (mode online)

```
main()
  └─ AuthService.init()
       ├─ ApiService.init()
       │     └─ FlutterSecureStorage.read('sigma_access_token') → token
       ├─ FlutterSecureStorage.read('sigma_access_token') → valide ?
       │     ├─ OUI → _restoreSessionFromToken()  → isLoggedIn = true
       │     └─ NON → read('sigma_refresh_token')
       │           ├─ VALIDE → ApiService.tryRefresh() → succès → restaurer session
       │           └─ ABSENT/KO → _clearSecureStorage() → isLoggedIn = false → LoginPage
       └─ notifyListeners() → MaterialApp rebuilds
```

### Flux 2 : Requête HTTP interceptée (401)

```
ApiService.get('/clients')
  └─ http.get() → 401
       └─ _handleUnauthorized()
             ├─ _isRefreshing = true
             ├─ POST /auth/refresh + refreshToken
             │     ├─ 200 → update _accessToken + SecureStorage → retry requête originale
             │     └─ 4xx → AuthService.logout() → LoginPage
             └─ requêtes concurrentes en attente → débloquées après refresh
```

### Flux 3 : Navigation Sidebar → MainLayout (RBAC)

```
Utilisateur clique entrée index N
  └─ Sidebar.onDestinationSelected(N)
       └─ MainLayout._onDestinationSelected(N)
             └─ AuthService.canAccessIndex(N) ?
                   ├─ true  → setState(_selectedIndex = N) → page affichée
                   └─ false → setState(_selectedIndex = 0) + SnackBar "Accès refusé"
```

---

## Gestion des erreurs

| Scénario | Comportement attendu |
|---|---|
| Refresh token expiré au démarrage | Nettoyage secure storage + redirection LoginPage |
| Refresh échoue pendant une session | `AuthService.logout()` + redirection LoginPage |
| `KeyDerivationService` échoue sur mobile | Exception non ignorable, app bloquée (pas de DB non chiffrée) |
| Navigation index non autorisé | Redirection Dashboard + SnackBar rouge |
| Serveur inaccessible pendant session | Bascule offline silencieuse (SyncStatusBadge), pas de déconnexion |
| Revalidation token échoue à la reconnexion | Maintien en mode offline, pas de déconnexion forcée |

---

## Correctness Properties

*Une propriété est une caractéristique ou un comportement qui doit être vrai pour toutes les exécutions valides du système — essentiellement une déclaration formelle de ce que le système doit faire. Les propriétés servent de pont entre les spécifications lisibles par l'humain et les garanties de correction vérifiables automatiquement.*

### Property 1 : Stockage sécurisé post-login (round-trip)

*Pour tout* login online réussi avec un couple `(accessToken, refreshToken)` quelconque, après l'appel à `login()`, la lecture dans `flutter_secure_storage` aux clés `sigma_access_token` et `sigma_refresh_token` doit retourner exactement ces mêmes valeurs.

**Validates: Requirements 1.1**

---

### Property 2 : Restauration de session au démarrage

*Pour tout* `accessToken` valide (non expiré) pré-chargé dans `flutter_secure_storage`, l'appel à `AuthService.init()` doit produire `isLoggedIn == true` sans afficher l'écran de login.

**Validates: Requirements 1.2**

---

### Property 3 : Nettoyage sécurisé au logout

*Pour tout* utilisateur connecté avec un `accessToken` quelconque stocké dans `flutter_secure_storage`, après l'appel à `logout()`, les clés `sigma_access_token` et `sigma_refresh_token` doivent être absentes du storage (lecture retourne `null`).

**Validates: Requirements 1.5**

---

### Property 4 : Injection du header Authorization

*Pour tout* `accessToken` non nul et pour tout verbe HTTP (`get`, `post`, `put`, `delete`) appelé sur un endpoint autre que `/auth/login` et `/auth/refresh`, la requête HTTP émise doit contenir le header `Authorization: Bearer <accessToken>`. Réciproquement, si `accessToken` est null ou si l'endpoint est exclu, le header `Authorization` doit être absent.

**Validates: Requirements 3.1, 3.2, 3.3**

---

### Property 5 : Chargement du token au démarrage d'ApiService (round-trip)

*Pour tout* `accessToken` préalablement stocké dans `flutter_secure_storage`, après l'appel à `ApiService.init()`, les requêtes émises doivent injecter ce même token dans le header `Authorization`.

**Validates: Requirements 3.4**

---

### Property 6 : Unicité du refresh par cycle (idempotence)

*Pour tout* nombre `N ≥ 1` de requêtes HTTP concurrentes recevant simultanément une réponse 401, le endpoint `POST /auth/refresh` doit être appelé exactement une fois (pas N fois), et toutes les `N` requêtes en attente doivent être rejouées après le refresh avec le nouveau token.

**Validates: Requirements 2.4, 2.5**

---

### Property 7 : Rejeu des requêtes après refresh réussi

*Pour tout* nouvel `accessToken` obtenu via un refresh réussi, toutes les requêtes mises en file d'attente pendant le refresh doivent être renvoyées avec ce nouveau token dans le header `Authorization`.

**Validates: Requirements 2.2, 2.4**

---

### Property 8 : Visibilité RBAC de la Sidebar

*Pour tout* rôle `r` de `SystemRole` et pour tout module `m` de `SidebarModule`, les entrées de navigation correspondant au module `m` doivent être présentes dans le widget tree de `Sidebar` si et seulement si `AuthService().canAccessModule(m)` retourne `true` pour le rôle `r`. Les entrées non autorisées ne doivent pas apparaître dans l'arbre (ni grisées, ni masquées par `Opacity`).

**Validates: Requirements 4.1, 4.4, 5.2**

---

### Property 9 : Masquage des titres de sections vides

*Pour tout* rôle `r`, si toutes les entrées de navigation d'une section donnée sont non autorisées pour ce rôle, alors le titre de cette section doit également être absent du widget tree.

**Validates: Requirements 4.5**

---

### Property 10 : Conformité de `canAccessModule()` à la matrice RBAC

*Pour tout* couple `(rôle, module)` de la matrice RBAC définie en Requirement 5.3, `AuthService().canAccessModule(module)` doit retourner exactement la valeur attendue par la matrice (`true` pour ✓, `false` pour ✗).

**Validates: Requirements 5.1, 5.3**

---

### Property 11 : Cohérence index ↔ module dans `canAccessIndex()`

*Pour tout* index de navigation `i` et pour tout module `m` tel que `i ∈ _moduleIndexes[m]`, `AuthService().canAccessIndex(i)` doit retourner la même valeur que `AuthService().canAccessModule(m)`.

**Validates: Requirements 5.4, 4.6**

---

### Property 12 : Dérivation de clé déterministe (idempotence)

*Pour tout* secret `s` stocké dans `flutter_secure_storage`, deux appels successifs à `KeyDerivationService().getDatabaseKey()` avec le même secret doivent retourner une clé identique (la dérivation est déterministe et reproductible).

**Validates: Requirements 6.4**

---

### Property 13 : Timeout d'inactivité indépendant du mode réseau

*Pour tout* délai d'inactivité configurable `T` et pour tout mode de l'application (online ou offline), si l'utilisateur reste inactif pendant `T` minutes, `SessionManager` doit déclencher la déconnexion dans les deux cas.

**Validates: Requirements 8.5**

---

## Stratégie de test

### Tests unitaires (example-based)

| Scénario | Fichier de test suggéré |
|---|---|
| Login offline ne stocke rien dans secure storage | `test/auth_service_offline_test.dart` |
| Refresh token absent → logout() appelé | `test/api_service_refresh_test.dart` |
| Refresh échoue (401) → logout() appelé | `test/api_service_refresh_test.dart` |
| Bascule offline → session conservée, isOnlineMode = false | `test/auth_service_mode_test.dart` |
| Platform mobile → sqflite_sqlcipher sélectionné | `test/database_service_platform_test.dart` |
| Platform desktop → sqflite_common_ffi sélectionné | `test/database_service_platform_test.dart` |
| KeyDerivationService échoue → SecurityException levée | `test/database_service_error_test.dart` |
| Desktop → bannière visible dans SecurityAuditPage | `test/security_audit_page_test.dart` |
| superAdmin + Desktop → audit log SQLITE_UNENCRYPTED_DESKTOP inséré | `test/security_audit_page_test.dart` |
| Reconnexion rôle différent → Sidebar reconstruite | `test/sidebar_rbac_test.dart` |

### Tests de propriétés (property-based)

Utiliser le package [`dart_check`](https://pub.dev/packages/dart_check) ou `fast_check` (Dart) pour les propriétés ci-dessus.

**Générateurs recommandés :**
- `Arbitrary.string()` pour les tokens JWT (taille variable, caractères aléatoires).
- `Arbitrary.from(SystemRole.values)` pour les rôles.
- `Arbitrary.from(SidebarModule.values)` pour les modules.
- `Arbitrary.integer(min: 0, max: 45)` pour les index de navigation.
- `Arbitrary.string()` pour les secrets de dérivation.

**Configuration :** minimum 100 itérations par propriété.

**Tag format :** `Feature: phase1-security, Property {N}: {titre de la propriété}`

### Tests d'intégration

| Scénario | Approche |
|---|---|
| Login end-to-end avec backend FastAPI réel | 1–2 exemples, serveur local de test |
| Refresh token end-to-end (expiration naturelle) | 1 exemple avec token TTL court |
| Surveillance disponibilité serveur (60 s) | Test d'intégration avec mock Timer |
| Chiffrement SQLite sur appareil Android/iOS réel | Test smoke sur device |

---

## Décisions architecturales

### Pourquoi déléguer à `canAccessModule()` plutôt qu'à des listes d'index dans Sidebar ?

La Sidebar contient 46 entrées sur 16 sections. Dupliquer la logique de rôle dans deux endroits (Sidebar + MainLayout) crée inévitablement des désynchronisations. Centraliser dans `AuthService.canAccessModule()` garantit une source unique de vérité, testable unitairement en isolation du widget tree.

### Pourquoi ne pas griser les entrées non autorisées ?

Ne pas afficher les entrées non autorisées (plutôt que les griser) évite de révéler l'existence de fonctionnalités inaccessibles à l'utilisateur. C'est une bonne pratique UX de sécurité (principle of least privilege visible).

### Pourquoi une file d'attente pour le refresh concurrent ?

Sans file d'attente, si 3 requêtes HTTP échouent simultanément avec 401, on déclencherait 3 tentatives de refresh en parallèle. Cela peut créer des race conditions sur le token stocké et déclencher des logouts intempestifs. Une file d'attente avec flag `_isRefreshing` garantit l'atomicité du cycle de refresh.

### Pourquoi `sigma_db_key` distinct de `sigma_access_token` ?

La clé de chiffrement de la base de données doit survivre à la déconnexion (le contenu offline reste accessible au prochain login). Les tokens JWT sont éphémères et liés à la session réseau. Séparer les clés secure_storage évite qu'un `clearAll()` au logout ne détruise la clé de la base chiffrée.
