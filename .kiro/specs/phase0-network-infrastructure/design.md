# Design Document — Phase 0 : Infrastructure réseau

## Overview

La Phase 0 pose les fondations réseau de SIGMA Micro-Finance : elle relie l'application Flutter offline-first à son backend FastAPI/PostgreSQL déployé sur le LAN, sans casser le comportement hors-ligne existant. L'architecture suit quatre axes indépendants mais cohérents :

1. **Migrations Alembic** — gestion versionnée du schéma PostgreSQL par domaine métier.
2. **Neuf services API Flutter** — couche réseau uniforme pour les modules non couverts.
3. **ConnectivityMonitor enrichi** — basculement automatique via `connectivity_plus` + ping `/health`.
4. **Configuration IP serveur** — UI admin dans les Paramètres pour modifier l'URL du serveur.

Tous les composants respectent la stratégie **"Server is Truth"** déjà établie par `ClientApiService` et `LoanApiService` : SQLite local en premier (réponse UI immédiate + cache offline), PostgreSQL comme source de vérité quand le réseau est disponible.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│  Flutter (postes clients)                                           │
│                                                                     │
│  ┌──────────┐  ┌────────────────────────────────────────────────┐  │
│  │ Écrans   │  │ Couche services (lib/core/services/)           │  │
│  │ Flutter  │→ │  XxxApiService (×9 nouveaux + 2 existants)     │  │
│  └──────────┘  │  ↓ online : ApiService (HTTP)                  │  │
│                │  ↓ offline : DatabaseService (SQLite)          │  │
│                │  ConnectivityMonitor (connectivity_plus+ping)  │  │
│                │  SyncService (queue + flush)                   │  │
│                └────────────────────────────────────────────────┘  │
│                                  ↕ HTTP/JSON (LAN)                  │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│  PC Serveur LAN                                                     │
│  FastAPI + PostgreSQL (sigma_db)                                    │
│  14 routers : /clients /prets /remboursements /epargne /caisse     │
│               /comptabilite /produits /agencies /groupes           │
│               /reporting /configuration /auth /agents + dashboard  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Components and Interfaces

### Axe 1 — Migrations Alembic

### Stratégie de découpage en domaines

Chaque domaine correspond à un fichier `backend/alembic/versions/` préfixé d'un numéro de séquence garantissant l'ordre d'application. Les clés étrangères imposent un graphe de dépendances strict :

```
001_utilisateurs     (aucune FK externe)
002_agences_agents   (aucune FK externe)
003_produits         (aucune FK externe)
004_clients          (→ aucune FK externe ; référencé par groupes, prêts, épargne)
005_groupes_solidaires  (→ clients)
006_prets_remboursements (→ clients, produits, groupes)
007_epargne          (→ clients, produits)
008_caisse           (aucune FK externe)
009_comptabilite     (→ ecritures FK interne uniquement)
010_configuration_audit (aucune FK externe)
```

### Structure de chaque fichier de migration

Chaque fichier suit le squelette Alembic standard avec :
- `revision` : identifiant UUID court (8 caractères)
- `down_revision` : révision précédente dans la chaîne
- `upgrade()` : `op.create_table()` + `op.create_index()` pour le domaine
- `downgrade()` : `op.drop_table()` en ordre inverse

```python
# backend/alembic/versions/001_utilisateurs.py

"""Domaine utilisateurs : utilisateurs_systeme

Revision ID: a1b2c3d4
Revises: None
Create Date: 2024-01-01
"""

from alembic import op
import sqlalchemy as sa

revision = 'a1b2c3d4'
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'utilisateurs_systeme',
        sa.Column('id', sa.String(), primary_key=True),
        sa.Column('agent_id', sa.String(), nullable=False),
        sa.Column('username', sa.String(), nullable=False),
        sa.Column('password_hash', sa.String(), nullable=False),
        sa.Column('role', sa.String(), nullable=False),
        sa.Column('is_active', sa.Boolean(), default=True),
        sa.Column('created_at', sa.DateTime(), nullable=True),
        sa.Column('permissions', sa.Text(), nullable=True),
        sa.Column('last_login', sa.DateTime(), nullable=True),
    )
    op.create_index('ix_utilisateurs_username', 'utilisateurs_systeme', ['username'], unique=True)


def downgrade() -> None:
    op.drop_index('ix_utilisateurs_username', 'utilisateurs_systeme')
    op.drop_table('utilisateurs_systeme')
```

