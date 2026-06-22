# Implementation Plan: Phase 2 — Corrections UI & Données Réelles

## Overview

Ce plan couvre le branchement de cinq zones UI sur des données réelles. Toutes les modifications sont chirurgicales et exploitent l'infrastructure existante. Les tâches sont organisées par dépendance : les nouvelles méthodes `DatabaseService` d'abord, puis les UI qui en dépendent, et enfin les checkpoints.

---

## Tasks

- [x] 1. Vérifier et compléter le modèle `DashboardData`
  - Lire `lib/models/dashboard_data.dart` : confirmer que `encours`, `collecteJour` et `par30` existent et sont de type `double`
  - Si un champ manque ou porte un nom différent, l'ajouter/renommer et mettre à jour `fromMap()` / `toMap()` ainsi que `DatabaseService().getHomeDashboardData()`
  - Ajouter un commentaire `// Phase 2 — BottomStatsBar` sur les trois champs concernés
  - _Exigences : 1.2, 1.4, 1.5_

- [x] 2. Brancher `BottomStatsBar` sur `DashboardNotifier`
  - Dans `lib/widgets/bottom_stats_bar.dart` :
    - Ajouter l'import `package:provider/provider.dart` et `DashboardNotifier`
    - Envelopper le `build()` dans `Consumer<DashboardNotifier>`
    - Remplacer `'15.45 M'` → `data != null ? _formatFcfa(data.encours) : '--'`
    - Remplacer `'2.34 M'` → `data != null ? _formatFcfa(data.collecteJour) : '--'`
    - Remplacer `'2.3%'` → `data != null ? '${data.par30.toStringAsFixed(1)}%' : '--'`
    - Ajouter la méthode helper `_formatFcfa(double value)` : ≥ 1M → `'X.XX M'`, ≥ 1K → `'X K'`, sinon `'X'`
  - _Exigences : 1.1, 1.2, 1.3, 1.6_

  - [ ]* 2.1 Écrire le test unitaire pour `BottomStatsBar`
    - Créer `test/widgets/bottom_stats_bar_test.dart`
    - Mocker `DashboardNotifier` avec `cachedData = null` → vérifier que `'--'` est affiché
    - Mocker avec `cachedData.encours = 15_450_000` → vérifier que `'15.45 M'` est affiché
    - _Exigences : 1.2, 1.3_

  - [ ]* 2.2 Écrire le property test P1 — Cohérence BottomStatsBar ↔ DashboardNotifier
    - **Propriété 1 : Cohérence BottomStatsBar ↔ DashboardNotifier**
    - **Valide : Exigences 1.2, 1.6**
    - Pour toute valeur `encours` double positive injectée dans le notifier, vérifier que la valeur affichée est non vide et ≠ `'--'`

- [x] 3. Ajouter `file_picker` dans `pubspec.yaml` (si absent)
  - Vérifier dans `pubspec.yaml` si `file_picker` est déjà présent (vraisemblablement ajouté en Phase 4/5)
  - Si absent : ajouter `file_picker: ^8.1.2` dans la section `dependencies`
  - Lancer `flutter pub get`
  - _Exigences : 2.2, 7.1_

- [x] 4. Ajouter `getGroupActiveLoansTotal()` dans `DatabaseService`
  - Dans `lib/core/services/database_service.dart`, ajouter la méthode :
    ```
    Future<double> getGroupActiveLoansTotal(int groupId)
    ```
  - Requête SQL : `SUM(p.capital_restant)` sur `prets JOIN clients` filtrée par `groupe_solidaire_id = groupId` et `statut IN ('ACTIF', 'EN_RETARD')`
  - Retourner `0.0` si aucun résultat ou exception (try/catch interne)
  - _Exigences : 4.1, 4.3_

  - [ ]* 4.1 Écrire les tests unitaires pour `getGroupActiveLoansTotal()`
    - Base SQLite en mémoire (`:memory:`)
    - Cas 1 : table vide → retourne 0.0
    - Cas 2 : 2 prêts actifs → retourne la somme correcte
    - Cas 3 : prêt clôturé (`statut = 'SOLDE'`) → ignoré
    - _Exigences : 4.1, 4.3_

