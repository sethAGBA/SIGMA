# Document de Conception — Phase 3 : Logique Métier Centrale

## Vue d'ensemble

La Phase 3 repose sur trois composants indépendants :

1. **Pont comptable automatique** — deux implémentations parallèles (Dart/SQLite et Python/PostgreSQL) qui génèrent des écritures lors de chaque opération financière.
2. **Jobs nocturnes APScheduler** — trois jobs Python planifiés sur le serveur backend.
3. **State management Dashboard** — `DashboardNotifier` basé sur Provider pour éliminer les recalculs à chaque navigation.

---

## 1. Pont comptable automatique

### 1.1 Architecture Flutter (offline / SQLite)

```
DatabaseService.insertLoan()
  └─► AutomaticAccountingService.createLoanDisbursementEntry()
        └─► AccountingService.createEcriture()
              └─► SQLite (écritures_comptables + lignes_ecritures)

DatabaseService.insertRepayment()
  └─► AutomaticAccountingService.createLoanRepaymentEntry()
        └─► AccountingService.createEcriture()

DatabaseService.insertSavingsTransaction()
  └─► AutomaticAccountingService.createSavingsDepositEntry()  (DEPOT)
  └─► AutomaticAccountingService.createSavingsWithdrawalEntry()  (RETRAIT)
```

**Comptes utilisés (configurables via `AccountingConfiguration`) :**

| Opération | Débit | Crédit |
|-----------|-------|--------|
| Déblocage prêt | `comptePrets` (501) | `compteCaisse` (530) |
| Remboursement | `compteCaisse` (530) | `comptePrets` (501) + `compteInterets` (701) + `comptePenalites` (703) |
| Dépôt épargne | `compteCaisse` (530) | `compteDepots` (521) |
| Retrait épargne | `compteDepots` (521) | `compteCaisse` (530) |
| Provision | `compteDotationProvisions` (6972) | `compteDepreciationPrets` (2971) |

**Numéros de pièce :**

| Préfixe | Opération |
|---------|-----------|
| `DBL-` | Déblocage prêt |
| `RBT-` | Remboursement |
| `DEP-` | Dépôt épargne |
| `RET-` | Retrait épargne |
| `PRV-` | Provision |

**Gestion des erreurs Flutter :**
- L'écriture comptable est créée dans la même transaction SQLite que l'opération.
- En cas d'échec de l'écriture, l'opération principale n'est PAS annulée (dégradation gracieuse) — l'erreur est loggée avec `debugPrint`.
- Ce comportement intentionnel évite de bloquer une opération métier critique (remboursement client) pour une erreur comptable.

### 1.2 Architecture Python (online / PostgreSQL)

```
POST /prets
  └─► create_pret() dans prets.py
        └─► AutomaticAccountingService.on_deblocage_pret()
              └─► _create_ecriture() → PostgreSQL

POST /remboursements
  └─► enregistrer_remboursement() dans remboursements.py
        └─► AutomaticAccountingService.on_remboursement()

POST /epargne/transactions
  └─► effectuer_transaction() dans epargne.py
        └─► on_depot_epargne() ou on_retrait_epargne()
```

**Comptes PostgreSQL (hardcodés RCSSFD) :**

| Compte | Rôle |
|--------|------|
| 501 | Crédits à la clientèle (prêts) |
| 521 | Épargne à vue |
| 530 | Caisse |
| 602 | Charges d'intérêts sur épargne |
| 701 | Produits d'intérêts sur prêts |
| 703 | Pénalités de retard |

---

## 2. Jobs nocturnes APScheduler

### 2.1 Planification

```
backend/app/jobs/scheduler.py
├── daily_penalties   → CronTrigger(hour=0, minute=5)     # chaque jour 00:05
├── monthly_interests → CronTrigger(day=1, hour=1, min=0)  # 1er du mois 01:00
└── nightly_scoring   → CronTrigger(hour=2, minute=0)      # chaque jour 02:00
```

Le scheduler démarre via `start_scheduler()` appelé dans `main.py` au démarrage FastAPI.

### 2.2 PenaltyService — Algorithme

```
Pour chaque Echeancier où statut ≠ 'Payé' ET date_prevue < aujourd'hui :
  jours_retard = (today - date_prevue).days
  taux = produit.taux_penalite_journalier ?? 0.001
  penalite = round(capital_restant × taux × jours_retard, 0)
  écheance.frais_dus = penalite
  écheance.total_du = capital_du + interets_dus + penalite
  si jours_retard > pret.jours_retard : pret.jours_retard = jours_retard
db.commit()
```

### 2.3 ScoringService — Barème

```
score = 60  (base)
+ 5   si ≥ 2 prêts soldés
+ 5   par prêt sans aucune pénalité
- 10  par prêt avec pénalités (retard détecté)
+ 10  si taux_remboursement_global ≥ 95%
- 15  si taux_remboursement_global < 80%
→ clamp [0, 100]

Niveau de risque :
  score ≥ 70 → 'Faible'
  score ≥ 40 → 'Moyen'
  score <  40 → 'Élevé'
```