### Table `configurations`

La table `configurations` (clé/valeur) est créée dans la migration `010_configuration_audit` car elle n'a pas de FK sortantes :

```python
op.create_table(
    'configurations',
    sa.Column('key', sa.String(), primary_key=True),
    sa.Column('value', sa.Text(), nullable=True),
)
```

### Coexistence avec `create_tables()`

Pendant la phase de transition, le backend reste compatible avec `create_tables()` (SQLAlchemy `create_all`) pour le développement local macOS. L'introduction des migrations Alembic se fait en parallèle et sera activée en production via `install_serveur.bat` (appel `alembic upgrade head` avant le démarrage du service).

---

## Axe 2 — Services API Flutter (neuf modules)

### Patron commun : "Server is Truth"

Tous les neuf nouveaux services suivent exactement le même patron que `ClientApiService` :

```dart
// Patron générique — remplacer Xxx par le nom du module
class XxxApiService {
  static final XxxApiService _instance = XxxApiService._internal();
  factory XxxApiService() => _instance;
  XxxApiService._internal();

  // LECTURE
  Future<List<XxxModel>> getAll() async {
    if (await SyncService().isOnline) {
      try {
        final response = await ApiService().get('/xxx');
        final data = ApiService.decodeResponse(response);
        if (data != null) {
          final items = (data is List ? data : (data['items'] as List? ?? []));
          final models = items.map((e) => XxxModel.fromMap(e)).toList();
          _updateLocalCache(models);  // arrière-plan
          return models;
        }
      } catch (_) {}
    }
    return await DatabaseService().getXxx();
  }

  // ÉCRITURE
  Future<void> insertXxx(XxxModel model) async {
    await DatabaseService().insertXxx(model);  // SQLite d'abord
    if (await SyncService().isOnline) {
      try {
        await ApiService().post('/xxx', model.toMap());
      } catch (_) {
        await SyncService().queueOperation(method: 'POST', path: '/xxx', body: model.toMap());
      }
    } else {
      await SyncService().queueOperation(method: 'POST', path: '/xxx', body: model.toMap());
    }
  }
}
```

### Mapping des neuf services

| Fichier Dart | Préfixe API | Méthodes principales |
|---|---|---|
| `savings_api_service.dart` | `/epargne` | `getComptes()`, `getCompteById()`, `ouvrirCompte()`, `effectuerTransaction()`, `getTransactions()` |
| `cash_api_service.dart` | `/caisse` | `getOperations()`, `getSolde()`, `createOperation()`, `getClotures()`, `clotureCaisse()` |
| `accounting_api_service.dart` | `/comptabilite` | `getComptes()`, `getJournaux()`, `getEcritures()`, `createEcriture()`, `getBalance()` |
| `reporting_api_service.dart` | `/reporting` | `getDashboardData()`, `getParStats()` |
| `dashboard_api_service.dart` | `/reporting/dashboard` | `getKpis()` — délègue à `ReportingApiService` |
| `products_api_service.dart` | `/produits` | `getProducts()`, `getProductById()`, `createProduct()`, `updateProduct()`, `deleteProduct()` |
| `agency_api_service.dart` | `/agencies` + `/agents` | `getAgencies()`, `getAgencyById()`, `createAgency()`, `getAgents()` |
| `group_api_service.dart` | `/groupes` | `getGroupes()`, `getGroupeById()`, `createGroupe()`, `updateGroupe()` |
| `configuration_api_service.dart` | `/configuration` | `getConfiguration()`, `updateConfiguration()` |

### Gestion du cache local

Chaque service implémente une méthode `_updateLocalCache(List<T> items)` privée qui itère les entités et appelle `DatabaseService().upsertXxx()`. Cette mise à jour est lancée sans `await` depuis les méthodes de lecture (fire-and-forget) pour ne pas bloquer l'UI.

### Traitement des erreurs API

Conforme à la règle 2.6 du requirements : si `ApiService.decodeResponse()` retourne `null` (timeout, 4xx, 5xx), le service retombe silencieusement sur `DatabaseService()`. Aucune exception ne remonte vers les écrans.

```dart
// Exemple dans savings_api_service.dart
try {
  final response = await ApiService().get('/epargne/comptes');
  final data = ApiService.decodeResponse(response);
  if (data != null) {
    // Utiliser les données serveur
    return ...;
  }
  // data == null → fallback implicite vers SQLite ci-dessous
} catch (_) {
  // Exception réseau → fallback implicite
}
return await DatabaseService().getCompteEpargne();
```