- [x] 5. Ajouter `getGroupRepaymentRate()` dans `DatabaseService`
  - Dans `lib/core/services/database_service.dart`, ajouter la méthode :
    ```
    Future<double?> getGroupRepaymentRate(int groupId)
    ```
  - Requête SQL : `SUM(montant_du)` et `SUM(montant_paye)` sur `echeanciers JOIN prets JOIN clients` par `groupe_solidaire_id = groupId`
  - Si `totalDu <= 0` → retourner `null`
  - Sinon retourner `(totalPaye / totalDu) * 100`, clampé à `[0.0, 100.0]`
  - _Exigences : 5.1, 5.6_

  - [ ]* 5.1 Écrire les tests unitaires pour `getGroupRepaymentRate()`
    - Cas 1 : aucun prêt → retourne null
    - Cas 2 : 50% payé → retourne 50.0
    - Cas 3 : 100% payé → retourne 100.0
    - _Exigences : 5.1, 5.6_

  - [ ]* 5.2 Écrire le property test P4/P5 — Invariants métriques groupes
    - **Propriétés 4/5 : encours ≥ 0 et taux ∈ [0, 100] ou null**
    - **Valide : Exigences 4.1, 4.3, 5.1, 5.6**
    - Pour tout ensemble de prêts générés (montants doubles positifs), vérifier les invariants

- [x] 6. Ajouter `getGroupLoans()` dans `DatabaseService`
  - Dans `lib/core/services/database_service.dart`, ajouter la méthode :
    ```
    Future<List<Map<String, dynamic>>> getGroupLoans(int groupId)
    ```
  - Requête SQL : `SELECT` sur `prets JOIN clients` filtré par `groupe_solidaire_id = groupId`, ordonné par `date_deblocage DESC`
  - Retourner liste vide si aucun résultat
  - _Exigences : 6.3_

- [x] 7. Checkpoint A — Vérifier les nouvelles méthodes DatabaseService
  - Lancer `flutter test test/services/` (si tests écrits pour les tâches 4.1, 5.1)
  - Lancer `flutter analyze lib/core/services/database_service.dart` — 0 erreur
  - Corriger avant de continuer

- [x] 8. Refactoriser `_buildGroupMetrics()` dans `GroupListPage`
  - Dans `lib/screens/groupes/group_list_page.dart` :
    - Remplacer le `FutureBuilder<List<Client>>` existant de `_buildGroupMetrics()` par un `FutureBuilder<List<dynamic>>` utilisant `Future.wait([getGroupActiveLoansTotal(), getGroupRepaymentRate(), getGroupMembers()])`
    - Formatter l'encours avec la logique `_formatFcfa` (≥1M, ≥1K, sinon brut)
    - Appliquer la couleur selon le taux : vert ≥90%, orange ≥70%, rouge <70%, gris si null
    - Remplacer `'0 FCFA'` (placeholder) par la valeur dynamique
    - Remplacer `'100%'` (placeholder) par la valeur dynamique
  - _Exigences : 4.1, 4.2, 4.3, 4.4, 5.1, 5.2, 5.3, 5.4, 5.5, 5.6_

- [x] 9. Refactoriser `_buildPerformanceTab()` et `_buildLoansTab()` dans `GroupDetailDialog`
  - Dans `lib/widgets/dialogs/group_detail_dialog.dart` :
    - `_buildPerformanceTab()` : remplacer les `_buildInfoItem` hardcodés par un `FutureBuilder<List<dynamic>>` qui charge `getGroupActiveLoansTotal`, `getGroupRepaymentRate`, `getGroupLoans` en parallèle
    - `_buildLoansTab()` : remplacer le message `'Aucun prêt collectif enregistré'` (toujours affiché) par une vraie liste construite depuis `getGroupLoans(groupId)`
    - Calculer l'ancienneté en mois depuis `_group.dateCreation`
    - Utiliser `'—'` comme repli si une valeur est null
  - _Exigences : 6.1, 6.2, 6.3, 6.4_