### 2.4 MonthlyInterests — Algorithme

```
Pour chaque CompteEpargne où statut == 'Actif' :
  taux = compte.taux_interet_applique ?? 0
  si taux <= 0 ou solde <= 0 : ignorer
  interets = round(solde × taux / 100 / 12, 0)
  si interets <= 0 : ignorer
  compte.solde += interets
  compte.interets_acquis += interets
  créer TransactionEpargne(type='INTERETS', montant=interets)
  créer Ecriture(Débit 602 / Crédit 521, montant=interets)
db.commit()
```

---

## 3. State management Dashboard

### 3.1 Choix technique : Provider

**Justification :** Provider est le package officiel Flutter recommandé par l'équipe Flutter/Google pour les cas d'usage simples à intermédiaires. Il ne nécessite pas de refonte architecturale profonde et peut être introduit progressivement (uniquement le dashboard dans un premier temps).

Riverpod est plus puissant mais introduit une courbe d'apprentissage et impose de réécrire tous les widgets pour utiliser `ConsumerWidget`. Provider permet une migration incrémentale.

### 3.2 Architecture

```
main.dart
└─► MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DashboardNotifier()),
      ],
      child: SigmaApp(),
    )

DashboardPage (ConsumerWidget ou Consumer<DashboardNotifier>)
└─► Écoute DashboardNotifier.state
      ├─ loading → CircularProgressIndicator
      ├─ loaded  → afficher HomeDashboardData depuis le cache
      └─ error   → afficher SnackBar non bloquant + données en cache

DashboardNotifier (ChangeNotifier)
├─ HomeDashboardData? _cachedData
├─ bool _isLoading
├─ String? _error
├─ load()         → charge depuis API ou SQLite, met en cache
├─ refresh()      → force le rechargement
└─ clearCache()   → appelé sur logout
```

### 3.3 Flux de données

```
Premier chargement :
  DashboardPage.initState()
    └─► notifier.load() si cache vide
          ├─ ApiService.isServerAvailable() → true
          │     └─► ApiService.get('/reporting/dashboard')
          │           + DatabaseService.getHomeDashboardData() (local)
          │           → merge → _cachedData
          └─ false
                └─► DatabaseService.getHomeDashboardData()
                      → _cachedData

Navigation répétée :
  DashboardPage.build()
    └─► notifier._cachedData != null → affichage immédiat (pas d'appel réseau)

Refresh manuel :
  RefreshIndicator.onRefresh()
    └─► notifier.refresh() → force rechargement

Logout :
  AuthService.logout()
    └─► DashboardNotifier.clearCache() → _cachedData = null
```

### 3.4 Intégration dans main.dart

```dart
// Avant (actuel) :
runApp(const SigmaApp());

// Après :
runApp(
  MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => DashboardNotifier()),
    ],
    child: const SigmaApp(),
  ),
);
```

### 3.5 Dépendance pubspec.yaml

```yaml
dependencies:
  provider: ^6.1.2
```

---

## 4. Tests

### Pont comptable

| Test | Type | Fichier |
|------|------|---------|
| Déblocage crée écriture Débit 501 / Crédit 530 | Unitaire | `test/services/automatic_accounting_test.dart` |
| Remboursement sans pénalités → 2 lignes seulement | Unitaire | idem |
| Remboursement avec intérêts+pénalités → 4 lignes | Unitaire | idem |
| Dépôt épargne → Débit 530 / Crédit 521 | Unitaire | idem |
| Retrait épargne → Débit 521 / Crédit 530 | Unitaire | idem |
| **Propriété** : montant débit == montant crédit (équilibre comptable) | Property | `test/services/accounting_balance_property_test.dart` |

### Jobs nocturnes (Python)

| Test | Type | Fichier |
|------|------|---------|
| PenaltyService : 0 échéances en retard → 0 pénalités | Unitaire | `backend/tests/test_penalty_service.py` |
| PenaltyService : 1 échéance 5 jours → pénalité = capital × 0.001 × 5 | Unitaire | idem |
| ScoringService : client sans retard → score ≥ 70 | Unitaire | `backend/tests/test_scoring_service.py` |
| ScoringService : client avec retards → score ≤ 50 | Unitaire | idem |
| MonthlyInterests : compte taux 0% → ignoré | Unitaire | `backend/tests/test_monthly_interests.py` |
| MonthlyInterests : compte 100k FCFA, 6% → 500 FCFA d'intérêts | Unitaire | idem |

### Dashboard state management

| Test | Type | Fichier |
|------|------|---------|
| `load()` stocke les données en cache | Unitaire | `test/notifiers/dashboard_notifier_test.dart` |
| Second appel à `build()` n'appelle pas DatabaseService | Unitaire | idem |
| `refresh()` vide le cache et recharge | Unitaire | idem |
| `clearCache()` remet `_cachedData` à null | Unitaire | idem |
