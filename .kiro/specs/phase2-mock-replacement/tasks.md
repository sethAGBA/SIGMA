# Implementation Plan: Phase 2 — Remplacement des valeurs hardcodées

## Overview

Ce plan couvre le remplacement de toutes les valeurs hardcodées identifiées dans les 5 zones de l'application SIGMA Micro-Finance. Chaque tâche cible un fichier précis et référence l'exigence correspondante. Les modifications sont chirurgicales et s'appuient exclusivement sur `AuthService` (singleton existant) et `DatabaseService` (service existant).

## Tasks

- [x] 1. Ajouter la méthode `getLastCashClosing()` dans `DatabaseService`
  - Dans `lib/core/services/database_service.dart`, ajouter la méthode suivante qui interroge la table `clotures_caisse` triée par `date_cloture DESC LIMIT 1` et retourne un `CashClosing?`
  - Retourner `null` si la table est vide
  - _Exigences : 5.1, 5.2, 5.3_

  - [x]* 1.1 Écrire un test unitaire pour `getLastCashClosing()`
    - Tester sur base SQLite en mémoire (`:memory:`)
    - Cas 1 : table vide → retourne `null`
    - Cas 2 : une clôture présente → retourne la bonne valeur
    - _Exigences : 5.1, 5.3_

- [x] 2. Corriger `CashClosingDialog` — agent et solde initial
  - Dans `lib/screens/caisse/cash_closing_dialog.dart` :
    - Dans `_loadData()`, appeler `DatabaseService().getLastCashClosing()` et stocker `soldeInitial = result?.soldePhysique ?? 0.0`
    - Afficher le `soldeInitial` dans le résumé financier à côté du solde théorique
    - Dans `_submit()`, remplacer `'Agent Connecté'` par `AuthService().currentUsername`
    - Ajouter un guard dans `_submit()` : si `AuthService().currentUsername.isEmpty`, afficher `SnackBar('Aucun utilisateur connecté. Veuillez vous reconnecter.')` et interrompre
  - _Exigences : 4.1, 4.2, 5.1, 5.2, 5.3_

  - [ ]* 2.1 Écrire un test unitaire pour `CashClosingDialog`
    - Tester que `agentCloture` == username de la session
    - Tester que la soumission est bloquée si `currentUsername` est vide
    - Tester que `soldeInitial` == 0.0 quand aucune clôture précédente n'existe
    - _Exigences : 4.1, 4.2, 5.3_

  - [x]* 2.2 Écrire le property test P2 — Continuité du solde de caisse
    - **Propriété 2 : Continuité du solde de caisse entre clôtures**
    - **Valide : Exigence 5.2**
    - Pour toute valeur `soldePhysique` générée aléatoirement (double positif), créer C1 avec ce solde, le persister, puis vérifier que `getLastCashClosing().soldePhysique == soldeInitial` du prochain dialogue

- [x] 3. Corriger `RepaymentFormDialog` — agent collecteur
  - Dans `lib/screens/remboursements/repayment_form_dialog.dart` :
    - Remplacer `'SYSTÈME'` par `AuthService().currentUsername.isNotEmpty ? AuthService().currentUsername : 'Inconnu'` dans la construction du modèle `Repayment`
  - _Exigences : 6.1, 6.2_

  - [x]* 3.1 Écrire le property test P1 partiel — agentCollecteur = username
    - **Propriété 1 : Les champs d'audit contiennent le username de session (volet Repayment)**
    - **Valide : Exigence 6.1**
    - Pour tout username aléatoire non vide, vérifier que le modèle `Repayment` soumis a `agentCollecteur == username`

- [x] 4. Corriger `DailyCollectionPage` — en-tête et filtre retard
  - Dans `lib/screens/remboursements/daily_collection_page.dart` :
    - Remplacer `'COLLECTE DU JOUR - Agent: Jean KOUASSI'` par le texte dynamique utilisant `AuthService().currentUsername` avec repli `'Inconnu'`
    - Ajouter `bool _filterRetard = false` dans l'état
    - Transformer le widget texte `'Filtrer par retard'` en `TextButton` ou `InkWell` qui bascule `_filterRetard` et appelle `_refresh()`
    - Ajouter un indicateur visuel (couleur ou icône) quand `_filterRetard == true`
  - _Exigences : 7.1, 7.2, 8.1, 8.2, 8.3, 8.4_

  - [x] 4.1 Adapter `DatabaseService().getPendingSchedules()` pour accepter `retardOnly`
    - Ajouter le paramètre optionnel `bool retardOnly = false`
    - En mode `retardOnly = true`, ajouter `WHERE jours_retard > 0` (ou `joursRetard > 0` selon le nom de colonne SQL) à la requête
    - _Exigences : 8.2, 8.3_

  - [x]* 4.2 Écrire les property tests P3/P4 — filtre retard
    - **Propriété 3/4 : Filtre retard toggle idempotent et correct**
    - **Valide : Exigences 8.2, 8.3**
    - Pour toute liste d'échéances mixte générée, vérifier que le filtre actif ne retourne que `joursRetard > 0`, et que désactiver le filtre restitue la liste complète