- [x] 10. Implémenter l'export CSV dans `ClientListPage`
  - Dans `lib/screens/clients/client_list_page.dart` :
    - Ajouter les imports : `dart:convert`, `dart:typed_data`, `package:file_picker/file_picker.dart`, `package:intl/intl.dart`
    - Ajouter la méthode `_exportSelectedClients(List<Client> allClients)`
    - Générer le CSV avec en-tête `'\uFEFF'` + colonnes, une ligne par client sélectionné
    - Appeler `FilePicker.platform.saveFile()` avec `fileName = 'clients_export_YYYY-MM-DD.csv'`
    - SnackBar de succès / SnackBar d'erreur selon le résultat
    - Modifier `_buildBatchActionBar(context)` → `_buildBatchActionBar(context, clients)` pour passer la liste et appeler `_exportSelectedClients(clients)` au lieu du SnackBar simulé
  - _Exigences : 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

  - [ ]* 10.1 Écrire les tests unitaires pour l'export CSV
    - Cas 1 : 0 client sélectionné → guard, pas d'export
    - Cas 2 : 1 client → CSV avec 1 ligne de données + en-tête
    - Cas 3 : N clients → CSV avec N lignes, vérifier colonnes
    - _Exigences : 2.1, 2.3_

  - [ ]* 10.2 Écrire le property test P2 — CSV contient tous les clients sélectionnés
    - **Propriété 2 : Complétude du CSV**
    - **Valide : Exigences 2.1, 2.2**
    - Pour tout sous-ensemble S de clients générés (1 à 50 éléments), vérifier `len(lignes_csv) == len(S)`

- [x] 11. Implémenter la navigation SMS groupé dans `ClientListPage`
  - Dans `lib/screens/clients/client_list_page.dart` :
    - Remplacer le `SnackBar` simulé du bouton SMS par `Navigator.push` vers `SmsSendingPage(preSelectedClientIds: _selectedClientIds.toList())`
  - _Exigences : 3.1_

- [x] 12. Modifier `SmsSendingPage` pour accepter les pré-sélections
  - Dans `lib/screens/communications/sms_sending_page.dart` :
    - Ajouter le paramètre `final List<int> preSelectedClientIds`
    - Dans `_loadData()`, après chargement des clients, si `preSelectedClientIds.length == 1` → pré-remplir `_selectedClient`
    - Si `preSelectedClientIds.length > 1` → activer `_isBulkMode = true` et peupler `_bulkClients`
    - Ajouter l'état `bool _isBulkMode = false` et `List<Client> _bulkClients = []`
    - En mode `_isBulkMode` : afficher la liste des destinataires, le bouton envoyer itère et affiche `'SMS envoyés : X/N'`
  - _Exigences : 3.1, 3.2, 3.3, 3.4, 3.5_

- [x] 13. Implémenter le bouton Scan dans `SaisieComptablePage`
  - Dans `lib/screens/comptabilite/saisie_comptable_page.dart` :
    - Ajouter les imports `package:file_picker/file_picker.dart`
    - Ajouter les champs d'état `String? _attachedFilePath` et `String? _attachedFileName`
    - Ajouter la méthode `_pickAttachment()` ouvrant `FilePicker.platform.pickFiles()` avec `allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg']`
    - Afficher SnackBar d'avertissement si taille > 10 Mo (non bloquant)
    - Remplacer le `TODO` du bouton Scan par l'appel à `_pickAttachment()`
    - Renommer l'icône en `Icons.attach_file_rounded` et le label en `'Pièce jointe'`
    - Afficher le nom du fichier sous le bouton avec un `×` pour supprimer
  - _Exigences : 7.1, 7.2, 7.4, 7.5, 7.6_

  - [x] 13.1 Ajouter le champ `piecesJointes` dans `EcritureComptable` si absent
    - Lire `lib/models/ecriture_comptable_model.dart` : vérifier la présence de `piecesJointes`
    - Si absent : ajouter `final String? piecesJointes` + mise à jour `fromMap()` + `toMap()`
    - Dans `_validateAndSave()` de `SaisieComptablePage`, passer `piecesJointes: _attachedFilePath` à la construction de `EcritureComptable`
    - _Exigences : 7.3_

