# Bugfix Requirements Document

## Introduction

Deux bugs critiques affectent la Phase 6 de SIGMA (conformité réglementaire RCSSFD/BCEAO), empêchant le bon fonctionnement du plan comptable pour les institutions déjà installées. Le premier bug provoque l'affichage du plan SYSCOHADA au lieu de RCSSFD après une migration v31→v32. Le second corrompait les libellés des comptes dans les deux fichiers assets en raison d'un double-encoding Windows-1252/UTF-8.

## Bug Analysis

### Current Behavior (Defect)

**Bug 1 — Migration v31→v32 : plan SYSCOHADA persisté à tort**

1.1 WHEN une base existante est migrée de v31 à v32 via `_onUpgrade`, THEN the system insère uniquement `plan_comptable_type = 'syscohada'` dans `configurations` sans appeler `insertFullChartOfAccounts()` avec le type RCSSFD

1.2 WHEN un utilisateur ouvre l'interface comptable après une migration v31→v32, THEN the system affiche le plan SYSCOHADA (comptes 271/571) alors que la norme SFD exige RCSSFD (comptes 501/530)

1.3 WHEN `_applyPhase6Schema()` s'exécute sur une base migrée sans plan défini, THEN the system n'exécute pas de reseed du plan comptable, laissant `comptes_comptables` avec les entrées SYSCOHADA existantes

**Bug 2 — Libellés corrompus dans les fichiers assets plan comptable**

1.4 WHEN `PlanParser.parse()` traite le fichier `plan_comptable_syscohada.txt`, THEN the system insère des libellés corrompus contenant des séquences `Ã©`, `Ã `, `Ã¨`, `â€™`, `Ã®` à la place des caractères accentués français

1.5 WHEN `PlanParser.parse()` traite le fichier `Plan des Comptes RCSSFD.txt`, THEN the system insère des libellés tronqués ou illisibles contenant `r?`, `cr?`, `?` à la place de caractères accentués tels que `é`, `è`, `â`

1.6 WHEN les deux fichiers assets sont chargés via `rootBundle`, THEN the system lit des octets Windows-1252 interprétés comme UTF-8, produisant un double-encoding silencieux sans erreur ni avertissement

### Expected Behavior (Correct)

**Bug 1 — Fix migration v31→v32**

2.1 WHEN une base existante est migrée de v31 à v32 et qu'aucun `plan_comptable_type` n'est encore défini, THEN the system SHALL appeler `ChartOfAccountsService().reseedChartOfAccounts(db, PlanComptableType.rcssfd)` pour peupler `comptes_comptables` avec le plan RCSSFD

2.2 WHEN `_applyPhase6Schema()` s'exécute après migration v31→v32 sans plan défini, THEN the system SHALL insérer `plan_comptable_type = 'rcssfd'` dans `configurations` (au lieu de `'syscohada'`)

2.3 WHEN une base existante est migrée de v31 à v32 et qu'un `plan_comptable_type` est déjà défini, THEN the system SHALL CONTINUE TO préserver la valeur existante sans écraser ni reseeder

**Bug 2 — Fix encodage assets**

2.4 WHEN `PlanParser.parse()` traite le fichier `plan_comptable_syscohada.txt` après correction, THEN the system SHALL insérer des libellés lisibles avec les caractères accentués français corrects (`é`, `è`, `à`, `â`, `î`, `ô`, `ù`, `ê`)

2.5 WHEN `PlanParser.parse()` traite le fichier `Plan des Comptes RCSSFD.txt` après correction, THEN the system SHALL insérer les ~170 libellés RCSSFD sans corruption ni troncature

2.6 WHEN `PlanParser.parse()` rencontre des séquences de caractères suspects typiques d'un double-encoding (ex : `Ã`, `â€`), THEN the system SHALL émettre un avertissement via `debugPrint` pour faciliter le diagnostic

### Unchanged Behavior (Regression Prevention)

3.1 WHEN une nouvelle installation est créée via `_onCreate`, THEN the system SHALL CONTINUE TO appeler `insertFullChartOfAccounts(db, type: PlanComptableType.rcssfd)` et insérer `plan_comptable_type = 'rcssfd'` via `_seedPhase6Defaults()`

3.2 WHEN l'utilisateur bascule manuellement le plan via `switchPlanComptable(type)` depuis `InstitutionConfigurationPage`, THEN the system SHALL CONTINUE TO appeler `reseedChartOfAccounts(db, type)` et mettre à jour le mapping automatique et la configuration

3.3 WHEN la migration v31→v32 s'applique sur une base déjà migrée (idempotence), THEN the system SHALL CONTINUE TO ne pas dupliquer la clé `plan_comptable_type` dans `configurations`

3.4 WHEN `getPlanComptableType()` est appelé après migration, THEN the system SHALL CONTINUE TO retourner le type stocké dans `configurations` sans lever d'exception

3.5 WHEN `PlanParser.parse()` traite un fichier asset UTF-8 propre sans caractères suspects, THEN the system SHALL CONTINUE TO parser le format `code;libellé` et retourner la liste complète des `AccountingAccount` avec hiérarchie parentale

---

## Bug Condition Pseudocode

### Bug 1 — Condition déclenchante

```pascal
FUNCTION isBugCondition_Migration(context)
  INPUT: context de type MigrationContext
  OUTPUT: boolean
  
  RETURN context.migrationPath = 'upgrade'
    AND context.oldVersion < 32
    AND context.newVersion >= 32
    AND NOT EXISTS(SELECT 1 FROM configurations WHERE key = 'plan_comptable_type')
END FUNCTION
```

```pascal
// Property: Fix Checking — Migration RCSSFD
FOR ALL ctx WHERE isBugCondition_Migration(ctx) DO
  _applyPhase6Schema'(db)
  planType ← SELECT value FROM configurations WHERE key = 'plan_comptable_type'
  comptesCaisse ← SELECT * FROM comptes_comptables WHERE numero = '530'
  ASSERT planType = 'rcssfd'
  ASSERT comptesCaisse IS NOT EMPTY
END FOR

// Property: Preservation Checking
FOR ALL ctx WHERE NOT isBugCondition_Migration(ctx) DO
  ASSERT _applyPhase6Schema'(db) = _applyPhase6Schema(db)  // comportement identique
END FOR
```

### Bug 2 — Condition déclenchante

```pascal
FUNCTION isBugCondition_Encoding(filePath)
  INPUT: filePath de type String
  OUTPUT: boolean
  
  // Un fichier sauvegardé en Windows-1252 et lu comme UTF-8
  content ← rootBundle.loadString(filePath)
  RETURN CONTAINS(content, 'Ã') OR CONTAINS(content, 'â€') OR CONTAINS(content, '?')
END FUNCTION
```

```pascal
// Property: Fix Checking — Libellés propres
FOR ALL line IN parsedLines WHERE isBugCondition_Encoding(assetPath) DO
  libelle ← PlanParser'.parse(line).libelle
  ASSERT NOT CONTAINS(libelle, 'Ã')
  ASSERT NOT CONTAINS(libelle, 'â€')
  ASSERT NOT CONTAINS(libelle, '?') // substitution Unicode
END FOR

// Property: Preservation Checking
FOR ALL line IN parsedLines WHERE NOT isBugCondition_Encoding(assetPath) DO
  ASSERT PlanParser'(line) = PlanParser(line)  // parsing identique sur fichiers propres
END FOR
```
