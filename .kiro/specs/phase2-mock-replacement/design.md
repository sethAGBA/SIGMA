# Design Document

> **Titre :** Phase 2 — Remplacement des valeurs hardcodées — SIGMA Micro-Finance

## Overview

La Phase 2 consiste à éliminer les 7 occurrences de valeurs statiques (mocks) réparties dans 5 fichiers de l'application Flutter SIGMA Micro-Finance, en les remplaçant par des données dynamiques issues de `AuthService` (session) et de `DatabaseService` (SQLite). Il n'y a pas de nouvelle architecture à créer : on branche des sources de données existantes sur des widgets existants.

Les modifications sont chirurgicales et à faible risque :
- Aucun nouveau service n'est nécessaire
- `AuthService` est déjà un singleton accessible partout
- `DatabaseService` expose déjà les méthodes SQL nécessaires (à l'exception de `getLastCashClosing`)

---

## Architecture

L'architecture existante est conservée telle quelle. Le diagramme ci-dessous montre les flux de données après la Phase 2 :

```mermaid
graph TD
    A[AuthService\nSingleton] -->|currentUsername| B[DashboardPage\nmessage de bienvenue]
    A -->|currentUsername| C[CashClosingDialog\nagentCloture]
    A -->|currentUsername| D[RepaymentFormDialog\nagentCollecteur]
    A -->|currentUsername| E[DailyCollectionPage\nen-tête]
    A -->|currentUsername| F[SaisieComptablePage\nagentSaisie]

    DB[DatabaseService\nSQLite] -->|getHomeDashboardData()| B
    DB -->|getLastCashClosing()| C
    DB -->|getPendingSchedules(retardOnly)| E
    DB -->|getDelinquentLoanDetails(id)| G[DelinquentLoanDetailPage]

    H[DelinquentLoansListPage] -->|loan\['id'\] dynamique| G
```

---

## Components and Interfaces

### 1. `DashboardPage` — message de bienvenue

**Fichier :** `lib/screens/dashboard/dashboard_page.dart`

Le message de bienvenue utilise déjà `AuthService().currentUser?.username ?? 'Utilisateur'`. Cette exigence est donc **déjà satisfaite** dans le code existant. Aucun changement nécessaire sur ce point.

Le bouton FAB est absent du code actuel — il faut l'ajouter. Il s'affichera comme un `SpeedDial` ou un `FloatingActionButton` avec un `PopupMenuButton` proposant :
- **Nouveau client** → navigation vers `ClientCreationPage` (ou équivalent)
- **Nouveau prêt** → navigation vers `LoanCreationPage` (ou équivalent)
- **Opération caisse** → navigation vers `CashLedgerPage` ou ouverture du `CashMiscellaneousDialog`

Les options sont désactivées si l'utilisateur n'a pas les permissions RBAC via `AuthService().canAccess('create_client')`, etc.

### 2. `CashClosingDialog` — agent et solde initial

**Fichier :** `lib/screens/caisse/cash_closing_dialog.dart`

**Changement 1 — `agentCloture`** : Remplacer la chaîne littérale `'Agent Connecté'` par `AuthService().currentUsername`. Ajouter un guard dans `_submit()` : si `currentUsername` est vide, afficher un `SnackBar` d'erreur et interrompre.

**Changement 2 — `soldeInitial`** : La méthode `_loadData()` doit appeler une nouvelle méthode `DatabaseService().getLastCashClosing()` qui retourne la dernière entrée de la table `clotures_caisse` triée par `date_cloture DESC LIMIT 1`. Si un résultat existe, `soldeInitial = result.soldePhysique`. Sinon `soldeInitial = 0.0`.

**Nouvelle méthode DatabaseService à ajouter :**

```dart
Future<CashClosing?> getLastCashClosing() async {
  final db = await database;
  final List<Map<String, dynamic>> maps = await db.query(
    'clotures_caisse',
    orderBy: 'date_cloture DESC',
    limit: 1,
  );
  if (maps.isEmpty) return null;
  return CashClosing.fromMap(maps.first);
}
```

### 3. `RepaymentFormDialog` — agent collecteur

**Fichier :** `lib/screens/remboursements/repayment_form_dialog.dart`

Remplacer `'SYSTÈME'` par `AuthService().currentUsername.isNotEmpty ? AuthService().currentUsername : 'Inconnu'` dans la construction du modèle `Repayment`.

### 4. `DailyCollectionPage` — en-tête et filtre retard

**Fichier :** `lib/screens/remboursements/daily_collection_page.dart`

**Changement 1 — En-tête** : Remplacer `'COLLECTE DU JOUR - Agent: Jean KOUASSI'` par `'COLLECTE DU JOUR — Agent : ${AuthService().currentUsername.isNotEmpty ? AuthService().currentUsername : 'Inconnu'}'`.

**Changement 2 — Filtre retard** : Ajouter un `bool _filterRetard = false` dans le state. Le widget texte `'Filtrer par retard'` devient un `InkWell` ou `TextButton` qui bascule `_filterRetard` et appelle `_refresh()`.

La méthode `_refresh()` passe le paramètre `retardOnly: _filterRetard` à `DatabaseService().getPendingSchedules()`.

```dart
// Signature à adapter dans DatabaseService
Future<List<RepaymentSchedule>> getPendingSchedules({bool retardOnly = false});
```

En mode `retardOnly = true`, la requête SQL ajoute `WHERE jours_retard > 0`.

### 5. `SaisieComptablePage` — agent de saisie

**Fichier :** `lib/screens/comptabilite/saisie_comptable_page.dart`

Deux occurrences à remplacer :
1. `initialValue: 'Admin'` dans le `TextFormField` « Agent de saisie » → `initialValue: AuthService().currentUsername`
2. `agentSaisie: 'Admin'` dans la construction de `EcritureComptable` → `agentSaisie: AuthService().currentUsername.isNotEmpty ? AuthService().currentUsername : 'Inconnu'`

### 6. `DelinquentLoansListPage` → `DelinquentLoanDetailPage` — loanId dynamique

**Fichier :** `lib/screens/reporting/delinquent_loans_list_page.dart`

Le code actuel utilise déjà `DelinquentLoanDetailPage(loanId: id)` avec `final int id = loan['id']` extrait de la liste. **Cette exigence est déjà satisfaite dans le code existant.** Aucun changement nécessaire.

---

## Data Models

Aucun nouveau modèle. Les champs existants sont réutilisés :

| Modèle | Champ | Type | Source après Phase 2 |
|---|---|---|---|
| `CashClosing` | `agentCloture` | `String` | `AuthService().currentUsername` |
| `CashClosing` | `soldeInitial` | `double` | `lastCashClosing?.soldePhysique ?? 0.0` |
| `Repayment` | `agentCollecteur` | `String` | `AuthService().currentUsername` |
| `EcritureComptable` | `agentSaisie` | `String` | `AuthService().currentUsername` |

---

## Correctness Properties

*Une propriété est une caractéristique ou un comportement qui doit rester vrai pour toutes les exécutions valides d'un système — c'est une spécification formelle de ce que le système doit faire. Les propriétés servent de pont entre les spécifications lisibles par l'humain et les garanties de correction vérifiables par machine.*

### Propriété 1 : Les champs d'audit contiennent le username de session

*Pour tout* username d'utilisateur connecté X, lors de la création d'un modèle `CashClosing`, `Repayment`, ou `EcritureComptable`, les champs `agentCloture`, `agentCollecteur`, et `agentSaisie` respectivement doivent être égaux à X.

**Valide : Exigences 4.1, 6.1, 9.2**

### Propriété 2 : Continuité du solde de caisse entre clôtures

*Pour toute* séquence de deux clôtures journalières consécutives C1 puis C2, le `soldeInitial` de C2 doit être égal au `soldePhysique` de C1.

**Valide : Exigence 5.2**

### Propriété 3 : Le filtre retard est un toggle idempotent

*Pour toute* liste d'échéances L, activer le filtre retard puis le désactiver doit restituer la liste complète L sans perte d'éléments.

**Valide : Exigences 8.2, 8.3**

### Propriété 4 : Le filtre retard n'inclut que les échéances en retard

*Pour toute* liste d'échéances filtrée par retard, chaque élément de la liste doit avoir `joursRetard > 0`.

**Valide : Exigence 8.2**

### Propriété 5 : La navigation vers le détail passe l'identifiant correct

*Pour tout* prêt en souffrance P dans la liste, le tap sur P ouvre `DelinquentLoanDetailPage` avec `loanId == P.id`.

**Valide : Exigences 10.1, 10.3**

---

## Error Handling

| Situation d'erreur | Comportement attendu |
|---|---|
| `AuthService().currentUsername` est vide | Utiliser `'Inconnu'` comme repli (champs d'audit), ou refuser la soumission avec message explicite (clôture caisse) |
| `DatabaseService().getLastCashClosing()` retourne null | Utiliser `soldeInitial = 0.0` |
| `DatabaseService().getDelinquentLoanDetails(id)` retourne null | Afficher « Dossier introuvable » |
| Aucune page de navigation configurée pour le FAB | Désactiver l'option correspondante (ne pas lancer d'exception) |
| `getPendingSchedules()` échoue en mode filtre | Afficher un `SnackBar` d'erreur et conserver l'état précédent |

---

## Testing Strategy

### Tests unitaires (obligatoires)

Tests d'exemple ciblant les cas nominaux et les cas limites :

- `CashClosingDialog` : vérifier que `agentCloture` est bien `AuthService().currentUsername` dans le modèle soumis
- `CashClosingDialog` : vérifier que `soldeInitial` est `0.0` quand aucune clôture précédente n'existe
- `CashClosingDialog` : vérifier que la soumission est refusée si `currentUsername` est vide
- `RepaymentFormDialog` : vérifier que `agentCollecteur` est `'Inconnu'` quand `currentUsername` est vide
- `SaisieComptablePage` : vérifier que `agentSaisie` est `'Inconnu'` quand `currentUsername` est vide
- `DailyCollectionPage` : vérifier que le filtre toggle change l'état `_filterRetard`
- `DatabaseService.getLastCashClosing()` : vérifier le retour null sur base vide, et la bonne valeur sur base peuplée

### Tests de propriétés (property-based tests)

La bibliothèque recommandée est **`fast_check`** (Dart/Flutter) ou **`dart_check`**.

Chaque test doit s'exécuter avec un minimum de 100 itérations.

**Test P1 — Champs d'audit = username de session**
```
Tag: Feature: phase2-mock-replacement, Property 1: audit fields equal session username
Pour tout username généré aléatoirement (chaîne non vide, max 50 chars),
initialiser AuthService avec ce username,
créer un CashClosing / Repayment / EcritureComptable via les dialogues,
vérifier agentCloture == username, agentCollecteur == username, agentSaisie == username.
```

**Test P2 — Continuité du solde de caisse**
```
Tag: Feature: phase2-mock-replacement, Property 2: cash balance continuity
Pour toute valeur de soldePhysique positive générée aléatoirement,
créer une CashClosing C1 avec ce soldePhysique,
persister C1,
initialiser un nouveau CashClosingDialog,
vérifier que soldeInitial affiché == C1.soldePhysique.
```

**Test P3/P4 — Filtre retard**
```
Tag: Feature: phase2-mock-replacement, Property 3/4: overdue filter toggle
Pour toute liste d'échéances générée aléatoirement (mix joursRetard == 0 et > 0),
activer le filtre : vérifier que tous les éléments ont joursRetard > 0,
désactiver le filtre : vérifier que la liste complète est restituée.
```

**Test P5 — Navigation dynamique**
```
Tag: Feature: phase2-mock-replacement, Property 5: dynamic loan navigation
Pour tout identifiant de prêt entier généré aléatoirement,
simuler un tap sur l'élément correspondant dans DelinquentLoansListPage,
vérifier que DelinquentLoanDetailPage reçoit exactement cet identifiant.
```

### Approche complémentaire

- Les tests UI visuels (indicateur filtre actif, bouton FAB désactivé) sont couverts par des **widget tests** avec `flutter_test` et `MockAuthService`.
- Les tests d'intégration avec la base de données réelle sont effectués sur une base SQLite en mémoire (`:memory:`).