- [x] 14. Checkpoint B — Vérifier l'ensemble des corrections UI
  - Lancer `flutter analyze` — 0 erreur bloquante
  - Lancer `flutter test` — tous les tests passent
  - Vérifier manuellement :
    - `BottomStatsBar` affiche des valeurs non hardcodées
    - Export CSV crée un vrai fichier avec les colonnes attendues
    - Bouton SMS navigue vers `SmsSendingPage`
    - Cartes de groupes affichent encours et taux calculés
    - Bouton Scan ouvre le sélecteur de fichier

- [x] 15. Vérifier l'absence des anciens placeholders
  - Lancer `grep -rn "'15.45 M'" lib/`  → 0 résultat
  - Lancer `grep -rn "'2.34 M'" lib/`   → 0 résultat
  - Lancer `grep -rn "'Exportation des données en cours" lib/` → 0 résultat
  - Lancer `grep -rn "'Préparation de l" lib/`  → 0 résultat
  - Lancer `grep -rn "Fonctionnalité de scan" lib/` → 0 résultat
  - Lancer `grep -rn "'0 FCFA'" lib/screens/groupes/` → 0 résultat
  - Lancer `grep -rn "'100%'" lib/screens/groupes/` → 0 résultat
  - Phase 2 terminée

---

## Task Dependency Graph

```json
{
  "waves": [
    { "wave": 1, "tasks": ["1", "3"] },
    { "wave": 2, "tasks": ["2", "4", "5", "6"] },
    { "wave": 3, "tasks": ["2.1", "2.2", "4.1", "5.1", "5.2"] },
    { "wave": 4, "tasks": ["7"] },
    { "wave": 5, "tasks": ["8", "9", "10", "11", "13"] },
    { "wave": 6, "tasks": ["10.1", "10.2", "12", "13.1"] },
    { "wave": 7, "tasks": ["14"] },
    { "wave": 8, "tasks": ["15"] }
  ]
}
```

**Dépendances critiques :**
- Tâche 2 dépend de la tâche 1 (DashboardData vérifié)
- Tâches 8 et 9 dépendent des tâches 4, 5 et 6 (méthodes DB créées)
- Tâche 12 dépend de la tâche 11 (navigation SMS implémentée)
- Tâche 13.1 dépend de la tâche 13 (Scan implémenté)
- Tâche 14 (checkpoint) dépend de toutes les tâches d'implémentation

---

## Notes

- Les tâches marquées `*` sont optionnelles (tests) mais fortement recommandées
- `file_picker` est très probablement déjà présent en Phase 4/5 — la tâche 3 est une simple vérification
- Les colonnes SQL (`groupe_solidaire_id`, `capital_restant`, `montant_du`, `montant_paye`) doivent correspondre aux noms réels dans `DatabaseService._createTables()` — vérifier avant d'écrire les requêtes des tâches 4, 5, 6
- La `BottomStatsBar` est rendue dans `MainLayout` qui est bien dans l'arbre `MultiProvider` de `main.dart` — pas de problème de contexte Provider
- Pour `_buildBatchActionBar`, il faut passer `clients` en paramètre car il provient du `FutureBuilder` — ajuster la signature et tous les appels
- En mode `_isBulkMode` de `SmsSendingPage`, désactiver l'`Autocomplete` de sélection individuelle et afficher la liste fixe des destinataires
