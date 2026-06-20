# Implementation Plan: Phase 6 — Conformité Réglementaire

## Overview

La Phase 6 aligne SIGMA sur les normes comptables SFD (RCSSFD/BCEAO) : référentiel comptable externalisé, exports auditeurs, PDF institutionnels, rapports SQL, fichiers plats BCEAO, relevés épargne et archivage contrats.

**Migration cible :** SQLite v31 → v32 (v33 prévue pour archivage contrat)

**3 vagues d'implémentation :**
1. **Vague 1** — Plan comptable RCSSFD + export balance + PDF branding
2. **Vague 2** — CustomReportPage SQL + exports BCEAO + relevés épargne PDF
3. **Vague 3** — Contrats PDF avancés + archivage scan contrat signé

## État initial

| Élément | État avant Phase 6 |
|---------|-------------------|
| Plan comptable | CSV SYSCOHADA inline dans `chart_of_accounts_service.dart` |
| Fichier RCSSFD | Référencé dans audit, absent du dépôt |
| Comptes auto Flutter | SYSCOHADA (271/571) — désaligné du backend Python (501/530) |
| Export balance | TODO dans `BalanceGeneralePage` |
| PDF contrat | En-tête statique « SIGMA MICRO-FINANCE » |
| CustomReportPage | Mock SnackBar, pas de SQL |

## Tasks

- [x] 1. Assets plan comptable + refactor `ChartOfAccountsService`
  - Extraire le CSV inline vers `lib/assets/docs/plan_comptable_syscohada.txt`
  - Créer `lib/assets/docs/Plan des Comptes RCSSFD.txt` (plan SFD UMOA)
  - Créer `lib/models/plan_comptable_type.dart` (`syscohada` | `rcssfd`)
  - Créer `lib/core/services/plan_comptable_loader.dart` (chargement `rootBundle`)
  - Refactorer `ChartOfAccountsService` : suppression CSV inline, `insertFullChartOfAccounts(db, type)`, `reseedChartOfAccounts()`
  - Déclarer les assets dans `pubspec.yaml`
  - _Exigences : 1.1, 1.2_

- [x] 2. Migration SQLite v32 + preset RCSSFD
  - Incrémenter `_version` de 31 à 32 dans `database_service.dart`
  - Ajouter `_applyPhase6Schema(db)` : insérer `plan_comptable_type = syscohada` si absent (bases migrées)
  - Ajouter `_seedPhase6Defaults(db)` : fresh install → `rcssfd` + `AccountingConfiguration.rcssfdDefault()`
  - Ajouter `getPlanComptableType()`, `switchPlanComptable(type)`
  - Ajouter `AccountingConfiguration.rcssfdDefault()` (501/530/521/701/703/602)
  - _Exigences : 1.3, 1.4, 1.5_

  - [x]* 2.1 Test migration v31→v32
    - Vérifier insertion `plan_comptable_type` après migration
    - Vérifier idempotence
    - _Exigences : 1.5_

- [x] 3. Sélecteur plan comptable dans configuration institution
  - Dans `institution_configuration_page.dart` → onglet Paramètres financiers :
    - Dropdown `PlanComptableType`
    - Dialog de confirmation avant `switchPlanComptable()`
  - _Exigences : 1.4_

- [x] 4. Export balance réglementaire CSV/Excel
  - Créer `lib/core/services/regulatory_export_service.dart`
  - `exportTrialBalanceCsv()` : UTF-8 BOM, séparateur `;`, métadonnées institution
  - Brancher bouton Exporter dans `balance_generale_page.dart`
  - _Exigences : 2.1, 2.2, 2.3, 2.4_

  - [ ]* 4.1 Test unitaire `RegulatoryExportService`
    - Vérifier format CSV (BOM, colonnes, totaux)
    - _Exigences : 2.1_

- [x] 5. En-têtes PDF dynamiques institution
  - Créer `lib/core/services/institution_pdf_branding.dart`
  - Brancher sur `PdfExportService.exportLoanContract()`
  - _Exigences : 3.1, 3.2, 3.3_

  - [ ]* 5.1 Généraliser le branding aux autres exports PDF (PAR, rapport mensuel)
    - _Exigences : 3.2_

- [ ] 6. Rapports dynamiques — vraies requêtes SQL
  - Créer `lib/core/services/custom_report_query_service.dart`
  - Mapper chaque indicateur `CustomReportPage` → requête SQL whitelistée
  - Afficher résultats dans un tableau + export PDF/CSV
  - Remplacer le mock `_generateReport()` (SnackBar 2s)
  - _Exigences : 4.1, 4.2_

- [ ] 7. Export BCEAO/Coban (fichiers plats)
  - Créer `lib/core/services/bceao_export_service.dart`
  - Exports : encours crédit, dépôts, PAR (CSV structuré, séparateur `|`)
  - UI : section dans module Reporting ou Comptabilité
  - _Exigences : 5.1, 5.2_

- [ ] 8. Relevés mensuels épargne PDF
  - Créer `lib/core/services/savings_statement_service.dart`
  - `generateMonthlyStatement(accountId, month, year)` avec `InstitutionPdfBranding`
  - Bouton « Générer relevé » dans détail compte épargne
  - _Exigences : 6.1, 6.2_

- [ ] 9. Contrats prêt PDF avancés
  - Créer `lib/core/services/loan_contract_template_service.dart`
  - Mapper variables SQL (client, montant, TEG, échéancier, garanties)
  - Layout multi-pages avec table d'amortissement
  - _Exigences : 7.1, 7.2_

- [ ] 10. Archivage légal contrat signé scanné
  - Migration v33 : `contrat_scan_path TEXT`, `contrat_scan_base64 TEXT` sur `prets`
  - Upload scan dans `loan_request_detail_dialog.dart` (file_picker / image_picker)
  - Affichage et téléchargement depuis détail prêt
  - _Exigences : 8.1, 8.2_

- [ ] 11. Checkpoint Phase 6
  - `flutter test` : tous les tests passent
  - `flutter analyze lib test` : 0 erreur
  - Vérifier export balance + bascule plan + PDF contrat avec institution configurée
  - _Exigences : toutes_

## Progression

| Vague | Tâches | Statut |
|-------|--------|--------|
| Vague 1 | 1–5 | ✅ Complète |
| Vague 2 | 6–8 | ⏳ À faire |
| Vague 3 | 9–10 | ⏳ À faire |
| Checkpoint | 11 | ⏳ À faire |

**Phase 6 : ~45%** (5/11 tâches principales)
