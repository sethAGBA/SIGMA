# Implementation Plan: Phase 3 — Logique Métier Centrale

## Overview

La Phase 3 est à ~95% implémentée. Ce plan couvre les tâches de complétion, de vérification et de test. Les tâches sont organisées en 4 groupes : vérification du pont comptable Flutter, vérification du pont comptable backend Python, vérification des jobs nocturnes, et implémentation du state management Dashboard.

## Tasks

- [x] 1. Vérifier et tester le pont comptable Flutter — déblocage prêt
  - Lire `lib/core/services/database_service.dart` → méthode `insertLoan()` : confirmer que `AutomaticAccountingService.createLoanDisbursementEntry()` est appelé dans la transaction SQLite
  - Lire `lib/core/services/automatic_accounting_service.dart` → `createLoanDisbursementEntry()` : vérifier les comptes Débit/Crédit et le format du numéro de pièce `DBL-`
  - Confirmer que l'écriture échoue de manière gracieuse (try/catch avec log) sans bloquer l'insertion du prêt
  - Ajouter un commentaire `// Phase 3 OK` si déjà conforme
  - _Exigences : 1.1, 1.3, 1.4, 1.5_

  - [ ]* 1.1 Écrire le test unitaire pour `createLoanDisbursementEntry()`
    - Créer `test/services/automatic_accounting_test.dart`
    - Base SQLite en mémoire avec `DatabaseService.setDatabaseForTesting()`
    - Vérifier que l'écriture créée a bien `Débit comptePrets` et `Crédit compteCaisse` avec le montant du prêt
    - **Propriété** : `sum(débits) == sum(crédits)` pour toute écriture générée
    - _Exigences : 1.1, 1.3_

- [x] 2. Vérifier et tester le pont comptable Flutter — remboursement
  - Dans `database_service.dart` → `insertRepayment()` : confirmer que `createLoanRepaymentEntry()` est appelé
  - Vérifier que les lignes intérêts et pénalités sont omises si leurs montants sont 0
  - Confirmer la gestion gracieuse des erreurs
  - _Exigences : 2.1, 2.3, 2.4, 2.5_

  - [ ]* 2.1 Écrire le test unitaire pour `createLoanRepaymentEntry()`
    - Cas 1 : remboursement capital seulement (2 lignes)
    - Cas 2 : capital + intérêts (3 lignes)
    - Cas 3 : capital + intérêts + pénalités (4 lignes)
    - **Propriété** : équilibre comptable `sum(débits) == sum(crédits)` pour les 3 cas
    - _Exigences : 2.1, 2.3, 2.4_

- [x] 3. Vérifier et tester le pont comptable Flutter — épargne
  - Dans `database_service.dart` → `insertSavingsTransaction()` : confirmer que `createSavingsDepositEntry()` ou `createSavingsWithdrawalEntry()` est appelé selon `type`
  - Vérifier que le `type_operation` invalide est géré
  - _Exigences : 3.1, 3.2, 3.5_

  - [ ]* 3.1 Écrire les tests unitaires pour dépôt et retrait épargne
    - Dépôt : `Débit compteCaisse / Crédit compteDepots`
    - Retrait : `Débit compteDepots / Crédit compteCaisse`
    - **Propriété** : équilibre comptable pour les deux opérations
    - _Exigences : 3.1, 3.2_

- [x] 4. Écrire le property test global — équilibre comptable
  - Créer `test/services/accounting_balance_property_test.dart`
  - **Propriété : Équilibre comptable universel**
  - Pour toute opération (déblocage, remboursement, dépôt, retrait, provision) avec des montants générés aléatoirement (doubles positifs), vérifier que `sum(débit) == sum(crédit)` sur toutes les lignes de l'écriture
  - 100 itérations par opération
  - _Exigences : 1.1, 2.1, 3.1, 4.1_