---

## Axe 3 — ConnectivityMonitor enrichi

### Architecture dual-source

Le `ConnectivityMonitor` actuel utilise uniquement un `Timer.periodic` de 30 s pour pinger `/health`. L'enrichissement ajoute une **deuxième source d'événements** : le stream `connectivity_plus`.

```
Sources d'événements                  Machine d'états
──────────────────                    ────────────────
connectivity_plus stream  ─────┐
                               ├──→  ConnectivityMonitor._handleEvent()
Timer 30s + ping /health  ─────┘         │
                                          ▼
                                 [offline] ←→ [syncing] ←→ [online]
```

### Interface étendue de `ConnectivityMonitor`

```dart
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityMonitor {
  static final ConnectivityMonitor _instance = ConnectivityMonitor._internal();
  factory ConnectivityMonitor() => _instance;
  ConnectivityMonitor._internal();

  final ValueNotifier<ConnectivityStatus> statusNotifier =
      ValueNotifier(ConnectivityStatus.offline);

  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  void start() {
    _timer?.cancel();
    _connectivitySubscription?.cancel();

    // Source 1 : connectivity_plus (événements système immédiats)
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen(_onConnectivityChanged);

    // Source 2 : ping périodique de 30 s (vérification de fond)
    _timer = Timer.periodic(const Duration(seconds: 30), _onTick);

    // Vérification immédiate au démarrage
    _onTick(Timer(Duration.zero, () {}));
  }

  void dispose() {
    _timer?.cancel();
    _connectivitySubscription?.cancel();
  }

  // Appelé par connectivity_plus quand le type réseau change
  Future<void> _onConnectivityChanged(List<ConnectivityResult> results) async {
    if (statusNotifier.value == ConnectivityStatus.syncing) return;

    final hasNetwork = results.any((r) => r != ConnectivityResult.none);

    if (!hasNetwork) {
      // Déconnexion système détectée → offline immédiat
      statusNotifier.value = ConnectivityStatus.offline;
      return;
    }

    // Réseau disponible → vérifier si le serveur répond
    await _checkAndTransition();
  }

  // Appelé par le timer de 30 s
  Future<void> _onTick(Timer _) async {
    if (statusNotifier.value == ConnectivityStatus.syncing) return;
    await _checkAndTransition();
  }

  // Logique de transition commune
  Future<void> _checkAndTransition() async {
    bool available;
    try {
      available = await ApiService().isServerAvailable();
    } catch (_) {
      statusNotifier.value = ConnectivityStatus.offline;
      return;
    }

    if (!available) {
      statusNotifier.value = ConnectivityStatus.offline;
      return;
    }

    if (statusNotifier.value == ConnectivityStatus.offline) {
      statusNotifier.value = ConnectivityStatus.syncing;
      final result = await SyncService().flushPendingOperations();
      // Passer online même si certaines entrées ont échoué (req. 3.7)
      statusNotifier.value = ConnectivityStatus.online;
      // Les entrées 'failed' restent dans la queue pour résolution manuelle
    } else {
      statusNotifier.value = ConnectivityStatus.online;
    }
  }
}
```

### Dépendance `pubspec.yaml`

```yaml
dependencies:
  connectivity_plus: ^6.0.5   # version stable, null-safe
```

### Garantie de non-concurrence

La garde `if (statusNotifier.value == ConnectivityStatus.syncing) return;` en tête de `_onConnectivityChanged` et `_onTick` empêche tout appel concurrent à `flushPendingOperations()`. Cette garde est vérifiée avant tout `await`.

---

## Axe 4 — Configuration IP serveur dans les Paramètres

### Localisation UI

La section « Connexion serveur » est ajoutée dans l'écran Paramètres existant (`lib/screens/configuration/` ou équivalent), conditionnellement affichée selon le rôle de l'utilisateur connecté.

### Widget `ServerConnectionSection`

