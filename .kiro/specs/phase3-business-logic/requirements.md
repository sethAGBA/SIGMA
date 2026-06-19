# Document des Exigences — Phase 3 : Logique Métier Centrale

## Introduction

La Phase 3 couvre la logique métier centrale du projet SIGMA Micro-Finance. Elle comprend trois axes :

1. **Pont comptable automatique** — génération automatique des écritures comptables à chaque opération financière (prêt, remboursement, épargne), côté Flutter (SQLite offline) et côté backend Python (PostgreSQL).
2. **Jobs nocturnes APScheduler** — calcul automatique des pénalités, recalcul des scores crédit, et capitalisation des intérêts épargne.
3. **State management Dashboard** — élimination des recalculs à chaque navigation via Provider/Riverpod.

**Constat préalable** : Les axes 1 et 2 sont déjà implémentés à ~95%. Cette spec documente l'existant, identifie les gaps, et définit les tâches de complétion et de test.

## Glossaire

- **AutomaticAccountingService (Flutter)** : Service Dart (`lib/core/services/automatic_accounting_service.dart`) générant les écritures comptables dans SQLite lors des opérations offline.
- **AutomaticAccountingService (Python)** : Service Python (`backend/app/services/accounting_service.py`) générant les écritures comptables dans PostgreSQL lors des appels API.
- **PenaltyService** : Service Python calculant les pénalités de retard journalières sur les échéances non soldées.
- **ScoringService** : Service Python recalculant le score crédit (0-100) de chaque client actif.
- **APScheduler** : Bibliothèque Python de planification de jobs asynchrones.
- **EcritureComptable** : Modèle représentant une écriture dans le journal comptable avec ses lignes débit/crédit.
- **LigneEcriture** : Ligne d'une écriture comptable (compte, libellé, montant débit, montant crédit).
- **AccountingConfiguration** : Modèle Dart stockant les numéros de comptes configurables (caisse, prêts, dépôts, intérêts, pénalités).
- **HomeDashboardData** : Objet Dart agrégeant KPIs, alertes, graphiques et agents pour le dashboard.
- **DashboardNotifier** : Futur `ChangeNotifier` (ou `StateNotifier` Riverpod) gérant le cache du dashboard.

---

## Exigences

### Exigence 1 : Pont comptable automatique — Déblocage de prêt

**User Story :** En tant que comptable, je veux qu'un déblocage de prêt génère automatiquement une écriture comptable Débit 501 / Crédit 530, afin que la comptabilité soit toujours synchronisée avec les opérations de crédit.

#### Critères d'acceptation

1. WHEN un prêt est débloqué via `DatabaseService.insertLoan()`, THE `AutomaticAccountingService` SHALL générer une écriture `Débit comptePrets / Crédit compteCaisse` avec le montant initial du prêt.
2. WHEN un prêt est débloqué via l'API `POST /prets`, THE `AutomaticAccountingService` Python SHALL générer une écriture `Débit 501 / Crédit 530` dans PostgreSQL.
3. THE écriture SHALL être créée dans la même transaction que l'insertion du prêt — si l'écriture échoue, le prêt ne doit pas être persisté.
4. IF `AutomaticAccountingService` lève une exception lors du déblocage, THE `DatabaseService` SHALL logger l'erreur et ne pas bloquer la création du prêt (dégradation gracieuse côté Flutter offline).
5. THE numéro de pièce SHALL suivre le format `DBL-YYYYMMDD-NNNN` où NNNN est un compteur séquentiel.

---

### Exigence 2 : Pont comptable automatique — Remboursement de prêt

**User Story :** En tant que comptable, je veux qu'un remboursement génère automatiquement une écriture Débit 530 / Crédit 501 + 701 + 703, afin que l'encaissement et sa décomposition soient tracés comptablement.

#### Critères d'acceptation