- [x] 5. Vérifier le pont comptable Python backend — déblocage et remboursement
  - Lire `backend/app/routers/prets.py` : confirmer que `on_deblocage_pret()` est appelé dans `create_pret()`
  - Lire `backend/app/routers/remboursements.py` : confirmer que `on_remboursement()` est appelé dans `enregistrer_remboursement()`
  - Lire `backend/app/services/accounting_service.py` : vérifier comptes 501/530 pour déblocage et 530/501/701/703 pour remboursement
  - Ajouter un commentaire `# Phase 3 OK` si conforme
  - _Exigences : 1.2, 2.2_

  - [ ]* 5.1 Écrire les tests Python pour le pont comptable backend
    - Créer `backend/tests/test_accounting_service.py`
    - Utiliser SQLAlchemy in-memory (SQLite) pour les tests
    - Tester `on_deblocage_pret()` : 2 lignes créées, Débit 501 / Crédit 530
    - Tester `on_remboursement()` avec et sans pénalités
    - Tester `on_depot_epargne()` et `on_retrait_epargne()`
    - _Exigences : 1.2, 2.2, 3.3_

- [x] 6. Vérifier le pont comptable Python backend — épargne
  - Lire `backend/app/routers/epargne.py` : confirmer que `on_depot_epargne()` ou `on_retrait_epargne()` est appelé selon `type_operation`
  - Confirmer que HTTP 400 est retourné pour `type_operation` invalide
  - _Exigences : 3.3, 3.4_

- [x] 7. Vérifier et tester le job `daily_penalties`
  - Lire `backend/app/services/penalty_service.py` : vérifier l'algorithme `capital_restant × taux × jours_retard`
  - Vérifier que `taux` utilise bien `0.001` par défaut si non défini
  - Vérifier la mise à jour de `pret.jours_retard`
  - Lire `backend/app/jobs/daily_penalties.py` : confirmer le logging
  - _Exigences : 5.1, 5.2, 5.3, 5.4, 5.5, 5.6_

  - [ ]* 7.1 Écrire les tests Python pour `PenaltyService`
    - Créer `backend/tests/test_penalty_service.py`
    - Cas 1 : table vide → 0 pénalités
    - Cas 2 : 1 échéance 5 jours de retard → `pénalité = capital × 0.001 × 5`
    - Cas 3 : échéance déjà payée → ignorée
    - **Propriété** : pénalité ≥ 0 pour tout jours_retard ≥ 0
    - _Exigences : 5.1, 5.2, 5.3_

- [x] 8. Vérifier et tester le job `nightly_scoring`
  - Lire `backend/app/services/scoring_service.py` : vérifier le barème (base 60, ajustements, clamp 0-100)
  - Vérifier `_score_to_risk_level()` : seuils 70 (Faible), 40 (Moyen), <40 (Élevé)
  - _Exigences : 6.1, 6.2, 6.3, 6.4, 6.5_

  - [ ]* 8.1 Écrire les tests Python pour `ScoringService`
    - Créer `backend/tests/test_scoring_service.py`
    - Cas 1 : client sans aucun prêt → score = 60
    - Cas 2 : client avec 2 prêts soldés sans retard → score ≥ 70 → niveau 'Faible'
    - Cas 3 : client avec retards multiples → score réduit → niveau 'Élevé'
    - _Exigences : 6.2, 6.3, 6.4_

- [x] 9. Vérifier et tester le job `monthly_interests`
  - Lire `backend/app/jobs/monthly_interests.py` : vérifier formule `solde × taux / 100 / 12`
  - Vérifier que les comptes avec `taux ≤ 0` ou `solde ≤ 0` sont ignorés
  - Vérifier la création de `TransactionEpargne(type='INTERETS')` et l'écriture `Débit 602 / Crédit 521`
  - _Exigences : 7.1, 7.2, 7.3, 7.4_

  - [ ]* 9.1 Écrire les tests Python pour `monthly_interests`
    - Créer `backend/tests/test_monthly_interests.py`
    - Cas 1 : compte avec taux 0% → ignoré
    - Cas 2 : compte 100 000 FCFA à 6% annuel → intérêts = 500 FCFA
    - Cas 3 : compte inactif → ignoré
    - _Exigences : 7.2, 7.3, 7.4_

- [x] 10. Vérifier le scheduler APScheduler
  - Lire `backend/app/jobs/scheduler.py` : confirmer les 3 jobs et leurs triggers cron
  - Vérifier que `replace_existing=True` est bien présent sur chaque job
  - Vérifier que `start_scheduler()` est appelé dans `backend/main.py`
  - _Exigences : 8.1, 8.2_

