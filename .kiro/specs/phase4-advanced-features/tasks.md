# Implementation Plan: Phase 4 — Fonctionnalités Métier Avancées

## Overview

La Phase 4 ajoute des fonctionnalités métier à des composants existants. Les modifications sont ciblées et s'appuient sur les services et modèles déjà en place. La migration SQLite passe de la version 29 à la version 30.

Les 4 axes d'implémentation sont :
1. **Produits & Prêts** — taux assurance, TEG, différé de capital
2. **Comité de crédit** — validation PIN superviseur
3. **Épargne DAT** — blocage retraits + pénalités rupture
4. **Clients** — épargne obligatoire auto + KYC upload + liaison groupe

## Tasks

- [x] 1. Migration SQLite v30 — Ajouter les nouvelles colonnes
  - Dans `lib/core/services/database_service.dart`, incrémenter `_version` de 29 à 30
  - Ajouter le bloc `if (oldVersion < 30)` dans `_onUpgrade` avec les DDL suivants :
    - `ALTER TABLE produits_financiers ADD COLUMN taux_assurance REAL`
    - `ALTER TABLE produits_financiers ADD COLUMN duree_max_differe_capital_mois INTEGER`
    - `ALTER TABLE prets ADD COLUMN mois_differe_capital INTEGER DEFAULT 0`
    - `ALTER TABLE comptes_epargne ADD COLUMN date_echeance_terme TEXT`
    - `ALTER TABLE comptes_epargne ADD COLUMN taux_penalite_rupture_ant REAL`
    - `CREATE TABLE IF NOT EXISTS documents_clients (id INTEGER PRIMARY KEY AUTOINCREMENT, client_id INTEGER NOT NULL, type_document TEXT NOT NULL, nom_fichier TEXT NOT NULL, chemin_local TEXT NOT NULL, date_ajout TEXT NOT NULL, FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE CASCADE)`
  - Ajouter les mêmes DDL dans `_onCreate` pour les nouvelles installations
  - _Exigences : 1.4, 3.5, 5.1, 5.2, 7.4_

  - [ ]* 1.1 Écrire le test de migration v29→v30
    - Vérifier que les 6 nouvelles colonnes/tables existent après migration
    - Vérifier la migration est idempotente (pas d'erreur si colonnes déjà présentes)
    - _Exigences : 1.4, 3.5, 5.1, 5.2_

- [x] 2. Mettre à jour le modèle `ProduitFinancier` — taux assurance + différé
  - Dans `lib/models/produit_financier_model.dart` :
    - Ajouter `final double? tauxAssurance` dans la classe
    - Ajouter `final int? dureeMaxDiffereCapitalMois` dans la classe
    - Mettre à jour `toMap()` avec `'taux_assurance'` et `'duree_max_differe_capital_mois'`
    - Mettre à jour `fromMap()` pour mapper ces deux nouvelles colonnes
    - Mettre à jour le constructeur
  - _Exigences : 1.1, 1.4, 1.5, 3.1_

- [x] 3. Mettre à jour le modèle `SavingsAccount` — DAT
  - Dans `lib/models/savings_account_model.dart` :
    - Ajouter `final DateTime? dateEcheanceTerme`
    - Ajouter `final double? tauxPenaliteRuptureAnt`
    - Mettre à jour `toMap()` et `fromMap()`
    - Mettre à jour le constructeur
  - _Exigences : 5.1, 5.2_

- [x] 4. Mettre à jour le modèle `Loan` — différé de capital
  - Dans `lib/models/loan_model.dart` :
    - Ajouter `final int? moisDiffereCapital`
    - Mettre à jour `toMap()` avec `'mois_differe_capital'`
    - Mettre à jour `fromMap()` pour mapper `mois_differe_capital`
  - _Exigences : 3.5_

- [x] 5. Créer `lib/core/utils/loan_calculator.dart` — TEG et amortissement avec différé
  - Créer le fichier (ou compléter s'il existe) avec la méthode statique :
    ```dart
    static double calculerTEG({
      required double tauxNominalAnnuel,
      double tauxAssurance = 0,
      double fraisDossier = 0,
      required double montantPret,
      required int dureesMois,
    })
    ```
  - Formule : `TEG = tauxNominalAnnuel + tauxAssurance + (fraisDossier / montantPret) / (dureesMois / 12) * 100`
  - Ajouter `calculerEcheancierAvecDiffere({montant, duree, taux, moisDiffere})` retournant `List<Map>` avec `capital_du`, `interets_dus`, `total_du` pour chaque mois
  - _Exigences : 2.1, 2.2, 3.4_

  - [x]* 5.1 Écrire les tests unitaires et property tests pour `LoanCalculator`
    - Test TEG sans assurance ni frais → TEG == taux nominal
    - Test TEG avec assurance 0.5% et frais 10 000 FCFA sur 100 000 FCFA 12 mois
    - **Propriété 1 : TEG ≥ tauxNominal** pour tout (montant, durée, taux, assurance, frais) positifs — 100 itérations
    - Test différé 2 mois : capital_du = 0 sur les 2 premières échéances, normal ensuite
    - **Propriété 2 : Somme des capitals_du = montantInitial** pour tout différé valide
    - _Exigences : 2.1, 2.2, 3.4_

- [x] 6. Mettre à jour `ProductFormDialog` — champs assurance et différé
  - Dans `lib/widgets/dialogs/product_form_dialog.dart` :
    - Ajouter un `TextFormField` pour `tauxAssurance` (suffixe `%/an`) dans la section paramètres crédit
    - Conditionner l'affichage du champ `dureeMaxDiffereCapitalMois` à `differePossible == true`
    - Pré-remplir ces champs en mode édition
  - _Exigences : 1.2, 3.2_

- [x] 7. Mettre à jour `LoanRequestFormDialog` — TEG et différé
  - Dans `lib/screens/prets/loan_request_form_dialog.dart` :
    - Ajouter l'affichage du TEG calculé (`LoanCalculator.calculerTEG(...)`) à côté du taux nominal
    - Recalculer le TEG en temps réel à chaque changement de montant / durée / produit sélectionné
    - Si le produit a `differePossible == true`, afficher un champ `moisDiffereCapital` entre 0 et `dureeMaxDiffereCapitalMois`
    - Afficher un badge orange si TEG > seuil d'usure (paramètre configurable, valeur par défaut 36%)
  - _Exigences : 2.3, 2.4, 2.5, 3.3_

  - [x] 7.1 Adapter la génération de l'échéancier pour inclure le différé
    - Dans `loan_request_detail_dialog.dart` (méthode `_disburseLoan`) :
      - Lire `loan.moisDiffereCapital`
      - Générer `moisDiffereCapital` échéances avec `capital_du = 0`
      - Générer les échéances restantes en amortissement normal
    - _Exigences : 3.4, 3.5_

- [x] 8. Créer `PinValidationDialog` — validation superviseur
  - Créer `lib/widgets/dialogs/pin_validation_dialog.dart` :
    - `TextField` obscur, maxLength=4, clavier numérique
    - Compteur de tentatives (max 3) affiché
    - Bouton « Valider » → appel `AuthService().validateSupervisorPin(pin)` (méthode à créer)
    - Si 3 échecs → fermer le dialog et retourner `false`
    - Retourne `true` si PIN valide, `false/null` sinon
  - Ajouter `validateSupervisorPin(String pin)` dans `AuthService` :
    - En mode online : appel API `POST /auth/validate-pin`
    - En mode offline : chercher dans `utilisateurs_systeme` locaux un superviseur avec `supervisor_pin`
  - _Exigences : 4.2, 4.3, 4.4, 4.5, 4.6_

- [x] 9. Intégrer la validation PIN dans le flux de déblocage de prêt
  - Dans `loan_request_detail_dialog.dart` :
    - Charger `seuilValidationPinFCFA` depuis `DatabaseService().getSeuilValidationPinFCFA()`
    - Si montant > seuil, afficher `PinValidationDialog` avant de procéder
    - Si PIN refusé ou annulé, interrompre le déblocage et afficher un SnackBar
  - _Exigences : 4.1, 4.2, 4.7_

- [x] 10. Créer `BreakDATDialog` — rupture anticipée DAT
  - Créer `lib/screens/epargne/break_dat_dialog.dart` :
    - Afficher : date d'échéance, intérêts acquis, taux de pénalité, pénalité calculée
    - Bouton « Valider avec PIN superviseur » → ouvre `PinValidationDialog`
    - Bouton « Annuler »
    - Retourne `true` (rupture confirmée) ou `false` (annulée)
  - _Exigences : 5.4, 5.5, 5.6_

- [x] 11. Intégrer la protection DAT dans `SavingsOperationDialog`
  - Dans `lib/screens/epargne/savings_operation_dialog.dart` → `_submit()` :
    - Avant de procéder à un retrait, vérifier `account.produit?.savingsCategory == SavingsCategory.bloquee`
    - Si oui et `DateTime.now().isBefore(account.dateEcheanceTerme)` :
      - Afficher `BreakDATDialog`
      - Si confirmé avec PIN : calculer la pénalité et la soustraire du montant de retrait ou du solde
      - Si annulé : interrompre sans message d'erreur
    - Si `dateEcheanceTerme` atteinte ou null → procéder normalement
  - _Exigences : 5.3, 5.4, 5.6, 5.7_

- [x] 12. Créer l'auto-ouverture du compte épargne obligatoire à la création client
  - Dans `lib/widgets/dialogs/client_form_dialog.dart` → après `ClientApiService().insertClient(...)` :
    - Chercher `DatabaseService().getProduits(type: ProductType.epargne)` et filtrer `savingsCategory == SavingsCategory.obligatoire`
    - Si produit trouvé : créer automatiquement un `SavingsAccount` avec `numeroCompte = 'CEP-${clientId}-${yyyyMM}'`
    - Appeler `DatabaseService().insertSavingsAccount(...)`
    - Afficher un `SnackBar` de confirmation
    - Si aucun produit obligatoire : pas d'exception
  - _Exigences : 6.1, 6.2, 6.3, 6.4, 6.5, 6.6_

  - [ ]* 12.1 Écrire le test unitaire pour l'auto-ouverture du compte épargne
    - Insérer un produit `SavingsCategory.obligatoire` dans une DB en mémoire
    - Créer un client → vérifier qu'un `SavingsAccount` est créé avec le bon format de numéro
    - Créer un client sans produit obligatoire → vérifier qu'aucun compte n'est créé et pas d'exception
    - _Exigences : 6.1, 6.2, 6.5_

- [x] 13. Ajouter l'upload KYC dans `ClientFormDialog`
  - Ajouter `file_picker: ^8.1.6` dans `pubspec.yaml`
  - Dans `lib/widgets/dialogs/client_form_dialog.dart` :
    - Liste des fichiers joints avec nom + taille formatée + icône + bouton suppression
    - Bouton « + Ajouter un document » → `FilePicker.platform.pickFiles(allowedExtensions: ['pdf','jpg','jpeg','png'])`
    - Validation : max 5 fichiers, max 10 Mo par fichier
    - À la soumission : copier les fichiers dans `{appDocDir}/kyc/{clientId}/` + insérer dans `documents_clients`
  - Ajouter `insertDocumentClient(...)` dans `DatabaseService`
  - _Exigences : 7.1, 7.2, 7.3, 7.4, 7.5, 7.6_

- [x] 14. Ajouter la liaison groupe solidaire dans `ClientFormDialog`
  - Dans `lib/widgets/dialogs/client_form_dialog.dart` :
    - Charger `DatabaseService().getGroupesSolidaires()` au chargement du formulaire
    - Ajouter un `DropdownButtonFormField<int?>` optionnel pour le groupe solidaire
    - Après création du client : si `_selectedGroupeId != null`, appeler `DatabaseService().addClientToGroup(groupeId, clientId)`
  - _Exigences : 8.1, 8.2, 8.3, 8.4_

- [x] 15. Mettre à jour `OpenSavingsAccountDialog` — champs DAT
  - Dans `lib/screens/epargne/open_savings_account_dialog.dart` :
    - Afficher `dateEcheanceTerme` si le produit sélectionné est `SavingsCategory.bloquee`
    - Afficher `tauxPenaliteRuptureAnt` si applicable
    - Persister ces champs via `DatabaseService().insertSavingsAccount()`
  - _Exigences : 5.1, 5.2_

- [x] 16. Checkpoint — Tous les tests Phase 4 passent
  - Lancer `flutter test`
  - Lancer `flutter analyze` — 0 erreur bloquante
  - Vérifier la migration SQLite v30 sur une base existante
  - _Exigences : toutes_

- [x] 17. Mettre à jour `analyse_projet.md`
  - Cocher toutes les tâches Phase 4 accomplies

## Task Dependency Graph

```json
{
  "waves": [
    { "wave": 1, "tasks": ["1", "2", "3", "4"] },
    { "wave": 2, "tasks": ["5", "6", "7", "8"] },
    { "wave": 3, "tasks": ["7.1", "9", "10", "12", "13", "14", "15"] },
    { "wave": 4, "tasks": ["11"] },
    { "wave": 5, "tasks": ["16"] },
    { "wave": 6, "tasks": ["17"] }
  ]
}
```

## Notes

- Les tâches marquées `*` sont optionnelles (tests)
- La tâche 1 (migration) est le prérequis de toutes les autres — elle doit être complétée en premier
- Les tâches 2, 3, 4 (modèles) sont indépendantes et peuvent s'exécuter en parallèle après la tâche 1
- La tâche 5 (`LoanCalculator`) est indépendante des modèles mais doit précéder les tâches 6 et 7
- La tâche 8 (`PinValidationDialog`) est réutilisée par les tâches 9 et 10 — l'implémenter avant
- Vérifier que `file_picker` est compatible avec Windows Desktop avant la tâche 13
