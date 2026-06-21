# Implementation Plan: Phase 6 — Conformité Réglementaire

## Overview

La Phase 6 aligne SIGMA sur les normes comptables SFD (RCSSFD/BCEAO) : référentiel comptable externalisé, exports auditeurs, PDF institutionnels, rapports SQL, fichiers plats BCEAO, relevés épargne et archivage contrats.

**Migration cible :** SQLite v31 → v32 (v33 prévue pour archivage contrat)

**3 vagues d'implémentation :**
1. **Vague 1** — Plan comptable RCSSFD + export balance + PDF branding
2. **Vague 2** — CustomReportPage SQL + exports BCEAO + relevés épargne PDF
3. **Vague 3** — Contrats PDF avancés + archivage scan contrat signé

## Task Dependency Graph

```
0 → 6
0-BIS → 6
1 → 6
2 → 6
3 → 6
4 → 6
5 → 6
6 → 11
7 → 11
8 → 11
9 → 11
10 → 11
```

## Tasks

- [x] 0. Bugfix — Corriger _applyPhase6Schema migration v31 vers v32 doit seeder RCSSFD
  - Dans `lib/core/services/database_service.dart`, méthode `_applyPhase6Schema()` :
    - Si `plan_comptable_type` absent : appeler `ChartOfAccountsService().reseedChartOfAccounts(db, PlanComptableType.rcssfd)`
    - Insérer `plan_comptable_type = 'rcssfd'` (non plus `'syscohada'`)
    - Si `plan_comptable_type` présent : ne rien faire (idempotence préservée)
  - _Exigences : 1-BUG1.1, 1-BUG1.2, 1-BUG1.3_

  - [ ]* 0.1 Test migration Bug1
    - Simuler une base v31 sans plan → vérifier que `plan_comptable_type = 'rcssfd'` et que compte 530 existe
    - Simuler une base v31 avec plan existant → vérifier absence de modification
    - _Exigences : 1-BUG1.1, 1-BUG1.2_

- [x] 1. Assets plan comptable et refactor ChartOfAccountsService
  - Extraire le CSV inline vers `lib/assets/docs/plan_comptable_syscohada.txt`
  - Créer `lib/assets/docs/Plan des Comptes RCSSFD.txt` (plan SFD UMOA)
  - Créer `lib/models/plan_comptable_type.dart` (`syscohada` | `rcssfd`)
  - Créer `lib/core/services/plan_comptable_loader.dart` (chargement `rootBundle`)
  - Refactorer `ChartOfAccountsService` : suppression CSV inline, `insertFullChartOfAccounts(db, type)`, `reseedChartOfAccounts()`
  - Déclarer les assets dans `pubspec.yaml`
  - _Exigences : 1.1, 1.2_

- [x] 2. Migration SQLite v32 et preset RCSSFD
  - Incrémenter `_version` de 31 à 32 dans `database_service.dart`
  - Ajouter `_applyPhase6Schema(db)` et `_seedPhase6Defaults(db)`
  - Ajouter `getPlanComptableType()`, `switchPlanComptable(type)`
  - Ajouter `AccountingConfiguration.rcssfdDefault()` (501/530/521/701/703/602)
  - _Exigences : 1.3, 1.4, 1.5_

  - [x]* 2.1 Test migration v31 vers v32
    - Vérifier insertion `plan_comptable_type` après migration
    - Vérifier idempotence
    - _Exigences : 1.5_

- [x] 3. Correctif encodage fichiers assets plan comptable
  - Réécrire `lib/assets/docs/plan_comptable_syscohada.txt` en UTF-8 propre
  - Réécrire `lib/assets/docs/Plan des Comptes RCSSFD.txt` en UTF-8 propre
  - Ajouter détection préventive dans `lib/core/utils/plan_parser.dart`
  - _Exigences : 1-BUG2.1, 1-BUG2.2, 1-BUG2.3_

  - [ ]* 3.1 Test encodage assets
    - Parser les deux fichiers corrigés et vérifier l'absence de séquences corrompues
    - Vérifier que le compte 501 a le libellé correct
    - _Exigences : 1-BUG2.1, 1-BUG2.2_

- [x] 4. Selecteur plan comptable dans configuration institution
  - Dans `institution_configuration_page.dart` : Dropdown `PlanComptableType` + Dialog de confirmation
  - _Exigences : 1.4_

- [x] 5. Export balance reglementaire CSV Excel
  - Créer `lib/core/services/regulatory_export_service.dart`
  - `exportTrialBalanceCsv()` : UTF-8 BOM, séparateur `;`, métadonnées institution
  - Brancher bouton Exporter dans `balance_generale_page.dart`
  - _Exigences : 2.1, 2.2, 2.3, 2.4_

  - [ ]* 5.1 Test unitaire RegulatoryExportService
    - Vérifier format CSV (BOM, colonnes, totaux)
    - _Exigences : 2.1_

- [x] 6. En-tetes PDF dynamiques institution
  - Créer `lib/core/services/institution_pdf_branding.dart`
  - Brancher sur `PdfExportService.exportLoanContract()`
  - _Exigences : 3.1, 3.2, 3.3_

  - [ ]* 6.1 Generaliser le branding aux autres exports PDF PAR et rapport mensuel
    - _Exigences : 3.2_

- [x] 7. Rapports dynamiques — vraies requetes SQL
  - Créer `lib/core/services/custom_report_query_service.dart`
  - Mapper chaque indicateur `CustomReportPage` → requête SQL whitelistée
  - Afficher résultats dans un tableau + export PDF/CSV
  - Remplacer le mock `_generateReport()` (SnackBar 2s)
  - _Exigences : 4.1, 4.2_

- [x] 8. Export BCEAO Coban fichiers plats
  - Créer `lib/core/services/bceao_export_service.dart`
  - Exports : encours crédit, dépôts, PAR (CSV structuré, séparateur `|`)
  - UI : section dans module Reporting ou Comptabilité
  - _Exigences : 5.1, 5.2_

- [x] 9. Releves mensuels epargne PDF
  - Créer `lib/core/services/savings_statement_service.dart`
  - `generateMonthlyStatement(accountId, month, year)` avec `InstitutionPdfBranding`
  - Bouton Générer relevé dans détail compte épargne
  - _Exigences : 6.1, 6.2_

- [x] 10. Contrats pret PDF avances
  - Créer `lib/core/services/loan_contract_template_service.dart`
  - Mapper variables SQL (client, montant, TEG, échéancier, garanties)
  - Layout multi-pages avec table d'amortissement
  - _Exigences : 7.1, 7.2_

- [x] 11. Archivage legal contrat signe scanne
  - Migration v33 : `contrat_scan_path TEXT`, `contrat_scan_base64 TEXT` sur `prets`
  - Upload scan dans `loan_request_detail_dialog.dart` (file_picker / image_picker)
  - Affichage et téléchargement depuis détail prêt
  - _Exigences : 8.1, 8.2_

- [x] 12. Checkpoint Phase 6
  - `flutter test` : tous les tests passent
  - `flutter analyze lib test` : 0 erreur
  - Vérifier export balance + bascule plan + PDF contrat avec institution configurée
  - _Exigences : toutes_

## Notes

Vague 1 (tâches 0-6) : terminée — bugfixes encodage et migration inclus.
Vague 2 (tâches 7-9) : à implémenter.
Vague 3 (tâches 10-11) : à implémenter.
Checkpoint (tâche 12) : dernière étape.
