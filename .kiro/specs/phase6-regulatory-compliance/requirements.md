# Document des Exigences — Phase 6 : Conformité Réglementaire

## Introduction

La Phase 6 aligne SIGMA sur les exigences comptables et réglementaires des **Systèmes Financiers Décentralisés (SFD)** de l'UMOA : plan comptable RCSSFD, exports auditeurs, documents PDF institutionnels, rapports dynamiques et fichiers plats BCEAO.

### Périmètre Phase 6

| Axe | Description |
|-----|-------------|
| **Plan comptable RCSSFD** | Référentiel asset + bascule SYSCOHADA/RCSSFD + mapping comptes automatiques |
| **Export balance** | CSV Excel (UTF-8 BOM, `;`) conforme auditeurs SYSCOHADA/RCSSFD |
| **PDF institutionnels** | En-têtes/pieds dynamiques depuis `LegalInformation` |
| **Rapports dynamiques** | `CustomReportPage` avec vraies requêtes SQL |
| **Exports BCEAO/Coban** | Fichiers plats CSV structurés |
| **Relevés épargne** | PDF mensuels automatiques |
| **Contrats prêt avancés** | Layout officiel avec variables SQL |
| **Archivage légal** | Contrat signé scanné (Blob/Base64) lié au prêt |

### État de l'existant

- `ChartOfAccountsService` embarquait un CSV SYSCOHADA inline (~1400 lignes) sans asset fichier.
- `AccountingConfiguration` utilisait des comptes SYSCOHADA (271, 571…) alors que le backend Python utilise RCSSFD (501, 530, 521).
- `BalanceGeneralePage` : boutons Imprimer/Exporter non branchés.
- `PdfExportService.exportLoanContract()` : en-tête statique « SIGMA MICRO-FINANCE ».
- `CustomReportPage` : simulation SnackBar sans SQL.
- Fichier `lib/assets/docs/Plan des Comptes RCSSFD.txt` référencé dans l'audit mais absent du dépôt.

## Glossaire

- **RCSSFD** : Référentiel Comptable Spécifique des SFD (instruction BCEAO n°025-02-2009).
- **SYSCOHADA** : Plan comptable OHADA général (référentiel entreprises).
- **PlanComptableType** : Enum `syscohada` | `rcssfd` stocké en `configurations.plan_comptable_type`.
- **RegulatoryExportService** : Service d'export balance et futurs exports réglementaires.
- **InstitutionPdfBranding** : En-tête/pied PDF depuis `LegalInformation`.

---

## Exigences

### Exigence 1 : Plan comptable RCSSFD

**User Story :** En tant que comptable, je veux utiliser le plan RCSSFD officiel, afin que mes écritures correspondent aux normes BCEAO.

#### Critères d'acceptation

1. THE application SHALL charger le plan SYSCOHADA depuis `lib/assets/docs/plan_comptable_syscohada.txt`.
2. THE application SHALL charger le plan RCSSFD depuis `lib/assets/docs/Plan des Comptes RCSSFD.txt`.
3. WHEN une nouvelle installation est créée, THE default plan SHALL be `rcssfd` avec `AccountingConfiguration.rcssfdDefault()`.
4. WHEN l'utilisateur change le plan dans `InstitutionConfigurationPage`, THE system SHALL reseeder `comptes_comptables` et mettre à jour le mapping automatique après confirmation.
5. THE migration v32 SHALL persister `plan_comptable_type` sans écraser les comptes existants (valeur `syscohada` pour bases migrées).

### Exigence 2 : Export balance réglementaire

**User Story :** En tant qu'auditeur externe, je veux exporter la balance au format Excel français, afin de l'intégrer dans mes outils d'audit.

#### Critères d'acceptation

1. THE `RegulatoryExportService.exportTrialBalanceCsv()` SHALL produire un CSV UTF-8 BOM avec séparateur `;`.
2. THE en-tête du fichier SHALL inclure : raison sociale, n° agrément, IFU, période, date export, type de plan.
3. THE colonnes SHALL être : N° Compte, Libellé, Total Débit, Total Crédit, Solde Débiteur, Solde Créditeur.
4. WHEN l'utilisateur clique Exporter dans `BalanceGeneralePage`, THE fichier SHALL être sauvegardé dans `{appDocDir}/exports/`.

### Exigence 3 : PDF dynamiques institution

**User Story :** En tant qu'administrateur, je veux que les PDF affichent les informations légales de mon institution.

#### Critères d'acceptation

1. THE `InstitutionPdfBranding` SHALL lire `LegalInformation` depuis la base.
2. THE en-tête SHALL afficher raison sociale, titre document, agrément, adresse si renseignés.
3. THE `exportLoanContract()` SHALL utiliser `InstitutionPdfBranding` au lieu du libellé statique SIGMA.

### Exigence 4 : Rapports dynamiques (à implémenter)

**User Story :** En tant que directeur, je veux construire des rapports SQL personnalisés.

#### Critères d'acceptation

1. THE `CustomReportPage` SHALL exécuter des requêtes SQL paramétrées (indicateurs prédéfinis).
2. THE résultats SHALL être exportables en PDF et CSV.

### Exigence 5 : Exports BCEAO/Coban (à implémenter)

**User Story :** En tant que responsable conformité, je veux générer les fichiers plats BCEAO.

#### Critères d'acceptation

1. THE system SHALL produire des CSV structurés (séparateurs et colonnes réglementaires).
2. THE exports SHALL couvrir au minimum : encours crédit, dépôts, PAR.

### Exigence 6 : Relevés épargne PDF (à implémenter)

**User Story :** En tant que client épargnant, je veux recevoir un relevé mensuel PDF.

#### Critères d'acceptation

1. THE job ou action manuelle SHALL générer un PDF par compte épargne actif.
2. THE relevé SHALL inclure mouvements du mois et solde final.

### Exigence 7 : Contrats prêt avancés (à implémenter)

**User Story :** En tant qu'agent crédit, je veux un contrat PDF au format officiel.

#### Critères d'acceptation

1. THE contrat SHALL mapper toutes les variables métier (montant, TEG, garanties, échéancier).
2. THE layout SHALL être configurable par template institution.

### Exigence 8 : Archivage contrat signé (à implémenter)

**User Story :** En tant qu'institution, je veux archiver le scan du contrat signé.

#### Critères d'acceptation

1. THE colonne `contrat_scan_base64` (ou chemin fichier) SHALL être liée au prêt.
2. THE scan SHALL être consultable depuis le détail prêt.