- [x] 5. Corriger `SaisieComptablePage` — agent de saisie (×2 occurrences)
  - Dans `lib/screens/comptabilite/saisie_comptable_page.dart` :
    - Remplacer `initialValue: 'Admin'` par `initialValue: AuthService().currentUsername`
    - Remplacer `agentSaisie: 'Admin'` par `agentSaisie: AuthService().currentUsername.isNotEmpty ? AuthService().currentUsername : 'Inconnu'`
    - Ajouter l'import `AuthService` si absent
  - _Exigences : 9.1, 9.2, 9.3_

  - [x]* 5.1 Écrire le property test P1 partiel — agentSaisie = username
    - **Propriété 1 : Les champs d'audit contiennent le username de session (volet EcritureComptable)**
    - **Valide : Exigence 9.2**
    - Pour tout username aléatoire non vide, vérifier que l'écriture persistée a `agentSaisie == username`

- [x] 6. Ajouter le bouton FAB sur le Dashboard
  - Dans `lib/screens/dashboard/dashboard_page.dart` :
    - Ajouter un `FloatingActionButton.extended` ou un `SpeedDial` (package `flutter_speed_dial` si disponible, sinon `PopupMenuButton` natif)
    - Trois options : « Nouveau client », « Nouveau prêt », « Opération caisse »
    - Chaque option navigue vers la page correspondante via le `Navigator` de l'application
    - Désactiver les options si `AuthService().canAccess(...)` retourne false pour la permission requise
  - _Exigences : 3.1, 3.2, 3.3, 3.4, 3.5_

  - [x]* 6.1 Écrire un test unitaire pour le FAB
    - Vérifier que le menu présente les 3 options
    - Vérifier que l'option est désactivée quand `canAccess` retourne false
    - _Exigences : 3.1, 3.5_

- [x] 7. Vérifier et documenter les exigences déjà satisfaites
  - Confirmer que `DashboardPage._buildWelcomeSection()` utilise déjà `AuthService().currentUser?.username ?? 'Utilisateur'` (Exigence 1 — déjà satisfaite)
  - Confirmer que `DelinquentLoansListPage` passe déjà `loanId: id` dynamique (Exigences 10.1, 10.2, 10.3 — déjà satisfaites)
  - Ajouter un commentaire `// Phase 2 OK` dans les deux fichiers concernés
  - _Exigences : 1.1, 1.2, 10.1, 10.2, 10.3_

- [x] 8. Checkpoint — Vérifier que tous les tests passent
  - Lancer `flutter test` depuis la racine du projet
  - S'assurer que tous les tests unitaires et property tests passent
  - Corriger toute régression introduite par les modifications

- [x] 9. Écrire le property test P1 global — champs d'audit
  - Combiner les property tests partiels des tâches 3.1 et 5.1 en un seul test paramétrique
  - **Propriété 1 : Les champs d'audit contiennent le username de session**
  - **Valide : Exigences 4.1, 6.1, 9.2**
  - Pour tout username aléatoire non vide X, vérifier que `CashClosing.agentCloture`, `Repayment.agentCollecteur` et `EcritureComptable.agentSaisie` sont tous égaux à X

  - [x]* 9.1 Écrire le property test P5 — navigation dynamique
    - **Propriété 5 : La navigation vers le détail passe l'identifiant correct**
    - **Valide : Exigences 10.1, 10.3**
    - Pour tout identifiant de prêt entier aléatoire, simuler le tap dans `DelinquentLoansListPage` et vérifier que `DelinquentLoanDetailPage` reçoit le bon `loanId`

- [x] 10. Checkpoint final — Tous les tests passent
  - Lancer `flutter test` et `flutter analyze`
  - Confirmer l'absence de valeurs hardcodées résiduelles via `grep -r "'Admin'" lib/` et `grep -r "'Jean" lib/` et `grep -r "'SYSTÈME'" lib/`
  - Phase 2 terminée

## Task Dependency Graph

```
1 (getLastCashClosing) → 2 (CashClosingDialog)
4 → 4.1 (getPendingSchedules avec retardOnly)
3, 5 → 9 (property test P1 global)
1, 2, 3, 4, 4.1, 5, 6, 7 → 8 (checkpoint)
8 → 9 → 10 (checkpoint final)
```

## Notes

- Les tâches marquées `*` sont optionnelles et peuvent être sautées pour un MVP rapide
- Les property tests nécessitent la bibliothèque `dart_check` ou `fast_check` — vérifier la disponibilité dans `pubspec.yaml` avant d'implémenter
- La tâche 7 est de validation uniquement — elle confirme que deux exigences sont déjà couvertes par le code existant
- La tâche 4.1 est une sous-tâche de la tâche 4 mais doit être réalisée en premier car `DailyCollectionPage` en dépend