```dart
// lib/screens/configuration/widgets/server_connection_section.dart

class ServerConnectionSection extends StatefulWidget {
  const ServerConnectionSection({super.key});

  @override
  State<ServerConnectionSection> createState() => _ServerConnectionSectionState();
}

class _ServerConnectionSectionState extends State<ServerConnectionSection> {
  late TextEditingController _urlController;
  String? _validationError;
  bool _isTesting = false;
  String? _testResult;

  // Regex de validation : http(s)://host:port
  static final _urlRegex = RegExp(
    r'^https?://[a-zA-Z0-9\-\.]+:\d{1,5}$',
    caseSensitive: false,
  );

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: ApiService().baseUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _saveUrl() async {
    final url = _urlController.text.trim();
    if (!_urlRegex.hasMatch(url)) {
      setState(() => _validationError = 'Format invalide. Exemple : http://192.168.1.100:8000');
      return;
    }
    setState(() => _validationError = null);
    await ApiService().setServerUrl(url);
    // Déclencher vérification immédiate (req. 4.4)
    ConnectivityMonitor().start();
  }

  Future<void> _testConnection() async {
    setState(() { _isTesting = true; _testResult = null; });
    final available = await ApiService().isServerAvailable();
    setState(() {
      _isTesting = false;
      _testResult = available ? 'Connexion réussie ✓' : 'Serveur inaccessible ✗';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ConnectivityStatus>(
      valueListenable: ConnectivityMonitor().statusNotifier,
      builder: (context, status, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Indicateur visuel de statut
            _StatusIndicator(status: status),
            // Champ URL
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'URL du serveur',
                errorText: _validationError,
              ),
            ),
            // Boutons
            Row(children: [
              ElevatedButton(onPressed: _saveUrl, child: const Text('Enregistrer')),
              TextButton(onPressed: _isTesting ? null : _testConnection,
                         child: const Text('Tester la connexion')),
            ]),
            if (_testResult != null) Text(_testResult!),
          ],
        );
      },
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final ConnectivityStatus status;
  const _StatusIndicator({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ConnectivityStatus.online  => Colors.green,
      ConnectivityStatus.syncing => Colors.orange,
      ConnectivityStatus.offline => Colors.red,
    };
    final label = switch (status) {
      ConnectivityStatus.online  => 'Connecté',
      ConnectivityStatus.syncing => 'Synchronisation...',
      ConnectivityStatus.offline => 'Hors ligne',
    };
    return Row(children: [
      CircleAvatar(radius: 6, backgroundColor: color),
      const SizedBox(width: 8),
      Text(label),
    ]);
  }
}
```

### Intégration dans l'écran Paramètres

```dart
// Dans l'écran Paramètres existant, ajouter :
if (SessionManager().currentUser?.role == 'ADMIN')
  const ServerConnectionSection(),
```

Le `SessionManager` expose le rôle de l'utilisateur courant. Si ce rôle n'est pas `ADMIN`, la section n'est pas rendue du tout (pas de message d'erreur affiché, req. 4.8).

---

## Data Models

### Modèles Flutter requis (nouveaux ou à vérifier)

Les neuf services API consomment des entités dont certaines n'ont pas encore de modèle Dart dédié. Les modèles suivants doivent exister ou être créés dans `lib/models/` :

| Modèle Dart | Table PostgreSQL | Service consommateur |
|---|---|---|
| `SavingsAccount` | `comptes_epargne` | `SavingsApiService` |
| `SavingsTransaction` | `transactions_epargne` | `SavingsApiService` |
| `CashOperation` | `operations_caisse` | `CashApiService` |
| `CaisseClotureModel` | `clotures_caisse` | `CashApiService` |
| `CompteComptable` | `comptes_comptables` | `AccountingApiService` |
| `EcritureComptable` | `ecritures` + `lignes_ecriture` | `AccountingApiService` |
| `FinancialProduct` | `produits_financiers` | `ProductsApiService` |
| `AgencyModel` | `agencies` | `AgencyApiService` |
| `AgentModel` | `agents` | `AgencyApiService` |
| `SolidaryGroup` | `groupes_solidaires` | `GroupApiService` |
| `DashboardKpis` | (agrégats) | `DashboardApiService` |

Chaque modèle expose `fromMap(Map<String, dynamic>)` et `toMap()` pour la sérialisation JSON, suivant le patron de `Client` et `Loan`.

### Table `configurations` (backend)

Cette table clé/valeur est gérée par le router `/configuration` et n'a pas de modèle SQLAlchemy dédié (opérations SQL raw). La migration `010` la crée :

```sql
CREATE TABLE configurations (
    key   VARCHAR PRIMARY KEY,
    value TEXT
);
```