- [x] 11. Implémenter `DashboardNotifier` avec Provider
  - Ajouter `provider: ^6.1.2` dans `pubspec.yaml` (vérifier qu'il n'est pas déjà présent)
  - Créer `lib/core/notifiers/dashboard_notifier.dart` avec `ChangeNotifier` :
    - Propriétés : `_cachedData`, `_isLoading`, `_error`
    - Méthode `load()` : si cache non vide, ne rien faire ; sinon charger depuis API (si online) ou SQLite (offline)
    - Méthode `refresh()` : vider le cache et appeler `load()`
    - Méthode `clearCache()` : `_cachedData = null; notifyListeners()`
  - _Exigences : 9.1, 9.2, 9.3, 9.4, 9.5, 9.6_

- [x] 12. Intégrer `DashboardNotifier` dans `main.dart` et `DashboardPage`
  - Dans `main.dart`, envelopper `SigmaApp` dans `MultiProvider` avec `ChangeNotifierProvider<DashboardNotifier>`
  - Dans `lib/screens/dashboard/dashboard_page.dart` :
    - Remplacer `_loadData()` par une consommation de `context.read<DashboardNotifier>().load()`
    - Utiliser `Consumer<DashboardNotifier>` pour le `build()`
    - Connecter `RefreshIndicator.onRefresh` à `notifier.refresh()`
  - Dans `AuthService.logout()` : appeler `DashboardNotifier().clearCache()`
  - Vérifier que la navigation retour sur le dashboard n'appelle plus `DatabaseService` si le cache est chaud
  - _Exigences : 9.2, 9.3, 9.4_

  - [ ]* 12.1 Écrire les tests pour `DashboardNotifier`
    - Créer `test/notifiers/dashboard_notifier_test.dart`
    - Cas 1 : `load()` → cache rempli, `_cachedData != null`
    - Cas 2 : second `load()` → aucun appel à `DatabaseService` (vérifier avec mock)
    - Cas 3 : `refresh()` → cache vidé puis rechargé
    - Cas 4 : `clearCache()` → `_cachedData == null`
    - _Exigences : 9.1, 9.2, 9.3, 9.4_

- [x] 13. Checkpoint — Tous les tests Phase 3 passent
  - Lancer `flutter test` depuis la racine du projet
  - Vérifier que les tests des tâches 1.1, 2.1, 3.1, 4, 12.1 passent
  - Lancer `flutter analyze` — 0 erreur bloquante
  - Confirmer avec `grep -r "AutomaticAccountingService" lib/` que le service est bien appelé dans les 3 points d'entrée (insertLoan, insertRepayment, insertSavingsTransaction)

- [x] 14. Mettre à jour `analyse_projet.md`
  - Cocher toutes les tâches Phase 3 confirmées dans `analyse_projet.md`
  - Mettre à jour les barres de progression Phase 3

## Task Dependency Graph

```json
{
  "waves": [
    { "wave": 1, "tasks": ["1", "2", "3", "5", "6", "7", "8", "9", "10"] },
    { "wave": 2, "tasks": ["4"] },
    { "wave": 3, "tasks": ["11"] },
    { "wave": 4, "tasks": ["12"] },
    { "wave": 5, "tasks": ["13"] },
    { "wave": 6, "tasks": ["14"] }
  ]
}
```

Les tâches 1 à 10 (vérification et tests) sont toutes indépendantes et peuvent s'exécuter en parallèle. La tâche 4 (property test global équilibre) dépend des constats des tâches 1-3. Les tâches 11-12 (Provider) sont séquentielles.

## Notes

- Les tâches marquées `*` sont optionnelles mais fortement recommandées — elles constituent la couverture de tests de la Phase 3
- Le pont comptable Flutter et Python est **déjà implémenté** — les tâches 1-10 sont principalement de la vérification et de la documentation, sauf si des gaps sont découverts
- Pour les tests Python, utiliser `pytest` + SQLAlchemy en mémoire (SQLite via `create_engine('sqlite://')`)
- La tâche 11 (Provider) est la seule vraie nouvelle implémentation de la Phase 3
- `flutter_speed_dial` n'est pas disponible dans ce projet — ne pas l'utiliser