1. WHEN un remboursement est enregistré via `DatabaseService.insertRepayment()`, THE `AutomaticAccountingService` SHALL générer une écriture avec `Débit compteCaisse` égal au `montantTotal`, et les crédits répartis entre `comptePrets` (capital), `compteInterets` (intérêts), `comptePenalites` (pénalités).
2. WHEN un remboursement est enregistré via l'API `POST /remboursements`, THE `AutomaticAccountingService` Python SHALL générer l'écriture `Débit 530 / Crédit 501 + 701 + 703` dans PostgreSQL.
3. IF `partInterets == 0`, THE écriture SHALL ne pas inclure de ligne crédit sur `compteInterets`.
4. IF `partPenalites == 0`, THE écriture SHALL ne pas inclure de ligne crédit sur `comptePenalites`.
5. THE écriture SHALL être créée dans la même transaction que l'insertion du remboursement.

---

### Exigence 3 : Pont comptable automatique — Dépôt et retrait épargne

**User Story :** En tant que comptable, je veux que chaque transaction d'épargne génère automatiquement une écriture comptable, afin que les mouvements de caisse et les dépôts clients soient retracés.

#### Critères d'acceptation

1. WHEN un dépôt épargne est enregistré, THE `AutomaticAccountingService` SHALL générer `Débit compteCaisse / Crédit compteDepots` avec le montant de la transaction.
2. WHEN un retrait épargne est enregistré, THE `AutomaticAccountingService` SHALL générer `Débit compteDepots / Crédit compteCaisse` avec le montant de la transaction.
3. WHEN un dépôt est enregistré via l'API `POST /epargne/transactions`, THE backend SHALL appeler `on_depot_epargne()` ou `on_retrait_epargne()` selon le `type_operation`.
4. IF `type_operation` n'est ni `DEPOT` ni `RETRAIT`, THE API SHALL retourner HTTP 400 sans créer d'écriture.
5. THE écriture SHALL être créée dans la même transaction SQLite/PostgreSQL que la transaction épargne.

---

### Exigence 4 : Pont comptable — Dotation aux provisions

**User Story :** En tant que directeur financier, je veux pouvoir enregistrer une dotation aux provisions sur créances douteuses, afin que le risque de crédit soit correctement provisionné dans les comptes.

#### Critères d'acceptation

1. WHEN `AutomaticAccountingService.createProvisionEntry(amount)` est appelé, THE service SHALL générer `Débit compteDotationProvisions / Crédit compteDepreciationPrets` avec le montant fourni.
2. THE libellé SHALL être `'Dotation aux provisions sur créances douteuses'`.
3. THE écriture SHALL utiliser le journal `OD` (opérations diverses).

---

### Exigence 5 : Job nocturne — Calcul des pénalités de retard

**User Story :** En tant qu'administrateur, je veux que les pénalités de retard soient calculées et appliquées automatiquement chaque nuit, afin que les montants dus soient toujours à jour sans intervention manuelle.

#### Critères d'acceptation