---

## Error Handling

### Hiérarchie de fallback par service

```
1. ApiService().get(path) → réponse 2xx → données serveur → mise à jour cache SQLite
2. ApiService().get(path) → null ou non-2xx → données SQLite locale (fallback silencieux)
3. Exception Dart (SocketException, TimeoutException) → catch _ → données SQLite locale
```

Aucune exception ne doit traverser la frontière service → écran. Les écrans observent toujours une `List<T>` (potentiellement vide).

### Gestion des conflits de sync

La logique de résolution des conflits est déjà implémentée dans `SyncService.resolveConflict()` (stratégie "last write wins" basée sur `updatedAt`). Les neuf nouveaux services bénéficient de cette infrastructure sans modification supplémentaire.

### Entrées `failed` dans la file

Quand `flushPendingOperations()` retourne `failed > 0`, `ConnectivityMonitor` passe quand même à `online`. Les entrées `failed` restent visibles dans l'interface de gestion de la file (module existant) pour résolution manuelle par l'administrateur.

---

## Séquence d'initialisation

Au démarrage de l'application Flutter (`main.dart`), l'ordre d'initialisation doit être :

```
1. ApiService().init()           → charger l'URL serveur depuis SharedPreferences
2. ConnectivityMonitor().start() → démarrer ping + abonnement connectivity_plus
3. SessionManager().init()       → restaurer la session JWT si disponible
4. DatabaseService().open()      → ouvrir SQLite local
```

Cette séquence garantit que l'URL correcte est chargée avant la première tentative de connexion.

---

## Testing Strategy

### Approche double

**Tests unitaires** : vérifient des exemples concrets et cas limites — comportement du singleton, validation de l'URL regex, état initial du champ URL, comportement du bouton "Tester la connexion".

**Tests de propriétés** (property-based) : vérifient les invariants universels sur tous les inputs — isolation offline/online, ordre des écritures SQLite avant HTTP, idempotence du flush concurrent, transitions d'état du `ConnectivityMonitor`.

**Tests d'intégration** : vérifient les comportements déterministes liés à l'infrastructure — application des migrations Alembic sur base vide, rollback, préservation des données.

**Tests de fumée** : vérifications structurelles one-shot — existence des neuf fichiers de service, existence des dix fichiers de migration.

### Outils recommandés

| Couche | Outil | Cadre |
|---|---|---|
| Propriétés Dart/Flutter | `dart_quickcheck` ou `fast_check` port Dart | `flutter test` |
| Tests unitaires Flutter | `flutter_test`, `mockito` | `flutter test` |
| Tests backend Python | `hypothesis` (PBT), `pytest` | `pytest` |
| Migrations | `pytest` + `alembic` + PostgreSQL de test | `pytest` |

---

## Correctness Properties

*Une propriété est une caractéristique ou un comportement qui doit rester vrai pour toutes les exécutions valides du système — une affirmation formelle sur ce que le système doit faire. Les propriétés servent de pont entre les spécifications lisibles par l'humain et les garanties de correction vérifiables automatiquement.*

---

### Property 1: Ordre des migrations respecte les dépendances FK

*Pour tout couple de tables (A, B) tel que A contient une clé étrangère vers B, la migration créant B doit avoir un numéro de révision inférieur (antérieur dans la chaîne) à la migration créant A.*

**Validates: Requirements 1.4**

---

### Property 2: Les migrations préservent les données des tables non concernées

*Pour toute table T non modifiée par une migration M et pour tout ensemble de lignes R présentes dans T avant l'application de M, après application de M le nombre de lignes dans T et leurs valeurs sont identiques.*

**Validates: Requirements 1.5**

---

### Property 3: Singleton — une factory retourne toujours la même instance

*Pour tout service API S parmi les neuf nouveaux services, appeler `S()` (factory) un nombre quelconque de fois retourne toujours la même instance en mémoire (identité référentielle).*

**Validates: Requirements 2.2**

---

### Property 4: Lecture online → API d'abord, cache ensuite

*Pour tout service API S et toute méthode de lecture, quand `SyncService().isOnline` retourne `true`, la méthode doit invoquer `ApiService().get()` et, si la réponse est valide, appeler les méthodes de mise à jour de `DatabaseService()` avant de retourner les données.*

**Validates: Requirements 2.3**

---

### Property 5: Lecture offline → SQLite exclusivement, aucun appel HTTP

*Pour tout service API S et toute méthode de lecture, quand `SyncService().isOnline` retourne `false`, aucun appel à `ApiService().get()` ne doit être émis et les données retournées proviennent exclusivement de `DatabaseService()`.*

**Validates: Requirements 2.4**

---

### Property 6: Écriture — SQLite avant HTTP

*Pour tout service API S, toute méthode d'écriture et tout payload valide, `DatabaseService().insertXxx()` ou `updateXxx()` est appelé avant tout appel à `ApiService().post()` ou `put()`, et ce quel que soit l'état de la connexion.*

**Validates: Requirements 2.5**

---

### Property 7: Aucune exception ne traverse la frontière service → écran

*Pour tout service API S, toute méthode de lecture et toute réponse API simulée (null, code 4xx, code 5xx, timeout), la méthode ne doit pas lever d'exception vers l'appelant et doit retourner les données du cache SQLite.*

**Validates: Requirements 2.6**

---

### Property 8: Événement `none` de connectivity_plus → offline immédiat

*Pour tout événement émis par le stream `connectivity_plus` contenant uniquement `ConnectivityResult.none`, `statusNotifier.value` doit passer à `ConnectivityStatus.offline` sans attendre le prochain tick du timer.*

**Validates: Requirements 3.2**

---

### Property 9: Événement non-none → vérification serveur immédiate

*Pour tout événement émis par le stream `connectivity_plus` contenant au moins un `ConnectivityResult` différent de `none`, `ApiService().isServerAvailable()` doit être appelé immédiatement (dans le même cycle d'exécution asynchrone), sans attendre le timer de 30 s.*

**Validates: Requirements 3.3**

---

### Property 10: Transition offline→online suit la séquence syncing→flush→online

*Pour tout scénario où `statusNotifier.value` est `ConnectivityStatus.offline` et où `isServerAvailable()` retourne `true`, la séquence observée doit être : passage à `syncing`, appel à `flushPendingOperations()`, puis passage à `online` — dans cet ordre strict.*

**Validates: Requirements 3.4**

---

### Property 11: Idempotence du flush — un seul appel concurrent

*Pour tout nombre N d'événements de connectivité émis pendant que `statusNotifier.value` est `ConnectivityStatus.syncing`, `flushPendingOperations()` doit être appelé exactement une fois (l'appel en cours), et non N+1 fois.*

**Validates: Requirements 3.5**

---

### Property 12: Retour online même après flush partiel

*Pour tout `SyncResult` retourné par `flushPendingOperations()` avec `failed > 0`, `statusNotifier.value` doit passer à `ConnectivityStatus.online` (et non rester `syncing` ou passer à `offline`), et les entrées `failed` doivent rester présentes dans la file `sync_queue`.*

**Validates: Requirements 3.7**

---

### Property 13: Visibilité de la section Connexion serveur liée au rôle ADMIN

*Pour tout utilisateur authentifié dont le rôle est `ADMIN`, la section « Connexion serveur » est visible dans l'écran Paramètres. Pour tout utilisateur dont le rôle est différent de `ADMIN`, la section est absente de l'arbre de widgets (non rendue, non masquée via opacity ou visibility).*

**Validates: Requirements 4.1, 4.8**

---

### Property 14: Validation URL — rejet de tout format non conforme

*Pour toute chaîne U ne correspondant pas au motif `http(s)://[host]:[port]`, soumettre U dans le champ URL doit afficher un message d'erreur de validation et ne pas appeler `ApiService().setServerUrl()`.*

**Validates: Requirements 4.6**

---

### Property 15: Soumission d'une URL valide → setServerUrl appelé puis vérification immédiate

*Pour toute URL valide U soumise par un utilisateur ADMIN, `ApiService().setServerUrl(U)` doit être appelé avec exactement U comme argument, suivi immédiatement d'un appel à `isServerAvailable()` (via `ConnectivityMonitor().start()`) qui met à jour `statusNotifier`.*

**Validates: Requirements 4.3, 4.4**

---

### Property 16: Indicateur visuel reflète le statut courant

*Pour toute valeur de `ConnectivityStatus` (`online`, `syncing`, `offline`), l'indicateur coloré dans la section « Connexion serveur » doit afficher respectivement vert, orange ou rouge, et ce de façon synchrone avec `statusNotifier.value`.*

**Validates: Requirements 4.5**