1. WHEN le job `daily_penalties` s'exécute à 00h05, THE `PenaltyService` SHALL scanner toutes les échéances dont `statut != 'Payé'` et `date_prevue < aujourd'hui`.
2. FOR chaque échéance en retard, THE `PenaltyService` SHALL calculer `pénalité = capital_restant × taux_journalier × jours_retard` et mettre à jour `frais_dus` et `total_du`.
3. THE taux de pénalité journalier par défaut SHALL être `0.001` (0,1% par jour) si aucun taux n'est défini sur le produit financier.
4. WHEN le `jours_retard` calculé pour un prêt dépasse `pret.jours_retard` actuel, THE `PenaltyService` SHALL mettre à jour `pret.jours_retard`.
5. WHEN le job se termine, THE scheduler SHALL logger le nombre d'échéances traitées et le total des pénalités calculées.
6. IF une exception survient pendant le job, THE scheduler SHALL logger l'erreur et ne pas crasher le serveur.

---

### Exigence 6 : Job nocturne — Recalcul des scores crédit

**User Story :** En tant que chef d'agence, je veux que le score de crédit de chaque client soit recalculé automatiquement chaque nuit, afin d'avoir un indicateur de risque toujours à jour pour les décisions de crédit.

#### Critères d'acceptation

1. WHEN le job `nightly_scoring` s'exécute à 02h00, THE `ScoringService` SHALL recalculer le score de tous les clients dont `statut == 'Actif'`.
2. THE score SHALL être calculé sur une base de 60 points avec les ajustements suivants : +5 si ≥2 prêts soldés, +5 par prêt sans retard, -10 par prêt avec retard, +10 si taux remboursement ≥ 95%, -15 si taux remboursement < 80%.
3. THE score SHALL être clampé entre 0 et 100.
4. THE niveau de risque SHALL être déterminé ainsi : score ≥ 70 → `'Faible'`, score ≥ 40 → `'Moyen'`, score < 40 → `'Élevé'`.
5. WHEN le job se termine, THE scheduler SHALL logger le nombre de clients traités.

---

### Exigence 7 : Job mensuel — Capitalisation des intérêts épargne

**User Story :** En tant que directeur, je veux que les intérêts sur les comptes d'épargne soient capitalisés automatiquement le 1er de chaque mois, afin que les clients reçoivent leurs intérêts sans intervention manuelle.

#### Critères d'acceptation

1. WHEN le job `monthly_interests` s'exécute le 1er du mois à 01h00, THE job SHALL traiter tous les comptes d'épargne dont `statut == 'Actif'`.
2. FOR chaque compte éligible, THE job SHALL calculer `intérêts = round(solde × taux_annuel / 100 / 12, 0)`.
3. IF `taux_annuel ≤ 0` ou `solde ≤ 0` ou `intérêts calculés ≤ 0`, THE job SHALL ignorer ce compte sans erreur.
4. WHEN les intérêts sont calculés, THE job SHALL créditer `compte.solde` et `compte.interets_acquis`, créer une `TransactionEpargne` de type `INTERETS`, et générer l'écriture `Débit 602 / Crédit 521`.
5. IF une exception survient pendant le traitement d'un compte, THE job SHALL effectuer un rollback et logger l'erreur sans interrompre le traitement des autres comptes.

---

### Exigence 8 : Planification APScheduler

**User Story :** En tant qu'administrateur système, je veux que les trois jobs soient planifiés automatiquement au démarrage du serveur FastAPI, afin qu'ils s'exécutent de manière fiable sans configuration manuelle.

#### Critères d'acceptation

1. WHEN le serveur FastAPI démarre, THE `start_scheduler()` SHALL enregistrer les 3 jobs avec leurs triggers cron respectifs : `daily_penalties` à 00h05, `monthly_interests` le 1er du mois à 01h00, `nightly_scoring` à 02h00.
2. THE scheduler SHALL utiliser `replace_existing=True` pour éviter les doublons en cas de redémarrage.
3. IF un job est déjà en cours d'exécution lors de son prochain déclenchement, THE scheduler SHALL ignorer ce déclenchement (comportement par défaut APScheduler `misfire_grace_time`).

---

### Exigence 9 : State management Dashboard — Cache des données

**User Story :** En tant qu'utilisateur, je veux que le tableau de bord se charge instantanément lors des navigations répétées, afin de ne pas attendre le rechargement des données à chaque fois que je reviens sur l'écran.

#### Critères d'acceptation

1. WHEN les données du dashboard sont chargées pour la première fois, THE `DashboardNotifier` SHALL stocker les `HomeDashboardData` en mémoire et les exposer via un `ValueNotifier` ou `StateNotifier`.
2. WHEN l'utilisateur navigue vers une autre page puis revient sur le dashboard, THE `DashboardPage` SHALL afficher les données en cache immédiatement sans déclencher de nouveau appel à `DatabaseService` ou `ApiService`.
3. WHEN le `RefreshIndicator` est déclenché manuellement, THE `DashboardNotifier` SHALL forcer le rechargement des données depuis la source (API si connecté, SQLite sinon).
4. WHEN `AuthService.logout()` est appelé, THE `DashboardNotifier` SHALL effacer le cache pour éviter d'afficher les données d'un autre utilisateur.
5. THE `DashboardNotifier` SHALL être un singleton injecté via le mécanisme de state management choisi (Provider ou Riverpod).
6. IF le rechargement échoue, THE `DashboardNotifier` SHALL conserver les données en cache et exposer une erreur non bloquante.
